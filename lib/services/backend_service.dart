import 'package:dio/dio.dart';
import '../core/constants.dart';

class BackendService {
  static final _dio = Dio(BaseOptions(
    baseUrl: AppConstants.backendUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Fetches an Agora RTC token from the backend.
  /// Returns empty string if the backend is not reachable (no-cert mode).
  static Future<String> getAgoraToken(String channelName, int uid) async {
    final res = await _dio.post('/api/agora/token', data: {
      'channelName': channelName,
      'uid': uid,
    });
    return (res.data['token'] as String?) ?? '';
  }

  /// Starts the Agora Conversational AI agent.
  /// Throws on any failure — callers must handle and show a real error.
  static Future<Map<String, dynamic>> startAgent({
    required String channelName,
    required int userUid,
    required String language,
    required Map<String, dynamic> patientContext,
  }) async {
    final res = await _dio.post('/api/agora/agent/start', data: {
      'channelName': channelName,
      'agentUid': AppConstants.agentUid,
      'userUid': userUid,
      'language': language,
      'patientContext': patientContext,
    });

    final data = res.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Agent start returned success=false');
    }
    return data;
  }

  /// Stops the agent — best-effort, errors are silently swallowed.
  static Future<void> stopAgent(String agentId, String channelName) async {
    try {
      await _dio.post('/api/agora/agent/stop', data: {
        'agentId': agentId,
        'channelName': channelName,
      });
    } catch (_) {
      // Best-effort — don't block session cleanup
    }
  }
}
