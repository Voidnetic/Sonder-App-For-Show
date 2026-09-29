import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';

class MomentCard extends StatelessWidget {
  final Moment moment;
  final VoidCallback onTap;

  const MomentCard({super.key, required this.moment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: moment.accentColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.kBorder, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.kBorder,
              offset: Offset(4, 4),
              blurRadius: 0, // Solid shadow for playful look
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