import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/status_views.dart';
import 'memories_gallery_screen.dart';
import 'reveal_screen.dart';

class MomentsArchiveScreen extends StatefulWidget {
  const MomentsArchiveScreen({super.key});

  @override
  State<MomentsArchiveScreen> createState() => _MomentsArchiveScreenState();
}

class _MomentsArchiveScreenState extends State<MomentsArchiveScreen> {
  late Future<List<Moment>> _moments;

  @override
  void initState() {
    super.initState();
    _moments = SonderApi.instance.getArchivedMoments();
  }

  Future<void> _reload() async {
    final next = SonderApi.instance.getArchivedMoments();
    setState(() {
      _moments = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  Future<void> _open(Moment moment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            moment.revealedAt == null ? RevealScreen(moment: moment) : MemoriesGalleryScreen(moment: moment),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.kTextPrimary,
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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

              // ARCHIVED MOMENTS LIST
              FutureBuilder<List<Moment>>(
                future: _moments,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
                  if (snapshot.hasError) {
                    return ErrorView(message: snapshot.error.toString(), onRetry: _reload);
                  }
                  final moments = snapshot.data!;
                  if (moments.isEmpty) {
                    return const EmptyView(
                      icon: Icons.lock_clock_rounded,
                      title: 'Nothing unlocked yet',
                      subtitle: 'Moments appear here once their countdown ends.',
                    );
                  }
                  return Column(children: [for (final moment in moments) _buildArchiveCard(moment)]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveCard(Moment moment) {
    final notRevealed = moment.revealedAt == null;
    return GestureDetector(
      onTap: () => _open(moment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: moment.accentColor,
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
                      Flexible(
                        child: Text(
                          notRevealed
                              ? "Ready to reveal ✨"
                              : "Unlocked ${formatMonthDay(moment.revealedAt ?? moment.unlockAt)}",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.kTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    moment.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${moment.memoryCount} memories captured",
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
      ),
    );
  }
}
