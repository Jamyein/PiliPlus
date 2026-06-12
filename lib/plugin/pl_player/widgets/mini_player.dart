import 'dart:math' as math;

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MiniPlayer extends StatefulWidget {
  final double miniWidth;
  final double miniHeight;
  // 位置由父级 overlay 唯一持有,所以这里只把手势事件原样转交,
  // 不再保留任何坐标状态。
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  const MiniPlayer({
    super.key,
    this.miniWidth = 160.0,
    this.miniHeight = 90.0,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  PlPlayerController? get _controller => PlPlayerController.instance;

  void _onTap() {
    _controller?.exitMiniPlayer(navigateToVideo: true);
  }

  void _onClose() {
    final ctrl = _controller;
    if (ctrl == null) return;
    ctrl.pause(notify: false);
    ctrl.isMiniPlayer.value = false;
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    final videoController = controller.videoController;
    if (videoController == null) return const SizedBox.shrink();

    return StreamBuilder<PlayerStatus>(
      stream: controller.playerStatus.stream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data?.isPlaying ?? true;
        return GestureDetector(
          onTap: _onTap,
          onPanStart: widget.onPanStart,
          onPanUpdate: widget.onPanUpdate,
          onPanEnd: widget.onPanEnd,
          child: Container(
            width: widget.miniWidth,
            height: widget.miniHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SimpleVideo(
                    controller: videoController,
                    fill: Colors.black,
                  ),
                ),
                _buildOverlay(isPlaying),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlay(bool isPlaying) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          const Spacer(),
          _buildBottomBar(isPlaying),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(right: 4, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _onClose,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isPlaying) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              final ctrl = _controller;
              if (isPlaying) {
                ctrl?.pause();
              } else {
                ctrl?.play();
              }
            },
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildProgressBar(),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final ctrl = _controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final durationMs = ctrl?.duration.value.inMilliseconds ?? 1;
        final positionMs = ctrl?.position.inMilliseconds ?? 0;
        final progress =
            durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
        return Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: math.max(progress, 0.01),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}
