import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';

class GlobalCameraScreen extends StatefulWidget {
  const GlobalCameraScreen({super.key});

  @override
  State<GlobalCameraScreen> createState() => _GlobalCameraScreenState();
}

class _GlobalCameraScreenState extends State<GlobalCameraScreen> {
  bool _isCaptured = false;
  String _selectedMomentTarget = "Birthday Night";

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
                child: Center(
                  child: _isCaptured
                      ? const Column(
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
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_rounded, color: Colors.white38, size: 80),
                            SizedBox(height: 12),
                            Text(
                              "Viewfinder Active",
                              style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            // TARGET MOMENT SELECTOR & SHUTTER BUTTON
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    "SENDING TO MOMENT:",
                    style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
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
                      value: _selectedMomentTarget,
                      dropdownColor: Colors.white,
                      underline: const SizedBox(),
                      isExpanded: true,
                      style: const TextStyle(color: AppTheme.kTextPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                      items: MockData.activeMoments.map((moment) {
                        return DropdownMenuItem<String>(
                          value: moment.title,
                          child: Text(moment.title),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMomentTarget = val);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SHUTTER BUTTON
                  GestureDetector(
                    onTap: _isCaptured
                        ? null
                        : () {
                            setState(() => _isCaptured = true);
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) setState(() => _isCaptured = false);
                            });
                          },
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}