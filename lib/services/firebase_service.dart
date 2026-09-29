import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;

  // ── Medications ────────────────────────────────────────────────────────────

  static Stream<QuerySnapshot> medicationsStream(String uid) => _db
      .collection(AppConstants.colMedications)
      .doc(uid)
      .collection('schedule')
      .orderBy('time')
      .snapshots();

  static Future<void> markMedicationTaken(String uid, String medId) async {
    await _db
        .collection(AppConstants.colMedications)
        .doc(uid)
        .collection('schedule')
        .doc(medId)
        .update({'status': 'taken'});
  }

  // ── Vitals ─────────────────────────────────────────────────────────────────

  static Future<void> saveVitals(String uid, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.colVitals)
        .doc(uid)
        .collection('readings')
        .add({...data, 'timestamp': FieldValue.serverTimestamp()});
  }

  static Stream<QuerySnapshot> vitalsStream(String uid) => _db
      .collection(AppConstants.colVitals)
      .doc(uid)
      .collection('readings')
      .orderBy('timestamp', descending: false)
      .limit(7)
      .snapshots();

  // ── Escalations ────────────────────────────────────────────────────────────

  static Stream<QuerySnapshot> escalationsStream() => _db
      .collection(AppConstants.colEscalations)
      .where('status', isEqualTo: 'active')
      .orderBy('timestamp', descending: true)
      .snapshots();

  static Future<void> resolveEscalation(String ticketId) async {
    await _db
        .collection(AppConstants.colEscalations)
        .doc(ticketId)
        .update({'status': 'resolved', 'resolvedAt': FieldValue.serverTimestamp()});
  }

  /// Raises a new emergency escalation ticket. Returns the ticket doc ID.
  static Future<String> raiseEscalation({
    required String patientName,
    required int patientUid,
    required String channelName,
    required String reason,
    String severity = 'CRITICAL',
  }) async {
    final doc = await _db.collection(AppConstants.colEscalations).add({
      'patientName': patientName,
      'patientUid': patientUid,
      'channelName': channelName,
      'reason': reason,
      'severity': severity,
      'status': 'active',
      'timestamp': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // ── Demo Data Seeding ──────────────────────────────────────────────────────

  static Future<void> seedDemoDataIfEmpty(String uid) async {
    final medsRef = _db
        .collection(AppConstants.colMedications)
        .doc(uid)
        .collection('schedule');

    final existing = await medsRef.limit(1).get();
    if (existing.docs.isNotEmpty) return; // already seeded

    // Seed medications
    final meds = [
      {'name': 'Lisinopril', 'dose': '10mg', 'time': '08:00', 'status': 'taken', 'icon': 'pill'},
      {'name': 'Metformin', 'dose': '500mg', 'time': '13:00', 'status': 'due', 'icon': 'pill'},
      {'name': 'Amlodipine', 'dose': '5mg', 'time': '18:30', 'status': 'upcoming', 'icon': 'pill'},
      {'name': 'Simvastatin', 'dose': '20mg', 'time': '21:00', 'status': 'upcoming', 'icon': 'pill'},
    ];
    for (final med in meds) {
      await medsRef.add({...med, 'createdAt': FieldValue.serverTimestamp()});
    }

    // Seed vitals (last 7 days)
    final vitalsRef = _db
        .collection(AppConstants.colVitals)
        .doc(uid)
        .collection('readings');

    final now = DateTime.now();
    final vitalsData = [
      {'bp_systolic': 128, 'bp_diastolic': 82, 'heart_rate': 74},
      {'bp_systolic': 132, 'bp_diastolic': 85, 'heart_rate': 78},
      {'bp_systolic': 125, 'bp_diastolic': 80, 'heart_rate': 72},
      {'bp_systolic': 130, 'bp_diastolic': 84, 'heart_rate': 76},
      {'bp_systolic': 127, 'bp_diastolic': 81, 'heart_rate': 73},
      {'bp_systolic': 122, 'bp_diastolic': 79, 'heart_rate': 70},
      {'bp_systolic': 126, 'bp_diastolic': 82, 'heart_rate': 75},
    ];
    for (int i = 0; i < vitalsData.length; i++) {
      await vitalsRef.add({
        ...vitalsData[i],
        'timestamp': Timestamp.fromDate(now.subtract(Duration(days: 6 - i))),
      });
    }
  }
}
