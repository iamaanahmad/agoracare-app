import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class WaveformPainter extends CustomPainter {
  final double animValue;
  final Color color;

  WaveformPainter({required this.animValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final midY = size.height / 2;
    final bars = 28;
    final barWidth = size.width / bars;

    for (int i = 0; i < bars; i++) {
      final x = i * barWidth + barWidth / 2;
      final phase = (i / bars) * 2 * pi + animValue * 2 * pi;
      final amplitude = (sin(phase) * 0.5 + 0.5) * (midY * 0.8) + 4;
      canvas.drawLine(
        Offset(x, midY - amplitude),
        Offset(x, midY + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) => old.animValue != animValue;
}

class AnimatedWaveform extends StatefulWidget {
  final bool active;
  final Color color;

  const AnimatedWaveform({
    super.key,
    required this.active,
    this.color = AppColors.primary,
  });

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(AnimatedWaveform old) {
    super.didUpdateWidget(old);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: WaveformPainter(
          animValue: _controller.value,
          color: widget.color,
        ),
        size: const Size(double.infinity, 48),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
