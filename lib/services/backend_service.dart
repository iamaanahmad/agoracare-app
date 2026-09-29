import 'package:dio/dio.dart';
import '../core/constants.dart';

class BackendService {
  static final _dio = Dio(BaseOptions(
    baseUrl: AppConstants.backendUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static Future<String> getAgoraToken(String channelName, int uid) async {
    final res = await _dio.post('/api/agora/token', data: {
      'channelName': channelName,
      'uid': uid,
    });
    // Backend returns { token, appId, channel, uid } — token may be empty string if no cert
    return (res.data['token'] as String?) ?? '';
  }

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
    return res.data as Map<String, dynamic>;
  }

  static Future<void> stopAgent(String agentId, String channelName) async {
    try {
      await _dio.post('/api/agora/agent/stop', data: {
        'agentId': agentId,
        'channelName': channelName,
      });
    } catch (_) {
      // Best effort stop
    }
  }
}
