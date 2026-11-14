import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/photo_picker.dart';
import '../utils/time_format.dart';
import '../widgets/status_views.dart';

/// Full-screen camera for capturing a memory.
///
/// With [moment] set it captures into that moment and pops with `true` after an upload. Without it
/// (the Camera tab) the user picks any active moment with the "Sending to" button.
class CaptureScreen extends StatefulWidget {
  final Moment? moment;

  const CaptureScreen({super.key, this.moment});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

enum _Phase { ready, uploading, secured }

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _yellow = Color(0xFFFFD84D);
  static const _zoomSteps = [0.5, 1.0, 2.0, 3.0, 5.0];

  // Camera
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraController? _controller;
  bool _cameraFailed = false;
  FlashMode _flash = FlashMode.off;
  bool _grid = true;
  double _minZoom = 1, _maxZoom = 1, _zoom = 1, _pinchStartZoom = 1;
  Offset? _focusPoint;
  Timer? _focusTimer;

  // Moments
  List<Moment>? _moments;
  Object? _momentsError;
  Moment? _target;

  // Capture state
  _Phase _phase = _Phase.ready;
  bool _capturedAny = false;
  late final AnimationController _shutterPulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  late final AnimationController _securedPop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  bool get _fixedMoment => widget.moment != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _target = widget.moment;
    if (!_fixedMoment) _loadMoments();
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _controller?.dispose();
    _shutterPulse.dispose();
    _securedPop.dispose();
    super.dispose();
  }

  // The camera must be released while the app is in the background and reopened afterwards.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller = null;
      controller?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && controller == null && _cameras.isNotEmpty) {
      _openCamera(_cameras[_cameraIndex]);
    }
  }

  // ------------------------------------------------------------------ camera

  Future<void> _startCamera() async {
    try {
      _cameras = await availableCameras();
    } catch (_) {
      _cameras = const [];
    }
    if (!mounted) return;
    if (_cameras.isEmpty) {
      setState(() => _cameraFailed = true);
      return;
    }
    _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    if (_cameraIndex < 0) _cameraIndex = 0;
    await _openCamera(_cameras[_cameraIndex]);
  }

  Future<void> _openCamera(CameraDescription description) async {
    final old = _controller;
    final controller = CameraController(description, ResolutionPreset.veryHigh, enableAudio: false);
    setState(() {
      _controller = null;
      _cameraFailed = false;
    });
    await old?.dispose();
    try {
      await controller.initialize();
      // Zoom and flash are extras: some cameras don't report them, and that shouldn't stop the preview.
      var minZoom = 1.0, maxZoom = 1.0;
      try {
        minZoom = await controller.getMinZoomLevel();
        maxZoom = await controller.getMaxZoomLevel();
      } catch (_) {}
      final flash = description.lensDirection == CameraLensDirection.front ? FlashMode.off : _flash;
      try {
        await controller.setFlashMode(flash);
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoom = 1.clamp(minZoom, maxZoom).toDouble();
        _flash = flash;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _phase != _Phase.ready) return;
    final current = _cameras[_cameraIndex].lensDirection;
    final next = _cameras.indexWhere((c) => c.lensDirection != current);
    _cameraIndex = next < 0 ? (_cameraIndex + 1) % _cameras.length : next;
    await _openCamera(_cameras[_cameraIndex]);
  }

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await controller.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {
      // This camera has no flash.
    }
  }

  Future<void> _setZoom(double zoom) async {
    final controller = _controller;
    if (controller == null) return;
    final value = zoom.clamp(_minZoom, _maxZoom).toDouble();
    setState(() => _zoom = value);
    await controller.setZoomLevel(value).catchError((_) {});
  }

  void _focusAt(TapUpDetails details, BoxConstraints constraints) {
    final controller = _controller;
    if (controller == null) return;
    final point = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    controller.setFocusPoint(point).catchError((_) {});
    controller.setExposurePoint(point).catchError((_) {});
    _focusTimer?.cancel();
    setState(() => _focusPoint = details.localPosition);
    _focusTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  // ------------------------------------------------------------------ moments

  Future<void> _loadMoments() async {
    setState(() {
      _moments = null;
      _momentsError = null;
    });
    try {
      final moments = await SonderApi.instance.getActiveMoments();
      if (!mounted) return;
      setState(() {
        _moments = moments;
        if (_target == null || !moments.any((m) => m.id == _target!.id)) {
          _target = moments.isEmpty ? null : moments.first;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _momentsError = e);
    }
  }

  Future<void> _chooseMoment() async {
    final moments = _moments;
    if (moments == null || moments.isEmpty) return;
    final chosen = await showModalBottomSheet<Moment>(
      context: context,
      backgroundColor: AppTheme.kBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: AppTheme.kBorder, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Send to which moment?', style: AppTheme.display(22)),
              const SizedBox(height: 14),
              for (final m in moments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, m),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: m.accentColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.kBorder, width: 2),
                        boxShadow: m.id == _target?.id
                            ? const [BoxShadow(color: AppTheme.kBorder, offset: Offset(3, 3))]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(m.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                          Text(
                            revealDescription(m.unlockAt).replaceFirst('Reveals ', ''),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
                          ),
                          if (m.id == _target?.id) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle_rounded, size: 20),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _target = chosen);
  }

  // ------------------------------------------------------------------ capture

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || controller.value.isTakingPicture) return;
    if (_target == null || _phase != _Phase.ready) return;
    _shutterPulse.forward(from: 0);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
      await _upload(bytes, name);
    } catch (e) {
      if (mounted) showErrorSnack(context, e is ApiException ? e : 'Could not take the photo. Please try again.');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_target == null || _phase != _Phase.ready) return;
    try {
      final photo = await pickPhoto(ImageSource.gallery);
      if (photo == null || !mounted) return;
      await _upload(photo.bytes, photo.filename);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _upload(Uint8List bytes, String filename) async {
    final target = _target!;
    setState(() => _phase = _Phase.uploading);
    try {
      await SonderApi.instance.uploadMemory(target.id, bytes, filename);
    } catch (e) {
      if (mounted) {
        setState(() => _phase = _Phase.ready);
        showErrorSnack(context, e);
      }
      return;
    }
    if (!mounted) return;
    _capturedAny = true;
    setState(() => _phase = _Phase.secured);
    _securedPop.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    if (_fixedMoment) {
      Navigator.pop(context, true);
    } else {
      setState(() => _phase = _Phase.ready);
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _viewfinder(),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const SizedBox(height: 18),
                _lockBadge(),
                const Spacer(),
                if (_controller != null && _phase == _Phase.ready) _zoomPills(),
                const SizedBox(height: 18),
                _shutterRow(),
                const SizedBox(height: 14),
                _momentButton(),
                const SizedBox(height: 14),
              ],
            ),
          ),
          if (_phase != _Phase.ready) _captureOverlay(),
        ],
      ),
    );
  }

  Widget _viewfinder() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        color: const Color(0xFF141414),
        alignment: Alignment.center,
        child: _cameraFailed
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.no_photography_outlined, color: Colors.white38, size: 56),
                    SizedBox(height: 12),
                    Text(
                      'Camera not available.\nAllow camera access in Settings, or pick a photo from the gallery.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white54, strokeWidth: 3),
      );
    }
    // Fill the screen with the preview, cropping the edges like the phone's own camera app.
    final previewSize = controller.value.previewSize;
    final aspect = previewSize == null ? controller.value.aspectRatio : previewSize.height / previewSize.width;
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onTapUp: (details) => _focusAt(details, constraints),
        onScaleStart: (_) => _pinchStartZoom = _zoom,
        onScaleUpdate: (details) {
          if (details.pointerCount == 2) _setZoom(_pinchStartZoom * details.scale);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(width: 1000, height: 1000 / aspect, child: CameraPreview(controller)),
              ),
            ),
            if (_grid) const IgnorePointer(child: CustomPaint(painter: _ThirdsGridPainter())),
            if (_focusPoint != null)
              Positioned(
                left: _focusPoint!.dx - 40,
                top: _focusPoint!.dy - 40,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_focusPoint),
                  tween: Tween(begin: 1.4, end: 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: const SizedBox(
                    width: 80,
                    height: 80,
                    child: CustomPaint(painter: _FocusBracketPainter(_yellow)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final flashIcon = switch (_flash) {
      FlashMode.auto => Icons.flash_auto_rounded,
      FlashMode.always => Icons.flash_on_rounded,
      _ => Icons.flash_off_rounded,
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (_fixedMoment)
            _topIcon(Icons.close_rounded, 'Close', () => Navigator.pop(context, _capturedAny))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('CAPTURE', style: AppTheme.display(18, color: Colors.white)),
            ),
          _topIcon(flashIcon, 'Flash', _controller == null ? null : _cycleFlash, active: _flash != FlashMode.off),
          _topIcon(Icons.grid_on_rounded, 'Grid', () => setState(() => _grid = !_grid), active: _grid),
          _topIcon(Icons.flip_camera_android_rounded, 'Flip camera', _cameras.length < 2 ? null : _flipCamera),
        ],
      ),
    );
  }

  Widget _topIcon(IconData icon, String tooltip, VoidCallback? onTap, {bool active = false}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 26, color: onTap == null ? Colors.white24 : (active ? _yellow : Colors.white)),
    );
  }

  /// The yellow pill near the top, like a camera app's "FRAME LOCKED" badge.
  Widget _lockBadge() {
    final target = _target;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'LOCKED UNTIL REVEAL 🔒',
            style: TextStyle(color: _yellow, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          target == null ? 'Nobody will see it until the countdown ends' : revealDescription(target.unlockAt),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
        ),
      ],
    );
  }

  Widget _zoomPills() {
    final steps = _zoomSteps.where((z) => z >= _minZoom - 0.01 && z <= _maxZoom + 0.01).toList();
    if (steps.length < 2) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final z in steps)
            GestureDetector(
              onTap: () => _setZoom(z),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_zoom - z).abs() < 0.05 ? Colors.black : Colors.transparent,
                ),
                child: Text(
                  (_zoom - z).abs() < 0.05 ? '${_formatZoom(z)}x' : _formatZoom(z),
                  style: TextStyle(
                    color: (_zoom - z).abs() < 0.05 ? _yellow : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatZoom(double z) => z == z.roundToDouble() ? z.toInt().toString() : z.toString();

  Widget _shutterRow() {
    final canShoot = _controller != null && _target != null && _phase == _Phase.ready;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _roundButton(Icons.photo_library_rounded, 'Choose from gallery',
            _target != null && _phase == _Phase.ready ? _pickFromGallery : null),
        GestureDetector(
          onTap: canShoot ? _shoot : null,
          child: AnimatedBuilder(
            animation: _shutterPulse,
            builder: (context, child) {
              final t = _shutterPulse.value;
              final squeeze = t < 0.5 ? t * 2 : (1 - t) * 2;
              return Transform.scale(scale: 1 - 0.12 * squeeze, child: child);
            },
            child: Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: canShoot ? Colors.white : Colors.white30, width: 4),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: canShoot ? Colors.white : Colors.white30),
              ),
            ),
          ),
        ),
        _roundButton(Icons.flip_camera_android_rounded, 'Flip camera', _cameras.length < 2 ? null : _flipCamera),
      ],
    );
  }

  Widget _roundButton(IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: onTap == null ? Colors.white30 : Colors.white, size: 26),
        ),
      ),
    );
  }

  /// "Sending to …": tap it to choose another moment (only on the Camera tab).
  Widget _momentButton() {
    final target = _target;
    String label;
    if (target != null) {
      label = target.title;
    } else if (_momentsError != null) {
      label = "Couldn't load moments · tap to retry";
    } else if (_moments == null) {
      label = 'Loading moments…';
    } else {
      label = 'No active moments · create one on Home';
    }
    final canChoose = !_fixedMoment && (_moments?.length ?? 0) > 1;
    return GestureDetector(
      onTap: _momentsError != null ? _loadMoments : (canChoose ? _chooseMoment : null),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: target?.accentColor ?? Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.kBorder, width: 2),
          boxShadow: const [BoxShadow(color: _yellow, offset: Offset(3, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_rounded, size: 18, color: AppTheme.kTextPrimary),
            const SizedBox(width: 8),
            if (target != null)
              const Text('Sending to ', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary)),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kTextPrimary),
              ),
            ),
            if (canChoose) ...[
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.kTextPrimary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _captureOverlay() {
    final secured = _phase == _Phase.secured;
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: secured
          ? ScaleTransition(
              scale: CurvedAnimation(parent: _securedPop, curve: Curves.elasticOut),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.kSoftMint, size: 86),
                  const SizedBox(height: 14),
                  Text('MEMORY SECURED 🔒', style: AppTheme.display(26, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text(
                    'Locked until reveal time',
                    style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                SizedBox(height: 16),
                Text(
                  'SECURING MEMORY…',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                ),
              ],
            ),
    );
  }
}

/// Rule-of-thirds lines over the preview.
class _ThirdsGridPainter extends CustomPainter {
  const _ThirdsGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3, y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Four corner brackets where the user tapped to focus.
class _FocusBracketPainter extends CustomPainter {
  final Color color;

  const _FocusBracketPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    const arm = 18.0;
    final w = size.width, h = size.height;
    for (final corner in [Offset.zero, Offset(w, 0), Offset(0, h), Offset(w, h)]) {
      final dx = corner.dx == 0 ? arm : -arm, dy = corner.dy == 0 ? arm : -arm;
      canvas.drawLine(corner, corner + Offset(dx, 0), paint);
      canvas.drawLine(corner, corner + Offset(0, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FocusBracketPainter oldDelegate) => oldDelegate.color != color;
}
