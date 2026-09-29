import 'package:flutter/material.dart';
import 'data/mock_data.dart';
import 'screens/create_moment_screen.dart';
import 'screens/active_moment_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/global_camera_screen.dart';
import 'screens/moments_archive_screen.dart';

void main() {
  runApp(const SonderApp());
}

// --- THEME ---
class AppTheme {
  static const Color kBackground = Color(0xFFFAF9F6); // Warm off-white
  static const Color kTextPrimary = Color(0xFF1C1C1C); // Dark charcoal
  static const Color kTextSecondary = Color(0xFF6B6B6B);
  static const Color kBorder = Color(0xFF2D2D2D);

  static const Color kLavender = Color(0xFFE6E6FA);
  static const Color kPaleYellow = Color(0xFFFFFACD);
  static const Color kSoftMint = Color(0xFFE0F8E6);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: kBackground,
      primaryColor: kTextPrimary,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: kTextPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
      ),
    );
  }
}

// --- MAIN APP & NAVIGATION ---
class SonderApp extends StatelessWidget {
  const SonderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonder Prototype',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigation(),
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const GlobalCameraScreen(),
    const MomentsArchiveScreen(), // <--- Plugged in here!
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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

// --- HOME SCREEN ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "SONDER",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.kPaleYellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.kBorder, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.face_6_rounded, size: 28),
                  ),
                )
              ],
            ),
            const SizedBox(height: 32),
            Text(
              "Hey, ${MockData.userName} 👋",
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 48),
            const Text(
              "YOUR MOMENTS",
              style: TextStyle(
                color: AppTheme.kTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ...MockData.activeMoments.map((moment) => MomentCard(
              moment: moment,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActiveMomentScreen(moment: moment),
                  ),
                );
              },
            )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateMomentScreen()),
          );
        },
        backgroundColor: AppTheme.kTextPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.kBorder, width: 1.5),
        ),
        icon: const Icon(Icons.add, color: AppTheme.kBackground),
        label: const Text(
          "CREATE MOMENT",
          style: TextStyle(
            color: AppTheme.kBackground,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

// --- MOMENT CARD WIDGET ---
class MomentCard extends StatelessWidget {
  final Moment moment;
  final VoidCallback onTap;

  const MomentCard({super.key, required this.moment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: moment.accentColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.kBorder, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.kBorder,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    moment.title.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.kTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Icon(Icons.star_border_rounded, size: 32),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "${moment.memoryCount} memories • ${moment.friendCount} friends",
                    style: const TextStyle(
                      color: AppTheme.kTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.kBackground.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.kBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Unlocks in ",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      moment.unlockText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}