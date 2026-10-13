import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import 'countdown_text.dart';

class MomentCard extends StatefulWidget {
  final Moment moment;
  final VoidCallback onTap;

  const MomentCard({super.key, required this.moment, required this.onTap});

  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> {
  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final unlocked = moment.isUnlocked;
    return GestureDetector(
      onTap: widget.onTap,
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
                children: [
                  Expanded(
                    child: Text(
                      moment.title.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.kTextPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(unlocked ? Icons.star_rounded : Icons.star_border_rounded, size: 32),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(unlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${moment.memoryCount} memories • ${moment.friendCount} friends',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.kTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
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
                child: unlocked
                    ? const Text(
                        'Ready to reveal ✨',
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Unlocks in ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Flexible(
                            child: CountdownText(
                              unlockAt: moment.unlockAt,
                              onFinished: () => setState(() {}),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
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
