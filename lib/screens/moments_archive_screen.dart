import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MomentsArchiveScreen extends StatelessWidget {
  const MomentsArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock past/unlocked moments for the archive
    final List<Map<String, dynamic>> pastMoments = [
      {"title": "Summer Beach Trip '25", "date": "Unlocked June 12", "photos": 42, "color": AppTheme.kSoftMint},
      {"title": "University Farewell", "date": "Unlocked May 04", "photos": 89, "color": AppTheme.kLavender},
      {"title": "New Year Countdown", "date": "Unlocked Jan 01", "photos": 31, "color": AppTheme.kPaleYellow},
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // HEADER
            const Text(
              "MOMENTS ARCHIVE",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: AppTheme.kTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Past Vault ✨",
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              "Explore all your unlocked time capsules and memories.",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.kTextSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // ARCHIVED MOMENTS GRID / LIST
            ...pastMoments.map((moment) {
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: moment["color"],
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.kBorder, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppTheme.kBorder,
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock_open_rounded, size: 18, color: AppTheme.kTextPrimary),
                              const SizedBox(width: 8),
                              Text(
                                moment["date"],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.kTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            moment["title"],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${moment["photos"]} memories captured",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.kBorder, width: 1.5),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: AppTheme.kTextPrimary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}