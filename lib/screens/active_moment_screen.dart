import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/countdown_text.dart';
import '../widgets/live_presence.dart';
import '../widgets/safety_sheets.dart';
import '../widgets/status_views.dart';
import 'camera_screen.dart';
import 'reveal_screen.dart';

class ActiveMomentScreen extends StatefulWidget {
  final Moment moment;

  const ActiveMomentScreen({super.key, required this.moment});

  @override
  State<ActiveMomentScreen> createState() => _ActiveMomentScreenState();
}

class _ActiveMomentScreenState extends State<ActiveMomentScreen> with SingleTickerProviderStateMixin {
  static const _maxReconnectAttempts = 5;

  late AnimationController _pulseController;
  late Moment _moment;
  int _selectedTab = 0; // 0 = Memories, 1 = Hangout
  bool _isCapturePressed = false;

  List<Memory>? _memories;
  Object? _memoriesError;

  List<ChatMessage>? _messages;
  Object? _messagesError;
  StreamSubscription<HangoutEvent>? _live;

  /// Everyone with this moment open right now ("Here now"), including you.
  Set<String> _hereNow = {};

  /// Who's typing, each with a timer that clears them if their "stopped typing" never arrives.
  final Map<String, Timer> _typing = {};

  /// Whether we told the others we're typing, and when to tell them we stopped.
  bool _iAmTyping = false;
  Timer? _typingIdle;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _sending = false;

  /// People the user blocked (or who blocked them). Their live messages are dropped.
  Set<String> _hiddenAuthors = {};

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  SonderApi get _api => SonderApi.instance;

  @override
  void initState() {
    super.initState();
    _moment = widget.moment;
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _loadMemories();
    _loadMessages();
    _connectLive();
    _loadBlocked();
  }

  Future<void> _loadBlocked() async {
    try {
      final blocked = await _api.getBlockedUsers();
      if (mounted) setState(() => _hiddenAuthors = {for (final u in blocked) u.id});
    } catch (_) {
      // Not critical: the server already filters the chat history.
    }
  }

  Future<void> _messageActions(ChatMessage message) async {
    final author = message.author;
    if (author == null) return;
    final blocked = await showContentActions(
      context,
      target: ReportTarget.message,
      targetId: message.id,
      author: author,
    );
    if (blocked && mounted) {
      setState(() {
        _hiddenAuthors = {..._hiddenAuthors, author.id};
        _messages = _messages?.where((m) => m.author?.id != author.id).toList();
        _memories = _memories?.where((m) => m.author.id != author.id).toList();
      });
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _typingIdle?.cancel();
    for (final t in _typing.values) {
      t.cancel();
    }
    if (_iAmTyping) _api.sendTyping(_moment.id, false);
    _live?.cancel();
    _pulseController.dispose();
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ data

  Future<void> _refreshMoment() async {
    try {
      final moment = await _api.getMoment(_moment.id);
      if (mounted) {
        setState(() {
          _moment = moment;
        });
      }
    } catch (_) {
      // The rest of the screen still works with the moment we already have.
    }
  }

  Future<void> _loadMemories() async {
    try {
      final memories = await _api.getMemories(_moment.id);
      if (mounted) {
        setState(() {
          _memories = memories;
          _memoriesError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _memoriesError = e;
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _api.getMessages(_moment.id);
      if (mounted) {
        setState(() {
          _messages = messages;
          _messagesError = null;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messagesError = e;
        });
      }
    }
  }

  void _connectLive() {
    _live?.cancel();
    _live = _api
        .hangoutStream(_moment.id)
        .listen(
          (event) {
            _reconnectAttempts = 0;
            switch (event) {
              case HangoutMessage(:final message):
                _clearTyping(message.author?.id); // their message arrived, so they've stopped typing
                _addMessage(message);
              case HangoutPresence(:final userIds):
                if (mounted) setState(() => _hereNow = userIds);
              case HangoutTyping(:final userId, :final typing):
                typing ? _markTyping(userId) : _clearTyping(userId);
            }
          },
          onError: (Object _) => _scheduleReconnect(),
          onDone: _scheduleReconnect,
          cancelOnError: true,
        );
  }

  void _markTyping(String userId) {
    if (!mounted || userId == _api.currentUser.value?.id || _hiddenAuthors.contains(userId)) return;
    _typing[userId]?.cancel();
    setState(() => _typing[userId] = Timer(const Duration(seconds: 6), () => _clearTyping(userId)));
  }

  void _clearTyping(String? userId) {
    final timer = _typing.remove(userId);
    if (timer == null) return;
    timer.cancel();
    if (mounted) setState(() {});
  }

  /// Called as you type: says "typing" once, then "stopped" after 3 quiet seconds.
  void _onComposerChanged(String text) {
    _typingIdle?.cancel();
    if (text.trim().isEmpty) {
      _setTyping(false);
      return;
    }
    _setTyping(true);
    _typingIdle = Timer(const Duration(seconds: 3), () => _setTyping(false));
  }

  void _setTyping(bool typing) {
    if (typing == _iAmTyping) return;
    _iAmTyping = typing;
    _api.sendTyping(_moment.id, typing);
  }

  void _scheduleReconnect() {
    if (!mounted || _reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _connectLive();
      _loadMessages(); // catch up on anything sent while disconnected
    });
  }

  void _addMessage(ChatMessage message) {
    if (!mounted || _hiddenAuthors.contains(message.author?.id)) return;
    final messages = _messages ?? [];
    if (messages.any((m) => m.id == message.id)) return;
    setState(() {
      _messages = [...messages, message];
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _chatController.clear();
    _typingIdle?.cancel();
    _setTyping(false);
    try {
      _addMessage(await _api.sendMessage(_moment.id, text));
    } catch (e) {
      if (mounted) {
        _chatController.text = text;
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openCamera() async {
    final captured = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => CameraScreen(moment: _moment)),
    );
    if (captured == true && mounted) {
      await Future.wait([_loadMemories(), _refreshMoment()]);
    }
  }

  void _openReveal() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => RevealScreen(moment: _moment)));
  }

  int get _memoryCount => _memories?.length ?? _moment.memoryCount;

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.tint(_moment.accentColor),
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
              _moment.title.toUpperCase(),
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
              "${countLabel(_moment.friendCount, 'friend', 'friends')} • ${countLabel(_memoryCount, 'memory', 'memories')}",
              style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // TAB SWITCHER: 📸 Memories | 💬 Hangout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.kSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.kBorder, width: 2),
                boxShadow: [BoxShadow(color: AppTheme.kBorder, offset: Offset(3, 3))],
              ),
              child: Row(children: [_tabButton("📸 Memories", 0), _tabButton("💬 Hangout", 1)]),
            ),
          ),

          // CONTENT AREA
          Expanded(child: _selectedTab == 0 ? _buildMemoriesTab() : _buildHangoutTab()),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          if (index == 1) _scrollToBottom();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.kTextPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.kOnPrimary : AppTheme.kTextPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 1: MEMORIES ---
  Widget _buildMemoriesTab() {
    final unlocked = _moment.isUnlocked;
    return Stack(
      children: [
        RefreshIndicator(
          color: AppTheme.kTextPrimary,
          onRefresh: () => Future.wait([_loadMemories(), _refreshMoment()]),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
            children: [
              unlocked ? _buildUnlockedBox() : _buildCountdownBox(),
              const SizedBox(height: 24),
              Text(
                "PARTICIPATING MEMORIES",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppTheme.kTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ..._buildMemoryList(),
            ],
          ),
        ),

        // FLOATING CAPTURE BUTTON
        if (!unlocked)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isCapturePressed = true),
              onTapUp: (_) {
                setState(() => _isCapturePressed = false);
                _openCamera();
              },
              onTapCancel: () => setState(() => _isCapturePressed = false),
              child: AnimatedScale(
                scale: _isCapturePressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.kTextPrimary,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppTheme.kBorder, width: 2),
                    boxShadow: _isCapturePressed ? [] : const [BoxShadow(color: Colors.white, offset: Offset(6, 6))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded, color: AppTheme.kOnPrimary, size: 28),
                      SizedBox(width: 12),
                      Text(
                        "CAPTURE MEMORY",
                        style: TextStyle(
                          color: AppTheme.kOnPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCountdownBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.kBorder, width: 2),
        boxShadow: [BoxShadow(color: AppTheme.kBorder, offset: Offset(4, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.2),
                  child: Icon(Icons.lock_rounded, size: 16, color: AppTheme.kTextPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "LOCKED STATE",
                style: TextStyle(
                  color: AppTheme.kTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CountdownText(
            unlockAt: _moment.unlockAt,
            onFinished: () => setState(() {}),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            _memoryCount == 1 ? "🔒 1 memory is currently locked." : "🔒 $_memoryCount memories are currently locked.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.kPaleYellow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.kBorder, width: 2),
        boxShadow: [BoxShadow(color: AppTheme.kBorder, offset: Offset(4, 4))],
      ),
      child: Column(
        children: [
          Icon(Icons.lock_open_rounded, size: 28, color: AppTheme.kTextPrimary),
          const SizedBox(height: 8),
          const Text(
            "THE MOMENT IS READY",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _openReveal,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.kTextPrimary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.kBorder, width: 2),
              ),
              child: Center(
                child: Text(
                  "REVEAL NOW",
                  style: TextStyle(color: AppTheme.kOnPrimary, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMemoryList() {
    final memories = _memories;
    if (memories == null) {
      if (_memoriesError != null) {
        return [ErrorView(message: _memoriesError.toString(), onRetry: _loadMemories)];
      }
      return [const LoadingView()];
    }
    if (memories.isEmpty) {
      return [
        const EmptyView(
          icon: Icons.camera_alt_outlined,
          title: 'No memories yet',
          subtitle: 'Be the first to capture one.',
        ),
      ];
    }
    final myId = _api.currentUser.value?.id;
    return [
      for (final memory in memories)
        _buildLockedMemoryCard(memory.author.id == myId ? '${memory.author.name} (you)' : memory.author.name),
    ];
  }

  Widget _buildLockedMemoryCard(String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.kBorder, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.kBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.kBorder, width: 1.5),
            ),
            child: Icon(Icons.blur_on_rounded, color: AppTheme.kTextSecondary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.kTextSecondary),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "Memory hidden securely",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: HANGOUT CHAT ---
  Widget _buildHangoutTab() {
    final messages = _messages;
    final myId = _api.currentUser.value?.id;
    final people = {for (final p in _moment.participants) p.id: p};
    final hereNow = [
      for (final id in _hereNow)
        if (id != myId && !_hiddenAuthors.contains(id) && people[id] != null) people[id]!,
    ];
    final typingNames = [for (final id in _typing.keys) people[id]?.name ?? 'Someone'];
    return Column(
      children: [
        if (!_moment.isUnlocked) HereNowStrip(others: hereNow),
        Expanded(
          child: messages == null
              ? (_messagesError != null
                    ? ErrorView(message: _messagesError.toString(), onRetry: _loadMessages)
                    : const LoadingView())
              : messages.isEmpty
              ? Center(
                  child: Text(
                    "No messages yet. Say hi 👋",
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
                  ),
                )
              : ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.all(24),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _buildMessage(messages[index], myId),
                ),
        ),

        if (typingNames.isNotEmpty) TypingIndicator(names: typingNames),

        // MESSAGE COMPOSER
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.kBackground,
            border: Border(top: BorderSide(color: AppTheme.kBorder, width: 2)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                if (!_moment.isUnlocked) ...[
                  GestureDetector(
                    onTap: _openCamera,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.kSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.kBorder, width: 1.5),
                      ),
                      child: Icon(Icons.add_rounded, color: AppTheme.kTextPrimary, size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.kBorder, width: 2),
                    ),
                    child: TextField(
                      key: const Key('chat-field'),
                      controller: _chatController,
                      onChanged: _onComposerChanged,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: "Write a message...",
                        border: InputBorder.none,
                        counterText: '',
                        hintStyle: TextStyle(color: AppTheme.kTextSecondary, fontSize: 14),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.kTextPrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.kBorder, width: 2),
                      boxShadow: [BoxShadow(color: AppTheme.kSoftMint, offset: Offset(3, 3))],
                    ),
                    child: Text(
                      _sending ? "..." : "Send",
                      style: TextStyle(color: AppTheme.kOnPrimary, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(ChatMessage msg, String? myId) {
    if (msg.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.kSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.kBorder, width: 1.5),
          ),
          child: Text(
            msg.text,
            style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Normal User Message
    final isMe = msg.author?.id == myId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // Long-press someone else's message to report it or block them.
        onLongPress: isMe ? null : () => _messageActions(msg),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.kTextPrimary : AppTheme.kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.kBorder, width: 2),
            boxShadow: [BoxShadow(color: AppTheme.kBorder, offset: Offset(3, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Text(
                  msg.author?.name ?? 'Someone',
                  style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                msg.text,
                style: TextStyle(
                  color: isMe ? AppTheme.kOnPrimary : AppTheme.kTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatClock(msg.createdAt, alwaysShowMinutes: true),
                style: TextStyle(
                  color: isMe ? AppTheme.kOnPrimary.withValues(alpha: 0.7) : AppTheme.kTextSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
