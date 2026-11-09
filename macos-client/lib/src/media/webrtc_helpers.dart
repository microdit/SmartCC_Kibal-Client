import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTC 헬퍼 클래스
/// 
/// RTCPeerConnection, RTCSessionDescription 등 WebRTC 관련 유틸리티 기능을 제공합니다.
/// Note: Simplified version - WebRTC functionality is limited in flutter_webrtc 0.11.7
class WebRtcHelpers {
  //--------------------------------------------------------------------------
  // RTCPeerConnection Configuration
  //--------------------------------------------------------------------------
  
  /// 기본 ICE 서버 구성
  static const List<Map<String, dynamic>> defaultIceServers = [
    {
      'urls': 'stun:stun.l.google.com:19302',
    },
  ];
  
  /// PRD 환경 ICE 서버 구성
  static List<Map<String, dynamic>> prdIceServers = [
    {
      'urls': 'stun:stun.l.google.com:19302',
    },
  ];
  
  //--------------------------------------------------------------------------
  // ICE Candidate
  //--------------------------------------------------------------------------
  
  /// ICE Candidate json에서 생성
  static RTCIceCandidate? fromJson(Map<String, dynamic> json) {
    try {
      return RTCIceCandidate(
        json['candidate'] as String? ?? '',
        json['sdpMid'] as String? ?? '',
        json['sdpMLineIndex'] as int? ?? 0,
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
    };
  }
  
  //--------------------------------------------------------------------------
  // RTCSessionDescription
  //--------------------------------------------------------------------------
  
  /// RTCSessionDescription json에서 생성
  static RTCSessionDescription? fromJsonSdp(Map<String, dynamic> json) {
    try {
      final type = json['type'] as String? ?? 'offer';
      return RTCSessionDescription(json['sdp'] as String? ?? '', type);
    } catch (e) {
      return null;
    }
  }
  
  /// RTCSessionDescription json으로 변환
  static Map<String, dynamic> toJsonSdp(RTCSessionDescription desc) {
    return {
      'sdp': desc.sdp,
      'type': desc.type,
    };
  }
  
  //--------------------------------------------------------------------------
  // Utility
  //--------------------------------------------------------------------------
  
  /// RTCPeerConnection 닫기
  static Future<void> closePeerConnection(RTCPeerConnection? pc) async {
    try {
      if (pc != null) {
        await pc.close();
        await pc.dispose();
      }
    } catch (e) {
      // Close may fail if already closed
    }
  }
  
  /// MediaStream 모든 트랙 정지
  static Future<void> stopStreamTracks(MediaStream? stream) async {
    if (stream == null) return;
    
    for (final track in stream.getTracks()) {
      await track.stop();
    }
  }
}
