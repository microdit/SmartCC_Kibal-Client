import 'dart:async';
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

  /// 원격 영상 트랙별 렌더 스트림 (track.id → 비디오 트랙 1개만 가진 스트림)
  ///
  /// ConfBridge SFU에서 한 세션에 여러 원격 영상 트랙이 도착할 수 있다.
  /// `RTCVideoRenderer`는 스트림의 첫 video track만 렌더하므로, 트랙별로
  /// 별도 스트림을 만들어 타일마다 올바른 영상을 표시한다.
  final Map<String, MediaStream> _remoteVideoStreams = {};
  final List<String> _remoteVideoTrackOrder = [];
  bool _videoSyncRunning = false;

  /// 수신이 멈춘(죽은) 영상 트랙 ID. 타일에서 제외한다(B3/F4).
  final Set<String> _inactiveVideoTracks = {};
  bool _videoSyncDirty = false;

  /// 영상 타일 목록이 갱신될 때 UI에 알린다(MediaProvider가 설정).
  VoidCallback? onRemoteVideoStreamsChanged;
  
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
  /// 영상 트랙별 렌더 스트림 목록(타일 1개 = 영상 트랙 1개).
  /// 아직 트랙별 스트림이 준비되지 않았으면 세션 대표 스트림으로 폴백한다.
  ///
  /// ConfBridge re-INVITE마다 새 트랙이 추가되며 과거 트랙이 남는다.
  /// 화면에는 **최신 트랙 3개**만 노출해 정지된 과거 타일/그리드 폭주를 막는다.
  static const int maxRemoteVideoTiles = 3;

  List<MediaStream> get remoteStreams {
    final all = <MediaStream>[];
    if (_remoteVideoTrackOrder.isNotEmpty) {
      for (final trackId in _remoteVideoTrackOrder) {
        final stream = _remoteVideoStreams[trackId];
        if (stream != null) all.add(stream);
      }
    }
    if (all.isEmpty) {
      for (final sessionId in _remoteSessions.keys) {
        final vid = _videoStreamOfSession(sessionId);
        if (vid != null) all.add(vid);
      }
    }
    if (all.length <= maxRemoteVideoTiles) return all;
    return all.sublist(all.length - maxRemoteVideoTiles);
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

    // 트랙별 렌더 스트림 정리 (공유 중인 원본 스트림은 건너뛴다)
    for (final stream in _remoteVideoStreams.values) {
      await _disposeRenderStream(stream);
    }
    _remoteVideoStreams.clear();
    _remoteVideoTrackOrder.clear();
    _inactiveVideoTracks.clear();
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
  ///
  /// v0.0.8 실측: `getLocalMedia()`가 기존 `_localStream`을 dispose하면서
  /// 송신 중인 video track까지 stop되어, 통화 중 원격 영상이 끊겼다.
  /// 다중 카메라 전환은 `RTCRtpSender.replaceTrack()` + 재협상이 필요하므로
  /// 구현 전까지는 스트림을 건드리지 않고 보류한다.
  Future<bool> toggleCamera() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final cameras = devices.where((d) => d.kind == 'videoinput').toList();
      AppLogger.instance.i(
          '카메라 전환 보류: 카메라 ${cameras.length}개, replaceTrack 미구현');
      return false;
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
  
  /// 영상 동기화(리프레시): 참가자 변화(re-INVITE) 후 화면이 멈추는 문제 대응.
  ///
  /// 1) 송신: 내 영상 트랙 off→on (사용자가 수동으로 끄고 켜면 복구되던 동작을 자동화,
  ///    인코더가 키프레임을 다시 보내 SFU 경유 전 참가자 화면이 갱신된다)
  /// 2) 수신: 렌더 타일 재구성 + 모든 원격 렌더러 srcObject 해제 후 재바인딩
  Future<void> resyncVideo({String reason = '-'}) async {
    final local = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    final kick = !_isVideoMuted && local.isNotEmpty;
    AppLogger.instance.i('VIDEO resync reason=$reason localKick=$kick '
        'remoteTiles=${_remoteVideoTrackOrder.length}');
    if (kick) {
      for (final t in local) {
        t.enabled = false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (final t in local) {
        t.enabled = !_isVideoMuted;
      }
    }
    // 수신 타일 재구성: 렌더 전용 스트림을 새로 만들어 텍스처를 다시 연결
    for (final id in List<String>.from(_remoteVideoTrackOrder)) {
      final stale = _remoteVideoStreams.remove(id);
      await _disposeRenderStream(stale);
    }
    _remoteVideoTrackOrder.clear();
    for (final r in _remoteRenderers.values) {
      r.srcObject = null;
    }
    onRemoteVideoStreamsChanged?.call();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await _syncRemoteVideoStreams();
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
    final trackIds = stream.getTracks().map((t) => t.id).toSet();
    // 첫 트랙 ID만 비교하면, 기존 오디오 트랙 + 새 영상 트랙을 함께 가진
    // 재협상 스트림이 통째로 버려져 새 영상이 유실된다(H5 이후 3자 증상).
    // 전체 트랙 집합이 동일할 때만 중복으로 본다.
    final existsById = list.any((s) {
      final ids = s.getTracks().map((t) => t.id).toSet();
      return ids.length == trackIds.length && ids.containsAll(trackIds);
    });
    if (!existsById) list.add(stream);
    final totals = _sessionTrackCounts(sessionId);
    AppLogger.instance.d(
        'remote session $sessionId handled: streams=${list.length} '
        'event(video=${stream.getVideoTracks().length} audio=${stream.getAudioTracks().length}) '
        'session(video=${totals['video']} audio=${totals['audio']})');
    _rebindAllRemoteRenderers();
    unawaited(_syncRemoteVideoStreams());
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

  /// 원격 영상 트랙별 렌더 스트림을 동기화한다.
  ///
  /// 한 세션에 영상 트랙이 여러 개 도착해도 트랙마다 스트림을 만들어
  /// `RTCVideoRenderer`가 첫 트랙만 그리는 문제를 우회한다.
  Future<void> _syncRemoteVideoStreams() async {
    if (_videoSyncRunning) {
      _videoSyncDirty = true;
      return;
    }
    _videoSyncRunning = true;
    try {
      do {
        _videoSyncDirty = false;

        final tracks = <String, MediaStreamTrack>{};
        final sourceStreams = <String, MediaStream>{};
        for (final streams in _remoteSessions.values) {
          for (final stream in streams) {
            for (final track in stream.getVideoTracks()) {
              final trackId = track.id;
              if (trackId == null || trackId.isEmpty) continue;
              if (_inactiveVideoTracks.contains(trackId)) continue;
              tracks[trackId] = track;
              sourceStreams[trackId] = stream;
            }
          }
        }

        // 사라진 트랙 정리
        for (final trackId in List<String>.from(_remoteVideoTrackOrder)) {
          if (tracks.containsKey(trackId)) continue;
          _remoteVideoTrackOrder.remove(trackId);
          final stale = _remoteVideoStreams.remove(trackId);
          await _disposeRenderStream(stale);
        }

        // 새 트랙 추가: 모든 영상 트랙을 1개짜리 전용 스트림으로 렌더한다.
        // 원본 스트림은 재협상 후 이전/새 트랙이 섞여 첫 트랙이 죽은 트랙일
        // 수 있으므로, 렌더 타일은 항상 트랙 단위로 분리한다.
        for (final entry in tracks.entries) {
          if (_remoteVideoStreams.containsKey(entry.key)) continue;
          try {
            final renderStream =
                await createLocalMediaStream('kibal-video-${entry.key}');
            await renderStream.addTrack(entry.value, addToNative: true);
            _remoteVideoStreams[entry.key] = renderStream;
            _remoteVideoTrackOrder.add(entry.key);
            AppLogger.instance
                .d('remote video tile 등록(전용) track=${entry.key}');
          } catch (e) {
            final fallback = sourceStreams[entry.key];
            if (fallback != null) {
              _remoteVideoStreams[entry.key] = fallback;
              _remoteVideoTrackOrder.add(entry.key);
              AppLogger.instance.w(
                  'remote video tile 폴백(원본) track=${entry.key}: $e');
            } else {
              AppLogger.instance
                  .w('remote video tile 생성 실패 track=${entry.key}: $e');
            }
          }
        }

        _rebindAllRemoteRenderers();
        onRemoteVideoStreamsChanged?.call();
      } while (_videoSyncDirty);
    } finally {
      _videoSyncRunning = false;
    }
  }

  /// 현재 수신 중인 영상 트랙만 타일로 유지한다(B3/F4).
  ///
  /// [active]에 없는 기존 트랙은 비활성으로 표시해 타일에서 내린다.
  /// 다시 수신되면(active에 포함) 자동 복귀한다.
  void retainRemoteVideoTracks(Set<String> active) {
    var changed = false;
    final known = <String>{};
    for (final streams in _remoteSessions.values) {
      for (final stream in streams) {
        for (final track in stream.getVideoTracks()) {
          final id = track.id;
          if (id != null && id.isNotEmpty) known.add(id);
        }
      }
    }
    for (final id in known) {
      final isActive = active.contains(id);
      if (isActive && _inactiveVideoTracks.remove(id)) changed = true;
      if (!isActive && _inactiveVideoTracks.add(id)) changed = true;
    }
    if (changed) {
      AppLogger.instance.d('remote video tiles active=${active.length} '
          'inactive=${_inactiveVideoTracks.length}');
      unawaited(_syncRemoteVideoStreams());
    }
  }

  /// 렌더 전용 스트림 정리 (공유 트랙은 stop하지 않는다)
  Future<void> _disposeRenderStream(MediaStream? stream) async {
    if (stream == null) return;
    // 세션 원본 스트림은 `_disposeStream`에서 이미 정리된다.
    if (_isSessionStream(stream)) return;
    try {
      await stream.dispose();
    } catch (e) {
      AppLogger.instance.w('remote video tile dispose 실패: $e');
    }
  }

  bool _isSessionStream(MediaStream stream) {
    for (final streams in _remoteSessions.values) {
      for (final candidate in streams) {
        if (identical(candidate, stream)) return true;
      }
    }
    return false;
  }

  /// 모든 원격 렌더러에 영상 타일 스트림을 재바인딩 (D4: 즉시 렌더 반영)
  void _rebindAllRemoteRenderers() {
    final vids = remoteStreams;
    for (var i = 0; i < vids.length && i < 4; i++) {
      final vid = vids[i];
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
          // 렌더러 초기화/바인딩 완료 후 UI 재빌드
          onRemoteVideoStreamsChanged?.call();
        });
      } else if (renderer.srcObject != vid) {
        renderer.srcObject = vid;
      }
    }
    // 타일 축소 시 잔여 렌더러 정리
    for (var i = vids.length; i < 4; i++) {
      _remoteRenderers['remote_$i']?.srcObject = null;
    }
  }

  /// 원격 스트림 제거
  ///
  /// [sessionId] 세션 ID
  void removeRemoteStream(String sessionId) {
    unawaited(_removeRemoteStream(sessionId));
  }

  /// 원격 스트림 내부 제거
  Future<void> _removeRemoteStream(String sessionId) async {
    final list = _remoteSessions[sessionId];
    if (list != null) {
      for (final stream in list) {
        await _disposeStream(stream);
      }
      _remoteSessions.remove(sessionId);
      _rebindAllRemoteRenderers();
      unawaited(_syncRemoteVideoStreams());
    }
  }

  /// 모든 원격 스트림 제거
  Future<void> removeAllRemoteStreams() async {
    for (final sessionId in List<String>.from(_remoteSessions.keys)) {
      await _removeRemoteStream(sessionId);
    }
    _inactiveVideoTracks.clear();
    await _syncRemoteVideoStreams();
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
