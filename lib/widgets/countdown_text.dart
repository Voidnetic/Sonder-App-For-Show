import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/time_format.dart';

/// Shows [unlockLabel] for [unlockAt], refreshing every second, and calls [onFinished] once when it hits zero.
class CountdownText extends StatefulWidget {
  final DateTime unlockAt;
  final TextStyle? style;
  final String finishedText;
  final VoidCallback? onFinished;

  const CountdownText({
    super.key,
    required this.unlockAt,
    this.style,
    this.finishedText = '00 : 00 : 00',
    this.onFinished,
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  bool _finishedNotified = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final finished = !DateTime.now().isBefore(widget.unlockAt);
    if (finished) {
      _timer?.cancel();
      if (!_finishedNotified) {
        _finishedNotified = true;
        widget.onFinished?.call();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = !DateTime.now().isBefore(widget.unlockAt);
    return Text(finished ? widget.finishedText : unlockLabel(widget.unlockAt), style: widget.style);
  }
}
