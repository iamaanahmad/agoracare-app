import 'package:flutter/material.dart';
import '../core/theme.dart';

class MedicationCard extends StatelessWidget {
  final String name;
  final String dose;
  final String time;
  final String status; // 'upcoming' | 'due' | 'taken' | 'missed'
  final VoidCallback? onMarkTaken;

  const MedicationCard({
    super.key,
    required this.name,
    required this.dose,
    required this.time,
    required this.status,
    this.onMarkTaken,
  });

  Color get _statusColor {
    switch (status) {
      case 'taken':
        return AppColors.success;
      case 'due':
        return AppColors.warning;
      case 'missed':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'taken':
        return '✓ Taken';
      case 'due':
        return '⏰ Due Now';
      case 'missed':
        return '✗ Missed';
      default:
        return 'Upcoming';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medication_rounded,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text('$dose  •  $time',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          if (status == 'due' && onMarkTaken != null)
            GestureDetector(
              onTap: onMarkTaken,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: const Text('Mark Taken',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_statusLabel,
                  style: TextStyle(
                      color: _statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
