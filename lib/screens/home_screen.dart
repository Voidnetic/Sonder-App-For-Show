import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/moment_card.dart';
import '../widgets/status_views.dart';
import 'active_moment_screen.dart';
import 'create_moment_screen.dart';
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
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "SONDER",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: user?.color ?? AppTheme.kPaleYellow,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.kBorder, width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.face_6_rounded, size: 28),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 32),

              // Greeting
              Text(
                "Hey, ${user?.name ?? 'there'} 👋",
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 48),

              // Moments Section
              const Text(
                "YOUR MOMENTS",
                style: TextStyle(
                  color: AppTheme.kTextSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              FutureBuilder<List<Moment>>(
                future: _moments,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView();
                  }
                  if (snapshot.hasError) {
                    return ErrorView(message: snapshot.error.toString(), onRetry: _reload);
                  }
                  final moments = snapshot.data!;
                  if (moments.isEmpty) {
                    return const EmptyView(
                      icon: Icons.auto_awesome_rounded,
                      title: 'No moments yet',
                      subtitle: 'Tap "Create moment" to start one with your friends.',
                    );
                  }
                  return Column(
                    children: [
                      for (final moment in moments) MomentCard(moment: moment, onTap: () => _open(moment)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppTheme.kTextPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.kBorder, width: 1.5),
        ),
        icon: const Icon(Icons.add, color: AppTheme.kBackground),
        label: const Text(
          "CREATE MOMENT",
          style: TextStyle(
            color: AppTheme.kBackground,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
