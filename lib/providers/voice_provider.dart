import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/agora_service.dart';
import '../services/backend_service.dart';
import '../services/firebase_service.dart';

enum VoiceOrbState { idle, connecting, listening, aiSpeaking, emergency }

class VoiceSession {
  final VoiceOrbState orbState;
  final bool isMuted;
  final String? agentId;
  final String? channelName;
  final String statusText;
  final List<TranscriptLine> transcript;

  const VoiceSession({
    this.orbState = VoiceOrbState.idle,
    this.isMuted = false,
    this.agentId,
    this.channelName,
    this.statusText = 'Tap orb to talk to Aria',
    this.transcript = const [],
  });

  VoiceSession copyWith({
    VoiceOrbState? orbState,
    bool? isMuted,
    String? agentId,
    String? channelName,
    String? statusText,
    List<TranscriptLine>? transcript,
  }) =>
      VoiceSession(
        orbState: orbState ?? this.orbState,
        isMuted: isMuted ?? this.isMuted,
        agentId: agentId ?? this.agentId,
        channelName: channelName ?? this.channelName,
        statusText: statusText ?? this.statusText,
        transcript: transcript ?? this.transcript,
      );
}

class TranscriptLine {
  final String text;
  final bool isUser;
  final DateTime time;
  TranscriptLine(this.text, {required this.isUser}) : time = DateTime.now();
}

class VoiceNotifier extends StateNotifier<VoiceSession> {
  final AgoraService _agora = AgoraService();

  VoiceNotifier() : super(const VoiceSession()) {
    _agora.onAgentJoined = (_) => state = state.copyWith(
          orbState: VoiceOrbState.listening,
          statusText: 'Aria is listening...',
        );
    _agora.onAgentLeft = (_) => _onAgentLeft();
    _agora.onError = (e) => state = state.copyWith(
          orbState: VoiceOrbState.idle,
          statusText: 'Error: $e. Tap to retry.',
        );
    _agora.onTranscript = (isUser, text) {
      final lines = [...state.transcript, TranscriptLine(text, isUser: isUser)];
      state = state.copyWith(transcript: lines);
    };
    _agora.onUserStartedSpeaking = () {
      if (state.orbState == VoiceOrbState.aiSpeaking ||
          state.orbState == VoiceOrbState.listening) {
        state = state.copyWith(
          orbState: VoiceOrbState.listening,
          statusText: 'Listening...',
        );
      }
    };
    _agora.onAgentStartedSpeaking = () {
      if (state.orbState != VoiceOrbState.emergency) {
        state = state.copyWith(
          orbState: VoiceOrbState.aiSpeaking,
          statusText: 'Aria is speaking...',
        );
      }
    };
  }

  Future<void> startSession({
    required String language,
    required Map<String, dynamic> patientContext,
    required int userUid,
  }) async {
    if (state.orbState != VoiceOrbState.idle) return;

    state = state.copyWith(
      orbState: VoiceOrbState.connecting,
      statusText: 'Connecting to Aria...',
      transcript: [],
    );

    try {
      final channelName =
          'care_${userUid}_${DateTime.now().millisecondsSinceEpoch}';

      await _agora.init();
      final token = await BackendService.getAgoraToken(channelName, userUid);
      await _agora.joinChannel(token, channelName, userUid);

      final result = await BackendService.startAgent(
        channelName: channelName,
        userUid: userUid,
        language: language,
        patientContext: patientContext,
      );

      // Backend returns { success, session: { agentId, channelName, ... } }
      final session = result['session'] as Map<String, dynamic>?;
      final agentId = session?['agentId'] as String?;

      state = state.copyWith(
        agentId: agentId,
        channelName: channelName,
        statusText: 'Waiting for Aria to join...',
      );
    } catch (e) {
      await _agora.dispose();
      String msg = 'Failed to connect. Tap to retry.';
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('Network')) {
        msg = 'No network. Check connection & retry.';
      } else if (e.toString().contains('DioException') ||
          e.toString().contains('timeout')) {
        msg = 'Server unreachable. Tap to retry.';
      }
      state = state.copyWith(
        orbState: VoiceOrbState.idle,
        statusText: msg,
      );
    }
  }

  Future<void> endSession() async {
    final agentId = state.agentId;
    final channelName = state.channelName;
    if (agentId != null && channelName != null) {
      await BackendService.stopAgent(agentId, channelName);
    }
    await _agora.dispose();
    state = const VoiceSession(statusText: 'Session ended. Tap to talk again.');
  }

  Future<void> toggleMute() async {
    final muted = !state.isMuted;
    await _agora.setMuted(muted);
    state = state.copyWith(
      isMuted: muted,
      statusText: muted ? 'Microphone muted' : 'Aria is listening...',
    );
  }

  /// Raises a real escalation ticket in Firestore so the nurse dashboard
  /// receives it in real time. Uses the active voice channel when present.
  Future<void> triggerEmergencyCall({
    required int userUid,
    String patientName = 'Patient',
    String reason = 'Emergency button pressed',
  }) async {
    final channelName = state.channelName ??
        'care_${userUid}_${DateTime.now().millisecondsSinceEpoch}';
    state = state.copyWith(
      orbState: VoiceOrbState.emergency,
      statusText: '🚨 Connecting to nurse...',
    );
    try {
      await FirebaseService.raiseEscalation(
        patientName: patientName,
        patientUid: userUid,
        channelName: channelName,
        reason: reason,
      );
      state = state.copyWith(
        statusText: '🚨 Nurse alerted — stay on the line, help is coming.',
      );
    } catch (_) {
      state = state.copyWith(
        statusText: '🚨 Emergency mode — could not reach nurse. Tap to retry.',
      );
    }
  }

  /// Lets a nurse join the patient's live channel from an escalation ticket.
  Future<void> joinExistingChannel({
    required String channelName,
    required int uid,
  }) async {
    state = state.copyWith(
      orbState: VoiceOrbState.connecting,
      statusText: 'Joining patient call...',
      transcript: [],
    );
    try {
      await _agora.dispose();
      await _agora.init();
      final token = await BackendService.getAgoraToken(channelName, uid);
      await _agora.joinChannel(token, channelName, uid);
      state = state.copyWith(
        channelName: channelName,
        orbState: VoiceOrbState.listening,
        statusText: 'Connected — you can hear the patient now.',
      );
    } catch (_) {
      state = state.copyWith(
        orbState: VoiceOrbState.idle,
        statusText: 'Could not join the call. Tap to retry.',
      );
    }
  }

  void _onAgentLeft() {
    state = state.copyWith(
      orbState: VoiceOrbState.idle,
      statusText: 'Session ended. Tap to talk again.',
    );
  }

  @override
  void dispose() {
    _agora.dispose();
    super.dispose();
  }
}

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceSession>(
  (ref) => VoiceNotifier(),
);
