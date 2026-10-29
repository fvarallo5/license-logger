import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LlLogo extends StatelessWidget {
  const LlLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'LicenseLogger',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          size: Size.square(size),
          painter: const _LlLogoPainter(),
        ),
      ),
    );
  }
}

class _LlLogoPainter extends CustomPainter {
  const _LlLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.28)),
      Paint()..color = AppColors.primary,
    );

    final stroke = Paint()
      ..color = AppColors.accent
      ..strokeWidth = s * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(
      Path()
        ..moveTo(s * 0.30, s * 0.26)
        ..lineTo(s * 0.30, s * 0.74)
        ..lineTo(s * 0.58, s * 0.74),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.50, s * 0.26)
        ..lineTo(s * 0.50, s * 0.74)
        ..lineTo(s * 0.78, s * 0.74),
      stroke..color = Colors.white.withValues(alpha: 0.88),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
