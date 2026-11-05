import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sip/flutter_sip.dart';
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

/// Kibal Mobile SIP 클라이언트
/// 
/// flutter_sip 라이브러리를 기반으로 SIP 등록, 통화, 해제 기능을 제공합니다.
class KibalSipClient {
  /// SIP 클라이언트 인스턴스
  late SIPClient _client;
  
  /// 현재 설정
  SipConfig? _config;
  
  /// 현재 상태
  SipClientState _state = SipClientState.idle;
  
  /// 현재 세션
  SipSession? _currentSession;
  
  /// 이벤트 스트림 컨트롤러
  final StreamController<SipEvent> _eventController = 
      StreamController<SipEvent>.broadcast();
  
  /// 구독자 콜백
  SipEventCallback? _callback;
  
  /// 등록 상태 리스너
  late StreamSubscription<RegistrationState> _registrationSubscription;
  
  ///通话 상태 리스너
  late StreamSubscription<CallState> _callSubscription;
  
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
    _client = SIPClient();
  }
  
  //--------------------------------------------------------------------------
  // Connection Management
  //--------------------------------------------------------------------------
  
  /// SIP 클라이언트 초기화
  /// 
  /// [config] SIP 설정
  /// [returns] 초기화 성공 여부
  Future<bool> init(SipConfig config) async {
    try {
      _config = config;
      _state = SipClientState.connecting;
      _emitEvent(SipEvent(type: SipEventType.registration, data: _state));
      
      final settings = SIPSettings(
        username: config.username,
        domain: config.domain,
        password: config.password,
        displayName: config.displayName ?? 'Kibal ${config.username}',
        transportType: _mapTransportType(config.transportType),
        port: config.port,
        wsServer: config.wsServer,
        iceServers: config.iceServers,
      );
      
      await _client.init(settings);
      _setupListeners();
      
      _state = SipClientState.connected;
      _emitEvent(SipEvent(type: SipEventType.registration, data: _state));
      
      return true;
    } catch (e) {
      _state = SipClientState.error;
      _emitEvent(SipEvent(
        type: SipEventType.error,
        error: 'SIP 클라이언트 초기화 실패: $e',
      ));
      return false;
    }
  }
  
  /// SIP 등록
  Future<bool> register() async {
    try {
      if (_state != SipClientState.connected) {
        throw Exception('SIP 클라이언트가 연결되지 않음');
      }
      
      await _client.register();
      return true;
    } catch (e) {
      _emitEvent(SipEvent(
        type: SipEventType.error,
        error: 'SIP 등록 실패: $e',
      ));
      return false;
    }
  }
  
  /// SIP 등록 해제
  Future<bool> unregister() async {
    try {
      await _client.unregister();
      return true;
    } catch (e) {
      _emitEvent(SipEvent(
        type: SipEventType.error,
        error: 'SIP 등록 해제 실패: $e',
      ));
      return false;
    }
  }
  
  /// SIP 연결 해제
  Future<void> disconnect() async {
    try {
      await _client.unregister();
      await _client.close();
      _cleanup();
      _state = SipClientState.idle;
      _emitEvent(SipEvent(type: SipEventType.registration, data: _state));
    } catch (e) {
      _emitEvent(SipEvent(
        type: SipEventType.error,
        error: 'SIP 연결 해제 실패: $e',
      ));
    }
  }
  
  //--------------------------------------------------------------------------
  // Call Management
  //--------------------------------------------------------------------------
  
  /// 통화 시작 (발신)
  /// 
  /// [target] 대상 내선 번호
  Future<bool> call(String target) async {
    try {
      if (_state != SipClientState.registered) {
        throw Exception('SIP 등록되지 않음');
      }
      
      final session = await _client.call(target);
      _currentSession = SipSession(session);
      _emitEvent(SipEvent(
        type: SipEventType.call,
        data: {'action': 'call', 'target': target, 'session': _currentSession},
      ));
      return true;
    } catch (e) {
      _emitEvent(SipEvent(
        type: SipEventType.error,
        error: '통화 시작 실패: $e',
      ));
      return false;
    }
  }
  
  /// 통화 수신 (수신)
  Future<bool> accept() async {
    try {
      if (_currentSession == null) {
        throw Exception('수신 중인 통화 없음');
      }
      
      await _currentSession!.accept();
      _emitEvent(SipEvent(
        type: SipEventType.call,
        data: {'action': 'accept', 'session': _currentSession},
      ));
      return true;
    } catch (e) {
      _emitEvent(SipEvent(
        type: SipEventType.error,
        error: '통화 수신 실패: $e',
      ));
      return false;
    }
  }
  
  /// 통화 거부
  Future<bool> reject() async {
    try {
      if (_currentSession == null) {
        throw Exception('수신 중인 통화 없음');
      }
      
      await _currentSession!.reject();
      _cleanupSession();
      _emitEvent(SipEvent(
        type: SipEventType.call,
        data: {'action': 'reject'},
      ));
      return true;
    } catch (e) {
      _emitEvent(SipEvent(
        type: SipEventType.error,
        error: '통화 거부 실패: $e',
      ));
      return false;
    }
  }
  
  /// 통화 종료
  Future<bool> hangup() async {
    try {
      if (_currentSession == null) {
        throw Exception('통화 중이 아님');
      }
      
      await _currentSession!.hangup();
      _cleanupSession();
      _emitEvent(SipEvent(
        type: SipEventType.call,
        data: {'action': 'hangup'},
      ));
      return true;
    } catch (e) {
      _emitEvent(SipEvent(
        type: SipEventType.error,
        error: '통화 종료 실패: $e',
      ));
      return false;
    }
  }
  
  //--------------------------------------------------------------------------
  // Event Handling
  //--------------------------------------------------------------------------
  
  /// 이벤트 emit
  void _emitEvent(SipEvent event) {
    _eventController.add(event);
    _callback?.call(event);
    
    // 상태 업데이트
    if (event.type == SipEventType.registration) {
      _state = event.data as SipClientState;
    }
  }
  
  /// 리스너 설정
  void _setupListeners() {
    // 등록 상태 리스너
    _registrationSubscription = _client.registrationState.listen((state) {
      switch (state) {
        case RegistrationState.registered:
          _state = SipClientState.registered;
          break;
        case RegistrationState.unregistered:
          _state = SipClientState.unregistered;
          break;
        case RegistrationState.failed:
        case RegistrationState.unregisteredFailure:
          _state = SipClientState.error;
          break;
        default:
          _state = SipClientState.connecting;
          break;
      }
      _emitEvent(SipEvent(
        type: SipEventType.registration,
        data: _state,
      ));
    });
    
    // 통화 상태 리스너
    _callSubscription = _client.callState.listen((callState) {
      switch (callState) {
        case CallState.incoming:
          // 수신 통화
          _emitEvent(SipEvent(
            type: SipEventType.call,
            data: {'state': 'incoming', 'session': callState.session},
          ));
          break;
        case CallState.established:
          // 통화 연결됨
          _emitEvent(SipEvent(
            type: SipEventType.call,
            data: {'state': 'established', 'session': callState.session},
          ));
          break;
        case CallState.terminated:
          // 통화 종료
          _cleanupSession();
          _emitEvent(SipEvent(
            type: SipEventType.call,
            data: {'state': 'terminated'},
          ));
          break;
        default:
          break;
      }
    });
  }
  
  /// 세션 정리
  void _cleanupSession() {
    _currentSession = null;
  }
  
  /// 모든 리소스 정리
  void _cleanup() {
    _registrationSubscription.cancel();
    _callSubscription.cancel();
    _cleanupSession();
  }
  
  /// 전송 타입 매핑
  SingleVideoTransportType _mapTransportType(SipTransportType type) {
    switch (type) {
      case SipTransportType.udp:
        return SingleVideoTransportType.udp;
      case SipTransportType.tcp:
        return SingleVideoTransportType.tcp;
      case SipTransportType.ws:
        return SingleVideoTransportType.ws;
      case SipTransportType.wss:
        return SingleVideoTransportType.wss;
      default:
        return SingleVideoTransportType.udp;
    }
  }
  
  //--------------------------------------------------------------------------
  // Dispose
  //--------------------------------------------------------------------------
  
  /// 리소스 해제
  void dispose() {
    _cleanup();
    _eventController.close();
    _client.close();
  }
}
