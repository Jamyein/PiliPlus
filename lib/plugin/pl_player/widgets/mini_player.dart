import 'dart:math' as math;

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MiniPlayer extends StatefulWidget {
  final double miniWidth;
  final double miniHeight;
  final ValueChanged<Offset>? onPositionChanged;
  final ValueChanged<Offset>? onDragEnd;

  const MiniPlayer({
    super.key,
    this.miniWidth = 160.0,
    this.miniHeight = 90.0,
    this.onPositionChanged,
    this.onDragEnd,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  PlPlayerController? get _controller => PlPlayerController.instance;
  Offset _position = Offset.zero;
  double _dragStartX = 0;
  double _dragStartY = 0;
  bool _isDragging = false;
  bool _isDismissing = false;
  double _dismissThreshold = 0;

  late AnimationController _dismissAnimationController;
  late Animation<double> _dismissAnimation;

  @override
  void initState() {
    super.initState();
    _dismissAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _dismissAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _dismissAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    final ctx = Get.context;
    if (ctx != null) {
      final size = MediaQuery.of(ctx).size;
      _position = Offset(
        size.width - widget.miniWidth - 16,
        size.height * 0.3,
      );
    }
    _dismissThreshold = widget.miniHeight * 0.4;
  }

  @override
  void dispose() {
    _dismissAnimationController.dispose();
    super.dispose();
  }

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

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _dragStartX = _position.dx;
    _dragStartY = _position.dy;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position = Offset(
        _dragStartX + details.delta.dx,
        _dragStartY + details.delta.dy,
      );
    });
    widget.onPositionChanged?.call(_position);
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final verticalVelocity = details.primaryVelocity ?? 0;

    if (verticalVelocity.abs() > 500 &&
        (_position.dy > screenHeight - widget.miniHeight ||
            _position.dy < 0)) {
      _animateDismiss();
      return;
    }

    double dx = _position.dx;
    double dy = _position.dy;
    dx = dx.clamp(0.0, screenWidth - widget.miniWidth);
    dy = dy.clamp(0.0, screenHeight - widget.miniHeight - kToolbarHeight);

    final snapLeft = dx < screenWidth / 2;
    setState(() {
      _position = Offset(
        snapLeft ? 8.0 : screenWidth - widget.miniWidth - 8,
        dy,
      );
    });
    widget.onDragEnd?.call(_position);
  }

  void _animateDismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _dismissAnimationController.forward().then((_) {
      if (mounted) {
        _onClose();
      }
    });
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
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
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
        final durationMs =
            ctrl?.duration.value.inMilliseconds ?? 1;
        final positionMs =
            ctrl?.position.inMilliseconds ?? 0;
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
