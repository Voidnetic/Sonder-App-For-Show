import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/photo_picker.dart';
import '../widgets/status_views.dart';

/// Captures a memory for one moment. Pops with `true` when a photo was uploaded.
class CameraScreen extends StatefulWidget {
  final Moment moment;

  const CameraScreen({super.key, required this.moment});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  PickedPhoto? _photo;
  bool _uploading = false;
  bool _isCaptured = false;

  Future<void> _capture(ImageSource source) async {
    if (_uploading || _isCaptured) return;
    try {
      final photo = await pickPhoto(source);
      if (photo == null || !mounted) return;
      setState(() {
        _photo = photo;
        _uploading = true;
      });
      await SonderApi.instance.uploadMemory(widget.moment.id, photo.bytes, photo.filename);
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _isCaptured = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR: Close button & Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context, _isCaptured),
                  ),
                  const Text(
                    "New instant",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 48), // Balance spacing
                ],
              ),
            ),

            // INSTAGRAM-STYLE CURVED VIEWFINDER
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(36), // Curved DazzCam/Instants corners
                  border: Border.all(color: AppTheme.kBorder, width: 2),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_photo != null)
                      Opacity(
                        opacity: _isCaptured ? 0.35 : 1,
                        child: Image.memory(_photo!.bytes, fit: BoxFit.cover),
                      ),
                    Center(child: _buildViewfinderOverlay()),

                    // Top-left curved text overlay stamp (like Instagram Instants)
                    Positioned(
                      top: 24,
                      left: 24,
                      right: 24,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${widget.moment.title.toUpperCase()} 📸",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // CAMERA CONTROLS (Gallery & Shutter)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Choose from gallery',
                    icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                    onPressed: () => _capture(ImageSource.gallery),
                  ),
                  const SizedBox(width: 40),
                  // Shutter Button
                  GestureDetector(
                    onTap: () => _capture(ImageSource.camera),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 88),
                ],
              ),
            ),

            // BOTTOM GROUP TARGET PILL (Instagram Instants style)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.kTextPrimary,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.kBorder, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.moment.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinderOverlay() {
    if (_uploading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            "SECURING MEMORY...",
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
        ],
      );
    }
    if (_isCaptured) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.kSoftMint, size: 80),
          SizedBox(height: 16),
          Text(
            "MEMORY SECURED 🔒",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
        ],
      );
    }
    if (_photo != null) return const SizedBox.shrink();
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.camera_rounded, color: Colors.white24, size: 70),
        SizedBox(height: 12),
        Text(
          "Tap the shutter to take a photo",
          style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
