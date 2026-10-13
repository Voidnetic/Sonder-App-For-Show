import 'package:flutter/material.dart';

import 'data/api_client.dart';
import 'data/models.dart';
import 'screens/global_camera_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/moments_archive_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SonderApi.instance.restoreSession();
  runApp(const SonderApp());
}

class SonderApp extends StatelessWidget {
  const SonderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

/// Shows the login screen while signed out and the main app while signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: SonderApi.instance.currentUser,
      builder: (context, user, _) => user == null ? const LoginScreen() : const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Built fresh on every tab switch so each tab shows up-to-date data.
  Widget _buildScreen() {
    switch (_currentIndex) {
      case 1:
        return const GlobalCameraScreen();
      case 2:
        return const MomentsArchiveScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  Widget _buildCustomBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.kBackground,
        border: Border(top: BorderSide(color: AppTheme.kBorder, width: 1.5)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_filled, "Home", 0),
            _navItem(Icons.camera_alt_outlined, "Camera", 1),
            _navItem(Icons.style_outlined, "Moments", 2),
            _navItem(Icons.face_retouching_natural, "Profile", 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.kTextPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppTheme.kBackground : AppTheme.kTextSecondary,
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.kTextPrimary : AppTheme.kTextSecondary,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
