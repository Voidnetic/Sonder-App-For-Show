import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // TAB INDICATION & TITLE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "ACCOUNT & PROFILE",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: AppTheme.kTextSecondary,
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
                    "Tab 4 / 4",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // USER INFO & LOGIN DETAILS CARD
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.kLavender,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppTheme.kBorder, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: AppTheme.kBorder,
                    offset: Offset(4, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.kPaleYellow,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.kBorder, width: 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.face_6_rounded, size: 40),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MockData.userName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.kTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "hassan.sonder@app.com",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.kTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.kSoftMint,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.kBorder, width: 1),
                          ),
                          child: const Text(
                            "Verified Account ✓",
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // STATS ROW
            Row(
              children: [
                Expanded(
                  child: _buildStatBox("91", "Memories", AppTheme.kSoftMint),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatBox("4", "Active Moments", AppTheme.kPaleYellow),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // FRIENDS LIST SECTION
            const Text(
              "CONNECTED CIRCLE (FRIENDS)",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppTheme.kTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.kBorder, width: 2),
              ),
              child: Column(
                children: MockData.friends.map((friend) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.kBackground,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.kBorder, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  friend[0],
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              friend,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.kTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.kSoftMint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.kBorder, width: 1),
                          ),
                          child: const Text(
                            "Synced",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),

            // APP SETTINGS SECTION
            const Text(
              "SETTINGS & PREFERENCES",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppTheme.kTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.kBorder, width: 2),
              ),
              child: Column(
                children: [
                  _buildSettingTile(Icons.notifications_active_outlined, "Unlock Reminders", "On"),
                  const Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
                  _buildSettingTile(Icons.palette_outlined, "Neo-Brutalist Theme", "Default"),
                  const Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
                  _buildSettingTile(Icons.security_rounded, "Cloud Sync Status", "Connected"),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // LOG OUT BUTTON
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Logged out successfully (Demo)")),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppTheme.kTextPrimary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.kBorder, width: 2),
                  boxShadow: const [BoxShadow(color: AppTheme.kPaleYellow, offset: Offset(3, 3))],
                ),
                child: const Center(
                  child: Text(
                    "LOG OUT",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String count, String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.kBorder, width: 2),
        boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(3, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.kTextPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String trailingValue) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.kTextPrimary, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.kTextPrimary),
              ),
            ],
          ),
          Text(
            trailingValue,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.kTextSecondary),
          ),
        ],
      ),
    );
  }
}