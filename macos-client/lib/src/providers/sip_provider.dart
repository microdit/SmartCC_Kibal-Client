import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../sip/sip_client.dart';
import '../sip/sip_config.dart';
import '../utils/app_logger.dart';

/// SIP Provider
/// 
/// SIP 클라이언트 상태와 기능을 제공하는 Provider 클래스입니다.
/// 앱 전체에서 SIP 상태를 관리하고, SIP 클라이언트를 제어할 수 있습니다.
class SipProvider with ChangeNotifier {
  /// SIP 클라이언트 인스턴스
  KibalSipClient? _client;
  
  /// 현재 설정
  SipConfig? _config;
  
  /// 등록 상태
  bool _isRegistered = false;
  
  /// 통화 중 여부
  bool _isInCall = false;

  /// 현재 통화가 실제 수립(응답완료) 상태인지 (D-UI: 연결중 vs 연결됨 구분)
  bool _isCallEstablished = false;

  /// 수신 대기 중인 통화가 있는지 여부
  bool _hasIncomingCall = false;
  
  /// 통화 상대방
  String? _currentCallTarget;
  
  /// 오류 메시지
  String? _error;

  /// 수신 무응답 자동취소 타이머 (60초)
  Timer? incomingTimeout;
  
  /// 로딩 상태
  bool _isLoading = false;

  /// UI로 전달할 미디어 이벤트 큐 (stream 등)
  final List<Map<String, dynamic>> _pendingMediaEvents = [];
  
  //--------------------------------------------------------------------------
  // Public Getters
  //--------------------------------------------------------------------------
  
  /// SIP 클라이언트
  KibalSipClient? get client => _client;
  
  /// 현재 설정
  SipConfig? get config => _config;
  
  /// 등록 여부
  bool get isRegistered => _isRegistered;
  
  /// 통화 중 여부
  bool get isInCall => _isInCall;

  /// 실제 응답 수립된 통화 여부 (Ring/Progress 상태는 false)
  bool get isCallEstablished => _isCallEstablished;

  /// 수신 대기 중인 통화가 있는지 여부
  bool get hasIncomingCall => _hasIncomingCall;
  
  /// 통화 상대방
  String? get currentCallTarget => _currentCallTarget;
  
  /// 오류 메시지
  String? get error => _error;
  
  /// 로딩 상태
  bool get isLoading => _isLoading;
  
  /// SIP 클라이언트 상태
  SipClientState get sipState {
    return _client?.state ?? SipClientState.idle;
  }
  
  //--------------------------------------------------------------------------
  // Initialization
  //--------------------------------------------------------------------------
  
  /// SIP Provider 초기화
  SipProvider() {
    _initClient();
  }
  
  /// SIP 클라이언트 초기화
  void _initClient() {
    _client = KibalSipClient(callback: _handleSipEvent);
  }
  
  //--------------------------------------------------------------------------
  // Configuration
  //--------------------------------------------------------------------------
  
  /// 설정 업데이트
  void updateConfig(SipConfig config) {
    _config = config;
    notifyListeners();
  }
  
  /// 설정 초기화
  void clearConfig() {
    _config = null;
    _isRegistered = false;
    _isInCall = false;
    _hasIncomingCall = false;
    _currentCallTarget = null;
    _error = null;
    notifyListeners();
  }

  //--------------------------------------------------------------------------
  // Connection Management
  //--------------------------------------------------------------------------
  
  /// SIP 연결
  Future<bool> connect() async {
    if (_config == null) {
      _error = 'SIP 설정이 없습니다';
      notifyListeners();
      return false;
    }
    
    if (_client == null) {
      _error = 'SIP 클라이언트가 초기화되지 않음';
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final result = await _client!.init(_config!);
      
      if (result) {
        await register();
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = 'SIP 연결 실패: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// SIP 등록
  Future<bool> register() async {
    if (_client == null) {
      _error = 'SIP 클라이언트가 초기화되지 않음';
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final result = await _client!.register();
      
      if (result) {
        _isRegistered = true;
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = 'SIP 등록 실패: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// SIP 등록 해제
  Future<bool> unregister() async {
    if (_client == null) {
      _error = 'SIP 클라이언트가 초기화되지 않음';
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final result = await _client!.unregister();
      
      if (result) {
        _isRegistered = false;
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = 'SIP 등록 해제 실패: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// SIP 연결 해제
  Future<void> disconnect() async {
    if (_client == null) return;
    
    try {
      await _client!.disconnect();
      _isRegistered = false;
      _isInCall = false;
      _hasIncomingCall = false;
      _currentCallTarget = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'SIP 연결 해제 실패: $e';
      notifyListeners();
    }
  }
  
  //--------------------------------------------------------------------------
  // Call Management
  //--------------------------------------------------------------------------
  
  /// 통화 시작
  /// 수신 무응답 60초 후 자동 거절 (수신 대기 세션 고정 방지)
  void _startIncomingTimeout() {
    incomingTimeout?.cancel();
    const dur = Duration(seconds: 60);
    incomingTimeout = Timer(dur, () async {
      if (_hasIncomingCall) {
        AppLogger.instance.w('수신 무응답 60초 → 자동 거절');
        try {
          await reject();
        } catch (_) {}
      }
    });
  }

  Future<bool> call(String target, {MediaStream? mediaStream}) async {    if (_client == null) {
      _error = 'SIP 클라이언트가 초기화되지 않음';
      notifyListeners();
      return false;
    }

    if (!_isRegistered) {
      _error = 'SIP가 등록되지 않음';
      notifyListeners();
      return false;
    }

    // 발신 전 진행 중 수신이 있으면 자동 거절 (수신 대기 세션이 발신을 막는 문제 해결)
    if (_hasIncomingCall) {
      AppLogger.instance
          .w('수신 대기 중 발신 시도 → 수신 자동 거절 후 발신 ($target)');
      try {
        await reject();
      } catch (_) {}
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final result = await _client!.call(target, mediaStream: mediaStream);
      
      if (result) {
        _isInCall = true;
        _currentCallTarget = target;
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = '통화 시작 실패: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// 통화 수신
  Future<bool> accept({MediaStream? mediaStream}) async {
    if (_client == null) {
      _error = 'SIP 클라이언트가 초기화되지 않음';
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final result = await _client!.accept(mediaStream: mediaStream);
      
      if (result) {
        _isInCall = true;
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = '통화 수신 실패: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// 통화 거부
  Future<bool> reject() async {
    if (_client == null) {
      _error = 'SIP 클라이언트가 초기화되지 않음';
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final result = await _client!.reject();
      
      if (result) {
        _isInCall = false;
        _hasIncomingCall = false;
        _currentCallTarget = null;
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = '통화 거부 실패: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// 통화 종료
  Future<bool> hangup() async {
    if (_client == null) {
      _error = 'SIP 클라이언트가 초기화되지 않음';
      notifyListeners();
      return false;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final result = await _client!.hangup();
      
      if (result) {
        _isInCall = false;
        _hasIncomingCall = false;
        _currentCallTarget = null;
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = '통화 종료 실패: $e';
      notifyListeners();
      return false;
    }
  }
  
  //--------------------------------------------------------------------------
  // Event Handling
  //--------------------------------------------------------------------------
  
  /// SIP 이벤트 처리
  void _handleSipEvent(SipEvent event) {
    switch (event.type) {
      case SipEventType.registration:
        // 등록 상태 업데이트
        if (event.data is SipClientState) {
          final state = event.data as SipClientState;
          _isRegistered = state == SipClientState.registered;
          if (state == SipClientState.error || state == SipClientState.disconnected) {
            _isRegistered = false;
          }
        }
        break;
        
      case SipEventType.call:
        // 통화 상태 업데이트
        if (event.data is Map) {
          final data = event.data as Map;
          final action = data['action'] as String?;
          
          switch (action) {
            case 'incoming':
              _hasIncomingCall = true;
              _isCallEstablished = false;
              _currentCallTarget = data['target'] as String?;
              _startIncomingTimeout();
              break;
            case 'call':
              _isInCall = false; // 발신 중
              _isCallEstablished = false;
              _hasIncomingCall = false;
              incomingTimeout?.cancel();
              _currentCallTarget = data['target'] as String?;
              break;
            case 'accept':
            case 'established':
              _isInCall = true;
              _isCallEstablished = true;
              incomingTimeout?.cancel();
              _hasIncomingCall = false;
              break;
            case 'hangup':
            case 'reject':
            case 'terminated':
              _isInCall = false;
              _isCallEstablished = false;
              _hasIncomingCall = false;
              incomingTimeout?.cancel();
              _currentCallTarget = null;
              break;
            case 'stream':
              _pendingMediaEvents.add(Map<String, dynamic>.from(data));
              break;
          }
        }
        break;
        
      case SipEventType.error:
        _error = event.error;
        break;
        
      case SipEventType.message:
        // 메시지 처리 (미사용)
        break;
    }
    
    notifyListeners();
  }
  
  //--------------------------------------------------------------------------
  // Media Events
  //--------------------------------------------------------------------------

  /// 대기 중인 미디어 이벤트를 꺼내고 큐를 비웁니다.
  List<Map<String, dynamic>> drainMediaEvents() {
    if (_pendingMediaEvents.isEmpty) return const [];
    final events = List<Map<String, dynamic>>.from(_pendingMediaEvents);
    _pendingMediaEvents.clear();
    return events;
  }

  //--------------------------------------------------------------------------
  // Utility Methods
  //--------------------------------------------------------------------------
  
  /// 등록 상태 텍스트 가져오기
  String getRegistrationStatusText() {
    if (_isLoading) return '연결 중...';
    if (_error != null) return '오류: $_error';
    
    switch (sipState) {
      case SipClientState.idle:
        return '미등록';
      case SipClientState.connecting:
        return '연결 중...';
      case SipClientState.connected:
        return '연결됨';
      case SipClientState.registered:
        return '등록됨';
      case SipClientState.unregistered:
        return '미등록';
      case SipClientState.disconnected:
        return '연결 끊김';
      case SipClientState.error:
        return '오류 발생';
    }
  }
  
  /// 통화 상태 텍스트 가져오기
  String getCallStatusText() {
    if (_isInCall) {
      return '통화 중 (${_currentCallTarget ?? '상대방'})';
    }
    return '통화 대기';
  }
  
  /// 사용 가능 여부 확인
  bool get isAvailable {
    return _client != null && 
           !_isLoading && 
           _error == null &&
           _config != null;
  }
  
  /// 통화 가능 여부 확인
  bool get canCall {
    return isAvailable && _isRegistered && !_isInCall;
  }
  
  /// 수신 통화 전용
  bool get canAccept {
    return _hasIncomingCall && _currentCallTarget != null;
  }
  
  //--------------------------------------------------------------------------
  // Dispose
  //--------------------------------------------------------------------------
  
  /// 리소스 해제
  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }
}
