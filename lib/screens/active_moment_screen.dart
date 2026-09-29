import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import 'camera_screen.dart';
import 'reveal_screen.dart';

class ActiveMomentScreen extends StatefulWidget {
  final Moment moment;

  const ActiveMomentScreen({super.key, required this.moment});

  @override
  State<ActiveMomentScreen> createState() => _ActiveMomentScreenState();
}

class _ActiveMomentScreenState extends State<ActiveMomentScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _selectedTab = 0; // 0 = Memories, 1 = Hangout
  bool _isCapturePressed = false;

  // Chat Controller & Local State
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {"type": "system", "text": "Ali joined the Moment"},
    {"type": "system", "text": "Hajra joined the Moment"},
    {"type": "user", "name": "Ali", "text": "Where are you guys?", "time": "10:42 PM", "isMe": false},
    {"type": "user", "name": "Hajra", "text": "We're outside 😂", "time": "10:43 PM", "isMe": false},
    {"type": "system", "text": "📸 Hassan captured a memory\n\"Nobody can see this yet.\""},
    {"type": "user", "name": "Hassan", "text": "Cominggg", "time": "10:45 PM", "isMe": true},
    {"type": "user", "name": "Ahmed", "text": "Someone save me food", "time": "10:46 PM", "isMe": false},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        "type": "user",
        "name": MockData.userName,
        "text": _chatController.text.trim(),
        "time": "Just now",
        "isMe": true,
      });
      _chatController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.moment.accentColor,
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
              widget.moment.title.toUpperCase(),
              style: const TextStyle(color: AppTheme.kTextPrimary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            const SizedBox(height: 2),
            Text(
              "${widget.moment.friendCount} friends • ${widget.moment.memoryCount} memories",
              style: const TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RevealScreen(moment: widget.moment)),
              );
            },
            child: const Text("TEST REVEAL", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.kTextPrimary)),
          )
        ],
      ),
      body: Column(
        children: [
          // TAB SWITCHER: 📸 Memories | 💬 Hangout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.kBorder, width: 2),
                boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(3, 3))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? AppTheme.kTextPrimary : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            "📸 Memories",
                            style: TextStyle(
                              color: _selectedTab == 0 ? Colors.white : AppTheme.kTextPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? AppTheme.kTextPrimary : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            "💬 Hangout",
                            style: TextStyle(
                              color: _selectedTab == 1 ? Colors.white : AppTheme.kTextPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CONTENT AREA
          Expanded(
            child: _selectedTab == 0 ? _buildMemoriesTab() : _buildHangoutTab(),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: MEMORIES ---
  Widget _buildMemoriesTab() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
          children: [
            // COUNTDOWN BOX
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.kBorder, width: 2),
                boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(4, 4))],
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
                          child: const Icon(Icons.lock_rounded, size: 16, color: AppTheme.kTextPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "LOCKED STATE",
                        style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.moment.unlockText,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "🔒 ${widget.moment.memoryCount} memories are currently locked.",
                    style: const TextStyle(color: AppTheme.kTextSecondary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "PARTICIPATING MEMORIES",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.kTextSecondary),
            ),
            const SizedBox(height: 16),
            ...MockData.friends.take(3).map((friend) => _buildLockedMemoryCard(friend)),
          ],
        ),

        // FLOATING CAPTURE BUTTON
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isCapturePressed = true),
            onTapUp: (_) {
              setState(() => _isCapturePressed = false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CameraScreen(moment: widget.moment)),
              );
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      "CAPTURE MEMORY",
                      style: TextStyle(
                        color: Colors.white,
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

  Widget _buildLockedMemoryCard(String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
            child: const Icon(Icons.blur_on_rounded, color: AppTheme.kTextSecondary, size: 26),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.kTextSecondary),
                  SizedBox(width: 4),
                  Text("Memory hidden securely", style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  // --- TAB 2: HANGOUT CHAT ---
  Widget _buildHangoutTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              if (msg["type"] == "system") {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.kBorder, width: 1.5),
                    ),
                    child: Text(
                      msg["text"]!,
                      style: const TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              // Normal User Message
              final isMe = msg["isMe"] == true;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.kTextPrimary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.kBorder, width: 2),
                    boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(3, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe) ...[
                        Text(
                          msg["name"]!,
                          style: const TextStyle(color: AppTheme.kPaleYellow, fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        msg["text"]!,
                        style: TextStyle(
                          color: isMe ? Colors.white : AppTheme.kTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            msg["time"]!,
                            style: TextStyle(
                              color: isMe ? Colors.white70 : AppTheme.kTextSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // MESSAGE COMPOSER
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.kBackground,
            border: const Border(top: BorderSide(color: AppTheme.kBorder, width: 2)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.kBorder, width: 1.5),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppTheme.kTextPrimary, size: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.kBorder, width: 2),
                    ),
                    child: TextField(
                      controller: _chatController,
                      decoration: const InputDecoration(
                        hintText: "Write a message...",
                        border: InputBorder.none,
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
                      boxShadow: const [BoxShadow(color: AppTheme.kSoftMint, offset: Offset(3, 3))],
                    ),
                    child: const Text(
                      "Send",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
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
}