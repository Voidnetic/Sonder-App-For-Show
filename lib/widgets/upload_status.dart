import 'package:flutter/material.dart';

import '../data/upload_queue.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import 'motion.dart';

/// On Home: how many photos are still on their way up, and any that the server refused.
/// Shows nothing when the queue is empty. Photos are only counted, never shown: they stay hidden until
/// the reveal like every other photo.
class UploadQueueBanner extends StatelessWidget {
  const UploadQueueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final queue = UploadQueue.instance;
    return ValueListenableBuilder<List<PendingUpload>>(
      valueListenable: queue.items,
      builder: (context, _, _) {
        final mine = queue.mine;
        final waiting = [
          for (final u in mine)
            if (u.state != UploadState.failed) u,
        ];
        final failed = [
          for (final u in mine)
            if (u.state == UploadState.failed) u,
        ];
        if (mine.isEmpty) return const SizedBox.shrink();
        final offline = waiting.any((u) => u.state == UploadState.offline);
        return Column(
          children: [
            if (waiting.isNotEmpty)
              Container(
                key: const Key('upload-banner'),
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                decoration: AppTheme.sticker(offline ? AppTheme.kPalePeach : AppTheme.kLightBlue, radius: 22),
                child: Row(
                  children: [
                    Text(offline ? '📴' : '📤', style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offline
                                ? '${countLabel(waiting.length, 'photo', 'photos')} waiting for internet'
                                : 'Uploading ${countLabel(waiting.length, 'photo', 'photos')}…',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kInk),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            offline
                                ? "Saved safely. They'll upload by themselves when you're back online."
                                : 'You can keep using Sonder.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.kInkSoft),
                          ),
                        ],
                      ),
                    ),
                    if (offline)
                      Pressable(
                        onTap: queue.kick,
                        child: Container(
                          key: const Key('upload-retry'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: AppTheme.sticker(AppTheme.kSurface, radius: 14, border: 1.5, offset: 2),
                          child: Text(
                            'Retry',
                            style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kTextPrimary),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.kInk),
                        ),
                      ),
                  ],
                ),
              ),
            for (final upload in failed)
              Container(
                key: Key('upload-failed-${upload.id}'),
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                decoration: AppTheme.sticker(AppTheme.kCoral, radius: 22),
                child: Row(
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "A photo for ${upload.momentTitle} couldn't upload: ${upload.error ?? 'unknown error'}",
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.kInk, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      icon: const Icon(Icons.close_rounded, color: AppTheme.kInk),
                      onPressed: () => queue.dismiss(upload.id),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
