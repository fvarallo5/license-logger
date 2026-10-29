import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Hours ring: day arc (primary) + night arc (night indigo) on a soft track.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.day,
    required this.night,
    required this.goal,
    this.size = 188,
    this.stroke = 16,
    this.center,
  });
  final double day;
  final double night;
  final double goal;
  final double size;
  final double stroke;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${(day + night).toStringAsFixed(1)} of ${goal.toStringAsFixed(0)} hours',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: LL.easeOut,
        builder: (context, t, child) => CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(day * t, night * t, goal, stroke),
          child: SizedBox.square(
            dimension: size,
            child: Center(child: center),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.day, this.night, this.goal, this.stroke);
  final double day, night, goal, stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = LL.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = LL.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    const start = -math.pi / 2;
    final dA = (day / goal).clamp(0.0, 1.0) * math.pi * 2;
    final nA = (night / goal).clamp(0.0, 1.0) * math.pi * 2;
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (dA > 0) {
      canvas.drawArc(
        rect,
        start,
        dA,
        false,
        arc(LL.primary)
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: math.pi * 2,
            transform: const GradientRotation(start),
            colors: const [Color(0xFF3B7BE0), LL.primary],
            stops: [0, (dA / (math.pi * 2)).clamp(0.01, 1.0)],
          ).createShader(rect),
      );
    }
    if (nA > 0) {
      // small gap between segments
      canvas.drawArc(rect, start + dA + .09, math.max(0, nA - .09), false, arc(LL.night));
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.day != day || o.night != night;
}
