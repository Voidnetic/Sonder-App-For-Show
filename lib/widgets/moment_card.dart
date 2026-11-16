import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../utils/time_format.dart';
import '../theme/app_theme.dart';
import 'countdown_text.dart';
import 'motion.dart';

class MomentCard extends StatefulWidget {
  final Moment moment;
  final VoidCallback onTap;

  const MomentCard({super.key, required this.moment, required this.onTap});

  @override
  State<MomentCard> createState() => _MomentCardState();
}

class _MomentCardState extends State<MomentCard> with SingleTickerProviderStateMixin {
  /// A slow "breathing" glow while the capsule is ready to open, to build anticipation.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(MomentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.moment.isReady && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.moment.isReady && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final unlocked = moment.isUnlocked;
    if (moment.isReady) return _readyCard(moment);
    final lastCaptured = lastCapturedLabel(
      moment.lastCapturedBy?.name,
      moment.lastCapturedAt,
      myId: SonderApi.instance.currentUser.value?.id,
      authorId: moment.lastCapturedBy?.id,
    );
    return Pressable(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: AppTheme.sticker(AppTheme.tint(moment.accentColor), radius: 32, border: 1.5),
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
                      style: TextStyle(
                        color: AppTheme.kInk,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(unlocked ? Icons.star_rounded : Icons.star_border_rounded, size: 32, color: AppTheme.kInk),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(unlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 20, color: AppTheme.kInk),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${countLabel(moment.memoryCount, 'memory', 'memories')} • ${countLabel(moment.friendCount, 'friend', 'friends')}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.kInk, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              // "Ahmed added a memory 10 min ago": shows activity while the photos stay hidden.
              if (!unlocked && lastCaptured != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.photo_camera_outlined, size: 18, color: AppTheme.kInkSoft),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        lastCaptured,
                        key: const Key('last-captured'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.kInkSoft, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.kBackground.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.kBorder, width: 1),
                ),
                child: unlocked
                    ? const Text('Ready to reveal ✨', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Unlocks in ', style: TextStyle(fontWeight: FontWeight.w600)),
                          Flexible(
                            child: CountdownText(
                              unlockAt: moment.unlockAt,
                              // The countdown ended while on screen: flip to "Ready to Open" right here.
                              onFinished: () => setState(_syncPulse),
                              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The countdown is over and this person hasn't opened it yet: a bright, gently pulsing card with a big
  /// "Ready to Open" badge. It stays on Home until they open it, then moves to the Past Vault.
  Widget _readyCard(Moment moment) {
    return Pressable(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_pulse.value);
          return Container(
            key: const Key('ready-card'),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: AppTheme.sticker(AppTheme.tint(moment.accentColor), radius: 32, border: 2).copyWith(
              boxShadow: [
                BoxShadow(color: AppTheme.shadowFor(AppTheme.kSunshine), offset: Offset(4 + 2 * t, 4 + 2 * t)),
                BoxShadow(
                  color: AppTheme.kSunshine.withValues(alpha: 0.25 + 0.35 * t),
                  blurRadius: 14 + 10 * t,
                  spreadRadius: 1 + 3 * t,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: AppTheme.sticker(AppTheme.kSunshine, radius: 14, border: 1.5, offset: 2),
                child: const Text(
                  '✨ READY TO OPEN',
                  key: Key('ready-badge'),
                  style: TextStyle(color: AppTheme.kInk, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                moment.title.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.kInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.lock_open_rounded, size: 20, color: AppTheme.kInk),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${countLabel(moment.memoryCount, 'memory', 'memories')} waiting • '
                      '${countLabel(moment.friendCount, 'friend', 'friends')}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.kInk, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: AppTheme.sticker(AppTheme.kPrimaryFill, radius: 20, border: 1.5, offset: 3),
                child: Center(
                  child: Text(
                    'TAP TO OPEN 🎁',
                    style: TextStyle(color: AppTheme.kOnPrimary, fontWeight: FontWeight.w900, letterSpacing: 1.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
