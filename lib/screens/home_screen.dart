import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/moment_card.dart';
import '../widgets/motion.dart';
import '../widgets/status_views.dart';
import 'active_moment_screen.dart';
import 'create_moment_screen.dart';
import 'friends_screen.dart';
import 'reveal_screen.dart';

/// Opens a moment: the reveal flow once it has unlocked, otherwise the live moment screen.
Future<void> openMoment(BuildContext context, Moment moment) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => moment.isUnlocked ? RevealScreen(moment: moment) : ActiveMomentScreen(moment: moment),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Moment>> _moments;

  @override
  void initState() {
    super.initState();
    _moments = SonderApi.instance.getActiveMoments();
  }

  Future<void> _reload() async {
    final next = SonderApi.instance.getActiveMoments();
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
    await openMoment(context, moment);
    if (mounted) await _reload();
  }

  Future<void> _create() async {
    final created = await Navigator.push<Moment>(
      context,
      MaterialPageRoute(builder: (context) => const CreateMomentScreen()),
    );
    if (!mounted) return;
    if (created != null) {
      await _open(created);
    } else {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SonderApi.instance.currentUser.value;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.kTextPrimary,
          onRefresh: _reload,
          child: FutureBuilder<List<Moment>>(
            future: _moments,
            builder: (context, snapshot) {
              final loaded = snapshot.connectionState == ConnectionState.done && !snapshot.hasError;
              final moments = loaded ? snapshot.data! : const <Moment>[];
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 110),
                children: [
                  _header(user),
                  const SizedBox(height: 28),
                  BubblyText("Hey, ${user?.name ?? 'there'} 👋"),
                  const SizedBox(height: 6),
                  const PopIn(
                    child: Text(
                      'Which moment are we living today?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PopIn(index: 1, child: _statTiles(loaded ? moments : null)),
                  if (moments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    PopIn(index: 2, child: _nextRevealBanner(moments.first)),
                  ],
                  const SizedBox(height: 32),
                  PopIn(index: 2, child: _sectionTitle('Your moments', loaded ? moments.length : null)),
                  const SizedBox(height: 16),
                  ..._momentList(snapshot),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: Pressable(
        onTap: _create,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.kTextPrimary,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.kBorder, width: 1.5),
            boxShadow: const [BoxShadow(color: AppTheme.kSunshine, offset: Offset(4, 4))],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: AppTheme.kBackground),
              SizedBox(width: 8),
              Text(
                'CREATE MOMENT',
                style: TextStyle(color: AppTheme.kBackground, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppUser? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('SONDER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 3)),
        const Spacer(),
        Pressable(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen())),
          child: Container(
            key: const Key('home-friends'),
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.kBorder, width: 1.5),
              boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(2, 2))],
            ),
            child: const Icon(Icons.group_add_outlined, size: 24, semanticLabel: 'Friends'),
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: user?.color ?? AppTheme.kPaleYellow,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.kBorder, width: 1.5),
            boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(2, 2))],
          ),
          child: const Center(child: Icon(Icons.face_6_rounded, size: 28)),
        ),
      ],
    );
  }

  /// Two bold number tiles, like a dashboard. Shows dashes while loading.
  Widget _statTiles(List<Moment>? moments) {
    final active = moments?.length;
    final memories = moments?.fold<int>(0, (sum, m) => sum + m.memoryCount);
    return Row(
      children: [
        Expanded(child: _statTile(active, 'Active moments', AppTheme.kPeriwinkle, Icons.hourglass_top_rounded)),
        const SizedBox(width: 14),
        Expanded(child: _statTile(memories, 'Memories locked', AppTheme.kCoral, Icons.lock_rounded)),
      ],
    );
  }

  Widget _statTile(int? value, String label, Color color, IconData icon) {
    return Container(
      height: 128,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.kBorder, width: 2),
        boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(4, 4))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Icon(icon, size: 30, color: AppTheme.kTextPrimary.withValues(alpha: 0.35)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value?.toString() ?? '–', style: AppTheme.display(36)),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  /// A banner for the moment that unlocks next, like a "trending" card.
  Widget _nextRevealBanner(Moment moment) {
    return Pressable(
      onTap: () => _open(moment),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.kLightBlue,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.kBorder, width: 2),
          boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(4, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: moment.accentColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.kBorder, width: 2),
              ),
              child: const Center(child: Text('⏳', style: TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEXT REVEAL', style: AppTheme.display(18)),
                  const SizedBox(height: 4),
                  Text(
                    '${moment.title} · ${revealDescription(moment.unlockAt).replaceFirst('Reveals ', '')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.kBorder, width: 2),
                boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(2, 2))],
              ),
              child: const Text('Open', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, int? count) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.kPaleYellow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.kBorder, width: 1.5),
            ),
            child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  List<Widget> _momentList(AsyncSnapshot<List<Moment>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return [const LoadingView()];
    if (snapshot.hasError) return [ErrorView(message: snapshot.error.toString(), onRetry: _reload)];
    final moments = snapshot.data!;
    if (moments.isEmpty) {
      return const [
        PopIn(
          index: 3,
          child: EmptyView(
            icon: Icons.auto_awesome_rounded,
            title: 'No moments yet',
            subtitle: 'Tap "Create moment" to start one with your friends.',
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < moments.length; i++)
        PopIn(
          index: i + 3,
          child: MomentCard(moment: moments[i], onTap: () => _open(moments[i])),
        ),
    ];
  }
}
