import 'dart:convert';
import 'dart:typed_data';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';

class AgoraService {
  RtcEngine? _engine;
  bool _isJoined = false;

  Function(int uid)? onAgentJoined;
  Function(int uid)? onAgentLeft;
  Function(String error)? onError;
  Function(bool isUser, String text)? onTranscript;
  Function()? onUserStartedSpeaking;
  Function()? onAgentStartedSpeaking;

  Future<void> init() async {
    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: AppConstants.agoraAppId));

    // Use AI client scenario — optimized for Conversational AI Engine
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileSpeechStandard,
      scenario: AudioScenarioType.audioScenarioAiClient,
    );
    await _engine!.enableAudio();
    await _engine!.setDefaultAudioRouteToSpeakerphone(true);
    await _engine!.setEnableSpeakerphone(true);

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onError: (err, msg) => onError?.call(msg),
      onJoinChannelSuccess: (conn, elapsed) {
        // User joined — waiting for agent
      },
      onUserJoined: (conn, uid, elapsed) {
        if (uid == AppConstants.agentUid) onAgentJoined?.call(uid);
      },
      onUserOffline: (conn, uid, reason) {
        if (uid == AppConstants.agentUid) onAgentLeft?.call(uid);
      },
      // Agora Conversational AI sends transcript via stream messages
      onStreamMessage: (conn, remoteUid, streamId, data, length, sentTs) {
        _handleStreamMessage(remoteUid, data);
      },
      onAudioVolumeIndication: (conn, speakers, speakerNumber, totalVolume) {
        for (final speaker in speakers) {
          if (speaker.volume != null && speaker.volume! > 20) {
            if (speaker.uid == 0) {
              onUserStartedSpeaking?.call();
            } else if (speaker.uid == AppConstants.agentUid) {
              onAgentStartedSpeaking?.call();
            }
          }
        }
      },
    ));

    // Enable volume indication for speaking state detection
    await _engine!.enableAudioVolumeIndication(
      interval: 500,
      smooth: 3,
      reportVad: true,
    );
  }

  void _handleStreamMessage(int uid, Uint8List data) {
    try {
      final json = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      // Agora Convo AI transcript format
      final text = json['text'] as String? ?? json['content'] as String?;
      if (text != null && text.isNotEmpty) {
        final isUser = uid != AppConstants.agentUid;
        onTranscript?.call(isUser, text);
      }
    } catch (_) {
      // Not a JSON transcript message, ignore
    }
  }

  Future<void> joinChannel(String token, String channelName, int uid) async {
    if (_isJoined) await leaveChannel();
    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
    _isJoined = true;
  }

  Future<void> leaveChannel() async {
    if (!_isJoined) return;
    await _engine!.leaveChannel();
    _isJoined = false;
  }

  Future<void> setMuted(bool muted) async {
    await _engine!.muteLocalAudioStream(muted);
  }

  Future<void> dispose() async {
    await leaveChannel();
    await _engine?.release();
    _engine = null;
  }
}
