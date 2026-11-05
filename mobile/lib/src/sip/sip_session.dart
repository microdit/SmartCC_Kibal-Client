import 'package:flutter_sip/flutter_sip.dart';

/// SIP 세션 상태
enum SipSessionState {
  idle,           // 대기 상태
  connecting,     // 연결 중
  established,    // 연결됨
  terminated,     // 종료됨
  failed,         // 실패
}

/// SIP 세션 타입
enum SipSessionType {
  outgoing,       // 발신
  incoming,       // 수신
}

/// SIP 세션 클래스
/// 
/// flutter_sip의 Session을 래핑하여 추가 기능을 제공합니다.
class SipSession {
  /// flutter_sip 세션
  final Session _session;
  
  /// 세션 ID
  final String id;
  
  /// 세션 타입
  SipSessionType type;
  
  /// 세션 상태
  SipSessionState state = SipSessionState.idle;
  
  /// 상대방 정보
  String? remoteParty;
  
  /// 통화 시작 시간
  DateTime? startTime;
  
  /// 통화 종료 시간
  DateTime? endTime;
  
  /// 통화 duration
  Duration get duration {
    if (startTime == null) return Duration.zero;
    if (endTime == null) return DateTime.now().difference(startTime!);
    return endTime!.difference(startTime!);
  }
  
  /// 생성자
  SipSession(this._session) : id = _session.id;
  
  /// 세션 타입 설정
  void setType(SipSessionType type) {
    this.type = type;
  }
  
  /// 세션 상태 업데이트
  void updateState(SipSessionState state) {
    this.state = state;
    
    if (state == SipSessionState.established) {
      startTime = DateTime.now();
    } else if (state == SipSessionState.terminated) {
      endTime = DateTime.now();
    }
  }
  
  /// 통화 수신
  Future<bool> accept() async {
    try {
      await _session.accept();
      type = SipSessionType.incoming;
      updateState(SipSessionState.established);
      return true;
    } catch (e) {
      updateState(SipSessionState.failed);
      return false;
    }
  }
  
  /// 통화 거부
  Future<bool> reject() async {
    try {
      await _session.reject();
      updateState(SipSessionState.terminated);
      return true;
    } catch (e) {
      updateState(SipSessionState.failed);
      return false;
    }
  }
  
  /// 통화 종료
  Future<bool> hangup() async {
    try {
      await _session.hangup();
      updateState(SipSessionState.terminated);
      return true;
    } catch (e) {
      updateState(SipSessionState.failed);
      return false;
    }
  }
  
  /// 상대방 정보 가져오기
  String? getRemoteParty() {
    if (remoteParty != null) return remoteParty;
    
    // flutter_sip의 Session에서 정보 추출
    try {
      // 세션에서 원격 URI 추출 (구현에 따라 다름)
      // 이 부분은 flutter_sip 라이브러리의 실제 API에 따라 조절 필요
      remoteParty = _session.remoteUri?.toString() ?? 'Unknown';
      return remoteParty;
    } catch (e) {
      return 'Unknown';
    }
  }
  
  /// 세션 정보 출력
  @override
  String toString() {
    return 'SipSession(id: $id, type: $type, state: $state, remote: ${getRemoteParty()}, duration: $duration)';
  }
  
  /// flutter_sip 세션 접근자
  Session get rawSession => _session;
}
