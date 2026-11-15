import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fades, lifts and slightly overshoots its child into place. Give list items increasing
/// [index]es for a staggered entrance. Kept well under a second so screens feel snappy.
class PopIn extends StatefulWidget {
  final Widget child;
  final int index;

  const PopIn({super.key, required this.child, this.index = 0});

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: math.min(widget.index, 5) * 60);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final lift = Curves.easeOutBack.transform(t);
        return Opacity(
          opacity: Curves.easeOut.transform(t),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - lift)),
            child: Transform.scale(scale: 0.94 + 0.06 * lift, child: child),
          ),
        );
      },
    );
  }
}

/// A big chunky heading that springs in with a little wobble, like a bubble popping into place.
class BubblyText extends StatefulWidget {
  final String text;
  final double size;
  final Color? color;
  final TextAlign? textAlign;

  const BubblyText(this.text, {super.key, this.size = 34, this.color, this.textAlign});

  @override
  State<BubblyText> createState() => _BubblyTextState();
}

class _BubblyTextState extends State<BubblyText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alignment = widget.textAlign == TextAlign.center ? Alignment.center : Alignment.centerLeft;
    return AnimatedBuilder(
      animation: _controller,
      child: Text(widget.text, textAlign: widget.textAlign, style: AppTheme.display(widget.size, color: widget.color)),
      builder: (context, child) {
        final t = _controller.value;
        final spring = Curves.elasticOut.transform(t);
        return Opacity(
          opacity: math.min(1, t * 3),
          child: Transform.rotate(
            angle: -0.06 * (1 - spring),
            alignment: alignment,
            child: Transform.scale(scale: 0.6 + 0.4 * spring, alignment: alignment, child: child),
          ),
        );
      },
    );
  }
}

/// Squishes slightly while pressed and bounces back, then calls [onTap].
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const Pressable({super.key, required this.child, this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 260),
        curve: _pressed ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}
