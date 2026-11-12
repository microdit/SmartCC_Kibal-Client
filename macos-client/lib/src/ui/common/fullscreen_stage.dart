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
  // 진입 직후·해제 중에는 컨트롤을 숨긴다(더블클릭 중 버튼이 크게 보이며 눌리는 문제)
  bool _showControls = false;
  bool _exiting = false;
  Timer? _hide;
  DateTime _enteredAt = DateTime.now();

  void _exit() {
    if (_exiting) return;
    _hide?.cancel();
    setState(() {
      _exiting = true;
      _showControls = false;
    });
    widget.onExit();
  }

  @override
  void initState() {
    super.initState();
    _enteredAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _hide?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _poke() {
    // 창 전환 애니메이션(약 0.8초) 동안은 표시하지 않음
    if (_exiting || DateTime.now().difference(_enteredAt) < const Duration(milliseconds: 900)) {
      return;
    }
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
          _exit();
        }
      },
      child: MouseRegion(
        onHover: (_) => _poke(),
        cursor: _showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _exit,
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                IgnorePointer(
                  ignoring: !_showControls,
                  child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
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
                              onPressed: _exit,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
