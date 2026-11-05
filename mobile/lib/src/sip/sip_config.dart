/// SIP 클라이언트 설정 모델
/// 
/// Asterisk 서버와 연결하기 위한 모든 설정을 포함합니다.
/// UDP/PJSIP 또는 WebRTC/WebSocket을 지원합니다.

class SipConfig {
  /// SIP 사용자 이름 (내선 번호)
  final String username;
  
  /// SIP 비밀번호
  final String password;
  
  /// SIP 도메인 (서버 주소)
  final String domain;
  
  /// SIP 포트
  final int port;
  
  /// 표시 이름 (Optional)
  final String? displayName;
  
  /// 전송 프로토콜
  final SipTransportType transportType;
  
  /// WebSocket URL (WebRTC용)
  final String? wsServer;
  
  /// STUN/TURN 서버 목록
  final List<String> iceServers;
  
  /// órg를 위한 생성자 (UDP/PJSIP)
  SipConfig.udp({
    required this.username,
    required this.password,
    required this.domain,
    this.port = 5060,
    this.displayName,
    this.iceServers = const [],
  }) : transportType = SipTransportType.udp, wsServer = null;
  
  /// WebRTC를 위한 생성자
  SipConfig.webrtc({
    required this.username,
    required this.password,
    required this.domain,
    this.port = 8088,
    this.displayName,
    required this.wsServer,
    this.iceServers = const [
      'stun:stun.l.google.com:19302',
    ],
  }) : transportType = SipTransportType.ws;
  
  /// 기본 생성자
  SipConfig({
    required this.username,
    required this.password,
    required this.domain,
    this.port = 5060,
    this.displayName,
    this.transportType = SipTransportType.udp,
    this.wsServer,
    this.iceServers = const [],
  });
  
  /// 시리얼화 (JSON → SipConfig)
  factory SipConfig.fromJson(Map<String, dynamic> json) {
    return SipConfig(
      username: json['username'] as String,
      password: json['password'] as String,
      domain: json['domain'] as String,
      port: json['port'] as int? ?? 5060,
      displayName: json['displayName'] as String?,
      transportType: SipTransportType.values.firstWhere(
        (e) => e.name == json['transportType'] as String?,
        orElse: () => SipTransportType.udp,
      ),
      wsServer: json['wsServer'] as String?,
      iceServers: (json['iceServers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
    );
  }
  
  /// 시리얼화 (SipConfig → JSON)
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'domain': domain,
      'port': port,
      'displayName': displayName,
      'transportType': transportType.name,
      'wsServer': wsServer,
      'iceServers': iceServers,
    };
  }
  
  /// 복사본 생성
  SipConfig copyWith({
    String? username,
    String? password,
    String? domain,
    int? port,
    String? displayName,
    SipTransportType? transportType,
    String? wsServer,
    List<String>? iceServers,
  }) {
    return SipConfig(
      username: username ?? this.username,
      password: password ?? this.password,
      domain: domain ?? this.domain,
      port: port ?? this.port,
      displayName: displayName ?? this.displayName,
      transportType: transportType ?? this.transportType,
      wsServer: wsServer ?? this.wsServer,
      iceServers: iceServers ?? this.iceServers,
    );
  }
  
  @override
  String toString() {
    return 'SipConfig(username: $username, domain: $domain, port: $port, transport: ${transportType.name})';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SipConfig &&
        other.username == username &&
        other.password == password &&
        other.domain == domain &&
        other.port == port &&
        other.displayName == displayName &&
        other.transportType == transportType &&
        other.wsServer == wsServer;
  }
  
  @override
  int get hashCode {
    return Object.hash(
      username,
      password,
      domain,
      port,
      displayName,
      transportType,
      wsServer,
    );
  }
}

/// SIP 전송 프로토콜 타입
enum SipTransportType {
  /// UDP (PJSIP용)
  udp,
  
  /// TCP (PJSIP용)
  tcp,
  
  /// WebSocket (WebRTC용)
  ws,
  
  /// WebSocket Secure (WebRTC + TLS)
  wss,
}

/// 사전 정의된 설정
class SipPresets {
  /// PRD 환경 - UDP (Mobile용)
  static SipConfig prdUdp(String username, String password) {
    return SipConfig.udp(
      username: username,
      password: password,
      domain: '192.168.11.2',
      port: 5060,
      displayName: 'Kibal Mobile $username',
    );
  }
  
  /// PRD 환경 - WebRTC (Web용)
  static SipConfig prdWebRtc(String username, String password) {
    return SipConfig.webrtc(
      username: username,
      password: password,
      domain: '192.168.11.2',
      port: 8088,
      displayName: 'Kibal Web $username',
      wsServer: 'ws://192.168.11.2:8088/ws',
    );
  }
  
  /// DEV 환경 - UDP
  static SipConfig devUdp(String username, String password) {
    return SipConfig.udp(
      username: username,
      password: password,
      domain: '127.0.0.1',
      port: 5060,
      displayName: 'Kibal DEV $username',
    );
  }
  
  /// DEV 환경 - WebRTC
  static SipConfig devWebRtc(String username, String password) {
    return SipConfig.webrtc(
      username: username,
      password: password,
      domain: '127.0.0.1',
      port: 8088,
      displayName: 'Kibal DEV $username',
      wsServer: 'ws://127.0.0.1:8088/ws',
    );
  }
}
