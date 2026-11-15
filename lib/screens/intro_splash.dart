import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The navy of the app icon and the Android launch screen.
const Color kBrandNavy = Color(0xFF1E2240);
const Color _cream = Color(0xFFF6EEDC);
const Color _ink = Color(0xFF1C1C1C);
const List<Color> _retro = [Color(0xFF7C8CFF), Color(0xFF4CC6A0), Color(0xFFFFC93C), Color(0xFFFF6F4F)];

/// The app's opening animation, laid over the first screen.
///
/// It starts as an exact copy of the Android launch screen (navy, the polaroid icon 288 px wide in the
/// middle), so the hand-over from Android to Flutter can't be seen. Then the icon lifts, "sonder" pops
/// in with the retro stack, the sparkles twinkle, and a circle opens from the middle like a camera
/// shutter to reveal the app underneath.
class IntroSplash extends StatefulWidget {
  final VoidCallback onFinished;

  const IntroSplash({super.key, required this.onFinished});

  static const Duration duration = Duration(milliseconds: 2100);

  @override
  State<IntroSplash> createState() => _IntroSplashState();
}

class _IntroSplashState extends State<IntroSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: IntroSplash.duration);

  // Each part of the animation as a slice of the timeline (0 to 1).
  late final _lift = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.10, 0.42, curve: Curves.easeInOutCubic),
  );
  late final _word = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.24, 0.60, curve: Curves.elasticOut),
  );
  late final _wordFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.24, 0.36, curve: Curves.easeOut),
  );
  late final _tagline = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.42, 0.62, curve: Curves.easeOut),
  );
  late final _twinkle = CurvedAnimation(parent: _c, curve: const Interval(0.30, 0.80));
  late final _exit = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.74, 1.0, curve: Curves.easeInCubic),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // People who turned animations off in Android settings get a quick fade instead.
      if (MediaQuery.of(context).disableAnimations) {
        _c.duration = const Duration(milliseconds: 300);
        _c.value = 0.74;
      }
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final exit = _exit.value;
        // The shutter: a growing hole in the navy layer, from 0 to past the screen corners.
        final holeRadius = exit * math.sqrt(size.width * size.width + size.height * size.height) * 0.62;
        // Material supplies the text styling: the intro sits above the app's own screens, where there is none.
        return Material(
          type: MaterialType.transparency,
          child: IgnorePointer(
            ignoring: exit > 0.3,
            child: ClipPath(
              clipper: _ShutterClipper(holeRadius),
              child: Container(
                // Fill the whole screen, like the Android launch screen it continues from.
                width: double.infinity,
                height: double.infinity,
                color: kBrandNavy,
                child: Opacity(
                  opacity: 1 - Curves.easeIn.transform(exit),
                  child: Transform.scale(
                    scale: 1 + exit * 0.12,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Same size and place as the Android launch icon.
                        Transform.translate(
                          offset: Offset(0, -72 * _lift.value),
                          child: Transform.scale(
                            scale: 1 - 0.1 * _lift.value + 0.04 * math.sin(_lift.value * math.pi),
                            child: Image.asset('assets/brand/splash_icon.png', width: 288, height: 288),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, 112),
                          child: Opacity(
                            opacity: _wordFade.value,
                            child: Transform.scale(scale: 0.55 + 0.45 * _word.value, child: const _RetroWord()),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, 172 + 8 * (1 - _tagline.value)),
                          child: Opacity(
                            opacity: _tagline.value,
                            child: const Text(
                              'capture now · reveal later',
                              style: TextStyle(
                                fontFamily: 'Bricolage',
                                color: Color(0xFFC9CBE0),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                        ..._sparkles(_twinkle.value),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Small cream sparkles that pop in one after another and gently pulse.
  List<Widget> _sparkles(double t) {
    const spots = [(-128.0, -150.0, 18.0, 0.0), (138.0, 40.0, 12.0, 0.25), (-110.0, 70.0, 10.0, 0.5)];
    return [
      for (final (dx, dy, r, delay) in spots)
        Transform.translate(
          offset: Offset(dx, dy - 72 * _lift.value),
          child: Transform.scale(
            scale: () {
              final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
              return Curves.elasticOut.transform(math.min(1.0, local * 2.2)) *
                  (0.85 + 0.15 * math.sin(local * 6 * math.pi));
            }(),
            child: CustomPaint(size: Size.square(r * 2), painter: _SparklePainter()),
          ),
        ),
    ];
  }
}

/// "sonder" in the chunky display font with the retro rainbow stack behind it, like the app icon.
class _RetroWord extends StatelessWidget {
  const _RetroWord();

  @override
  Widget build(BuildContext context) {
    TextStyle style(Paint? stroke, Color? fill) => TextStyle(
      fontFamily: 'Bagel',
      fontSize: 64,
      height: 1,
      letterSpacing: 1,
      foreground: stroke,
      color: stroke == null ? fill : null,
    );
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round
      ..color = _ink;
    Widget layer(Color fill, double offset) => Transform.translate(
      offset: Offset(offset, offset),
      child: Stack(
        children: [
          Text('sonder', style: style(outline, null)),
          Text('sonder', style: style(null, fill)),
        ],
      ),
    );
    return Stack(
      children: [for (var i = 0; i < _retro.length; i++) layer(_retro[i], (_retro.length - i) * 4.0), layer(_cream, 0)],
    );
  }
}

class _ShutterClipper extends CustomClipper<Path> {
  final double radius;

  _ShutterClipper(this.radius);

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (radius <= 0) return path;
    return Path.combine(
      PathOperation.difference,
      path,
      Path()..addOval(Rect.fromCircle(center: size.center(Offset.zero), radius: radius)),
    );
  }

  @override
  bool shouldReclip(_ShutterClipper old) => old.radius != radius;
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2, c = size.center(Offset.zero);
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..cubicTo(c.dx + r * .12, c.dy - r * .24, c.dx + r * .24, c.dy - r * .12, c.dx + r, c.dy)
      ..cubicTo(c.dx + r * .24, c.dy + r * .12, c.dx + r * .12, c.dy + r * .24, c.dx, c.dy + r)
      ..cubicTo(c.dx - r * .12, c.dy + r * .24, c.dx - r * .24, c.dy + r * .12, c.dx - r, c.dy)
      ..cubicTo(c.dx - r * .24, c.dy - r * .12, c.dx - r * .12, c.dy - r * .24, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = _cream);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => false;
}
