import 'dart:convert';
import 'dart:typed_data';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';

class AgoraService {
  RtcEngine? _engine;
  bool _isJoined = false;

  bool get isJoined => _isJoined;

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
    // Route audio to the loudspeaker by default. The explicit
    // setEnableSpeakerphone() call is deferred until AFTER joinChannel —
    // calling it here returns ERR_NOT_READY (-3) because audio routing
    // isn't initialized until the engine is in a channel.
    await _engine!.setDefaultAudioRouteToSpeakerphone(true);

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onError: (err, msg) {
        debugPrint('[Agora] onError code=$err msg=$msg');
        onError?.call(msg);
      },
      onJoinChannelSuccess: (conn, elapsed) {
        debugPrint('[Agora] onJoinChannelSuccess channel=${conn.channelId} '
            'localUid=${conn.localUid} elapsed=$elapsed');
      },
      onConnectionStateChanged: (conn, stateType, reason) {
        debugPrint('[Agora] connectionState=$stateType reason=$reason');
      },
      onUserJoined: (conn, uid, elapsed) {
        debugPrint('[Agora] onUserJoined uid=$uid (agentUid=${AppConstants.agentUid}) elapsed=$elapsed');
        // Any remote user that joins a 1:1 care channel is the Convo AI agent.
        // Match the configured agent UID, but also accept any remote peer so a
        // UID-format difference can never strand the session.
        onAgentJoined?.call(uid);
      },
      onUserOffline: (conn, uid, reason) {
        debugPrint('[Agora] onUserOffline uid=$uid reason=$reason');
        onAgentLeft?.call(uid);
      },
      // Agora Conversational AI sends transcript via stream messages
      onStreamMessage: (conn, remoteUid, streamId, data, length, sentTs) {
        debugPrint('[Agora] onStreamMessage from uid=$remoteUid len=$length');
        _handleStreamMessage(remoteUid, data);
      },
      // Fires when the agent's audio stream starts/stops — confirms audio flow.
      onRemoteAudioStateChanged: (conn, remoteUid, state, reason, elapsed) {
        debugPrint('[Agora] onRemoteAudioStateChanged uid=$remoteUid '
            'state=$state reason=$reason');
      },
      onFirstRemoteAudioFrame: (conn, userId, elapsed) {
        debugPrint('[Agora] onFirstRemoteAudioFrame uid=$userId elapsed=$elapsed');
      },
      onAudioVolumeIndication: (conn, speakers, speakerNumber, totalVolume) {
        for (final speaker in speakers) {
          final vol = speaker.volume ?? 0;
          if (vol > 15) {
            debugPrint('[Agora] volume uid=${speaker.uid} vol=$vol');
            // uid 0 = local user; any non-zero remote uid = the agent (Aria).
            if (speaker.uid == 0) {
              onUserStartedSpeaking?.call();
            } else {
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
    final raw = utf8.decode(data, allowMalformed: true);
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // Agora Convo AI transcript format varies — try common fields.
      final text = json['text'] as String? ??
          json['content'] as String? ??
          json['data'] as String? ??
          json['message'] as String?;
      if (text != null && text.isNotEmpty) {
        final isUser = uid != AppConstants.agentUid;
        onTranscript?.call(isUser, text);
      }
    } catch (_) {
      // Not plain JSON — logged above as RAW for format inspection.
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
        // MUST match the Agora Convo AI agent's channel profile.
        // The agent joins in LIVE_BROADCASTING (mode 2) as a broadcaster;
        // a Communication-profile client would not see it reliably.
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
    _isJoined = true;

    // Now that we're in a channel, audio routing is ready — force speaker on.
    // Wrapped so a routing hiccup never aborts the session.
    try {
      await _engine!.setEnableSpeakerphone(true);
    } catch (_) {
      // Non-fatal: default route already set to speakerphone in init().
    }

    // Explicitly subscribe to the agent's audio and max the playback volume,
    // so Aria's TTS is audible even if auto-subscribe missed the late joiner.
    try {
      await _engine!.muteAllRemoteAudioStreams(false);
      await _engine!.adjustPlaybackSignalVolume(100);
    } catch (e) {
      debugPrint('[Agora] post-join audio setup warning: $e');
    }
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
