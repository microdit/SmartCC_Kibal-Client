import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';
import '../utils/app_logger.dart';
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
  void onNewReinvite(ReInvite event) {}

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
    return 'ws://${config.domain}:${config.port}/ws';
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

  /// 세션 정리
  void _cleanupSession() {
    _currentSession = null;
    _currentCall = null;
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
