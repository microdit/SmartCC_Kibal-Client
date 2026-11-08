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
/// flutter_sip 0.0.8용 단순 세션 래퍼
/// Note: flutter_sip 0.0.8 doesn't expose Session class directly,
/// so this is a simple state management wrapper.
class SipSession {
  /// 세션 ID
  final String id;
  
  /// 세션 타입
  SipSessionType type;
  
  /// 세션 상태
  SipSessionState state;
  
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
  /// Note: id can be a call ID or session identifier
  SipSession(String? id) : 
    this.id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    type = SipSessionType.outgoing,
    state = SipSessionState.idle;
  
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
      updateState(SipSessionState.terminated);
      return true;
    } catch (e) {
      updateState(SipSessionState.failed);
      return false;
    }
  }
  
  /// 상대방 정보 설정
  void setRemoteParty(String? remoteParty) {
    this.remoteParty = remoteParty;
  }
  
  /// 상대방 정보 가져오기
  String? getRemoteParty() {
    return remoteParty ?? 'Unknown';
  }
  
  /// 세션 정보 출력
  @override
  String toString() {
    return 'SipSession(id: $id, type: $type, state: $state, remote: ${getRemoteParty()}, duration: $duration)';
  }
}
