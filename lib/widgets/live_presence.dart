import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';

/// "Ali and Hajra are here now": who else has this moment open right now, with their avatars.
class HereNowStrip extends StatelessWidget {
  /// Everyone present except the signed-in user.
  final List<AppUser> others;

  const HereNowStrip({super.key, required this.others});

  static String label(List<AppUser> others) {
    final names = others.map((u) => u.name).toList();
    return switch (names.length) {
      0 => 'Just you here right now',
      1 => '${names[0]} is here now',
      2 => '${names[0]} and ${names[1]} are here now',
      _ => '${names[0]}, ${names[1]} and ${names.length - 2} more are here now',
    };
  }

  @override
  Widget build(BuildContext context) {
    const size = 26.0, overlap = 16.0;
    final shown = others.take(4).toList();
    return Container(
      key: const Key('here-now'),
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.kBorder, width: 1.5),
      ),
      child: Row(
        children: [
          // A small live dot so it reads as "right now".
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: others.isEmpty ? AppTheme.kTextSecondary : const Color(0xFF34C77B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          if (shown.isNotEmpty) ...[
            SizedBox(
              width: size + overlap * (shown.length - 1),
              height: size,
              child: Stack(
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Positioned(
                      left: i * overlap,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: AppTheme.tint(shown[i].color),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.kBorder, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            shown[i].initial,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.kTextPrimary),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label(others),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.kTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ali is typing…" with three bouncing dots, shown just above the message box.
class TypingIndicator extends StatefulWidget {
  final List<String> names;

  const TypingIndicator({super.key, required this.names});

  static String label(List<String> names) => switch (names.length) {
    1 => '${names[0]} is typing',
    2 => '${names[0]} and ${names[1]} are typing',
    _ => '${names.length} people are typing',
  };

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('typing-indicator'),
      padding: const EdgeInsets.fromLTRB(28, 0, 24, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              TypingIndicator.label(widget.names),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.kTextSecondary),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedBuilder(
            animation: _dots,
            builder: (context, _) => Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Transform.translate(
                    offset: Offset(0, -3 * math.max(0, math.sin((_dots.value - i * 0.18) * 2 * math.pi))),
                    child: Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(left: 3, top: 6),
                      decoration: BoxDecoration(color: AppTheme.kTextSecondary, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
