import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/api_client.dart';
import 'data/push_service.dart';
import 'screens/global_camera_screen.dart';
import 'screens/home_screen.dart';
import 'screens/intro_splash.dart';
import 'screens/login_screen.dart';
import 'screens/moments_archive_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/verify_email_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([SonderApi.instance.restoreSession(), ThemeController.instance.load()]);
  runApp(const SonderApp(showIntro: true));
  // Picks up a verification requirement that started after this phone signed in.
  unawaited(SonderApi.instance.refreshVerification());
  // After the first frame, so a slow Firebase start never delays the app opening.
  unawaited(PushService.init());
}

class SonderApp extends StatefulWidget {
  /// Play the opening animation over the first screen (off in tests).
  final bool showIntro;

  const SonderApp({super.key, this.showIntro = false});

  @override
  State<SonderApp> createState() => _SonderAppState();
}

/// Picks light or dark from the user's choice (Profile → Theme) and the phone's own setting.
class _SonderAppState extends State<SonderApp> with WidgetsBindingObserver {
  final _theme = ThemeController.instance;
  late bool _introDone = !widget.showIntro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _theme.mode.addListener(_apply);
    _apply();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _theme.mode.removeListener(_apply);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _apply(); // the phone switched dark mode on or off

  void _apply() {
    final look = _theme.lookFor(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    // Light status bar icons over the navy intro, then whatever suits the theme.
    SystemChrome.setSystemUIOverlayStyle(
      look != AppLook.light || !_introDone ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    if (look == AppTheme.look) return;
    if (mounted) {
      setState(() => AppTheme.look = look);
    } else {
      AppTheme.look = look;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The colours are read directly by the screens, so a theme change rebuilds the whole app (the key);
    // MainNavigation remembers which tab was open.
    return MaterialApp(
      key: ValueKey(AppTheme.look),
      title: 'Sonder',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootMessengerKey,
      theme: AppTheme.theme,
      home: const AuthGate(),
      // The intro sits on top of the first screen and opens like a shutter to reveal it.
      builder: (context, child) => _introDone
          ? child!
          : Stack(
              fit: StackFit.expand,
              children: [
                child!,
                IntroSplash(
                  onFinished: () {
                    setState(() => _introDone = true);
                    _apply();
                  },
                ),
              ],
            ),
    );
  }
}

/// Shows the login screen while signed out and the main app while signed in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final api = SonderApi.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([api.currentUser, api.verificationRequired]),
      builder: (context, _) {
        if (api.currentUser.value == null) {
          MainNavigation.savedTab = 0;
          return const LoginScreen();
        }
        // Email sign-ups confirm their address first (only when the server sends email).
        if (api.verificationRequired.value) return const VerifyEmailScreen();
        return const MainNavigation();
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  /// The open tab. Kept outside the widget so it survives the app rebuilding for a theme change;
  /// reset to Home when someone signs out.
  static int savedTab = 0;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = MainNavigation.savedTab;

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
    return Scaffold(body: _buildScreen(), bottomNavigationBar: _buildCustomBottomNav());
  }

  Widget _buildCustomBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.kBar,
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
      onTap: () => setState(() => _currentIndex = MainNavigation.savedTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.kPrimaryFill : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: isSelected ? AppTheme.kOnPrimary : AppTheme.kTextSecondary, size: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.kPrimaryFill : AppTheme.kTextSecondary,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
