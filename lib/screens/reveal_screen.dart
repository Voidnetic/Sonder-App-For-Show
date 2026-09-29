import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';

class RevealScreen extends StatefulWidget {
  final Moment moment; // <--- Accepts the active moment

  const RevealScreen({super.key, required this.moment});

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> with SingleTickerProviderStateMixin {
  bool _isRevealed = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerReveal() async {
    for (int i = 0; i < 3; i++) {
      await _shakeController.forward();
      await _shakeController.reverse();
    }
    setState(() => _isRevealed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kPaleYellow,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.kTextPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final dx = _shakeController.value * 12.0;
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: _isRevealed
                        ? const Icon(Icons.lock_open_rounded, key: ValueKey("open"), size: 100, color: AppTheme.kTextPrimary)
                        : const Icon(Icons.lock_rounded, key: ValueKey("closed"), size: 100, color: AppTheme.kTextPrimary),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _isRevealed ? "THE MOMENT IS UNLOCKED!" : "THE MOMENT IS READY",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.kTextSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.moment.title, // <--- Displays correct dynamic title
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "${widget.moment.memoryCount} memories • ${widget.moment.friendCount} friends",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
                ),
                const SizedBox(height: 64),
                if (!_isRevealed)
                  GestureDetector(
                    onTap: _triggerReveal,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.kTextPrimary,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: AppTheme.kBorder, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.white, offset: Offset(6, 6))],
                      ),
                      child: const Center(
                        child: Text(
                          "REVEAL",
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.kSoftMint,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: AppTheme.kBorder, width: 2),
                      boxShadow: const [BoxShadow(color: AppTheme.kBorder, offset: Offset(4, 4))],
                    ),
                    child: const Center(
                      child: Text(
                        "EXPLORE MEMORIES ✨",
                        style: TextStyle(color: AppTheme.kTextPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}