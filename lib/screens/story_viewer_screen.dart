import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

/// Full-screen, story-style slideshow of an unlocked moment's photos.
///
/// - Each photo plays for [storyDuration] with progress bars at the top, then moves on; after the last one
///   it closes.
/// - Tap the right side for the next photo and the left side for the previous one, or swipe sideways.
///   Hold to pause, swipe down to close.
/// - Tap an emoji or type a comment: it goes to the moment's chat as a reply to this photo, with a
///   thumbnail of it.
class StoryViewerScreen extends StatefulWidget {
  final Moment moment;
  final List<Memory> memories;
  final int initialIndex;

  /// Shown as "⋯" in the corner (hide, report or block). The slideshow pauses while it's open.
  final Future<void> Function(Memory memory)? onOptions;

  static const storyDuration = Duration(seconds: 5);
  static const reactions = ['❤️', '😂', '😍', '🔥', '😮', '👏'];

  const StoryViewerScreen({
    super.key,
    required this.moment,
    required this.memories,
    this.initialIndex = 0,
    this.onOptions,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with SingleTickerProviderStateMixin {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late final AnimationController _progress = AnimationController(vsync: this, duration: StoryViewerScreen.storyDuration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _go(_index + 1);
    });
  late int _index = widget.initialIndex;
  final _reply = TextEditingController();
  final _replyFocus = FocusNode();

  bool _held = false; // finger down (hold to pause)
  bool _busy = false; // sending, or the options sheet is open
  String? _toast;
  Timer? _toastTimer;

  Memory get _current => widget.memories[_index];

  @override
  void initState() {
    super.initState();
    _replyFocus.addListener(_syncPlayback);
    _progress.forward();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _progress.dispose();
    _pages.dispose();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  bool get _paused => _held || _busy || _replyFocus.hasFocus;

  /// Pauses while held, typing, sending or in the options sheet; carries on from where it was otherwise.
  void _syncPlayback() {
    if (!mounted) return;
    if (_paused) {
      _progress.stop();
    } else if (!_progress.isAnimating && _progress.value < 1) {
      _progress.forward();
    }
    setState(() {});
  }

  void _go(int index) {
    if (index < 0) {
      _progress.value = 0; // already the first photo: just start it again
      _syncPlayback();
    } else if (index >= widget.memories.length) {
      Navigator.of(context).maybePop();
    } else {
      _pages.jumpToPage(index);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _progress.value = 0;
    _syncPlayback();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;
    final memory = _current;
    setState(() => _busy = true);
    _syncPlayback();
    try {
      await SonderApi.instance.sendMessage(widget.moment.id, trimmed, memoryId: memory.id);
      _reply.clear();
      _replyFocus.unfocus();
      _showToast(trimmed.characters.length <= 2 ? 'Sent $trimmed to the chat' : 'Sent to the chat 💬');
    } catch (e) {
      _showToast(e.toString());
    } finally {
      if (mounted) {
        _busy = false;
        _syncPlayback();
      }
    }
  }

  void _showToast(String text) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _openOptions() async {
    final onOptions = widget.onOptions;
    if (onOptions == null) return;
    setState(() => _busy = true);
    _syncPlayback();
    await onOptions(_current);
    if (mounted) {
      _busy = false;
      _syncPlayback();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The photos. Sideways swipes come from the PageView; taps, holds and swipe-down from each page.
          PageView.builder(
            controller: _pages,
            itemCount: widget.memories.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) => _page(widget.memories[index]),
          ),
          // A soft shade behind the top bar and the reply box so they read on any photo.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
                  stops: [0, 0.18, 0.7, 1],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Column(children: [_topBar(), const Spacer(), if (_toast != null) _toastPill(_toast!), _replyBar()]),
          ),
        ],
      ),
    );
  }

  Widget _page(Memory memory) {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          if (_replyFocus.hasFocus) {
            _replyFocus.unfocus(); // first tap just closes the keyboard
          } else if (details.localPosition.dx < constraints.maxWidth / 3) {
            _go(_index - 1);
          } else {
            _go(_index + 1);
          }
        },
        onLongPressStart: (_) {
          _held = true;
          _syncPlayback();
        },
        onLongPressEnd: (_) {
          _held = false;
          _syncPlayback();
        },
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) Navigator.of(context).maybePop();
        },
        child: Center(
          child: Image.network(
            SonderApi.instance.imageUrl(memory.imageUrl!),
            key: Key('story-photo-${memory.id}'),
            fit: BoxFit.contain,
            width: double.infinity,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 3)),
            errorBuilder: (context, error, stack) =>
                const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final memory = _current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 0),
      child: Column(
        children: [
          // One bar per photo: full for the ones seen, filling up for this one.
          AnimatedBuilder(
            animation: _progress,
            builder: (context, _) => Row(
              children: [
                for (var i = 0; i < widget.memories.length; i++)
                  Expanded(
                    child: Container(
                      height: 3.5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: i < _index ? 1 : (i == _index ? _progress.value : 0),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 4),
              Container(
                width: 36,
                height: 36,
                decoration: AppTheme.sticker(AppTheme.tint(memory.author.color), circle: true, border: 1.5, offset: 0),
                child: Center(
                  child: Text(
                    memory.author.initial,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kInk),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.author.name,
                      key: const Key('story-author'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    Text(
                      [
                        widget.moment.title,
                        timeAgo(memory.capturedAt),
                        if (_paused && !_replyFocus.hasFocus) 'paused',
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${_index + 1}/${widget.memories.length}',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 12),
              ),
              if (widget.onOptions != null)
                IconButton(
                  key: const Key('story-options'),
                  tooltip: 'Options',
                  icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                  onPressed: _openOptions,
                ),
              IconButton(
                key: const Key('story-close'),
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          if (memory.caption != null && memory.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Text(
                memory.caption!,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toastPill(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: AppTheme.sticker(AppTheme.kPrimaryFill, radius: 18, border: 1.5, offset: 2),
        child: Text(
          text,
          style: TextStyle(color: AppTheme.kOnPrimary, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _replyBar() {
    final name = _current.author.id == SonderApi.instance.currentUser.value?.id ? 'your' : "${_current.author.name}'s";
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick reactions.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final emoji in StoryViewerScreen.reactions)
                GestureDetector(
                  key: Key('react-$emoji'),
                  onTap: () => _send(emoji),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(emoji, style: const TextStyle(fontSize: 30)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('story-reply-field'),
                  controller: _reply,
                  focusNode: _replyFocus,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  maxLength: 2000,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Comment on $name photo…',
                    hintStyle: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Colors.white54, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                key: const Key('story-send'),
                onTap: () => _send(_reply.text),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: AppTheme.sticker(AppTheme.kPrimaryFill, circle: true, border: 1.5, offset: 2),
                  child: _busy
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.kOnPrimary),
                        )
                      : Icon(Icons.send_rounded, color: AppTheme.kOnPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
