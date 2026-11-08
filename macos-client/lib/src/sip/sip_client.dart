import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sip/flutter_sip.dart';
import 'package:flutter_sip/login_status_enum.dart';
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
/// 
/// Note: This implementation uses the actual flutter_sip 0.0.8 API
class KibalSipClient {
  /// SIP 클라이언트 인스턴스 (flutter_sip Adaptor)
  late FlutterSip _flutterSip;
  
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
  
  /// 등록 상태 콜백
  // Note: flutter_sip 0.0.8 uses direct callback, not Stream
  
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
    _flutterSip = FlutterSip();
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
      
      // Initialize flutter_sip with SIP server URL
      final sipUrl = 'http://${config.domain}:${config.port}';
      FlutterSip.init(sipUrl);
      
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
      if (_state != SipClientState.connected && _state != SipClientState.unregistered) {
        throw Exception('SIP 클라이언트가 연결되지 않음');
      }
      
      if (_config == null) {
        throw Exception('SIP 설정이 없음');
      }
      
      await _flutterSip.loginSip(
        userName: _config!.username,
        password: _config!.password,
        displayName: _config!.displayName ?? 'Kibal ${_config!.username}',
        sipIp: _config!.domain,
        port: _config!.port.toString(),
      );
      
      // Wait for registration to complete
      await Future.delayed(Duration(seconds: 2));
      return _state == SipClientState.registered;
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
      await _flutterSip.logoutSip();
      _state = SipClientState.unregistered;
      _emitEvent(SipEvent(
        type: SipEventType.registration,
        data: _state,
      ));
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
      await _flutterSip.logoutSip();
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
      
      await _flutterSip.makeCall(
        phoneNo: target,
        displayName: target,
      );
      
      // Create a simple session object
      _currentSession = SipSession(null);
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
  
  /// 통화 수신 (수신) - Note: flutter_sip 0.0.8 doesn't support answerCall
  /// For now, this is a placeholder. Incoming calls need to be handled differently.
  Future<bool> accept() async {
    try {
      if (_currentSession == null) {
        throw Exception('수신 중인 통화 없음');
      }
      
      // TODO: Implement proper call answering
      // flutter_sip 0.0.8 doesn't have answerCall method
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
  
  /// 통화 거부 - Note: flutter_sip 0.0.8 doesn't support endCall for incoming
  Future<bool> reject() async {
    try {
      if (_currentSession == null) {
        throw Exception('수신 중인 통화 없음');
      }
      
      // TODO: Implement proper call rejection
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
  
  /// 통화 종료 - Note: flutter_sip 0.0.8 doesn't support endCall
  /// For now, this is a placeholder
  Future<bool> hangup() async {
    try {
      if (_currentSession == null) {
        throw Exception('통화 중이 아님');
      }
      
      // TODO: Implement proper call termination
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
    // Note: onLoginStatusChange takes a callback directly, not a Stream
    _flutterSip.onLoginStatusChange((status) {
      switch (status) {
        case LoginStatusEnum.progress:
          _state = SipClientState.connecting;
          break;
        case LoginStatusEnum.ok:
          _state = SipClientState.registered;
          break;
        case LoginStatusEnum.cleared:
          _state = SipClientState.unregistered;
          break;
        case LoginStatusEnum.failed:
        case LoginStatusEnum.none:
          _state = SipClientState.error;
          break;
        case LoginStatusEnum.refreshing:
          _state = SipClientState.connecting;
          break;
      }
      _emitEvent(SipEvent(
        type: SipEventType.registration,
        data: _state,
      ));
    });
    
    // Note: flutter_sip 0.0.8 doesn't have onCallStatusChange
    // Call status is handled through explicit method calls (makeCall, answerCall, endCall)
  }
  
  /// 세션 정리
  void _cleanupSession() {
    _currentSession = null;
  }
  
  /// 모든 리소스 정리
  void _cleanup() {
    // Note: flutter_sip 0.0.8 uses direct callback, no subscription to cancel
    _cleanupSession();
  }
  
  //--------------------------------------------------------------------------
  // Dispose
  //--------------------------------------------------------------------------
  
  /// 리소스 해제
  void dispose() {
    _cleanup();
    _eventController.close();
  }
}
