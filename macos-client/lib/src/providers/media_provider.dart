import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../media/media_manager.dart';
import '../utils/app_logger.dart';

/// 미디어 Provider
/// 
/// WebRTC 미디어 스트림(카메라, 마이크, 원격 스트림)을 관리하는 Provider 클래스입니다.
/// 앱 전체에서 미디어 상태를 관리하고, 미디어 스트림을 제어할 수 있습니다.
class MediaProvider with ChangeNotifier {
  /// 미디어 매니저 인스턴스
  final MediaManager _mediaManager = MediaManager();
  
  /// 로컬 스트림 여부
  bool _hasLocalStream = false;
  
  /// 원격 스트림 수
  int _remoteStreamCount = 0;
  
  /// 카메라 전면 여부
  bool _isFrontCamera = true;
  
  /// 오디오 뮤트 여부
  bool _isAudioMuted = false;
  
  /// 비디오 뮤트 여부
  bool _isVideoMuted = false;
  String? _defaultVideoDeviceId;
  String? _defaultMicDeviceId;
  
  /// 오류 메시지
  String? _error;
  
  /// 로딩 상태
  bool _isLoading = false;

  /// dispose 여부
  bool _disposed = false;
  
  //--------------------------------------------------------------------------
  // Public Getters
  //--------------------------------------------------------------------------
  
  /// 미디어 매니저
  MediaManager get mediaManager => _mediaManager;
  
  /// 로컬 스트림
  MediaStream? get localStream => _mediaManager.localStream;
  
  /// 로컬 스트림 여부
  bool get hasLocalStream => _hasLocalStream;
  
  /// 원격 스트림 목록
  List<MediaStream> get remoteStreams => _mediaManager.remoteStreams;
  
  /// 원격 스트림 수
  int get remoteStreamCount => _remoteStreamCount;
  
  /// 카메라 전면 여부
  bool get isFrontCamera => _isFrontCamera;
  
  /// 오디오 뮤트 여부
  bool get isAudioMuted => _isAudioMuted;
  
  /// 비디오 뮤트 여부
  bool get isVideoMuted => _isVideoMuted;
  
  /// 오류 메시지
  String? get error => _error;
  
  /// 로딩 상태
  bool get isLoading => _isLoading;
  
  //--------------------------------------------------------------------------
  // Initialization
  //--------------------------------------------------------------------------
  
  /// MediaProvider 초기화
  MediaProvider() {
    _mediaManager.onRemoteVideoStreamsChanged = _onRemoteVideoStreamsChanged;
    _initMediaManager();
  }

  /// 영상 타일 목록 갱신 시 UI 재빌드
  void _onRemoteVideoStreamsChanged() {
    if (_disposed) return;
    _updateStreamStates();
    notifyListeners();
  }
  
  /// 미디어 매니저 초기화
  Future<void> _initMediaManager() async {
    try {
      await _mediaManager.init();
      _updateStreamStates();
      // 렌더러 풀이 준비된 뒤 재빌드해야 원격 타일이 placeholder로 남지 않는다.
      if (!_disposed) notifyListeners();
    } catch (e) {
      _error = '미디어 매니저 초기화 실패: $e';
      notifyListeners();
    }
  }
  
  //--------------------------------------------------------------------------
  // Local Media Management
  //--------------------------------------------------------------------------
  
  /// 로컬 미디어 스트림 가져오기
  ///
  /// [videoDeviceId]/[micDeviceId]: 디바이스 명시 선택 (미디어 테스트 화면에서 지정)
  Future<bool> getLocalMedia({
    String? videoDeviceId,
    String? micDeviceId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final stream = await _mediaManager.getLocalMedia(
        useFrontCamera: _isFrontCamera,
        useAudio: !_isAudioMuted,
        useVideo: !_isVideoMuted,
        videoDeviceId: videoDeviceId ?? _defaultVideoDeviceId,
        audioDeviceId: micDeviceId ?? _defaultMicDeviceId,
      );
      
      if (stream != null) {
        _hasLocalStream = true;
        _updateStreamStates();
        AppLogger.instance.evt('MEDIA', 'localStreamReady',
            state: 'video=${stream.getVideoTracks().length} audio=${stream.getAudioTracks().length}',
            details: {'frontCamera': _isFrontCamera, 'audioMuted': _isAudioMuted});
      } else {
        AppLogger.instance.w('MEDIA localStream null (사용 불가: 권한/장치 확인)');
      }

      _isLoading = false;
      notifyListeners();
      return stream != null;
    } catch (e) {
      _isLoading = false;
      _error = '로컬 미디어 스트림 가져오기 실패: $e';
      AppLogger.instance.e('MEDIA getLocalMedia 실패: $e');
      notifyListeners();
      return false;
    }
  }
  
  /// 로컬 미디어 스트림 해제 (원격 렌더러 풀 보존)
  Future<void> releaseLocalMedia() async {
    try {
      await _mediaManager.releaseLocalMedia();
      AppLogger.instance.evt('MEDIA', 'localStreamReleased');
      _hasLocalStream = false;
      _updateStreamStates();
      notifyListeners();
    } catch (e) {
      _error = '로컬 미디어 스트림 해제 실패: $e';
      AppLogger.instance.e('MEDIA releaseLocalMedia 실패: $e');
      notifyListeners();
    }
  }

  /// 완전 해제 (로그아웃용 — 렌더러 풀 포함 dispose)
  Future<void> disposeAllMedia() async {
    try {
      await _mediaManager.dispose();
      _hasLocalStream = false;
      _updateStreamStates();
      AppLogger.instance.evt('MEDIA', 'disposeAllMedia');
      notifyListeners();
    } catch (e) {
      _error = '미디어 완전 해제 실패: $e';
      AppLogger.instance.e('MEDIA disposeAllMedia 실패: $e');
      notifyListeners();
    }
  }
  
  //--------------------------------------------------------------------------
  // Camera Control
  //--------------------------------------------------------------------------
  
  /// 카메라 전환
  Future<bool> toggleCamera() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final result = await _mediaManager.toggleCamera();
      
      if (result) {
        _isFrontCamera = _mediaManager.isFrontCamera;
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      _error = '카메라 전환 실패: $e';
      notifyListeners();
      return false;
    }
  }
  
  //--------------------------------------------------------------------------
  // Audio/Video Control
  //--------------------------------------------------------------------------
  
  /// 오디오 뮤트 토글
  Future<bool> toggleAudio() async {
    try {
      final result = await _mediaManager.toggleAudio();
      
      if (result) {
        _isAudioMuted = _mediaManager.isAudioMuted;
        notifyListeners();
      }
      
      return result;
    } catch (e) {
      _error = '오디오 뮤트 토글 실패: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// 비디오 뮤트 토글
  Future<bool> toggleVideo() async {
    try {
      final result = await _mediaManager.toggleVideo();
      
      if (result) {
        _isVideoMuted = _mediaManager.isVideoMuted;
        notifyListeners();
      }
      
      return result;
    } catch (e) {
      _error = '비디오 뮤트 토글 실패: $e';
      notifyListeners();
      return false;
    }
  }
  
  //--------------------------------------------------------------------------
  // Remote Media Management
  //--------------------------------------------------------------------------
  
  /// 원격 스트림 추가
  void addRemoteStream(MediaStream stream, String sessionId) {
    _mediaManager.addRemoteStream(stream, sessionId);
    final session = _mediaManager.sessionMediaCounts(sessionId);
    AppLogger.instance.evt('MEDIA', 'remoteStreamAdded',
        state: 'video=${stream.getVideoTracks().length} audio=${stream.getAudioTracks().length}',
        details: {
          'sessionId': sessionId,
          'sessionStreams': session['streams'],
          'sessionVideo': session['video'],
          'sessionAudio': session['audio'],
        });
    _updateStreamStates();
    notifyListeners();
  }

  /// 원격 스트림 제거
  void removeRemoteStream(String sessionId) {
    AppLogger.instance.evt('MEDIA', 'remoteStreamRemoved',
        details: {'sessionId': sessionId});
    _mediaManager.removeRemoteStream(sessionId);
    _updateStreamStates();
    notifyListeners();
  }
  
  /// 모든 원격 스트림 제거
  Future<void> removeAllRemoteStreams() async {
    await _mediaManager.removeAllRemoteStreams();
    _updateStreamStates();
    notifyListeners();
  }
  
  //--------------------------------------------------------------------------
  // Stream State Management
  //--------------------------------------------------------------------------
  
  /// 스트림 상태 업데이트
  void _updateStreamStates() {
    _hasLocalStream = _mediaManager.localStream != null;
    _remoteStreamCount = _mediaManager.remoteStreams.length;
    _isFrontCamera = _mediaManager.isFrontCamera;
    _isAudioMuted = _mediaManager.isAudioMuted;
    _isVideoMuted = _mediaManager.isVideoMuted;
  }
  
  //--------------------------------------------------------------------------
  // Renderer Access
  //--------------------------------------------------------------------------
  
  /// 로컬 렌더러 가져오기
  RTCVideoRenderer? getLocalRenderer() {
    return _mediaManager.getLocalRenderer();
  }
  
  /// 원격 렌더러 가져오기
  RTCVideoRenderer? getRemoteRenderer(int index) {
    return _mediaManager.getRemoteRenderer(index);
  }
  
  /// 모든 렌더러 가져오기
  List<RTCVideoRenderer> getAllRenderers() {
    return _mediaManager.getAllRenderers();
  }
  
  //--------------------------------------------------------------------------
  // Utility Methods
  //--------------------------------------------------------------------------
  
  /// 로컬 스트림이 비디오를 포함하는지 확인
  bool get hasLocalVideo {
    return _mediaManager.hasVideo(_mediaManager.localStream);
  }
  
  /// 로컬 스트림이 오디오를 포함하는지 확인
  bool get hasLocalAudio {
    return _mediaManager.hasAudio(_mediaManager.localStream);
  }
  
  /// 원격 스트림에 비디오가 있는지 확인
  bool hasRemoteVideo() {
    return _mediaManager.remoteStreams.any(
      (stream) => _mediaManager.hasVideo(stream),
    );
  }
  
  /// 스트림 정보 가져오기
  String getStreamInfo(MediaStream? stream) {
    return _mediaManager.getStreamInfo(stream);
  }
  
  /// 카메라 장치 목록 가져오기
  Future<List<MediaDeviceInfo>> getVideoDevices() async {
    return await _mediaManager.getVideoDevices();
  }
  
  /// 오디오 장치 목록 가져오기
  Future<List<MediaDeviceInfo>> getAudioDevices() async {
    return await _mediaManager.getAudioDevices();
  }
  
  //--------------------------------------------------------------------------
  // Status Text
  //--------------------------------------------------------------------------
  
  /// 카메라 상태 텍스트
  String get cameraStatusText {
    if (!_hasLocalStream) return '카메라: OFF';
    return _isFrontCamera ? '카메라: 전면' : '카메라: 후면';
  }
  
  /// 오디오 상태 텍스트
  String get audioStatusText {
    if (!_hasLocalStream) return '마이크: OFF';
    return _isAudioMuted ? '마이크: 뮤트' : '마이크: ON';
  }
  
  /// 비디오 상태 텍스트
  String get videoStatusText {
    if (!_hasLocalStream) return '비디오: OFF';
    return _isVideoMuted ? '비디오: 뮤트' : '비디오: ON';
  }
  
  /// 사용 가능 여부
  bool get isAvailable {
    return _error == null && !_isLoading;
  }
  
  //--------------------------------------------------------------------------
  // Dispose
  //--------------------------------------------------------------------------
  
  /// 리소스 해제
  @override
  Future<void> dispose() async {
    _disposed = true;
    _mediaManager.onRemoteVideoStreamsChanged = null;
    await _mediaManager.dispose();
    super.dispose();
  }
}
