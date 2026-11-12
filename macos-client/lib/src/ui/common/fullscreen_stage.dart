import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 영상 전체 화면 스테이지 (1:1·다자간 공통)
///
/// - 더블클릭 / Esc → [onExit]
/// - 마우스 이동 시 하단 컨트롤 오버레이 3초 표시
class FullscreenStage extends StatefulWidget {
  const FullscreenStage({
    super.key,
    required this.child,
    required this.onExit,
    required this.audioMuted,
    required this.onToggleAudio,
    required this.onHangup,
  });

  final Widget child;
  final VoidCallback onExit;
  final bool audioMuted;
  final VoidCallback onToggleAudio;
  final VoidCallback onHangup;

  @override
  State<FullscreenStage> createState() => _FullscreenStageState();
}

class _FullscreenStageState extends State<FullscreenStage> {
  final FocusNode _focus = FocusNode();
  bool _showControls = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _poke();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _hide?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _poke() {
    _hide?.cancel();
    if (!_showControls) setState(() => _showControls = true);
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focus,
      onKeyEvent: (e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          widget.onExit();
        }
      },
      child: MouseRegion(
        onHover: (_) => _poke(),
        cursor: _showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onExit,
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: widget.audioMuted ? '마이크 켜기' : '마이크 끄기',
                              icon: Icon(widget.audioMuted ? Icons.mic_off : Icons.mic,
                                  color: widget.audioMuted ? Colors.red : Colors.white),
                              onPressed: widget.onToggleAudio,
                            ),
                            IconButton(
                              tooltip: '전체 화면 해제 (더블클릭 / Esc)',
                              icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                              onPressed: widget.onExit,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: '종료',
                              style: IconButton.styleFrom(backgroundColor: Colors.red),
                              icon: const Icon(Icons.call_end, color: Colors.white),
                              onPressed: widget.onHangup,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
