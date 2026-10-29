import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HoursArc extends StatelessWidget {
  const HoursArc({
    super.key,
    required this.hours,
    this.nightHours = 0,
    this.goal = 50,
    this.nightGoal = 10,
    this.caption = 'Permit hours',
  });

  final double hours;
  final double nightHours;
  final double goal;
  final double nightGoal;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final clamped = hours.clamp(0, goal);
    final t = goal <= 0 ? 0.0 : clamped / goal;
    final nightT = nightGoal <= 0 ? 0.0 : nightHours.clamp(0, nightGoal) / nightGoal;
    final hoursLabel = clamped == clamped.roundToDouble()
        ? clamped.toStringAsFixed(0)
        : clamped.toStringAsFixed(1);
    final pct = (t * 100).clamp(0, 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A121F), Color(0xFF0F1B2D), Color(0xFF123A72)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            width: double.infinity,
            child: CustomPaint(
              painter: _ArcPainter(
                progress: t.toDouble(),
                nightProgress: nightT.toDouble(),
                track: Colors.white.withValues(alpha: 0.14),
                fill: AppColors.accent,
                nightFill: AppColors.accent,
              ),
              child: Align(
                alignment: const Alignment(0, 0.28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hoursLabel,
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 0.95,
                        letterSpacing: -1.5,
                      ),
                    ),
                    Text(
                      '/ ${goal.toStringAsFixed(0)} hrs',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _pill('$pct% there', AppColors.accent, AppColors.text),
              const SizedBox(width: 8),
              _pill(
                '${nightHours.toStringAsFixed(1)} / ${nightGoal.toStringAsFixed(0)} night',
                AppColors.primaryDark,
                AppColors.text,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.progress,
    required this.nightProgress,
    required this.track,
    required this.fill,
    required this.nightFill,
  });

  final double progress;
  final double nightProgress;
  final Color track;
  final Color fill;
  final Color nightFill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.78);
    final radius = size.width * 0.34;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = math.pi;
    const sweep = math.pi;

    for (var i = 0; i <= 12; i++) {
      final a = start + sweep * (i / 12);
      final inner = radius + 16;
      final outer = i % 3 == 0 ? radius + 26 : radius + 21;
      canvas.drawLine(
        center + Offset(math.cos(a) * inner, math.sin(a) * inner),
        center + Offset(math.cos(a) * outer, math.sin(a) * outer),
        Paint()
          ..color = Colors.white.withValues(alpha: i % 3 == 0 ? 0.45 : 0.2)
          ..strokeWidth = i % 3 == 0 ? 2.4 : 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect,
        start,
        sweep * progress.clamp(0, 1),
        false,
        Paint()
          ..color = fill.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawArc(
        rect,
        start,
        sweep * progress.clamp(0, 1),
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: start,
            endAngle: start + sweep,
            colors: const [
              AppColors.primaryDark,
              AppColors.accent,
              AppColors.yellowSoft,
            ],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round,
      );
    }

    final nightRect = Rect.fromCircle(center: center, radius: radius - 16);
    canvas.drawArc(
      nightRect,
      start,
      sweep,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    if (nightProgress > 0) {
      canvas.drawArc(
        nightRect,
        start,
        sweep * nightProgress.clamp(0, 1),
        false,
        Paint()
          ..color = nightFill
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress ||
      old.nightProgress != nightProgress ||
      old.track != track ||
      old.fill != fill ||
      old.nightFill != nightFill;
}
