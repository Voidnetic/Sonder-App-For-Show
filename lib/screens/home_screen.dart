import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import '../widgets/moment_card.dart';
import 'create_moment_screen.dart';
import 'active_moment_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Header Row
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
            
            // Greeting
            Text(
              "Hey, ${MockData.userName} 👋",
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 48),
            
            // Moments Section
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
            
            // Cards
            ...MockData.activeMoments.map((moment) => MomentCard(
              moment: moment,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                   builder: (context) => ActiveMomentScreen(moment: moment), // <--- Added moment: moment
                    ),
                    );
              },
            )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateMomentScreen(),
            ),
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