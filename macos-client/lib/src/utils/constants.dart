import 'package:flutter/material.dart';

/// Kibal macOS Client 상수 정의
/// 
/// SIP 서버, 포트, 환경 설정 등 모든 상수를 정의합니다.

class AppConstants {
  //--------------------------------------------------------------------------
  // App Info
  //--------------------------------------------------------------------------
  
  static const String appName = 'Kibal macOS';
  static const String appVersion = '0.1.0';
  static const String buildNumber = '1';
  
  //--------------------------------------------------------------------------
  // SIP Server Configuration
  //--------------------------------------------------------------------------
  
  // DEV 환경 (로컬 Docker Asterisk: kibal-dev-asterisk)
  static const String devDomain = '192.168.0.3';
  static const int devSipPort = 5060;
  static const int devWsPort = 8088;
  static const String devWsServer = 'ws://192.168.0.3:8088/ws';
  
  // PRD 환경
  static const String prdDomain = '192.168.11.2';
  static const int prdSipPort = 5060;
  static const int prdWsPort = 8088;
  static const String prdWsServer = 'ws://192.168.11.2:8088/ws';
  
  // Default environment (macOS 개발 단계는 DEV 기본)
  static const String defaultDomain = devDomain;
  static const int defaultSipPort = devSipPort;
  static const String defaultWsServer = devWsServer;
  
  //--------------------------------------------------------------------------
  // SIP Accounts (Placeholders - real passwords in secure storage)
  //--------------------------------------------------------------------------
  
  static const List<String> sipExtensions = [
    '1001',
    '1002',
    '1003',
    '1004',
    '1101',
    '1102',
    '1103',
    '1104',
  ];
  
  // UDP extensions (Mobile)
  static const List<String> udpExtensions = ['1001', '1002', '1003', '1004'];
  
  // WebRTC extensions (Web)
  static const List<String> webrtcExtensions = ['1101', '1102', '1103', '1104'];

  // 빠른 연결 계정 (DEV 수동 테스트용 — 계정: 암호)
  static const Map<String, String> devQuickAccounts = {
    '1101': '1101pass',
    '1102': '1102pass',
    '1103': '1103pass',
  };
  
  //--------------------------------------------------------------------------
  // Conference Room
  //--------------------------------------------------------------------------
  
  static const String conferenceRoom = '6000';

  /// 회의실(ConfBridge) 번호 판정: 6000~6999 → 다자간 화면으로 진입 (B1/F1)
  static bool isConferenceRoom(String target) =>
      RegExp(r'^6\d{3}$').hasMatch(target.trim());

  //--------------------------------------------------------------------------
  // OPS 콘솔 (원격 로그 수집)
  //--------------------------------------------------------------------------

  // OPS API 포트 (kibal-dev-ops / kibal-prd-ops)
  static const int opsPort = 8091;

  // 클라이언트 로그 수집용 공유 키 (server deploy/*/ops.env OPS_CLIENT_KEY와 일치)
  // DEV 전용 기본값. PRD는 별도 키로 치환 필요.
  static const String opsClientKey = 'dev-kibal-clients-2026';

  /// OPS 로그 수집 URL (도메인 기반).
  static String opsLogUrl(String domain) => 'http://$domain:$opsPort/api/client-logs';
  
  //--------------------------------------------------------------------------
  // Media Configuration
  //--------------------------------------------------------------------------
  
  // Video constraints
  static const Map<String, dynamic> videoConstraints = {
    'width': 1280,
    'height': 720,
    'facingMode': 'user', // front camera
    'frameRate': 30,
  };
  
  static const Map<String, dynamic> lowVideoConstraints = {
    'width': 640,
    'height': 480,
    'facingMode': 'user',
    'frameRate': 15,
  };
  
  // Audio constraints
  static const bool enableAudio = true;
  static const bool enableVideo = true;
  
  //--------------------------------------------------------------------------
  // ICE/STUN/TURN Servers
  //--------------------------------------------------------------------------
  
  static const List<String> defaultIceServers = [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
    'stun:stun2.l.google.com:19302',
  ];
  
  static const List<String> prdIceServers = [
    'stun:stun.l.google.com:19302',
    // TURN server will be added when configured
    // 'turn:192.168.11.2:3478',
  ];
  
  //--------------------------------------------------------------------------
  // Timeouts
  //--------------------------------------------------------------------------
  
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration registrationTimeout = Duration(seconds: 10);
  static const Duration callTimeout = Duration(seconds: 45);
  static const Duration iceTimeout = Duration(seconds: 10);
  
  //--------------------------------------------------------------------------
  // Retry Configuration
  //--------------------------------------------------------------------------
  
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(milliseconds: 1000);
  
  //--------------------------------------------------------------------------
  // UI Configuration
  //--------------------------------------------------------------------------
  
  // Colors
  static const int primaryColor = 0xFF2196F3;
  static const int secondaryColor = 0xFF4CAF50;
  static const int errorColor = 0xFFF44336;
  static const int warningColor = 0xFFFFC107;
  static const int infoColor = 0xFF2196F3;
  
  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  
  // Border Radius
  static const double borderRadiusSm = 4.0;
  static const double borderRadiusMd = 8.0;
  static const double borderRadiusLg = 12.0;
  static const double borderRadiusXl = 16.0;
  static const double borderRadiusFull = 100.0;
  
  // Shadows
  static const List<BoxShadow> defaultShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4.0,
      offset: Offset(0, 2),
    ),
  ];
  
  //--------------------------------------------------------------------------
  // Animation Durations
  //--------------------------------------------------------------------------
  
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  //--------------------------------------------------------------------------
  // Storage Keys
  //--------------------------------------------------------------------------
  
  static const String storageSipConfig = 'sip_config';
  static const String storageLastExtension = 'last_extension';
  static const String storageCameraFront = 'camera_front';
  static const String storageAudioMuted = 'audio_muted';
  static const String storageVideoMuted = 'video_muted';
  
  //--------------------------------------------------------------------------
  // API Endpoints
  //--------------------------------------------------------------------------
  
  // Asterisk CLI commands (for debugging)
  static const List<String> asteriskDebugCommands = [
    'pjsip show contacts',
    'pjsip show endpoints',
    'pjsip show transports',
    'core show channels',
    'confbridge list',
  ];
  
  //--------------------------------------------------------------------------
  // Log Configuration
  //--------------------------------------------------------------------------
  
  static const bool enableDebugLogs = true;
  static const bool enableSipLogs = true;
  static const bool enableMediaLogs = true;
  static const int maxLogLines = 1000;
  
  //--------------------------------------------------------------------------
  // Build Configuration
  //--------------------------------------------------------------------------
  
  static const bool isProduction = false;
  static const bool isDevelopment = true;
  static const bool isDebug = true;
  
  //--------------------------------------------------------------------------
  // Feature Flags
  //--------------------------------------------------------------------------
  
  static const bool enableStun = true;
  static const bool enableTurn = false; // TURN not configured yet
  static const bool enableIce = true;
  static const bool enableSfu = true;
  
  //--------------------------------------------------------------------------
  // Security
  //--------------------------------------------------------------------------
  
  // Never log these in production
  static const List<String> sensitiveKeys = [
    'password',
    'secret',
    'token',
    'credential',
    'auth',
  ];
}

/// Predefined SIP configurations
class SipPresets {
  /// Get UDP configuration for PRD
  static Map<String, dynamic> get prdUdpConfig {
    return {
      'username': '',
      'password': '',
      'domain': AppConstants.prdDomain,
      'port': AppConstants.prdSipPort,
      'displayName': '',
      'transportType': 'udp',
      'iceServers': AppConstants.prdIceServers,
    };
  }
  
  /// Get WebRTC configuration for PRD
  static Map<String, dynamic> get prdWebRtcConfig {
    return {
      'username': '',
      'password': '',
      'domain': AppConstants.prdDomain,
      'port': AppConstants.prdWsPort,
      'displayName': '',
      'transportType': 'ws',
      'wsServer': AppConstants.prdWsServer,
      'iceServers': AppConstants.prdIceServers,
    };
  }
  
  /// Get default configuration
  static Map<String, dynamic> get defaultConfig {
    return prdUdpConfig;
  }
}
