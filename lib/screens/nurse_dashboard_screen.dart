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
                onJoinCall: () async {
                  final notifier = ref.read(voiceProvider.notifier);
                  // Nurse joins the same channel as patient
                  await notifier.startSession(
                    language: lang,
                    userUid: 8888, // nurse UID
                    patientContext: {'role': 'nurse'},
                  );
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
  final VoidCallback onJoinCall;
  final VoidCallback onResolve;

  const _EscalationCard({
    required this.ticketId,
    required this.data,
    required this.onJoinCall,
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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onJoinCall,
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: const Text('Join Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
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
