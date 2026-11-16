import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/safety_sheets.dart';
import '../widgets/status_views.dart';
import 'active_moment_screen.dart';
import 'story_viewer_screen.dart';

/// All photos of an unlocked moment.
class MemoriesGalleryScreen extends StatefulWidget {
  final Moment moment;

  const MemoriesGalleryScreen({super.key, required this.moment});

  @override
  State<MemoriesGalleryScreen> createState() => _MemoriesGalleryScreenState();
}

class _MemoriesGalleryScreenState extends State<MemoriesGalleryScreen> {
  late Future<List<Memory>> _memories;

  /// Also show the photos you hid from your own view (dimmed, so you can bring them back).
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _memories = _fetch();
  }

  // Hidden photos come too, so the "Show hidden" switch needs no extra request.
  Future<List<Memory>> _fetch() => SonderApi.instance.getMemories(widget.moment.id, includeHidden: true);

  void _reload() {
    setState(() {
      _memories = _fetch();
    });
  }

  bool _isMine(Memory memory) => memory.author.id == SonderApi.instance.currentUser.value?.id;

  /// Photos are permanent once unlocked, but anyone can hide one from their own view (everyone else still
  /// sees it), and report or block whoever posted someone else's.
  Future<void> _photoActions(Memory memory) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.kBackground,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppTheme.kBorder, width: 2),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              key: const Key('photo-hide'),
              leading: Icon(
                memory.hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppTheme.kTextPrimary,
              ),
              title: Text(
                memory.hidden ? 'Show it again' : 'Hide from my view',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: memory.hidden
                  ? null
                  : Text('Only for you. Your friends still see it.', style: TextStyle(color: AppTheme.kTextSecondary)),
              onTap: () => Navigator.pop(context, memory.hidden ? 'unhide' : 'hide'),
            ),
            if (!_isMine(memory))
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report or block', style: TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(context, 'report'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'report') {
      final blocked = await showContentActions(
        context,
        target: ReportTarget.memory,
        targetId: memory.id,
        author: memory.author,
      );
      if (blocked && mounted) _reload(); // the server now hides their photos
      return;
    }
    try {
      if (choice == 'hide') {
        await SonderApi.instance.hideMemory(widget.moment.id, memory.id);
        if (mounted) showSnack(context, 'Hidden from your view. Show hidden photos from the top right.');
      } else {
        await SonderApi.instance.unhideMemory(widget.moment.id, memory.id);
      }
      if (mounted) _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString());
    }
  }

  /// Opens the story-style slideshow at [index] (of the photos currently shown).
  Future<void> _openStory(List<Memory> memories, int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => StoryViewerScreen(
          moment: widget.moment,
          memories: memories,
          initialIndex: index,
          onOptions: (memory) async {
            Navigator.pop(context); // back to the grid, where the change shows
            await _photoActions(memory);
          },
        ),
      ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ActiveMomentScreen(moment: widget.moment, chatOnly: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final unlockedOn = moment.revealedAt ?? moment.unlockAt;
    return Scaffold(
      backgroundColor: AppTheme.screenTint(moment.accentColor),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.kTextPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              moment.title.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.kTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Unlocked ${formatMonthDay(unlockedOn)} • ${countLabel(moment.friendCount, 'friend', 'friends')}",
              style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('vault-chat'),
            tooltip: 'Chat',
            icon: Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.kTextPrimary),
            onPressed: _openChat,
          ),
          FutureBuilder<List<Memory>>(
            future: _memories,
            builder: (context, snapshot) {
              final hidden = snapshot.data?.where((m) => m.hidden).length ?? 0;
              if (hidden == 0) return const SizedBox.shrink();
              return IconButton(
                key: const Key('toggle-hidden'),
                tooltip: _showHidden ? 'Hide hidden photos' : 'Show $hidden hidden',
                icon: Icon(
                  _showHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppTheme.kTextPrimary,
                ),
                onPressed: () => setState(() => _showHidden = !_showHidden),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Memory>>(
        future: _memories,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) return ErrorView(message: snapshot.error.toString(), onRetry: _reload);
          final all = snapshot.data!;
          final memories = _showHidden ? all : all.where((m) => !m.hidden).toList();
          if (memories.isEmpty && all.isNotEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: EmptyView(
                icon: Icons.visibility_off_outlined,
                title: 'You hid every photo',
                subtitle: 'Tap the eye at the top right to see them again.',
              ),
            );
          }
          if (memories.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: EmptyView(
                icon: Icons.photo_outlined,
                title: 'No memories were captured',
                subtitle: 'Nobody took a photo during this moment.',
              ),
            );
          }
          if (memories.any((m) => m.locked)) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: EmptyView(
                icon: Icons.lock_rounded,
                title: 'Still locked',
                subtitle: 'These memories are hidden until the moment unlocks.',
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: memories.length,
            itemBuilder: (context, index) => _buildPhotoCard(memories, index),
          );
        },
      ),
    );
  }

  Widget _buildPhotoCard(List<Memory> memories, int index) {
    final memory = memories[index];
    return GestureDetector(
      key: Key('photo-${memory.id}'),
      onTap: () => _openStory(memories, index),
      child: Opacity(
        opacity: memory.hidden ? 0.45 : 1,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.kBorder, width: 2),
            boxShadow: [BoxShadow(color: AppTheme.kShadow, offset: Offset(3, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Image.network(
                  SonderApi.instance.imageUrl(memory.imageUrl!),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null ? child : const LoadingView(),
                  errorBuilder: (context, error, stack) =>
                      Icon(Icons.broken_image_outlined, color: AppTheme.kTextSecondary, size: 40),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.kBorder, width: 2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        memory.author.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                    if (memory.hidden)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.visibility_off_outlined, size: 16, color: AppTheme.kTextSecondary),
                      ),
                    GestureDetector(
                      key: Key('photo-options-${memory.id}'),
                      onTap: () => _photoActions(memory),
                      child: const Icon(Icons.more_horiz_rounded, size: 20, semanticLabel: 'Photo options'),
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
}
