import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/constants.dart';

/// 비디오 뷰 위젯
/// 
/// WebRTC 비디오 스트림을 표시하는 위젯입니다.
/// 로컬/원격 비디오를 동일하게 처리할 수 있습니다.
class VideoView extends StatelessWidget {
  /// 비디오 렌더러
  final RTCVideoRenderer? renderer;
  
  /// 스트림
  final MediaStream? stream;
  
  /// 비디오 타입
  final String label;
  
  /// 화면 반전 여부 (로컬 카메라 전면일 때 사용)
  final bool mirror;
  
  /// 비디오 fit 타입
  final RTCVideoViewObjectFit objectFit;
  
  /// placeholder 표시 여부
  final bool showPlaceholder;
  
  /// 수정자
  final Widget? overlay;
  
  /// 생성자
  const VideoView({
    super.key,
    this.renderer,
    this.stream,
    required this.label,
    this.mirror = false,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    this.showPlaceholder = true,
    this.overlay,
  }) : assert(renderer != null || stream != null, 'renderer or stream must be provided');

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 비디오 렌더링
        _buildVideoRenderer(),
        
        // 오버레이
        if (overlay != null) overlay!,
        
        // 라벨
        Positioned(
          bottom: AppConstants.spacingSm,
          left: AppConstants.spacingSm,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingSm,
              vertical: AppConstants.spacingXs,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusSm),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
        
        // 비디오 없음 placeholder
        if (showPlaceholder && renderer == null)
          _buildPlaceholder(),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // Video Renderer
  //--------------------------------------------------------------------------
  
  Widget _buildVideoRenderer() {
    // 스트림이 있고 렌더러가 없을 때
    if (stream != null && renderer == null) {
      final localRenderer = RTCVideoRenderer();
      localRenderer.srcObject = stream!;
      return RTCVideoView(
        localRenderer,
        mirror: mirror,
        objectFit: objectFit,
      );
    }
    
    // 렌더러가 있을 때
    if (renderer != null) {
      return RTCVideoView(
        renderer!,
        mirror: mirror,
        objectFit: objectFit,
      );
    }
    
    // 스트림이 없을 때
    return Container(color: Colors.black);
  }

  //--------------------------------------------------------------------------
  // Placeholder
  //--------------------------------------------------------------------------
  
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_outlined, size: 48, color: Colors.white54),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              '$label를 기다리는 중...',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

/// 비디오 그리드 위젯
/// 
/// 다중 비디오 스트림을 그리드 형태로 표시합니다.
class VideoGrid extends StatelessWidget {
  /// 비디오 스트림 목록
  final List<MediaStream> streams;
  
  /// 로컬 스트림
  final MediaStream? localStream;
  
  /// 로컬 스트림 미러링 여부
  final bool localMirror;
  
  /// Grid 항목建設子
  final Widget Function(BuildContext, MediaStream, int) builder;
  
  /// 생성자
  const VideoGrid({
    super.key,
    required this.streams,
    this.localStream,
    this.localMirror = false,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    // 스트림이 없을 때
    if (streams.isEmpty && localStream == null) {
      return _buildPlaceholderGrid();
    }
    
    // 1개 스트림일 때
    if (streams.length == 1 && localStream == null) {
      return builder(context, streams.first, 0);
    }
    
    // 다중 스트림일 때
    return GridView.count(
      crossAxisCount: _getColumnCount(streams.length + (localStream != null ? 1 : 0)),
      childAspectRatio: 16 / 9,
      crossAxisSpacing: AppConstants.spacingSm,
      mainAxisSpacing: AppConstants.spacingSm,
      children: [
        // 로컬 스트림 (PIP)
        if (localStream != null)
          builder(context, localStream!, -1),
        
        // 원격 스트림
        for (int i = 0; i < streams.length; i++)
          builder(context, streams[i], i),
      ],
    );
  }

  //--------------------------------------------------------------------------
  // Column Count
  //--------------------------------------------------------------------------
  
  int _getColumnCount(int totalStreams) {
    switch (totalStreams) {
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
      case 4:
        return 2;
      case 5:
      case 6:
        return 3;
      default:
        return 3;
    }
  }

  //--------------------------------------------------------------------------
  // Placeholder Grid
  //--------------------------------------------------------------------------
  
  Widget _buildPlaceholderGrid() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 16 / 9,
      crossAxisSpacing: AppConstants.spacingSm,
      mainAxisSpacing: AppConstants.spacingSm,
      children: List.generate(4, (index) => 
        Container(
          color: Colors.grey[900],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off_outlined, size: 32, color: Colors.white54),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  '영상 ${index + 1}',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 비디오 프리뷰 위젯
/// 
/// 로컬 비디오를 미리보기하는 위젯입니다.
class VideoPreview extends StatelessWidget {
  /// 미디어 스트림
  final MediaStream? stream;
  
  /// 비디오 렌더러
  final RTCVideoRenderer? renderer;
  
  /// 미러링 여부
  final bool mirror;
  
  /// placeholder 표시
  final bool showPlaceholder;
  
  /// 생성자
  const VideoPreview({
    super.key,
    this.stream,
    this.renderer,
    this.mirror = true,
    this.showPlaceholder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMd),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMd),
        child: VideoView(
          renderer: renderer,
          stream: stream,
          label: '미리보기',
          mirror: mirror,
          showPlaceholder: showPlaceholder,
        ),
      ),
    );
  }
}

/// 원격 비디오 뷰어
/// 
/// 원격 비디오 스트림을 표시하는 위젯입니다.
class RemoteVideoViewer extends StatelessWidget {
  /// 미디어 스트림
  final MediaStream? stream;
  
  /// 세션 ID
  final String sessionId;
  
  /// 렌더러 인덱스
  final int rendererIndex;
  
  /// 생성자
  const RemoteVideoViewer({
    super.key,
    this.stream,
    required this.sessionId,
    this.rendererIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return VideoView(
      stream: stream,
      label: '원격 $sessionId',
      mirror: false,
      showPlaceholder: true,
    );
  }
}

/// 로컬 비디오 뷰어
/// 
/// 로컬 비디오 스트림을 표시하는 위젯입니다.
class LocalVideoViewer extends StatelessWidget {
  /// 미디어 스트림
  final MediaStream? stream;
  
  /// 미러링 여부
  final bool mirror;
  
  /// 생성자
  const LocalVideoViewer({
    super.key,
    this.stream,
    this.mirror = true,
  });

  @override
  Widget build(BuildContext context) {
    return VideoView(
      stream: stream,
      label: '로컬',
      mirror: mirror,
      showPlaceholder: true,
    );
  }
}
