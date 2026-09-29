import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../providers/voice_provider.dart';

class VoiceOrb extends StatefulWidget {
  final VoiceOrbState state;
  final VoidCallback onTap;
  const VoiceOrb({super.key, required this.state, required this.onTap});

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(VoiceOrb old) {
    super.didUpdateWidget(old);
    final ms = switch (widget.state) {
      VoiceOrbState.idle       => 1800,
      VoiceOrbState.connecting => 600,
      VoiceOrbState.listening  => 400,
      VoiceOrbState.aiSpeaking => 600,
      VoiceOrbState.emergency  => 250,
    };
    _pulseCtrl.duration = Duration(milliseconds: ms);
  }

  Color get _color => switch (widget.state) {
    VoiceOrbState.idle       => AppColors.primary,
    VoiceOrbState.connecting => AppColors.warning,
    VoiceOrbState.listening  => AppColors.success,
    VoiceOrbState.aiSpeaking => AppColors.purple,
    VoiceOrbState.emergency  => AppColors.danger,
  };

  IconData get _icon => switch (widget.state) {
    VoiceOrbState.idle       => Icons.mic_rounded,
    VoiceOrbState.connecting => Icons.sync_rounded,
    VoiceOrbState.listening  => Icons.mic_rounded,
    VoiceOrbState.aiSpeaking => Icons.volume_up_rounded,
    VoiceOrbState.emergency  => Icons.warning_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnim, _rotateCtrl]),
        builder: (_, __) {
          return SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulse ring
                Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                // Mid pulse ring
                Transform.scale(
                  scale: _pulseAnim.value * 0.88,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color.withValues(alpha: 0.13),
                    ),
                  ),
                ),
                // Spinning arc (connecting only)
                if (widget.state == VoiceOrbState.connecting)
                  Transform.rotate(
                    angle: _rotateCtrl.value * 2 * pi,
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.5),
                          width: 2.5,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                    ),
                  ),
                // Core orb
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _color.withValues(alpha: 0.95),
                        _color,
                      ],
                      center: const Alignment(-0.3, -0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: _color.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(_icon, color: Colors.white, size: 42),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }
}
