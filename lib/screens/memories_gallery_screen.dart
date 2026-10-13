import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/status_views.dart';

/// All photos of an unlocked moment.
class MemoriesGalleryScreen extends StatefulWidget {
  final Moment moment;

  const MemoriesGalleryScreen({super.key, required this.moment});

  @override
  State<MemoriesGalleryScreen> createState() => _MemoriesGalleryScreenState();
}

class _MemoriesGalleryScreenState extends State<MemoriesGalleryScreen> {
  late Future<List<Memory>> _memories;

  @override
  void initState() {
    super.initState();
    _memories = SonderApi.instance.getMemories(widget.moment.id);
  }

  void _reload() {
    setState(() {
      _memories = SonderApi.instance.getMemories(widget.moment.id);
    });
  }

  void _openPhoto(Memory memory) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: Image.network(SonderApi.instance.imageUrl(memory.imageUrl!), fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              [memory.author.name, if (memory.caption != null) memory.caption!].join(' • '),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final unlockedOn = moment.revealedAt ?? moment.unlockAt;
    return Scaffold(
      backgroundColor: moment.accentColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.kTextPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              moment.title.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.kTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Unlocked ${formatMonthDay(unlockedOn)} • ${moment.friendCount} friends",
              style: const TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Memory>>(
        future: _memories,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) return ErrorView(message: snapshot.error.toString(), onRetry: _reload);
          final memories = snapshot.data!;
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
            itemBuilder: (context, index) => _buildPhotoCard(memories[index]),
          );
        },
      ),
    );
  }

  Widget _buildPhotoCard(Memory memory) {
    return GestureDetector(
      onTap: () => _openPhoto(memory),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.kBorder, width: 2),
          boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(3, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                SonderApi.instance.imageUrl(memory.imageUrl!),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const LoadingView(),
                errorBuilder: (context, error, stack) =>
                    const Icon(Icons.broken_image_outlined, color: AppTheme.kTextSecondary, size: 40),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.kBorder, width: 2)),
              ),
              child: Text(
                memory.author.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
