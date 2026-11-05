import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTC 헬퍼 클래스
/// 
/// RTCPeerConnection, RTCSessionDescription 등 WebRTC 관련 유틸리티 기능을 제공합니다.
class WebRtcHelpers {
  //--------------------------------------------------------------------------
  // RTCPeerConnection Configuration
  //--------------------------------------------------------------------------
  
  /// 기본 ICE 서버 구성
  static const List<Map<String, dynamic>> defaultIceServers = [
    {
      'urls': 'stun:stun.l.google.com:19302',
    },
    {
      'urls': 'stun:stun1.l.google.com:19302',
    },
    {
      'urls': 'stun:stun2.l.google.com:19302',
    },
  ];
  
  /// PRD 환경 ICE 서버 구성
  static List<Map<String, dynamic>> prdIceServers = [
    {
      'urls': 'stun:stun.l.google.com:19302',
    },
    // TURN 서버가 구성되면 여기에 추가
    // {
    //   'urls': 'turn:192.168.11.2:3478',
    //   'username': 'kibal',
    //   'credential': 'password',
    // },
  ];
  
  /// RTCConfiguration 생성
  static RTCConfiguration createRTCConfiguration({
    List<Map<String, dynamic>> iceServers = defaultIceServers,
    bool useTurn = false,
  }) {
    return RTCConfiguration(
      iceServers: iceServers,
      iceTransportPolicy: RTCIceTransportPolicy.all,
      bundlePolicy: RTCBundlePolicy.maxBundle,
      rtcpMuxPolicy: RTCRtcpMuxPolicy.rtcpMux,
      iceCandidatePoolSize: 10,
    );
  }
  
  //--------------------------------------------------------------------------
  // RTCPeerConnection Management
  //--------------------------------------------------------------------------
  
  /// RTCPeerConnection 생성
  static RTCPeerConnection createPeerConnection({
    RTCConfiguration? configuration,
    Map<String, dynamic>? constraints,
  }) {
    final config = configuration ?? createRTCConfiguration();
    final connConstraints = constraints ?? <String, dynamic>{};
    
    return RTCPeerConnection(config, connConstraints);
  }
  
  /// RTCPeerConnection 연결 상태 확인
  static RTCPeerConnectionState getConnectionState(RTCPeerConnection pc) {
    return pc.connectionState;
  }
  
  /// RTCPeerConnection ICE 연결 상태 확인
  static RTCIceConnectionState getIceConnectionState(RTCPeerConnection pc) {
    return pc.iceConnectionState;
  }
  
  /// RTCPeerConnection Signaling 상태 확인
  static RTCSignalingState getSignalingState(RTCPeerConnection pc) {
    return pc.signalingState;
  }
  
  //--------------------------------------------------------------------------
  // ICE Candidate
  //--------------------------------------------------------------------------
  
  /// ICE Candidate 생성
  static RTCIceCandidate createIceCandidate({
    required String candidate,
    required String sdpMid,
    required int sdpMLineIndex,
    String? usernameFragment,
  }) {
    return RTCIceCandidate(
      candidate: candidate,
      sdpMid: sdpMid,
      sdpMLineIndex: sdpMLineIndex,
      usernameFragment: usernameFragment,
    );
  }
  
  /// ICE Candidate json에서 생성
  static RTCIceCandidate? fromJson(Map<String, dynamic> json) {
    try {
      return RTCIceCandidate(
        candidate: json['candidate'] as String,
        sdpMid: json['sdpMid'] as String? ?? '',
        sdpMLineIndex: (json['sdpMLineIndex'] as num?)?.toInt() ?? 0,
        usernameFragment: json['usernameFragment'] as String?,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// ICE Candidate json으로 변환
  static Map<String, dynamic> toJson(RTCIceCandidate candidate) {
    return {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
      if (candidate.usernameFragment != null)
        'usernameFragment': candidate.usernameFragment,
    };
  }
  
  //--------------------------------------------------------------------------
  // RTCSessionDescription
  //--------------------------------------------------------------------------
  
  /// RTCSessionDescription 생성
  static RTCSessionDescription createSessionDescription({
    required String sdp,
    required RTCSdpType type,
  }) {
    return RTCSessionDescription(sdp, type);
  }
  
  /// RTCSessionDescription json에서 생성
  static RTCSessionDescription? fromJson(Map<String, dynamic> json) {
    try {
      final type = json['type'] as String;
      return RTCSessionDescription(
        json['sdp'] as String,
        type == 'offer' 
          ? RTCSdpType.offer 
          : (type == 'answer' ? RTCSdpType.answer : RTCSdpType.pranswer),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// RTCSessionDescription json으로 변환
  static Map<String, dynamic> toJson(RTCSessionDescription desc) {
    return {
      'sdp': desc.sdp,
      'type': desc.type.name,
    };
  }
  
  //--------------------------------------------------------------------------
  // SDP Utilities
  //--------------------------------------------------------------------------
  
  /// SDP에서 비디오 코덱 확인
  static bool hasVideoCodec(String sdp, String codec) {
    return sdp.contains('a=rtpmap:.* $codec') ||
           sdp.contains('a=rtpmap:.* $codec/') ||
           sdp.contains('a=fmtp:.* profile-level-id=');
  }
  
  /// SDP에서 오디오 코덱 확인
  static bool hasAudioCodec(String sdp, String codec) {
    return sdp.contains('a=rtpmap:.* $codec');
  }
  
  /// SDP에 H.264 코덱이 있는지 확인
  static bool hasH264(String sdp) {
    return hasVideoCodec(sdp, 'H264') || 
           hasVideoCodec(sdp, 'h264') ||
           sdp.contains('profile-level-id=');
  }
  
  /// SDP에 VP8 코덱이 있는지 확인
  static bool hasVP8(String sdp) {
    return hasVideoCodec(sdp, 'VP8') || 
           hasVideoCodec(sdp, 'vp8');
  }
  
  /// SDP에 Opus 코덱이 있는지 확인
  static bool hasOpus(String sdp) {
    return hasAudioCodec(sdp, 'opus') || 
           hasAudioCodec(sdp, 'OPUS');
  }
  
  //--------------------------------------------------------------------------
  // Media Constraints
  //--------------------------------------------------------------------------
  
  /// 기본 미디어 제약 조건
  static const Map<String, dynamic> defaultMediaConstraints = {
    'audio': true,
    'video': {
      'width': 1280,
      'height': 720,
      'facingMode': 'user',
    },
  };
  
  /// 비디오만 제약 조건
  static const Map<String, dynamic> videoOnlyConstraints = {
    'audio': false,
    'video': {
      'width': 1280,
      'height': 720,
      'facingMode': 'user',
    },
  };
  
  /// 오디오만 제약 조건
  static const Map<String, dynamic> audioOnlyConstraints = {
    'audio': true,
    'video': false,
  };
  
  /// 낮은 해상도 제약 조건
  static const Map<String, dynamic> lowResolutionConstraints = {
    'audio': true,
    'video': {
      'width': 640,
      'height': 480,
      'facingMode': 'user',
    },
  };
  
  //--------------------------------------------------------------------------
  // Statistics & Monitoring
  //--------------------------------------------------------------------------
  
  /// RTCPeerConnection 통계 가져오기
  static Future<Map<String, dynamic>> getStats(RTCPeerConnection pc) async {
    try {
      final stats = await pc.getStats();
      return stats.toMap();
    } catch (e) {
      return {};
    }
  }
  
  /// RTCPeerConnection ICE 후보 가져오기
  static Future<List<RTCIceCandidate>> getLocalIceCandidates(
    RTCPeerConnection pc,
  ) async {
    try {
      final candidates = await pc.getLocalIceCandidates();
      return candidates;
    } catch (e) {
      return [];
    }
  }
  
  /// RTCPeerConnection에서 설정된 ICE 후보 가져오기
  static List<RTCIceCandidate> getLocalIceCandidatesSync(
    RTCPeerConnection pc,
  ) {
    final candidates = <RTCIceCandidate>[];
    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        candidates.add(candidate);
      }
    };
    return candidates;
  }
  
  //--------------------------------------------------------------------------
  // Error Handling
  //--------------------------------------------------------------------------
  
  /// RTCError 유형 확인
  static bool isRTCError(dynamic error) {
    return error is RTCError || error.toString().contains('RTCError');
  }
  
  /// WebRTC 오류 메시지 추출
  static String getRTCErrorMessage(dynamic error) {
    if (error is RTCError) {
      return error.message;
    }
    return error.toString();
  }
  
  //--------------------------------------------------------------------------
  // Utility
  //--------------------------------------------------------------------------
  
  /// RTCPeerConnection 닫기
  static Future<void> closePeerConnection(RTCPeerConnection pc) async {
    try {
      await pc.close();
      await pc.dispose();
    } catch (e) {
      // Close may fail if already closed
    }
  }
  
  /// RTCPeerConnection 모든 트랙 정지
  static Future<void> stopAllTracks(RTCPeerConnection pc) async {
    final senders = await pc.getSenders();
    for (final sender in senders) {
      if (sender.track != null) {
        await sender.track!.stop();
        await sender.track!.dispose();
      }
    }
  }
  
  /// MediaStream 모든 트랙 정지
  static Future<void> stopStreamTracks(MediaStream? stream) async {
    if (stream == null) return;
    
    for (final track in stream.getTracks()) {
      await track.stop();
      await track.dispose();
    }
  }
  
  /// RTCDataChannel 생성
  static RTCDataChannel createDataChannel(
    RTCPeerConnection pc, {
    required String label,
    RTCDataChannelInit? init,
  }) {
    return pc.createDataChannel(label, init);
  }
  
  /// RTCDataChannel이 열려 있는지 확인
  static bool isDataChannelOpen(RTCDataChannel channel) {
    return channel.readyState == RTCDataChannelState.open;
  }
  
  /// RTCDataChannel 상태 확인
  static RTCDataChannelState getDataChannelState(RTCDataChannel channel) {
    return channel.readyState;
  }
}
