import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The sky behind every screen in the two aurora looks:
///   - Northern Lights: a starry night with soft green, magenta and violet light streaks
///   - Aurora Blossom: navy fading to teal, with a pink and orchid glow rising from the bottom
/// Nothing in the other looks. It's painted once per page and doesn't move, so it costs nothing to scroll.
class AuroraSky extends StatelessWidget {
  const AuroraSky({super.key});

  @override
  Widget build(BuildContext context) {
    final painter = switch (AppTheme.look) {
      AppLook.aurora => const _NorthernLightsPainter(),
      AppLook.blossom => const _BlossomPainter(),
      _ => null,
    };
    if (painter == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: painter, child: const SizedBox.expand()),
      ),
    );
  }
}

/// Wraps every page in the sky (only used in the aurora looks), then runs the normal page transition.
class SkyPageTransitionsBuilder extends PageTransitionsBuilder {
  final bool ios;

  const SkyPageTransitionsBuilder({this.ios = false});

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final PageTransitionsBuilder inner = ios
        ? const CupertinoPageTransitionsBuilder()
        : const ZoomPageTransitionsBuilder();
    return inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      Stack(fit: StackFit.expand, children: [const AuroraSky(), child]),
    );
  }
}

/// A soft oval of light: [color] fading out, centred at ([x], [y]) as fractions of the screen,
/// [length] long (fraction of the width), squashed to [thickness] and tilted by [angle] radians.
void _band(
  Canvas canvas,
  Size size, {
  required Color color,
  required double x,
  required double y,
  required double length,
  required double thickness,
  required double angle,
  required double opacity,
}) {
  final r = size.width * length;
  canvas.save();
  canvas.translate(size.width * x, size.height * y);
  canvas.rotate(angle);
  canvas.scale(1, thickness);
  final paint = Paint()
    ..shader = RadialGradient(
      colors: [
        color.withValues(alpha: opacity),
        color.withValues(alpha: opacity * 0.45),
        color.withValues(alpha: 0),
      ],
      stops: const [0, 0.45, 1],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
  canvas.drawCircle(Offset.zero, r, paint);
  canvas.restore();
}

/// Little white dots, always in the same places (a fixed seed), mostly towards the top.
void _stars(Canvas canvas, Size size, {required int count, required double maxOpacity, required double reach}) {
  final random = math.Random(7);
  final paint = Paint();
  for (var i = 0; i < count; i++) {
    final x = random.nextDouble() * size.width;
    final y = math.pow(random.nextDouble(), 1.4) * size.height * reach;
    final radius = 0.5 + random.nextDouble() * 1.1;
    paint.color = Colors.white.withValues(alpha: maxOpacity * (0.3 + random.nextDouble() * 0.7));
    canvas.drawCircle(Offset(x, y.toDouble()), radius, paint);
  }
}

class _NorthernLightsPainter extends CustomPainter {
  const _NorthernLightsPainter();

  static const _green = Color(0xFF3DFFB0);
  static const _teal = Color(0xFF2BD9C9);
  static const _magenta = Color(0xFFFF5FD2);
  static const _violet = Color(0xFF8A5CFF);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF070B1C), Color(0xFF05070F), Color(0xFF080C1A)],
        ).createShader(rect),
    );
    _stars(canvas, size, count: 80, maxOpacity: 0.85, reach: 0.9);
    // The streaks: a long green curtain, a second fainter one, magenta at its edge and violet underneath.
    _band(canvas, size, color: _green, x: 0.2, y: 0.3, length: 0.95, thickness: 0.26, angle: -0.55, opacity: 0.8);
    _band(canvas, size, color: _green, x: 0.05, y: 0.42, length: 0.5, thickness: 0.3, angle: -0.6, opacity: 0.45);
    _band(canvas, size, color: _teal, x: 0.65, y: 0.15, length: 0.65, thickness: 0.2, angle: -0.3, opacity: 0.5);
    _band(canvas, size, color: _magenta, x: 0.9, y: 0.4, length: 0.65, thickness: 0.26, angle: -0.7, opacity: 0.6);
    _band(canvas, size, color: _violet, x: 0.4, y: 0.6, length: 0.85, thickness: 0.3, angle: -0.45, opacity: 0.5);
    _band(canvas, size, color: _green, x: 0.78, y: 0.8, length: 0.6, thickness: 0.22, angle: -0.35, opacity: 0.38);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BlossomPainter extends CustomPainter {
  const _BlossomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF142848), Color(0xFF173A63), Color(0xFF0B5777), Color(0xFF3B4C8F), Color(0xFF7A5AAE)],
          stops: [0, 0.35, 0.62, 0.84, 1],
        ).createShader(rect),
    );
    _stars(canvas, size, count: 35, maxOpacity: 0.6, reach: 0.5);
    // The glow rising from below: orchid in the middle, pink to the left, a hint of teal on the right.
    _band(
      canvas,
      size,
      color: const Color(0xFFEB96FF),
      x: 0.6,
      y: 0.9,
      length: 1.05,
      thickness: 0.55,
      angle: -0.15,
      opacity: 0.75,
    );
    _band(
      canvas,
      size,
      color: const Color(0xFFF9D4E0),
      x: 0.15,
      y: 0.86,
      length: 0.7,
      thickness: 0.5,
      angle: 0.1,
      opacity: 0.6,
    );
    _band(
      canvas,
      size,
      color: const Color(0xFFFF9EC7),
      x: 0.9,
      y: 0.7,
      length: 0.5,
      thickness: 0.5,
      angle: -0.3,
      opacity: 0.35,
    );
    _band(
      canvas,
      size,
      color: const Color(0xFF3FD0C9),
      x: 0.0,
      y: 0.35,
      length: 0.6,
      thickness: 0.45,
      angle: -0.4,
      opacity: 0.28,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
