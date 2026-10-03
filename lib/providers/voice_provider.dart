import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/agora_service.dart';
import '../services/backend_service.dart';
import '../services/firebase_service.dart';

enum VoiceOrbState { idle, connecting, listening, aiSpeaking, emergency }

/// Emergency escalation lifecycle shown on the patient's screen.
enum EmergencyStatus { none, waiting, connected }

class VoiceSession {
  final VoiceOrbState orbState;
  final bool isMuted;
  final String? agentId;
  final String? channelName;
  final String statusText;
  final List<TranscriptLine> transcript;
  final EmergencyStatus emergencyStatus;
  final String? escalationTicketId;

  const VoiceSession({
    this.orbState = VoiceOrbState.idle,
    this.isMuted = false,
    this.agentId,
    this.channelName,
    this.statusText = 'Tap orb to talk to Aria',
    this.transcript = const [],
    this.emergencyStatus = EmergencyStatus.none,
    this.escalationTicketId,
  });

  VoiceSession copyWith({
    VoiceOrbState? orbState,
    bool? isMuted,
    String? agentId,
    String? channelName,
    String? statusText,
    List<TranscriptLine>? transcript,
    EmergencyStatus? emergencyStatus,
    String? escalationTicketId,
    bool clearEscalationTicket = false,
  }) =>
      VoiceSession(
        orbState: orbState ?? this.orbState,
        isMuted: isMuted ?? this.isMuted,
        agentId: agentId ?? this.agentId,
        channelName: channelName ?? this.channelName,
        statusText: statusText ?? this.statusText,
        transcript: transcript ?? this.transcript,
        emergencyStatus: emergencyStatus ?? this.emergencyStatus,
        escalationTicketId: clearEscalationTicket
            ? null
            : (escalationTicketId ?? this.escalationTicketId),
      );
}

class TranscriptLine {
  final String text;
  final bool isUser;
  final String turnKey;
  final DateTime time;
  TranscriptLine(this.text, {required this.isUser, this.turnKey = ''})
      : time = DateTime.now();
}

// ── Provider ────────────────────────────────────────────────────────────────

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceSession>(
  (ref) => VoiceNotifier(),
);

// ── Notifier ─────────────────────────────────────────────────────────────────

class VoiceNotifier extends StateNotifier<VoiceSession> {
  final AgoraService _agora = AgoraService();

  // Completer that resolves when the Agora agent (UID 9999) joins the channel.
  Completer<void>? _agentJoinCompleter;
  Timer? _agentJoinTimeout;

  // Guards against a race: the agent can join the RTC channel BEFORE
  // startSession() finishes awaiting startAgent() and sets up the completer.
  // When that happens we record it here so the wait resolves immediately.
  bool _agentHasJoined = false;

  VoiceNotifier() : super(const VoiceSession()) {
    _agora.onAgentJoined = (_) {
      _agentHasJoined = true;
      // Resolve the completer so startSession() can proceed past the await
      if (_agentJoinCompleter != null && !_agentJoinCompleter!.isCompleted) {
        _agentJoinCompleter!.complete();
      }
      state = state.copyWith(
        orbState: VoiceOrbState.listening,
        statusText: 'Aria is connected — speak now',
      );
    };

    _agora.onAgentLeft = (_) {
      _cancelJoinTimeout();
      state = state.copyWith(
        orbState: VoiceOrbState.idle,
        statusText: 'Session ended. Tap to talk again.',
      );
    };

    _agora.onError = (e) {
      _cancelJoinTimeout();
      _agentJoinCompleter?.completeError(Exception(e));
      state = state.copyWith(
        orbState: VoiceOrbState.idle,
        statusText: 'Error: $e — tap to retry.',
      );
    };

    _agora.onTranscript = (isUser, text, turnKey) {
      final lines = [...state.transcript];
      // One bubble per turn: if we already have a bubble for this turnKey,
      // replace its text with the latest (growing) transcript; otherwise add
      // a new bubble. This keeps each turn as a single, updating message.
      final idx = lines.lastIndexWhere((l) => l.turnKey == turnKey);
      if (idx >= 0) {
        lines[idx] = TranscriptLine(text, isUser: isUser, turnKey: turnKey);
      } else {
        lines.add(TranscriptLine(text, isUser: isUser, turnKey: turnKey));
      }
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

  // ── Start ──────────────────────────────────────────────────────────────────

  Future<void> startSession({
    required String language,
    required Map<String, dynamic> patientContext,
    required int userUid,
  }) async {
    if (state.orbState != VoiceOrbState.idle) return;

    // Reset join-tracking state for this fresh session.
    _agentHasJoined = false;
    _agentJoinCompleter = Completer<void>();

    state = state.copyWith(
      orbState: VoiceOrbState.connecting,
      statusText: 'Connecting to Aria...',
      transcript: const [],
    );

    final channelName =
        'care_${userUid}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // ── Step 1: init Agora RTC engine ──────────────────────────────────
      await _agora.init();

      // ── Step 2: fetch RTC token from backend ───────────────────────────
      state = state.copyWith(statusText: 'Fetching session token...');
      String token;
      try {
        token = await BackendService.getAgoraToken(channelName, userUid);
      } on DioException catch (e) {
        throw _backendError(e, 'Token fetch failed');
      }

      // ── Step 3: join the Agora RTC channel ────────────────────────────
      state = state.copyWith(statusText: 'Joining channel...');
      await _agora.joinChannel(token, channelName, userUid);

      // ── Step 4: arm the join watchdog BEFORE starting the agent ───────
      // The agent often joins the RTC channel within ~1–2 s of the backend
      // call — frequently BEFORE startAgent()'s HTTP response returns. Arming
      // the 15 s timeout here (and tracking _agentHasJoined) avoids a race
      // where onAgentJoined fires before we start awaiting.
      _agentJoinTimeout = Timer(const Duration(seconds: 15), () {
        if (_agentJoinCompleter != null &&
            !_agentJoinCompleter!.isCompleted) {
          _agentJoinCompleter!.completeError(
            TimeoutException(
              'Aria did not join within 15 s. '
              'Check Agora credentials and backend logs.',
            ),
          );
        }
      });

      // ── Step 5: tell the backend to provision the Convo AI agent ──────
      state = state.copyWith(statusText: 'Starting Aria (Agora Convo AI)...');
      Map<String, dynamic> agentResult;
      try {
        agentResult = await BackendService.startAgent(
          channelName: channelName,
          userUid: userUid,
          language: language,
          patientContext: patientContext,
        );
      } on DioException catch (e) {
        throw _backendError(e, 'Agent start failed');
      }

      final session =
          agentResult['session'] as Map<String, dynamic>? ?? {};
      final agentId = session['agentId'] as String? ?? '';

      state = state.copyWith(
        agentId: agentId,
        channelName: channelName,
        statusText: 'Waiting for Aria to join...',
      );

      // ── Step 6: wait for the agent to appear (unless it already did) ──
      if (!_agentHasJoined) {
        await _agentJoinCompleter!.future; // resolves in onAgentJoined
      }
      _cancelJoinTimeout();

      // onAgentJoined already set state to listening — we're done.
    } catch (e) {
      _cancelJoinTimeout();
      await _agora.dispose();

      final msg = e is TimeoutException
          ? e.message ?? 'Aria timed out. Tap to retry.'
          : _friendlyError(e);

      debugPrint('[VoiceProvider] startSession error: $e');
      state = state.copyWith(
        orbState: VoiceOrbState.idle,
        channelName: null,
        agentId: null,
        statusText: msg,
      );
    }
  }

  // ── End ────────────────────────────────────────────────────────────────────

  Future<void> endSession() async {
    _cancelJoinTimeout();
    _escalationSub?.cancel();

    // If an emergency escalation is open, resolve it so it drops off the
    // nurse dashboard (no more stale "connected" cards).
    final ticketId = state.escalationTicketId;
    if (ticketId != null && ticketId.isNotEmpty) {
      await FirebaseService.resolveEscalation(ticketId);
    }

    final agentId = state.agentId;
    final channelName = state.channelName;
    if (agentId != null && channelName != null) {
      await BackendService.stopAgent(agentId, channelName);
    }
    await _agora.dispose();
    // Keep the transcript on screen; it is cleared only when a NEW session
    // starts. Reset session fields but preserve the conversation history.
    state = state.copyWith(
      orbState: VoiceOrbState.idle,
      isMuted: false,
      agentId: null,
      channelName: null,
      statusText: 'Session ended. Tap to talk again.',
      emergencyStatus: EmergencyStatus.none,
      clearEscalationTicket: true,
    );
  }

  // ── Mute ───────────────────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    final muted = !state.isMuted;
    await _agora.setMuted(muted);
    state = state.copyWith(
      isMuted: muted,
      statusText: muted ? 'Microphone muted' : 'Aria is listening...',
    );
  }

  // ── Emergency ──────────────────────────────────────────────────────────────

  StreamSubscription? _escalationSub;

  Future<void> triggerEmergency({
    required String patientName,
    required int patientUid,
  }) async {
    final channelName = state.channelName ??
        'emergency_${patientUid}_${DateTime.now().millisecondsSinceEpoch}';

    state = state.copyWith(
      orbState: VoiceOrbState.emergency,
      statusText: '🚨 Alerting nurse...',
      channelName: channelName,
      emergencyStatus: EmergencyStatus.waiting,
    );

    // Ensure the patient is actually IN the RTC channel so the web nurse has
    // someone to talk to. If a voice session is already live we're already in
    // the channel; otherwise join it now (plain human audio, no AI agent).
    try {
      if (!_agora.isJoined) {
        await _agora.init();
        String token = '';
        try {
          token = await BackendService.getAgoraToken(channelName, patientUid);
        } catch (_) {}
        await _agora.joinChannel(token, channelName, patientUid);
      }
    } catch (e) {
      debugPrint('[VoiceProvider] emergency channel join: $e');
    }

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final ticketId = await FirebaseService.raiseEscalation(
        patientName: patientName,
        patientUid: patientUid,
        channelName: channelName,
        reason: 'Patient requested emergency nurse connection',
        severity: 'critical',
      );

      if (ticketId.isEmpty) {
        state = state.copyWith(
          statusText: '🚨 Could not reach nurse — please call for help.',
          emergencyStatus: EmergencyStatus.none,
        );
        return;
      }

      state = state.copyWith(
        escalationTicketId: ticketId,
        emergencyStatus: EmergencyStatus.waiting,
        statusText: '🚨 Sent — waiting for a nurse to answer...',
      );

      // Listen for the nurse accepting → flip to "connected".
      _escalationSub?.cancel();
      _escalationSub =
          FirebaseService.escalationDocStream(ticketId).listen((snap) {
        final data = snap.data() as Map<String, dynamic>?;
        final status = data?['status'] as String?;
        if (status == 'accepted') {
          state = state.copyWith(
            emergencyStatus: EmergencyStatus.connected,
            statusText: '🚨 Nurse connected — audio bridge active',
          );
        } else if (status == 'resolved') {
          _escalationSub?.cancel();
          state = state.copyWith(
            emergencyStatus: EmergencyStatus.none,
            statusText: 'Nurse call ended.',
          );
        }
      });
    } catch (e) {
      debugPrint('[VoiceProvider] Emergency escalation error: $e');
      state = state.copyWith(
        statusText: '🚨 Could not reach nurse — please call for help.',
        emergencyStatus: EmergencyStatus.none,
      );
    }
  }

  /// Nurse joins the patient's existing RTC channel to bridge live audio.
  /// This is a plain human-to-human join (no Convo AI agent is started).
  /// On a single shared device this no-ops if a session already owns the
  /// engine; on the nurse's own device it connects the two parties.
  Future<void> joinAsNurse(String patientChannel) async {
    // If this app instance is already in a live session (e.g. the SAME device
    // is acting as both patient and nurse during a demo), we cannot open a
    // second Agora connection on one engine. Treat the accept as a logical
    // bridge instead of erroring.
    if (state.orbState != VoiceOrbState.idle &&
        state.orbState != VoiceOrbState.emergency) {
      state = state.copyWith(
        statusText: '🚨 Bridged to patient (same device) — use two devices for live audio',
      );
      return;
    }
    try {
      state = state.copyWith(
        orbState: VoiceOrbState.emergency,
        statusText: '🚨 Joining patient audio…',
        channelName: patientChannel,
      );
      await _agora.init();
      String token = '';
      try {
        token = await BackendService.getAgoraToken(patientChannel, 8888);
      } catch (_) {}
      await _agora.joinChannel(token, patientChannel, 8888);
      state = state.copyWith(
        orbState: VoiceOrbState.emergency,
        statusText: '🚨 Connected to patient — live audio bridge active',
      );
    } catch (e) {
      // -17 = ERR_JOIN_CHANNEL_REJECTED (already joined on this engine).
      final msg = e.toString().contains('-17')
          ? '🚨 Accepted — live audio needs a second device (one engine per app).'
          : 'Could not join patient audio: $e';
      debugPrint('[VoiceProvider] joinAsNurse error: $e');
      state = state.copyWith(statusText: msg);
      // Do NOT rethrow — the accept itself already succeeded.
    }
  }

  /// Patient ends the emergency → resolve the ticket so it drops off the
  /// nurse dashboard, and reset the button.
  Future<void> endEmergency() async {
    _escalationSub?.cancel();
    final ticketId = state.escalationTicketId;
    if (ticketId != null && ticketId.isNotEmpty) {
      await FirebaseService.resolveEscalation(ticketId);
    }
    state = state.copyWith(
      emergencyStatus: EmergencyStatus.none,
      clearEscalationTicket: true,
      statusText: 'Emergency ended.',
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _cancelJoinTimeout() {
    _agentJoinTimeout?.cancel();
    _agentJoinTimeout = null;
  }

  /// Converts a DioException into a readable message.
  String _backendError(DioException e, String prefix) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return '$prefix: backend not reachable. '
          'Run "adb reverse tcp:9002 tcp:9002" and start the server.';
    }
    final serverMsg =
        (e.response?.data as Map?)?['error'] as String? ?? e.message ?? '';
    return '$prefix: $serverMsg';
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('ConnectionRefused')) {
      return 'Backend not reachable. Run "adb reverse tcp:9002 tcp:9002".';
    }
    return 'Connection failed: $msg';
  }

  @override
  void dispose() {
    _cancelJoinTimeout();
    _escalationSub?.cancel();
    _agora.dispose();
    super.dispose();
  }
}
