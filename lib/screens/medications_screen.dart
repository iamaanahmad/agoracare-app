import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';
import '../widgets/medication_card.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  String _getStatus(String timeStr) {
    try {
      final now = TimeOfDay.now();
      final parts = timeStr.split(':');
      final medHour = int.parse(parts[0]);
      final medMin = int.parse(parts[1]);
      final nowMins = now.hour * 60 + now.minute;
      final medMins = medHour * 60 + medMin;
      final diff = medMins - nowMins;
      if (diff < -30) return 'missed';
      if (diff.abs() <= 30) return 'due';
      return 'upcoming';
    } catch (_) {
      return 'upcoming';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final today = DateFormat('EEEE, d MMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.medicationsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.5));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const _EmptyMedications();

          final taken = docs
              .where((d) =>
                  (d.data() as Map<String, dynamic>)['status'] == 'taken')
              .length;
          final adherence = taken / docs.length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AdherenceCard(
                  adherence: adherence, taken: taken, total: docs.length),
              const SizedBox(height: 24),
              const Text("Today's Schedule",
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] as String? ??
                    _getStatus(data['time'] as String? ?? '');
                return MedicationCard(
                  name: data['name'] as String? ?? '',
                  dose: data['dose'] as String? ?? '',
                  time: data['time'] as String? ?? '',
                  status: status,
                  onMarkTaken: status == 'due'
                      ? () => FirebaseService.markMedicationTaken(uid, doc.id)
                      : null,
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  final double adherence;
  final int taken;
  final int total;
  const _AdherenceCard(
      {required this.adherence, required this.taken, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = (adherence * 100).round();
    final color = pct >= 80
        ? AppColors.success
        : pct >= 50
            ? AppColors.warning
            : AppColors.danger;
    final bgColor = pct >= 80
        ? AppColors.successLight
        : pct >= 50
            ? AppColors.warningLight
            : AppColors.dangerLight;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: adherence,
                  strokeWidth: 6,
                  backgroundColor: AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Text('$pct%',
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Adherence",
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$taken of $total doses taken',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pct >= 80
                        ? '🎉 Great job!'
                        : pct >= 50
                            ? '⚠️ Keep it up'
                            : '❗ Needs attention',
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMedications extends StatelessWidget {
  const _EmptyMedications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.medication_outlined,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No medications scheduled',
              style: TextStyle(
                  color: AppColors.textSecond,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('Ask Aria to add your medications',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
