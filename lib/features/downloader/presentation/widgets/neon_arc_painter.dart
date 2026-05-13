import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/themes/app_theme.dart';

/// A [CustomPainter] that draws a neon-glowing arc for download progress.
///
/// Extracted here so both [DownloaderPage] and [DownloadsPage] share the same
/// implementation without duplication.
class NeonArcPainter extends CustomPainter {
  final double progress;
  final Color neonColor;
  final Color glowColor;

  const NeonArcPainter({
    required this.progress,
    this.neonColor = AppTheme.neonCyan,
    Color? glowColor,
  }) : glowColor = glowColor ?? const Color(0x3D00CEC9); // neonCyan @ 24%

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 4;
    const strokeWidth = 8.0;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    if (sweepAngle <= 0) return;

    // Outer glow pass
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Main neon arc with gradient
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [AppTheme.neonPurple, neonColor],
          stops: const [0.0, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant NeonArcPainter old) =>
      old.progress != progress || old.neonColor != neonColor;
}

/// An animated pulsing orb used as the header illustration on the
/// downloader screen.
class NeonPulseOrb extends StatelessWidget {
  final Animation<double> animation;
  final double size;
  final IconData icon;

  const NeonPulseOrb({
    super.key,
    required this.animation,
    this.size = 80,
    this.icon = Icons.arrow_downward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final scale = 1.0 + animation.value * 0.06;
        final glow = 8.0 + animation.value * 16;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.neonPurple, AppTheme.neonCyan],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonCyan.withAlpha(80),
                  blurRadius: glow,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppTheme.neonPurple.withAlpha(60),
                  blurRadius: glow * 1.4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.48),
          ),
        );
      },
    );
  }
}
