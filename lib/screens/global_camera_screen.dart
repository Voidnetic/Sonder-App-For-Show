import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/photo_picker.dart';
import '../widgets/status_views.dart';

class GlobalCameraScreen extends StatefulWidget {
  const GlobalCameraScreen({super.key});

  @override
  State<GlobalCameraScreen> createState() => _GlobalCameraScreenState();
}

class _GlobalCameraScreenState extends State<GlobalCameraScreen> {
  late Future<List<Moment>> _moments;
  String? _selectedMomentId;
  bool _uploading = false;
  bool _isCaptured = false;

  @override
  void initState() {
    super.initState();
    _moments = _loadMoments();
  }

  Future<List<Moment>> _loadMoments() async {
    final moments = await SonderApi.instance.getActiveMoments();
    if (moments.isNotEmpty && !moments.any((m) => m.id == _selectedMomentId)) {
      _selectedMomentId = moments.first.id;
    }
    return moments;
  }

  Future<void> _capture(ImageSource source) async {
    final momentId = _selectedMomentId;
    if (momentId == null || _uploading || _isCaptured) return;
    try {
      final photo = await pickPhoto(source);
      if (photo == null || !mounted) return;
      setState(() => _uploading = true);
      await SonderApi.instance.uploadMemory(momentId, photo.bytes, photo.filename);
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _isCaptured = true;
      });
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isCaptured = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kTextPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR WITH TAB INDICATION
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "QUICK CAPTURE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.kPaleYellow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.kBorder, width: 1.5),
                    ),
                    child: const Text(
                      "Tab 2 / 4",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.kTextPrimary),
                    ),
                  ),
                ],
              ),
            ),

            // CAMERA VIEWFINDER BOX
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: AppTheme.kSoftMint, offset: Offset(4, 4))],
                ),
                child: Center(child: _buildViewfinderContent()),
              ),
            ),

            // TARGET MOMENT SELECTOR & SHUTTER BUTTON
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: FutureBuilder<List<Moment>>(
                future: _moments,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView(color: Colors.white);
                  }
                  if (snapshot.hasError) {
                    return _message(snapshot.error.toString(), retry: true);
                  }
                  final moments = snapshot.data!;
                  if (moments.isEmpty) {
                    return _message('No active moments.\nCreate one on the Home tab first.');
                  }
                  return Column(
                    children: [
                      const Text(
                        "SENDING TO MOMENT:",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.kBorder, width: 2),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedMomentId,
                          dropdownColor: Colors.white,
                          underline: const SizedBox(),
                          isExpanded: true,
                          style: const TextStyle(
                            color: AppTheme.kTextPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                          items: [
                            for (final moment in moments)
                              DropdownMenuItem<String>(
                                value: moment.id,
                                child: Text(moment.title, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMomentId = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Choose from gallery',
                            icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                            onPressed: () => _capture(ImageSource.gallery),
                          ),
                          const SizedBox(width: 32),
                          // SHUTTER BUTTON
                          GestureDetector(
                            onTap: () => _capture(ImageSource.camera),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _isCaptured ? AppTheme.kSoftMint : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.kBorder, width: 4),
                                boxShadow: const [BoxShadow(color: AppTheme.kLavender, offset: Offset(3, 3))],
                              ),
                              child: Center(
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: _isCaptured ? AppTheme.kSoftMint : AppTheme.kTextPrimary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 80),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinderContent() {
    if (_uploading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            "UPLOADING...",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ],
      );
    }
    if (_isCaptured) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.kSoftMint, size: 80),
          SizedBox(height: 16),
          Text(
            "MEMORY STORED",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          SizedBox(height: 8),
          Text(
            "Locked until reveal time 🔒",
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_rounded, color: Colors.white38, size: 80),
        SizedBox(height: 12),
        Text(
          "Tap the shutter to capture",
          style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ],
    );
  }

  Widget _message(String text, {bool retry = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        if (retry) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _moments = _loadMoments();
            }),
            child: const Text('RETRY', style: TextStyle(color: AppTheme.kPaleYellow, fontWeight: FontWeight.w900)),
          ),
        ],
      ],
    );
  }
}
