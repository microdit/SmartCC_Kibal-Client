import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';
import '../utils/app_logger.dart';
import '../utils/remote_log_forwarder.dart';
import 'sip_config.dart';
import 'sip_session.dart';

/// SIP 클라이언트 상태
enum SipClientState {
  idle,           // 초기 상태
  connecting,     // 연결 중
  connected,      // WebSocket/SIP 연결됨
  registered,     // SIP 등록 완료
  unregistered,   // 등록 해제
  disconnected,   // 연결 끊김
  error,          // 오류 발생
}

/// SIP 이벤트 타입
enum SipEventType {
  registration,   // 등록 상태 변경
  call,           // 통화 상태 변경
  message,        // 메시지 수신
  error,          // 오류 발생
}

/// SIP 이벤트
class SipEvent {
  final SipEventType type;
  final dynamic data;
  final String? error;

  const SipEvent({
    required this.type,
    this.data,
    this.error,
  });

  @override
  String toString() {
    return 'SipEvent(type: $type, data: $data, error: $error)';
  }
}

/// SIP 클라이언트 콜백
typedef SipEventCallback = void Function(SipEvent event);

/// Kibal SIP 클라이언트
///
/// dart-sip-ua(sip_ua) 기반으로 SIP 등록, 통화, 해제 기능을 제공합니다.
/// macOS/iOS/Android/Windows/Web에서 동일하게 동작합니다.
class KibalSipClient implements SipUaHelperListener {
  /// SIP UA 헬퍼 (dart-sip-ua)
  final SIPUAHelper _helper = SIPUAHelper();

  /// 현재 설정
  SipConfig? _config;

  /// 현재 상태
  SipClientState _state = SipClientState.idle;

  /// 현재 세션
  SipSession? _currentSession;

  /// 현재 통화
  Call? _currentCall;

  /// 이벤트 스트림 컨트롤러
  final StreamController<SipEvent> _eventController =
      StreamController<SipEvent>.broadcast();

  /// 구독자 콜백
  SipEventCallback? _callback;

  /// 전송 연결 대기
  Completer<bool>? _transportCompleter;

  /// 등록 대기
  Completer<bool>? _registerCompleter;

  /// onTrack 래핑 설치된 통화 ID (H1/A1: msid 없는 원격 트랙 복구)
  final Set<String> _trackRecoveryInstalled = <String>{};

  /// 복구된 원격 트랙을 담는 세션별 스트림
  final Map<String, MediaStream> _recoveredRemoteStreams =
      <String, MediaStream>{};

  /// 중복 복구 방지용 트랙 키 (callId:trackId)
  final Set<String> _recoveredTrackKeys = <String>{};

  /// sip_ua가 정상 STREAM 이벤트로 노출한 트랙 키 (callId:trackId)
  final Set<String> _surfacedTrackKeys = <String>{};

  /// 수신기 스윕 예약된 통화 ID
  final Set<String> _receiverSweepScheduled = <String>{};

  /// RTP 수신량 진단 타이머 (T-C)
  Timer? _statsTimer;

  //--------------------------------------------------------------------------
  // Public API
  //--------------------------------------------------------------------------

  /// SIP 클라이언트 상태
  SipClientState get state => _state;

  /// 현재 설정
  SipConfig? get config => _config;

  /// 현재 세션
  SipSession? get currentSession => _currentSession;

  /// 이벤트 스트림
  Stream<SipEvent> get events => _eventController.stream;

  /// 생성자
  KibalSipClient({SipEventCallback? callback}) {
    _callback = callback;
    _helper.addSipUaHelperListener(this);
  }

  //--------------------------------------------------------------------------
  // Connection Management
  //--------------------------------------------------------------------------

  /// SIP 클라이언트 초기화 및 전송 연결
  Future<bool> init(SipConfig config) async {
    try {
      _config = config;
      _setState(SipClientState.connecting);

      final settings = UaSettings()
        ..webSocketUrl = _webSocketUrl(config)
        ..uri = 'sip:${config.username}@${config.domain}'
        ..authorizationUser = config.username
        ..password = config.password
        ..displayName = config.displayName ?? 'Kibal ${config.username}'
        ..transportType = TransportType.WS
        ..register = true
        ..register_expires = 300
        ..userAgent = 'Kibal Client/1.0'
        ..iceServers = config.iceServers
            .map((url) => <String, String>{'urls': url})
            .toList();

      final transportCompleter = Completer<bool>();
      _transportCompleter = transportCompleter;
      await _helper.start(settings);

      var connected = false;
      // register:true 자동등록 성공 시 identity 기록
      AppLogger.setIdentity(user: config.username, domain: config.domain);
      // 원격 로그 수집: 도메인/내선 번호를 반영해 라우팅/식별
      RemoteLogForwarder.instance.onLogin(
        extension: config.username,
        domain: config.domain,
      );
      AppLogger.instance.call('init',
          params: {
            'ws': _webSocketUrl(config),
            'domain': config.domain,
            'port': config.port,
            'transport': config.transportType.name,
          });
      // register:true 자동등록이 급하게 연결(could fail then self-reconnect)까지 대기:
      // connected/registered 어느 것이라도 오면 성공으로 접수 (최대 15초)
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(deadline)) {
        if (_state == SipClientState.connected ||
            _state == SipClientState.registered) {
          connected = true;
          break;
        }
        try {
          connected =
              await transportCompleter.future.timeout(const Duration(
            milliseconds: 300,
          ));
          if (connected) break;
        } on TimeoutException {
          // 재 폴링 계속
        }
      }
      connected = connected ||
          _state == SipClientState.connected ||
          _state == SipClientState.registered;

      if (connected) {
        _setState(SipClientState.connected);
      } else {
        _setState(SipClientState.error);
        _emitError('SIP 전송 연결 시간 초과');
      }

      return connected;
    } catch (e) {
      _setState(SipClientState.error);
      _emitError('SIP 클라이언트 초기화 실패: $e');
      return false;
    }
  }

  /// SIP 등록
  Future<bool> register() async {
    try {
      if (_config == null) {
        throw Exception('SIP 설정이 없음');
      }

      if (_state != SipClientState.connected &&
          _state != SipClientState.unregistered) {
        throw Exception('SIP 전송이 연결되지 않음 (상태: ${_state.name})');
      }

      if (_state == SipClientState.registered) {
        return true;
      }

      final registerCompleter = Completer<bool>();
      _registerCompleter = registerCompleter;
      _helper.register();

      final ok = await registerCompleter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );

      if (!ok) {
        _emitError('SIP 등록 시간 초과 또는 실패');
      }

      return ok;
    } catch (e) {
      _setState(SipClientState.error);
      _emitError('SIP 등록 실패: $e');
      return false;
    }
  }

  /// SIP 등록 해제
  Future<bool> unregister() async {
    try {
      final ok = await _helper.unregister();
      _setState(SipClientState.unregistered);
      return ok;
    } catch (e) {
      _emitError('SIP 등록 해제 실패: $e');
      return false;
    }
  }

  /// SIP 연결 해제
  Future<void> disconnect() async {
    try {
      _helper.stop();
      _cleanup();
      _setState(SipClientState.idle);
    } catch (e) {
      _emitError('SIP 연결 해제 실패: $e');
    }
  }

  //--------------------------------------------------------------------------
  // Call Management
  //--------------------------------------------------------------------------

  /// 통화 시작 (발신)
  ///
  /// [mediaStream]을 지정하면 해당 로컬 스트림을 통화에 사용하고,
  /// 생략하면 SIP 엔진이 직접 카메라/마이크를 획득합니다.
  Future<bool> call(String target, {MediaStream? mediaStream}) async {
    try {
      if (_state != SipClientState.registered) {
        throw Exception('SIP 등록되지 않음');
      }

      if (_currentCall != null) {
        throw Exception('이미 통화 중임');
      }

      // 카메라가 없는 환경에서는 음성 통화로 자동 대체
      final voiceOnly = !await _canUseVideo(mediaStream);
      AppLogger.instance.i(
          'SIP call -> $target voiceOnly=$voiceOnly hasLocalStream=${mediaStream != null}');
      final ok = await _helper.call(
        target,
        voiceOnly: voiceOnly,
        mediaStream: mediaStream,
      );
      if (!ok) {
        throw Exception('통화 요청이 거부됨');
      }

      _currentSession = SipSession(target)
        ..setType(SipSessionType.outgoing)
        ..setRemoteParty(target);

      _emitEvent(SipEvent(
        type: SipEventType.call,
        data: {
          'action': 'call',
          'target': target,
          'session': _currentSession,
        },
      ));

      return true;
    } catch (e) {
      _emitError('통화 시작 실패: $e');
      return false;
    }
  }

  /// 통화 수신
  Future<bool> accept({MediaStream? mediaStream}) async {
    try {
      final call = _currentCall;
      if (call == null) {
        throw Exception('수신 중인 통화 없음');
      }

      final voiceOnly = call.voiceOnly || !await _canUseVideo(mediaStream);
      AppLogger.instance
          .i('SIP accept <- ${_targetOf(call)} voiceOnly=$voiceOnly');
      call.answer(
        _helper.buildCallOptions(voiceOnly),
        mediaStream: mediaStream,
      );
      _currentSession?.updateState(SipSessionState.established);

      _emitEvent(SipEvent(
        type: SipEventType.call,
        data: {
          'action': 'accept',
          'target': _targetOf(call),
          'session': _currentSession,
        },
      ));
      return true;
    } catch (e) {
      _emitError('통화 수신 실패: $e');
      return false;
    }
  }

  /// 통화 거부
  Future<bool> reject() async {
    try {
      final call = _currentCall;
      if (call == null) {
        throw Exception('수신 중인 통화 없음');
      }

      call.hangup();
      AppLogger.instance.i('SIP reject');
      _cleanupSession();

      _emitEvent(const SipEvent(
        type: SipEventType.call,
        data: {'action': 'reject'},
      ));
      return true;
    } catch (e) {
      _emitError('통화 거부 실패: $e');
      return false;
    }
  }

  /// 통화 종료
  Future<bool> hangup() async {
    try {
      final call = _currentCall;
      if (call == null) {
        throw Exception('통화 중이 아님');
      }

      call.hangup();
      AppLogger.instance.i('SIP hangup (local)');
      _cleanupSession();

      _emitEvent(const SipEvent(
        type: SipEventType.call,
        data: {'action': 'hangup'},
      ));
      return true;
    } catch (e) {
      _emitError('통화 종료 실패: $e');
      return false;
    }
  }

  //--------------------------------------------------------------------------
  // SipUaHelperListener
  //--------------------------------------------------------------------------

  @override
  void registrationStateChanged(RegistrationState state) {
    switch (state.state) {
      case RegistrationStateEnum.REGISTERED:
        _setState(SipClientState.registered);
        _completeRegister(true);
        break;
      case RegistrationStateEnum.REGISTRATION_FAILED:
        _setState(SipClientState.error);
        _emitError('SIP 등록 실패: ${state.cause ?? '알 수 없는 원인'}');
        _completeRegister(false);
        break;
      case RegistrationStateEnum.UNREGISTERED:
        _setState(SipClientState.unregistered);
        _completeRegister(false);
        break;
      case RegistrationStateEnum.NONE:
      case null:
        break;
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    switch (state.state) {
      case TransportStateEnum.CONNECTING:
        _setState(SipClientState.connecting);
        break;
      case TransportStateEnum.CONNECTED:
        _setState(SipClientState.connected);
        _completeTransport(true);
        break;
      case TransportStateEnum.DISCONNECTED:
        AppLogger.instance
            .i('SIP transport disconnected (cause: ${state.cause ?? '없음'})');
        _setState(SipClientState.disconnected);
        _completeTransport(false);
        break;
      case TransportStateEnum.NONE:
        break;
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    final target = _targetOf(call);
    // H1/A1: sip_ua는 event.streams가 비어 있는 원격 트랙(msid 없음)을
    // STREAM 이벤트로 emit하지 않는다. 회의 오디오 누락을 복구하기 위해
    // peerConnection.onTrack을 래핑해 orphan 트랙을 세션 스트림으로 승격한다.
    if (state.state != CallStateEnum.ENDED &&
        state.state != CallStateEnum.FAILED) {
      _installRemoteTrackRecovery(call);
    }
    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        _currentCall = call;
        AppLogger.instance.call('callInitiation',
            target: target,
            state: 'initiated',
            params: {
              'direction':
                  (call.direction)?.name ?? '-',
              'id': call.id,
            });
        if (call.direction == Direction.incoming) {
          _currentSession = SipSession(call.id)
            ..setType(SipSessionType.incoming)
            ..setRemoteParty(_targetOf(call));

          _emitEvent(SipEvent(
            type: SipEventType.call,
            data: {
              'action': 'incoming',
              'target': _targetOf(call),
              'session': _currentSession,
            },
          ));
        }
        break;

      case CallStateEnum.CONNECTING:
      case CallStateEnum.PROGRESS:
        _currentSession?.updateState(SipSessionState.connecting);
        AppLogger.instance.call('callProgress',
            target: target,
            state: state.state.name,
            params: {'id': call.id});
        _emitEvent(SipEvent(
          type: SipEventType.call,
          data: {'action': 'progress', 'target': _targetOf(call)},
        ));
        break;

      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        _currentSession?.updateState(SipSessionState.established);
        _startStatsProbe(call);
        _scheduleReceiverSweep(call);
        AppLogger.instance.call('callEstablished',
            target: target,
            state: state.state.name,
            params: {'id': call.id});
        _emitEvent(SipEvent(
          type: SipEventType.call,
          data: {
            'action': 'established',
            'target': _targetOf(call),
            'session': _currentSession,
          },
        ));
        break;

      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _currentSession?.updateState(
          state.state == CallStateEnum.FAILED
              ? SipSessionState.failed
              : SipSessionState.terminated,
        );
        AppLogger.instance.call('callTerminated',
            target: target,
            state: state.state.name,
            params: {
              'id': call.id,
              'cause': state.cause?.toString() ?? '-',
            });
        _emitEvent(SipEvent(
          type: SipEventType.call,
          data: {'action': 'terminated', 'target': _targetOf(call)},
        ));
        _cleanupSession();
        break;

      case CallStateEnum.STREAM:
        // 원격/로컬 미디어 스트림 수신 (originator: local/remote)
        final stream = state.stream;
        // sip_ua가 정상 노출한 트랙은 수신기 스윕 대상에서 제외
        if (stream != null) {
          final streamCallId = call.id ?? 'unknown';
          for (final track in stream.getTracks()) {
            _surfacedTrackKeys.add('$streamCallId:${track.id}');
          }
        }
        final videoTracks = stream?.getVideoTracks().length ?? 0;
        final audioTracks = stream?.getAudioTracks().length ?? 0;
        AppLogger.instance.call('mediaStream',
            target: _targetOf(call),
            state: state.originator?.name ?? '-',
            params: {
              'video': videoTracks,
              'audio': audioTracks,
              'id': call.id,
            });
        _emitEvent(SipEvent(
          type: SipEventType.call,
          data: {
            'action': 'stream',
            'target': _targetOf(call),
            'sessionId': call.id,
            'originator': state.originator?.toString(),
            'stream': state.stream,
          },
        ));
        break;

      case CallStateEnum.UNMUTED:
      case CallStateEnum.MUTED:
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
      case CallStateEnum.REFER:
      case CallStateEnum.NONE:
        break;
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {
    final hasAudio = event.hasAudio ?? false;
    final hasVideo = event.hasVideo ?? false;
    AppLogger.instance.i(
        'SIP re-INVITE 수신 hasAudio=$hasAudio hasVideo=$hasVideo -> 자동 수락');
    unawaited(_acceptReinvite(event));
  }

  Future<void> _acceptReinvite(ReInvite event) async {
    final accept = event.accept;
    if (accept == null) {
      AppLogger.instance.w('SIP re-INVITE accept 콜백 없음');
      return;
    }
    try {
      final accepted = await accept(<String, dynamic>{});
      AppLogger.instance.i('SIP re-INVITE 응답 전송 accepted=$accepted');
    } catch (error) {
      AppLogger.instance.e('SIP re-INVITE 수락 실패: $error');
    }
  }

  //--------------------------------------------------------------------------
  // Remote Track Recovery / Media Diagnostics (H1/A1, T-C)
  //--------------------------------------------------------------------------

  /// peerConnection.onTrack을 래핑해 msid 없는 원격 트랙을 복구한다.
  ///
  /// sip_ua 1.1.0은 `if (event.streams.isNotEmpty)`일 때만 STREAM 이벤트를
  /// emit하므로, msid가 없는 원격 오디오 트랙은 조용히 폐기된다.
  /// ConfBridge(SFU) 회의에서 서버는 오디오를 보내지만 클라이언트가 이를
  /// 노출하지 못하는 H1 증상의 직접 원인이다.
  void _installRemoteTrackRecovery(Call call) {
    final pc = call.peerConnection;
    final callId = call.id;
    if (pc == null || callId == null) return;
    if (!_trackRecoveryInstalled.add(callId)) return;

    final previous = pc.onTrack;
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isEmpty) {
        _recoverRemoteTrack(call, event.track);
      }
      previous?.call(event);
    };
    AppLogger.instance.d('SIP remote-track recovery armed id=$callId');
  }

  /// msid가 없는 원격 트랙을 세션 스트림으로 승격한다.
  Future<void> _recoverRemoteTrack(Call call, MediaStreamTrack track) async {
    // 종료된 통화의 늦은 콜백으로 인한 stale 이벤트 방지
    if (_currentCall == null || _currentCall!.id != call.id) return;
    final callId = call.id ?? 'unknown';
    final key = '$callId:${track.id}';
    if (!_recoveredTrackKeys.add(key)) return;

    try {
      var stream = _recoveredRemoteStreams[callId];
      if (stream == null) {
        stream = await createLocalMediaStream('kibal-remote-$callId');
        _recoveredRemoteStreams[callId] = stream;
      }
      // addToNative=false: 재협상 후 nil 스트림 addTrack 크래시(D8) 회피.
      // 원격 오디오 재생은 WebRTC 오디오 엔진이 자동 수행하므로
      // 네이티브 스트림 컨테이너 등록은 불필요하다.
      await stream.addTrack(track, addToNative: false);

      final video = stream.getVideoTracks().length;
      final audio = stream.getAudioTracks().length;
      AppLogger.instance.call('mediaStream',
          target: _targetOf(call),
          state: 'remote',
          params: {
            'video': video,
            'audio': audio,
            'id': callId,
            'recovered': true,
            'kind': track.kind,
          });
      _emitEvent(SipEvent(
        type: SipEventType.call,
        data: {
          'action': 'stream',
          'target': _targetOf(call),
          'sessionId': callId,
          'originator': 'Originator.remote',
          'stream': stream,
          'recovered': true,
        },
      ));
    } catch (e) {
      _recoveredTrackKeys.remove(key);
      AppLogger.instance.e('SIP remote-track recovery failed ($key): $e');
    }
  }

  /// onTrack 이벤트가 누락된 경우를 대비한 수신기 스윕 폴백.
  ///
  /// 통화 확립 2초 후 각 RTCRtpReceiver의 오디오 트랙 중 sip_ua가 아직
  /// 노출하지 않은 트랙을 복구한다(중복은 키 집합으로 방지).
  void _scheduleReceiverSweep(Call call) {
    final callId = call.id;
    if (callId == null) return;
    if (!_receiverSweepScheduled.add(callId)) return;

    Future<void>.delayed(const Duration(seconds: 2), () async {
      if (_currentCall?.id != callId) return;
      final pc = call.peerConnection;
      if (pc == null) return;
      try {
        final receivers = await pc.getReceivers();
        for (final receiver in receivers) {
          final track = receiver.track;
          if (track == null || track.kind != 'audio') continue;
          final key = '$callId:${track.id}';
          if (_surfacedTrackKeys.contains(key)) continue;
          await _recoverRemoteTrack(call, track);
        }
      } catch (e) {
        AppLogger.instance.w('SIP receiver sweep 실패: $e');
      }
    });
  }

  /// RTP 수신량 진단 로그 (T-C: 오디오가 실제로 흐르는지 확인).
  /// 원격 영상 트랙별 수신 바이트 추적(유효 트랙 판정, B3/F4)
  final Map<String, int> _videoTrackBytes = {};
  final Map<String, DateTime> _videoTrackLastGrowth = {};
  final Map<String, DateTime> _videoTrackFirstSeen = {};
  int _summaryAudioBase = 0;
  int _summaryVideoBase = 0;
  int _probeTicks = 0;

  static const Duration _trackStaleAfter = Duration(seconds: 15);
  static const int _summaryEveryTicks = 6; // 5초 x 6 = 30초

  /// RTP 수신량 진단 + 유효 영상 트랙 판정 + 30초 INFO 요약.
  ///
  /// - 5초 DEBUG: 기존 `SIP stats inbound` (로컬 정밀 분석용)
  /// - 30초 INFO: `SIP media summary` (기본 업로드 모드에서도 서버 진단/하트비트)
  /// - 유효 트랙: 최근 15초 내 bytesReceived가 증가한 영상 트랙 → UI 타일 정리
  void _startStatsProbe(Call call) {
    _statsTimer?.cancel();
    _videoTrackBytes.clear();
    _videoTrackLastGrowth.clear();
    _videoTrackFirstSeen.clear();
    _summaryAudioBase = 0;
    _summaryVideoBase = 0;
    _probeTicks = 0;
    _statsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final pc = call.peerConnection;
      if (pc == null) return;
      try {
        final reports = await pc.getStats();
        final now = DateTime.now();
        var audioBytes = 0;
        var videoBytes = 0;
        var audioPackets = 0;
        var audioLost = 0;
        var identified = 0;
        final seen = <String>{};
        for (final report in reports) {
          if (report.type != 'inbound-rtp') continue;
          final values = report.values;
          final kind = values['kind'] ?? values['mediaType'];
          final bytes = (values['bytesReceived'] as num?)?.toInt() ?? 0;
          final packets = (values['packetsReceived'] as num?)?.toInt() ?? 0;
          if (kind == 'audio') {
            audioBytes += bytes;
            audioPackets += packets;
            audioLost += (values['packetsLost'] as num?)?.toInt() ?? 0;
          } else if (kind == 'video') {
            videoBytes += bytes;
            final trackId = values['trackIdentifier'] as String?;
            if (trackId == null || trackId.isEmpty) continue;
            identified++;
            seen.add(trackId);
            _videoTrackFirstSeen.putIfAbsent(trackId, () => now);
            final prev = _videoTrackBytes[trackId];
            if (prev == null || bytes > prev) {
              _videoTrackLastGrowth[trackId] = now;
            }
            _videoTrackBytes[trackId] = bytes;
          }
        }
        AppLogger.instance.d('SIP stats inbound '
            'audioBytes=$audioBytes audioPackets=$audioPackets '
            'videoBytes=$videoBytes');

        // 유효 영상 트랙: 최근 15초 내 수신 증가 또는 막 등장한 트랙(유예)
        if (identified > 0) {
          final active = <String>{};
          for (final id in seen) {
            final grew = _videoTrackLastGrowth[id];
            final first = _videoTrackFirstSeen[id]!;
            if ((grew != null && now.difference(grew) < _trackStaleAfter) ||
                now.difference(first) < _trackStaleAfter) {
              active.add(id);
            }
          }
          _emitEvent(SipEvent(
            type: SipEventType.call,
            data: {
              'action': 'activeTracks',
              'sessionId': call.id,
              'trackIds': active.toList(),
            },
          ));
        }

        // 30초 INFO 요약(하트비트 겸용)
        _probeTicks++;
        if (_probeTicks % _summaryEveryTicks == 0) {
          final dA = audioBytes - _summaryAudioBase;
          final dV = videoBytes - _summaryVideoBase;
          _summaryAudioBase = audioBytes;
          _summaryVideoBase = videoBytes;
          final activeCount = seen.where((id) {
            final g = _videoTrackLastGrowth[id];
            return g != null && now.difference(g) < _trackStaleAfter;
          }).length;
          final ice = pc.iceConnectionState?.toString().split('.').last ?? '-';
          AppLogger.instance.i('SIP media summary 30s '
              'audioKB=${(dA / 1024).toStringAsFixed(0)} '
              'videoKB=${(dV / 1024).toStringAsFixed(0)} '
              'videoTracks=$activeCount/${seen.length} '
              'audioLost=$audioLost ice=$ice'
              '${dA <= 0 ? ' WARN_NO_AUDIO' : ''}');
        }
      } catch (e) {
        AppLogger.instance.w('SIP stats 수집 실패: $e');
      }
    });
  }

  void _stopMediaDiagnostics() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  void _disposeRecoveredRemoteStreams() {
    for (final stream in _recoveredRemoteStreams.values) {
      stream.dispose();
    }
    _recoveredRemoteStreams.clear();
    _recoveredTrackKeys.clear();
    _surfacedTrackKeys.clear();
    _receiverSweepScheduled.clear();
    _trackRecoveryInstalled.clear();
  }

  //--------------------------------------------------------------------------
  // Event Handling
  //--------------------------------------------------------------------------

  /// 비디오 사용 가능 여부 (카메라 유무 확인)
  Future<bool> _canUseVideo(MediaStream? stream) async {
    if (stream != null) {
      return stream.getVideoTracks().isNotEmpty;
    }

    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      return devices.any((device) => device.kind == 'videoinput');
    } catch (_) {
      return true;
    }
  }

  /// WebSocket URL 결정
  String _webSocketUrl(SipConfig config) {
    final server = config.wsServer;
    if (server != null && server.isNotEmpty) {
      return server;
    }
    // D1: SIP 포트(5060)로 ws URL을 만들면 Connection refused 폭주.
    // wsServer 미지정 시 Asterisk 기본 WS 포트 8088 사용.
    final wsPort = config.port == 8088 ? config.port : 8088;
    AppLogger.instance.w(
        'WS 서버 미지정 → 기본 ws://${config.domain}:$wsPort/ws 사용 (port=${config.port})');
    return 'ws://${config.domain}:$wsPort/ws';
  }

  /// 원격 식별자에서 사용자 부분 추출
  String? _targetOf(Call call) {
    final identity = call.remote_identity;
    if (identity == null) return null;

    var value = identity;
    if (value.startsWith('sip:') || value.startsWith('sips:')) {
      value = value.substring(value.indexOf(':') + 1);
    }
    final at = value.indexOf('@');
    return at > 0 ? value.substring(0, at) : value;
  }

  /// 등록 대기 완료 (중복 완료 방지)
  void _completeRegister(bool value) {
    final completer = _registerCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
    _registerCompleter = null;
  }

  /// 전송 연결 대기 완료 (중복 완료 방지)
  void _completeTransport(bool value) {
    final completer = _transportCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
    _transportCompleter = null;
  }

  /// 상태 변경 및 등록 이벤트 emit
  void _setState(SipClientState state) {
    _state = state;
    AppLogger.instance.i('SIP state -> ${state.name}');
    _emitEvent(SipEvent(type: SipEventType.registration, data: state));
  }

  /// 오류 이벤트 emit
  void _emitError(String message) {
    AppLogger.instance.e('SIP $message');
    _emitEvent(SipEvent(type: SipEventType.error, error: message));
  }

  /// 이벤트 emit
  void _emitEvent(SipEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
    _callback?.call(event);
  }

  /// 세션 정리 (통화 종료/거부/행업 공통 경로)
  void _cleanupSession() {
    _resetMediaDiagnostics();
    _currentSession = null;
    _currentCall = null;
  }

  /// 통화 종료 시 미디어 진단/복구 리소스 정리 (멱등)
  void _resetMediaDiagnostics() {
    _stopMediaDiagnostics();
    _disposeRecoveredRemoteStreams();
  }

  /// 모든 리소스 정리
  void _cleanup() {
    _cleanupSession();
    _transportCompleter = null;
    _registerCompleter = null;
  }

  //--------------------------------------------------------------------------
  // Dispose
  //--------------------------------------------------------------------------

  /// 리소스 해제
  void dispose() {
    _helper.removeSipUaHelperListener(this);
    _helper.stop();
    _cleanup();
    _eventController.close();
  }
}
