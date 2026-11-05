import 'package:intl/intl.dart';

/// 형식화 유틸리티 클래스
/// 
/// 날짜, 시간, 전화번호, SIP URI 등 다양한 데이터를 포맷팅합니다.
class Formatters {
  //--------------------------------------------------------------------------
  // Date/Time Formatters
  //--------------------------------------------------------------------------
  
  /// 기본 날짜 포맷터 (YYYY-MM-DD)
  static final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
  
  /// 기본 시간 포맷터 (HH:MM:SS)
  static final DateFormat timeFormatter = DateFormat('HH:mm:ss');
  
  /// 날짜+시간 포맷터 (YYYY-MM-DD HH:MM:SS)
  static final DateFormat dateTimeFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
  
  /// 상대 시간 포맷 (1분 전, 1시간 전 등)
  static final DateFormat relativeDateFormatter = DateFormat('yyyy-MM-dd');
  
  /// 통화 duration 포맷 (MM:SS)
  static String formatCallDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// 통화 duration 포맷 (HH:MM:SS)
  static String formatLongCallDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// 타임스탬프 포맷 (YYYY-MM-DDTHH:MM:SS)
  static String formatTimestamp(DateTime timestamp) {
    return dateTimeFormatter.format(timestamp);
  }
  
  /// ISO 8601 포맷
  static String formatIso8601(DateTime timestamp) {
    return timestamp.toIso8601String();
  }
  
  /// 상대 시간 텍스트 (e.g., "1분 전", "2시간 전")
  static String formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return dateFormatter.format(timestamp);
    }
  }
  
  //--------------------------------------------------------------------------
  // SIP URI Formatters
  //--------------------------------------------------------------------------
  
  /// SIP URI 생성 (sip:username@domain)
  static String formatSipUri(String username, String domain) {
    return 'sip:$username@$domain';
  }
  
  /// SIP URI에서 사용자 이름 추출
  static String? extractUsernameFromSipUri(String sipUri) {
    try {
      // sip:username@domain 형식
      if (sipUri.startsWith('sip:')) {
        final parts = sipUri.substring(4).split('@');
        if (parts.length >= 1) {
          return Uri.decodeComponent(parts[0]);
        }
      }
      // username@domain 형식
      final atIndex = sipUri.indexOf('@');
      if (atIndex > 0) {
        return Uri.decodeComponent(sipUri.substring(0, atIndex));
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// SIP URI에서 도메인 추출
  static String? extractDomainFromSipUri(String sipUri) {
    try {
      // sip:username@domain 형식
      if (sipUri.startsWith('sip:')) {
        final parts = sipUri.substring(4).split('@');
        if (parts.length >= 2) {
          return Uri.decodeComponent(parts[1]);
        }
      }
      // username@domain 형식
      final atIndex = sipUri.indexOf('@');
      if (atIndex > 0 && atIndex < sipUri.length - 1) {
        return Uri.decodeComponent(sipUri.substring(atIndex + 1));
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// SIP URI에서 display name 추출
  static String? extractDisplayNameFromSipUri(String sipUri) {
    try {
      // "Display Name" <sip:username@domain> 형식
      final startQuote = sipUri.indexOf('"');
      final endQuote = sipUri.lastIndexOf('"');
      if (startQuote >= 0 && endQuote > startQuote) {
        return sipUri.substring(startQuote + 1, endQuote);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// SIP URI 단순화 (sip:username@domain → username)
  static String simplifySipUri(String sipUri) {
    final username = extractUsernameFromSipUri(sipUri);
    if (username != null) {
      return username;
    }
    return sipUri;
  }
  
  //--------------------------------------------------------------------------
  // Phone Number Formatters
  //--------------------------------------------------------------------------
  
  /// 전화번호 포맷 (010-1234-5678)
  static String formatPhoneNumber(String phoneNumber) {
    // 숫자만 추출
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digits.length <= 3) {
      return digits;
    } else if (digits.length <= 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, digits.length > 11 ? 11 : digits.length)}';
    }
  }
  
  /// 내선 번호 포맷 (1001 → 1001)
  static String formatExtension(String extension) {
    // 숫자만 추출
    final digits = extension.replaceAll(RegExp(r'[^0-9]'), '');
    return digits;
  }
  
  /// 전화번호에서 숫자만 추출
  static String extractDigitsOnly(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  }
  
  //--------------------------------------------------------------------------
  // Size Formatters
  //--------------------------------------------------------------------------
  
  /// 파일 크기 포맷 (B, KB, MB, GB)
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)}KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }
  
  //--------------------------------------------------------------------------
  // Resolution Formatters
  //--------------------------------------------------------------------------
  
  /// 해상도 포맷 (1280x720)
  static String formatResolution(int width, int height) {
    return '${width}x$height';
  }
  
  /// 해상도 포맷 (PDO -> 1280x720p)
  static String formatResolutionWithP(int width, int height) {
    return '${width}x${height}p';
  }
  
  /// 비트레이트 포맷 (kbps)
  static String formatBitrate(int bitrate) {
    if (bitrate >= 1000000) {
      return '${(bitrate / 1000000).toStringAsFixed(2)}Mbps';
    } else if (bitrate >= 1000) {
      return '${(bitrate / 1000).toStringAsFixed(2)}kbps';
    }
    return '$bitrate bps';
  }
  
  //--------------------------------------------------------------------------
  // Network Formatters
  //--------------------------------------------------------------------------
  
  /// IP 주소 포맷
  static String formatIpAddress(String ip) {
    // IPv4, IPv6 포맷 유지
    return ip;
  }
  
  /// MAC 주소 포맷 (XX:XX:XX:XX:XX:XX)
  static String formatMacAddress(String mac) {
    // : 또는 - 제거
    final clean = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (clean.length != 12) {
      return mac;
    }
    return '${clean.substring(0, 2)}:${clean.substring(2, 4)}:${clean.substring(4, 6)}:${clean.substring(6, 8)}:${clean.substring(8, 10)}:${clean.substring(10, 12)}'.toUpperCase();
  }
  
  //--------------------------------------------------------------------------
  // Error Formatters
  //--------------------------------------------------------------------------
  
  /// 오류 메시지 포맷
  static String formatError(String error) {
    // 민감한 정보 마스킹
    final masked = _maskSensitiveInfo(error);
    return masked;
  }
  
  /// 민감한 정보 마스킹
  static String _maskSensitiveInfo(String text) {
    // 비밀번호, 토큰, 인증 정보 등 마스킹
    const sensitivePatterns = [
      r'password["\'\s:=]+[^\s"\'&]+',
      r'secret["\'\s:=]+[^\s"\'&]+',
      r'token["\'\s:=]+[^\s"\'&]+',
      r'credential["\'\s:=]+[^\s"\'&]+',
      r'auth["\'\s:=]+[^\s"\'&]+',
      r'192\.168\.\d+\.\d+', // 내부 IP
    ];
    
    var result = text;
    for (final pattern in sensitivePatterns) {
      result = result.replaceAll(RegExp(pattern, caseSensitive: false), '[MASKED]');
    }
    return result;
  }
  
  //--------------------------------------------------------------------------
  // SIP State Formatters
  //--------------------------------------------------------------------------
  
  /// SIP 등록 상태 텍스트
  static String formatRegistrationState(String state) {
    switch (state.toLowerCase()) {
      case 'registered':
        return '등록됨';
      case 'unregistered':
        return '미등록';
      case 'connecting':
        return '연결 중...';
      case 'disconnected':
        return '연결 끊김';
      case 'failed':
        return '등록 실패';
      default:
        return state;
    }
  }
  
  /// SIP 통화 상태 텍스트
  static String formatCallState(String state) {
    switch (state.toLowerCase()) {
      case 'idle':
        return '대기';
      case 'connecting':
        return '연결 중...';
      case 'established':
        return '통화 중';
      case 'terminated':
        return '종료됨';
      case 'incoming':
        return '수신 중';
      case 'outgoing':
        return '발신 중';
      default:
        return state;
    }
  }
  
  //--------------------------------------------------------------------------
  // Media Formatters
  //--------------------------------------------------------------------------
  
  /// 코덱 이름 포맷
  static String formatCodec(String codec) {
    switch (codec.toLowerCase()) {
      case 'h264':
        return 'H.264';
      case 'vp8':
        return 'VP8';
      case 'vp9':
        return 'VP9';
      case 'opus':
        return 'Opus';
      case 'ulaw':
        return 'G.711 u-law';
      case 'alaw':
        return 'G.711 a-law';
      case 'g722':
        return 'G.722';
      default:
        return codec;
    }
  }
  
  /// 미디어 타입 텍스트
  static String formatMediaType(String type) {
    switch (type.toLowerCase()) {
      case 'audio':
        return '오디오';
      case 'video':
        return '비디오';
      case 'application':
        return '데이터';
      default:
        return type;
    }
  }
  
  //--------------------------------------------------------------------------
  // Validation
  //--------------------------------------------------------------------------
  
  /// SIP 사용자 이름 유효성 검사
  static bool isValidSipUsername(String username) {
    // 숫자만 허용 (내선 번호)
    return RegExp(r'^[0-9]{1,6}$').hasMatch(username);
  }
  
  /// SIP 도메인 유효성 검사
  static bool isValidSipDomain(String domain) {
    return RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(domain) &&
           !domain.startsWith('.') &&
           !domain.endsWith('.');
  }
  
  /// SIP 비밀번호 유효성 검사
  static bool isValidSipPassword(String password) {
    return password.length >= 4 && password.length <= 64;
  }
  
  /// IP 주소 유효성 검사
  static bool isValidIpAddress(String ip) {
    // IPv4 검사
    return RegExp(r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$').hasMatch(ip);
  }
  
  /// 포트 유효성 검사
  static bool isValidPort(int port) {
    return port >= 1 && port <= 65535;
  }
  
  //--------------------------------------------------------------------------
  // Utility
  //--------------------------------------------------------------------------
  
  /// NULL 또는 빈 문자열 체크
  static bool isNullOrEmpty(String? text) {
    return text == null || text.trim().isEmpty;
  }
  
  /// NULL 또는 빈 리스트 체크
  static bool isNullOrEmptyList(List? list) {
    return list == null || list.isEmpty;
  }
  
  /// 대문자로 변환
  static String toUpperCase(String text) {
    return text.toUpperCase();
  }
  
  /// 소문자로 변환
  static String toLowerCase(String text) {
    return text.toLowerCase();
  }
  
  /// 첫 글자 대문자
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  ////null을 빈 문자열로 변환
  static String nullToEmpty(String? text) {
    return text ?? '';
  }
  
  /// 조건부 텍스트
  static String conditionalText(bool condition, String trueText, String falseText) {
    return condition ? trueText : falseText;
  }
  
  /// 복수형 처리
  static String pluralize(int count, String singular, String plural) {
    return count == 1 ? singular : plural;
  }
}
