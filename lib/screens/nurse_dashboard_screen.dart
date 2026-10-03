import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/voice_provider.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';

class NurseDashboardScreen extends ConsumerStatefulWidget {
  const NurseDashboardScreen({super.key});

  @override
  ConsumerState<NurseDashboardScreen> createState() =>
      _NurseDashboardScreenState();
}

class _NurseDashboardScreenState
    extends ConsumerState<NurseDashboardScreen> {
  final _player = AudioPlayer();
  int _prevCount = 0;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🚨 Live Escalations'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: AppColors.success, size: 8),
                SizedBox(width: 6),
                Text('Online',
                    style: TextStyle(color: AppColors.success, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.escalationsStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          // Play alert on new ticket
          if (docs.length > _prevCount && _prevCount != 0) {
            _player.play(AssetSource('sounds/alert.mp3'));
          }
          _prevCount = docs.length;

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.success, size: 56),
                  SizedBox(height: 16),
                  Text('No active escalations',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('All patients are stable',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 14)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _EscalationCard(
                ticketId: doc.id,
                data: data,
                onAccept: () async {
                  // Primary action: flip the patient's screen to "connected".
                  // This must succeed regardless of the audio bridge.
                  await FirebaseService.acceptEscalation(doc.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Accepted — joining the patient\'s channel…'),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                  // Secondary: join the PATIENT'S channel (not a new one) to
                  // bridge audio. On a single device this no-ops because the
                  // patient already owns the engine; on the nurse's own device
                  // it joins the live channel. Never let failure undo accept.
                  final patientChannel = data['channelName'] as String? ?? '';
                  if (patientChannel.isNotEmpty) {
                    try {
                      await ref
                          .read(voiceProvider.notifier)
                          .joinAsNurse(patientChannel);
                    } catch (e) {
                      debugPrint('[Nurse] audio join failed (non-fatal): $e');
                    }
                  }
                },
                onResolve: () => FirebaseService.resolveEscalation(doc.id),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

class _EscalationCard extends StatelessWidget {
  final String ticketId;
  final Map<String, dynamic> data;
  final Future<void> Function() onAccept;
  final VoidCallback onResolve;

  const _EscalationCard({
    required this.ticketId,
    required this.data,
    required this.onAccept,
    required this.onResolve,
  });

  Color get _severityColor {
    final s = data['severity'] as String? ?? 'medium';
    switch (s) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severity = (data['severity'] as String? ?? 'medium').toUpperCase();
    final patientName = data['patientName'] as String? ?? 'Unknown Patient';
    final reason = data['reason'] as String? ?? 'Emergency escalation';
    final channel = data['channelName'] as String? ?? '';
    final ts = data['timestamp'] as Timestamp?;
    final timeAgo = ts != null
        ? _timeAgo(ts.toDate())
        : 'Just now';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _severityColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _severityColor.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: _severityColor, size: 16),
                const SizedBox(width: 8),
                Text(severity,
                    style: TextStyle(
                        color: _severityColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const Spacer(),
                Text(timeAgo,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('"$reason"',
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 4),
                Text('Channel: $channel',
                    style: const TextStyle(
                        color: AppColors.border, fontSize: 11)),
                const SizedBox(height: 16),
                if ((data['status'] as String? ?? 'active') == 'accepted')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_in_talk_rounded,
                            color: AppColors.success, size: 16),
                        SizedBox(width: 6),
                        Text('Connected with patient',
                            style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    if ((data['status'] as String? ?? 'active') != 'accepted')
                      Expanded(
                        child: _AcceptButton(onAccept: onAccept),
                      ),
                    if ((data['status'] as String? ?? 'active') != 'accepted')
                      const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onResolve,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Resolve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface2,
                          foregroundColor: AppColors.textMuted,
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ── Accept Button (with in-flight spinner) ───────────────────────────────────

class _AcceptButton extends StatefulWidget {
  final Future<void> Function() onAccept;
  const _AcceptButton({required this.onAccept});

  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await widget.onAccept();
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.call_rounded, size: 18),
      label: Text(_busy ? 'Accepting…' : 'Accept & Join'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
      ),
    );
  }
}
