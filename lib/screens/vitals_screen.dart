import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  final _hrCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    setState(() => _saving = true);
    await FirebaseService.saveVitals(uid, {
      'bp_systolic': int.tryParse(_systolicCtrl.text) ?? 0,
      'bp_diastolic': int.tryParse(_diastolicCtrl.text) ?? 0,
      'heart_rate': int.tryParse(_hrCtrl.text) ?? 0,
    });
    _systolicCtrl.clear();
    _diastolicCtrl.clear();
    _hrCtrl.clear();
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Log card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: AppColors.dangerLight,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.favorite_rounded,
                          color: AppColors.danger, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text('Log Vitals',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _VitalInput(
                            ctrl: _systolicCtrl,
                            label: 'Systolic',
                            unit: 'mmHg')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _VitalInput(
                            ctrl: _diastolicCtrl,
                            label: 'Diastolic',
                            unit: 'mmHg')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _VitalInput(
                            ctrl: _hrCtrl,
                            label: 'Heart Rate',
                            unit: 'bpm')),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Reading'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Chart
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.vitalsStream(uid),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text('No vitals recorded yet',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                );
              }
              final systolicSpots = <FlSpot>[];
              final diastolicSpots = <FlSpot>[];
              for (int i = 0; i < docs.length; i++) {
                final d = docs[i].data() as Map<String, dynamic>;
                systolicSpots.add(FlSpot(
                    i.toDouble(), (d['bp_systolic'] as num?)?.toDouble() ?? 0));
                diastolicSpots.add(FlSpot(i.toDouble(),
                    (d['bp_diastolic'] as num?)?.toDouble() ?? 0));
              }
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Blood Pressure Trend',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 180,
                      child: LineChart(LineChartData(
                        gridData: FlGridData(
                          show: true,
                          getDrawingHorizontalLine: (_) => const FlLine(
                              color: AppColors.borderLight, strokeWidth: 1),
                          getDrawingVerticalLine: (_) => const FlLine(
                              color: AppColors.borderLight, strokeWidth: 1),
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: systolicSpots,
                            isCurved: true,
                            color: AppColors.danger,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.danger.withValues(alpha: 0.06),
                            ),
                          ),
                          LineChartBarData(
                            spots: diastolicSpots,
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withValues(alpha: 0.06),
                            ),
                          ),
                        ],
                      )),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Legend(color: AppColors.danger, label: 'Systolic'),
                        const SizedBox(width: 20),
                        _Legend(color: AppColors.primary, label: 'Diastolic'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VitalInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String unit;
  const _VitalInput(
      {required this.ctrl, required this.label, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(
              color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(hintText: unit),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}
