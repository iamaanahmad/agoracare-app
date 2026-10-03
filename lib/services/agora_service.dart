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
  // isUser: who spoke · text: full text so far · turnKey: unique id for this
  // conversation turn (same key = same bubble, updated in place).
  Function(bool isUser, String text, String turnKey)? onTranscript;
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

  // Reassembly buffer for Agora Convo AI chunked stream messages.
  // Format per packet: "<messageId>|<partIndex>|<totalParts>|<base64Payload>".
  final Map<String, Map<int, String>> _streamParts = {};

  void _handleStreamMessage(int uid, Uint8List data) {
    final raw = utf8.decode(data, allowMalformed: true);

    // Try the chunked "id|idx|total|base64" protocol first.
    final parts = raw.split('|');
    String? payload;
    if (parts.length >= 4) {
      final msgId = parts[0];
      final idx = int.tryParse(parts[1]) ?? 1;
      final total = int.tryParse(parts[2]) ?? 1;
      final chunk = parts.sublist(3).join('|'); // base64 may be chunk only

      final buf = _streamParts.putIfAbsent(msgId, () => {});
      buf[idx] = chunk;
      if (buf.length < total) return; // wait for all parts

      final b64 = List.generate(total, (i) => buf[i + 1] ?? '').join();
      _streamParts.remove(msgId);
      try {
        payload = utf8.decode(base64.decode(b64));
      } catch (_) {
        payload = null;
      }
    } else {
      payload = raw; // maybe already plain JSON
    }

    if (payload == null) return;
    _parseTranscript(uid, payload);
  }

  void _parseTranscript(int uid, String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final object = json['object'] as String? ?? '';

      // Only handle transcription messages (ignore metrics/state/errors).
      if (!object.contains('transcription')) return;

      final text = (json['text'] ?? json['content'] ?? json['data']) as String?;
      if (text == null || text.trim().isEmpty) return;

      // Speaker from the message object type:
      //   assistant.transcription → Aria;  user.transcription → patient.
      final bool isUser = object.startsWith('user')
          ? true
          : object.startsWith('assistant')
              ? false
              : uid != AppConstants.agentUid;

      // Agora tags every transcription with a stream/turn id. All messages
      // sharing the same turn id belong to ONE bubble, which we update in
      // place with the latest (growing) text — this stops both the
      // sentence-splitting into multiple bubbles and the partial-ASR repeats.
      final turnId = (json['turn_id'] ?? json['stream_id'] ?? json['message_id'])
          ?.toString();
      final turnKey = '${isUser ? 'u' : 'a'}:${turnId ?? text.hashCode}';

      onTranscript?.call(isUser, text.trim(), turnKey);
    } catch (_) {
      // Not a transcript payload — ignore.
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
    // Clear transcript reassembly state so sessions don't bleed into each other.
    _streamParts.clear();
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
