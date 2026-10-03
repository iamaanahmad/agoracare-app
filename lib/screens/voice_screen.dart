import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/voice_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/voice_orb.dart';
import '../widgets/waveform_painter.dart';

class VoiceScreen extends ConsumerWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(voiceProvider);
    final notifier = ref.read(voiceProvider.notifier);
    final lang = ref.watch(languageProvider);
    final user = FirebaseAuth.instance.currentUser;
    final isActive = session.orbState != VoiceOrbState.idle;

    return SafeArea(
      child: Column(
        children: [
          // ── Status pill ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _StatusPill(session: session),
          ),

          // ── Transcript (scrollable, fills available space) ──────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _TranscriptCard(session: session),
            ),
          ),

          // ── Orb section ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left spacer — same width as mute button to keep orb centered
                SizedBox(
                  width: 56,
                  child: isActive
                      ? _MuteButton(
                          isMuted: session.isMuted,
                          onTap: notifier.toggleMute,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Orb — always centered
                VoiceOrb(
                  state: session.orbState,
                  onTap: () async {
                    if (isActive) {
                      await notifier.endSession();
                    } else {
                      await notifier.startSession(
                        language: lang,
                        userUid: user?.uid.hashCode.abs() ?? 12345,
                        patientContext: {
                          'name': 'Patient',
                          'medications': [
                            'Lisinopril 10mg',
                            'Metformin 500mg',
                            'Amlodipine 5mg',
                            'Simvastatin 20mg',
                          ],
                        },
                      );
                    }
                  },
                ),
                const SizedBox(width: 16),
                // Right spacer — balances layout
                const SizedBox(width: 56),
              ],
            ),
          ),

          // ── Status text ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                session.statusText,
                key: ValueKey(session.statusText),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),

          // ── Emergency button ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: _EmergencyButton(
              status: session.emergencyStatus,
              onTap: session.emergencyStatus == EmergencyStatus.none
                  ? () async {
                      await notifier.triggerEmergency(
                        patientName: user?.displayName ??
                            'Patient (${user?.uid.substring(0, 5) ?? 'Rural'})',
                        patientUid: user?.uid.hashCode.abs() ?? 12345,
                      );
                    }
                  : () async {
                      // While waiting or connected, the button ends the emergency.
                      await notifier.endEmergency();
                    },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Pill ────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final VoiceSession session;
  const _StatusPill({required this.session});

  Color get _color {
    switch (session.orbState) {
      case VoiceOrbState.idle:       return AppColors.primary;
      case VoiceOrbState.connecting: return AppColors.warning;
      case VoiceOrbState.listening:  return AppColors.success;
      case VoiceOrbState.aiSpeaking: return AppColors.purple;
      case VoiceOrbState.emergency:  return AppColors.danger;
    }
  }

  Color get _bgColor {
    switch (session.orbState) {
      case VoiceOrbState.idle:       return AppColors.primaryLight;
      case VoiceOrbState.connecting: return AppColors.warningLight;
      case VoiceOrbState.listening:  return AppColors.successLight;
      case VoiceOrbState.aiSpeaking: return AppColors.purpleLight;
      case VoiceOrbState.emergency:  return AppColors.dangerLight;
    }
  }

  String get _label {
    switch (session.orbState) {
      case VoiceOrbState.idle:       return 'Aria · Ready';
      case VoiceOrbState.connecting: return 'Aria · Connecting';
      case VoiceOrbState.listening:  return 'Aria · Listening';
      case VoiceOrbState.aiSpeaking: return 'Aria · Speaking';
      case VoiceOrbState.emergency:  return 'Aria · Emergency';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: _color),
          const SizedBox(width: 8),
          Text(_label,
              style: TextStyle(
                  color: _color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const Spacer(),
          SizedBox(
            width: 48,
            height: 20,
            child: AnimatedWaveform(
              active: session.orbState == VoiceOrbState.aiSpeaking,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

// ── Mute Button ────────────────────────────────────────────────────────────────

class _MuteButton extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onTap;
  const _MuteButton({required this.isMuted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isMuted ? AppColors.dangerLight : AppColors.surface2,
          border: Border.all(
            color: isMuted ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border,
          ),
          boxShadow: cardShadow,
        ),
        child: Icon(
          isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: isMuted ? AppColors.danger : AppColors.textMuted,
          size: 20,
        ),
      ),
    );
  }
}

// ── Transcript Card ────────────────────────────────────────────────────────────

class _TranscriptCard extends StatefulWidget {
  final VoiceSession session;
  const _TranscriptCard({required this.session});

  @override
  State<_TranscriptCard> createState() => _TranscriptCardState();
}

class _TranscriptCardState extends State<_TranscriptCard> {
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(_TranscriptCard old) {
    super.didUpdateWidget(old);
    if (widget.session.transcript.length != old.session.transcript.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: cardShadow,
      ),
      child: widget.session.transcript.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded,
                        color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tap the orb to start talking',
                      style: TextStyle(
                          color: AppColors.textSecond,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text('Conversation will appear here',
                      style: TextStyle(
                          color: AppColors.textHint, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: widget.session.transcript.length,
              itemBuilder: (_, i) =>
                  _Bubble(line: widget.session.transcript[i]),
            ),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }
}

class _Bubble extends StatelessWidget {
  final TranscriptLine line;
  const _Bubble({required this.line});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: line.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: line.isUser ? AppColors.primary : AppColors.surface2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(line.isUser ? 16 : 4),
            bottomRight: Radius.circular(line.isUser ? 4 : 16),
          ),
        ),
        child: Text(
          line.text,
          style: TextStyle(
            color: line.isUser ? Colors.white : AppColors.textSecond,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ── Emergency Button ───────────────────────────────────────────────────────────

class _EmergencyButton extends StatelessWidget {
  final VoidCallback? onTap;
  final EmergencyStatus status;
  const _EmergencyButton({required this.onTap, required this.status});

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String label;
    late final Color color;

    switch (status) {
      case EmergencyStatus.none:
        icon = Icons.emergency_rounded;
        label = 'Emergency — Connect to Nurse';
        color = AppColors.danger;
        break;
      case EmergencyStatus.waiting:
        icon = Icons.hourglass_top_rounded;
        label = 'Sent — waiting for nurse… (tap to cancel)';
        color = AppColors.warning;
        break;
      case EmergencyStatus.connected:
        icon = Icons.call_end_rounded;
        label = 'Nurse connected — tap to end';
        color = AppColors.success;
        break;
    }

    final bg = status == EmergencyStatus.none
        ? AppColors.dangerLight
        : status == EmergencyStatus.waiting
            ? AppColors.warningLight
            : AppColors.successLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (status == EmergencyStatus.waiting)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
