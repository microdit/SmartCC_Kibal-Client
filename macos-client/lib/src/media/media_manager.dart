import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/app_logger.dart';

/// 미디어 스트림 타입
enum MediaStreamType {
  local,      // 로컬 카메라/마이크
  remote,     // 원격 스트림
}

/// 미디어 관리자
/// 
/// WebRTC 미디어 스트림(카메라, 마이크, 원격 스트림)을 관리합니다.
class MediaManager {
  /// 로컬 미디어 스트림
  MediaStream? _localStream;
  
  /// 원격 미디어 스트림 매핑 (세션 ID → 스트림 목록)
  ///
  /// D2: ConfBridge 등 재협상 환경에서는 영상/음성이 별도 스트림으로 도착한다.
  /// sessionId별로 "영상 스트림"과 "음성(기타) 스트림"을 모두 보관해 음성 유실을 방지한다.
  final Map<String, List<MediaStream>> _remoteSessions = {};
  
  /// 로컬 비디오 렌더러 컨트롤러
  final Map<String, RTCVideoRenderer> _localRenderers = {};
  
  /// 원격 비디오 렌더러 컨트롤러
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  
  /// 카메라 전면/후면 상태
  bool _isFrontCamera = true;
  
  /// 오디오 뮤트 상태
  bool _isAudioMuted = false;
  
  /// 비디오 뮤트 상태
  bool _isVideoMuted = false;
  
  //--------------------------------------------------------------------------
  // Public Getters
  //--------------------------------------------------------------------------
  
  /// 로컬 스트림
  MediaStream? get localStream => _localStream;
  
  /// 원격 스트림 목록
  /// 세션당 렌더 대표 스트림 목록 (영상 우선, 없으면 첫 스트림)
  List<MediaStream> get remoteStreams {
    final result = <MediaStream>[];
    for (final sessionId in _remoteSessions.keys) {
      final vid = _videoStreamOfSession(sessionId);
      if (vid != null) result.add(vid);
    }
    return result;
  }
  
  /// 카메라 전면 여부
  bool get isFrontCamera => _isFrontCamera;
  
  /// 오디오 뮤트 여부
  bool get isAudioMuted => _isAudioMuted;
  
  /// 비디오 뮤트 여부
  bool get isVideoMuted => _isVideoMuted;
  
  /// 스트림 개수
  int get streamCount => (_localStream != null ? 1 : 0) + _remoteSessions.length;
  
  //--------------------------------------------------------------------------
  // Initialization & Cleanup
  //--------------------------------------------------------------------------
  
  /// 미디어 관리자 초기화
  Future<void> init() async {
    await _initializeRenderers();
  }
  
  /// 렌더러 초기화
  Future<void> _initializeRenderers() async {
    // 로컬 렌더러 생성
    _localRenderers['default'] = RTCVideoRenderer();
    await _localRenderers['default']!.initialize();
    
    // 원격 렌더러 풀 생성 (최대 4개까지 미리 생성)
    for (int i = 0; i < 4; i++) {
      _remoteRenderers['remote_$i'] = RTCVideoRenderer();
      await _remoteRenderers['remote_$i']!.initialize();
    }
  }
  
  /// 리소스 정리 (완전 폐기 — 로그아웃 전용)
  Future<void> dispose() async {
    // 로컬 스트림 정리
    await _disposeStream(_localStream);
    _localStream = null;
    
    // 원격 스트림 정리
    for (final streams in _remoteSessions.values) {
      for (final stream in streams) {
        await _disposeStream(stream);
      }
    }
    _remoteSessions.clear();
    
    // 렌더러 정리
    for (final renderer in [..._localRenderers.values, ..._remoteRenderers.values]) {
      await renderer.dispose();
    }
    _localRenderers.clear();
    _remoteRenderers.clear();
  }
  
  /// 스트림 정리
  Future<void> _disposeStream(MediaStream? stream) async {
    if (stream == null) return;

    for (final track in stream.getTracks()) {
      await track.stop();
    }
  }

  /// 통화 종료용: 로컬 미디어만 해제 (원격 렌더러 풀 보존)
  Future<void> releaseLocalMedia() async {
    await _disposeStream(_localStream);
    _localStream = null;
    final local = _localRenderers['default'];
    if (local != null) {
      local.srcObject = null;
    } else {
      // 풀이 소실된 경우 복구
      final r = RTCVideoRenderer();
      await r.initialize();
      _localRenderers['default'] = r;
    }
  }
  
  //--------------------------------------------------------------------------
  // Local Media
  //--------------------------------------------------------------------------
  
  /// 로컬 미디어 스트림 가져오기
  /// 
  /// [useFrontCamera] 전면 카메라 사용 여부
  /// [useAudio] 오디오 사용 여부
  /// [useVideo] 비디오 사용 여부
  Future<MediaStream?> getLocalMedia({
    bool useFrontCamera = true,
    bool useAudio = true,
    bool useVideo = true,
    String? videoDeviceId,
    String? audioDeviceId,
  }) async {
    try {
      // 카메라 방향 설정
      _isFrontCamera = useFrontCamera;

      final audioConstraint = useAudio ? (audioDeviceId ?? true) : false;
      // macOS flutter_webrtc는 deviceId에 Map imm객체를 지원하지 않음
      // (Map을 넘기면 doesNotRecognizeSelector로 프로세스 크래시) — 문자열만 사용
      final videoDeviceFilter = <String, dynamic>{
        'facingMode': useFrontCamera ? 'user' : 'environment',
        'width': 1280,
        'height': 720,
      };
      if (videoDeviceId != null) {
        videoDeviceFilter['deviceId'] = videoDeviceId;
      }
      final constraints = <String, dynamic>{
        'audio': audioConstraint,
        'video': useVideo ? videoDeviceFilter : false,
      };
      
      // 기기 미디어 스트림 가져오기
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      
      // 기존 스트림 정리
      await _disposeStream(_localStream);

      _localStream = stream;

      // 로컬 렌더러에 스트림 설정 (풀 소실 시 복구)
      if (_localRenderers['default'] == null) {
        final r = RTCVideoRenderer();
        await r.initialize();
        _localRenderers['default'] = r;
      }
      if (useVideo) {
        _localRenderers['default']!.srcObject = stream;
      }
      
      return stream;
    } catch (e) {
      debugPrint('Failed to get local media: $e');

      // 카메라가 없거나 사용할 수 없으면 오디오만으로 대체
      if (useVideo) {
        debugPrint('Retrying local media without video');
        return getLocalMedia(
          useFrontCamera: useFrontCamera,
          useAudio: useAudio,
          useVideo: false,
        );
      }

      return null;
    }
  }
  
  /// 카메라 전환
  Future<bool> toggleCamera() async {
    try {
      _isFrontCamera = !_isFrontCamera;
      
      // 새로운 스트림 가져오기
      final newStream = await getLocalMedia(
        useFrontCamera: _isFrontCamera,
        useAudio: !_isAudioMuted,
        useVideo: !_isVideoMuted,
      );
      
      return newStream != null;
    } catch (e) {
      debugPrint('Failed to toggle camera: $e');
      return false;
    }
  }
  
  //--------------------------------------------------------------------------
  // Audio/Video Control
  //--------------------------------------------------------------------------
  
  /// 오디오 뮤트 토글
  Future<bool> toggleAudio() async {
    try {
      _isAudioMuted = !_isAudioMuted;
      
      if (_localStream != null) {
        for (final track in _localStream!.getAudioTracks()) {
          // Use setter instead of setEnabled()
          track.enabled = !_isAudioMuted;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Failed to toggle audio: $e');
      return false;
    }
  }
  
  /// 비디오 뮤트 토글
  Future<bool> toggleVideo() async {
    try {
      _isVideoMuted = !_isVideoMuted;
      
      if (_localStream != null) {
        for (final track in _localStream!.getVideoTracks()) {
          // Use setter instead of setEnabled()
          track.enabled = !_isVideoMuted;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Failed to toggle video: $e');
      return false;
    }
  }
  
  /// 오디오 장치 가져오기
  Future<List<MediaDeviceInfo>> getAudioDevices() async {
    try {
      return await navigator.mediaDevices.enumerateDevices();
    } catch (e) {
      debugPrint('Failed to get audio devices: $e');
      return [];
    }
  }
  
  /// 비디오 장치 가져오기
  Future<List<MediaDeviceInfo>> getVideoDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      return devices.where((d) => d.kind == 'videoinput').toList();
    } catch (e) {
      debugPrint('Failed to get video devices: $e');
      return [];
    }
  }
  
  //--------------------------------------------------------------------------
  // Remote Media
  //--------------------------------------------------------------------------
  
  /// 원격 스트림 추가
  ///
  /// [stream] 원격 미디어 스트림 (flutter_webrtc는 트랙마다 별도 스트림 이벤트를 준다)
  /// [sessionId] 세션 ID
  ///
  /// D2: 영상/음성이 별도 스트림으로 도착해도 둘 다 보관한다.
  /// (이전 로직은 영상 스트림 보유 시 음성 전용 스트림을 폐기해 회의 음성이 사라졌다)
  /// addTrack은 재협상 후 nil 스트림 크래시(PlatformException) 유발로 사용하지 않는다.
  void addRemoteStream(MediaStream stream, String sessionId) {
    final list = _remoteSessions.putIfAbsent(sessionId, () => <MediaStream>[]);
    final firstTrackId = stream.getTracks().isEmpty ? null : stream.getTracks().first.id;
    final existsById = list.any((s) =>
        s.getTracks().map((t) => t.id).contains(firstTrackId));
    if (!existsById) list.add(stream);
    final totals = _sessionTrackCounts(sessionId);
    AppLogger.instance.d(
        'remote session $sessionId handled: streams=${list.length} '
        'event(video=${stream.getVideoTracks().length} audio=${stream.getAudioTracks().length}) '
        'session(video=${totals['video']} audio=${totals['audio']})');
    _rebindAllRemoteRenderers();
  }

  /// 세션별 누적 트랙/스트림 수 (H1 진단: 스트림 단위 이벤트와 세션 합계 구분)
  Map<String, int> sessionMediaCounts(String sessionId) =>
      _sessionTrackCounts(sessionId);

  Map<String, int> _sessionTrackCounts(String sessionId) {
    final list = _remoteSessions[sessionId] ?? const <MediaStream>[];
    var video = 0;
    var audio = 0;
    for (final s in list) {
      video += s.getVideoTracks().length;
      audio += s.getAudioTracks().length;
    }
    return {'streams': list.length, 'video': video, 'audio': audio};
  }

  /// 세션 목록(순서 유지)에서 영상을 가진 스트림 반환
  MediaStream? _videoStreamOfSession(String sessionId) {
    final list = _remoteSessions[sessionId];
    if (list == null) return null;
    for (final s in list) {
      if (s.getVideoTracks().isNotEmpty) return s;
    }
    return list.isNotEmpty ? list.first : null;
  }

  /// 모든 원격 렌더러에 세션의 영상 스트림을 재바인딩 (D4: 즉시 렌더 반영)
  void _rebindAllRemoteRenderers() {
    final sessionIds = _remoteSessions.keys.toList();
    for (var i = 0; i < sessionIds.length && i < 4; i++) {
      final vid = _videoStreamOfSession(sessionIds[i]);
      var renderer = _remoteRenderers['remote_$i'];
      if (renderer == null) {
        final r = RTCVideoRenderer();
        final capturedVid = vid;
        r.initialize().then((_) {
          final existing = _remoteRenderers['remote_$i'];
          final bindTo = existing ?? r;
          if (existing == null) {
            _remoteRenderers['remote_$i'] = r;
          }
          if (bindTo.srcObject != capturedVid) {
            bindTo.srcObject = capturedVid;
          }
        });
      } else if (renderer.srcObject != vid) {
        renderer.srcObject = vid;
      }
    }
    // 세션 축소 시 잔여 렌더러 정리
    for (var i = sessionIds.length; i < 4; i++) {
      _remoteRenderers['remote_$i']?.srcObject = null;
    }
  }

  /// 원격 스트림 제거
  ///
  /// [sessionId] 세션 ID
  void removeRemoteStream(String sessionId) {
    _removeRemoteStream(sessionId);
  }

  /// 원격 스트림 내부 제거
  void _removeRemoteStream(String sessionId) async {
    final list = _remoteSessions[sessionId];
    if (list != null) {
      for (final stream in list) {
        await _disposeStream(stream);
      }
      _remoteSessions.remove(sessionId);
      _rebindAllRemoteRenderers();
    }
  }

  /// 모든 원격 스트림 제거
  Future<void> removeAllRemoteStreams() async {
    for (final sessionId in List<String>.from(_remoteSessions.keys)) {
      _removeRemoteStream(sessionId);
    }
    _rebindAllRemoteRenderers();
  }

  /// 원격 스트림 가져오기
  MediaStream? getRemoteStream(String sessionId) {
    return _videoStreamOfSession(sessionId);
  }
  
  //--------------------------------------------------------------------------
  // Renderer Access
  //--------------------------------------------------------------------------
  
  /// 로컬 렌더러 가져오기
  RTCVideoRenderer? getLocalRenderer() {
    return _localRenderers['default'];
  }
  
  /// 원격 렌더러 가져오기
  RTCVideoRenderer? getRemoteRenderer(int index) {
    return _remoteRenderers['remote_$index'];
  }
  
  /// 모든 렌더러 가져오기
  List<RTCVideoRenderer> getAllRenderers() {
    return [..._localRenderers.values, ..._remoteRenderers.values];
  }
  
  //--------------------------------------------------------------------------
  // Track Management
  //--------------------------------------------------------------------------
  
  /// 스트림이 비디오를 포함하는지 확인
  bool hasVideo(MediaStream? stream) {
    if (stream == null) return false;
    return stream.getVideoTracks().isNotEmpty;
  }
  
  /// 스트림이 오디오를 포함하는지 확인
  bool hasAudio(MediaStream? stream) {
    if (stream == null) return false;
    return stream.getAudioTracks().isNotEmpty;
  }
  
  /// 스트림 정보 가져오기
  String getStreamInfo(MediaStream? stream) {
    if (stream == null) return 'No stream';
    
    final videoTracks = stream.getVideoTracks();
    final audioTracks = stream.getAudioTracks();
    
    return 'Video: ${videoTracks.length}, Audio: ${audioTracks.length}';
  }
}
