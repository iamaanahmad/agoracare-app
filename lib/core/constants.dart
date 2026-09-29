class AppConstants {
  // Production backend (Vercel)
  static const backendUrl = 'https://agoracare.vercel.app';

  // Agora
  static const agoraAppId = '7c7198641e7a4f3cb3e2add631372592';

  // Agent UID — must match backend (always 9999)
  static const agentUid = 9999;

  // Firestore collections
  static const colEscalations = 'escalations';
  static const colMedications = 'medications';
  static const colAdherence = 'adherence';
  static const colVitals = 'vitals';
}
