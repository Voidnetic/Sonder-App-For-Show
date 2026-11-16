import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import 'motion.dart';

/// "Ali invited you to Graduation Night": you only join once you tap Accept.
class InvitationCard extends StatefulWidget {
  final Moment moment;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  const InvitationCard({super.key, required this.moment, required this.onAccept, required this.onDecline});

  @override
  State<InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<InvitationCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final inviter = moment.invitedBy ?? moment.creator;
    final when = moment.isUnlocked ? 'Already unlocked ✨' : revealDescription(moment.unlockAt);
    return Container(
      key: Key('invite-${moment.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.sticker(AppTheme.tint(moment.accentColor), radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: AppTheme.sticker(AppTheme.tint(inviter.color), circle: true, border: 1.5, offset: 0),
                child: Center(
                  child: Text(
                    inviter.initial,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kInk),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${inviter.name} invited you to',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.kInkSoft),
                ),
              ),
              const Text('💌', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            moment.title.toUpperCase(),
            style: const TextStyle(color: AppTheme.kInk, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            '$when · ${countLabel(moment.friendCount, 'friend', 'friends')} in',
            style: TextStyle(color: AppTheme.kInkSoft, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: _busy ? null : () => _run(widget.onDecline),
                  child: Container(
                    key: Key('invite-decline-${moment.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: AppTheme.sticker(AppTheme.kSurface, radius: 18, border: 1.5, offset: 3),
                    child: Center(
                      child: Text(
                        'Decline',
                        style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kTextPrimary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Pressable(
                  onTap: _busy ? null : () => _run(widget.onAccept),
                  child: Container(
                    key: Key('invite-accept-${moment.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: AppTheme.sticker(AppTheme.kPrimaryFill, radius: 18, border: 1.5, offset: 3),
                    child: Center(
                      child: _busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.kOnPrimary),
                            )
                          : Text(
                              'Accept',
                              style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kOnPrimary),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
