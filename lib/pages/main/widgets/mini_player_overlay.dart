import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MiniPlayerOverlay extends StatefulWidget {
  final double miniWidth;
  final double miniHeight;

  const MiniPlayerOverlay({
    super.key,
    this.miniWidth = 160.0,
    this.miniHeight = 90.0,
  });

  @override
  State<MiniPlayerOverlay> createState() => _MiniPlayerOverlayState();
}

class _MiniPlayerOverlayState extends State<MiniPlayerOverlay> {
  Worker? _instanceWorker;
  Worker? _miniWorker;
  bool _visible = false;
  Offset _position = const Offset(16, 100);
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // 监听单例实例的创建/销毁：instance 可能晚于本组件创建（首播视频时），
    // 也可能在前一个视频结束后被新的实例替换。任一变化都要重新绑定 isMiniPlayer。
    _instanceWorker = ever<PlPlayerController?>(
      PlPlayerController.instanceRx,
      (_) {
        if (!mounted) return;
        _bindPlayer();
        setState(() {});
      },
    );
    _bindPlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initPosition();
    }
  }

  void _initPosition() {
    final size = MediaQuery.of(context).size;
    _position = Offset(
      size.width - widget.miniWidth - 16,
      size.height * 0.3,
    );
  }

  void _bindPlayer() {
    // 先解绑旧的内部 worker，避免泄漏以及对已销毁 Rx 的监听。
    _miniWorker?.dispose();
    _miniWorker = null;
    final player = PlPlayerController.instance;
    if (player == null) {
      _visible = false;
      return;
    }
    _visible = player.isMiniPlayer.value;
    _miniWorker = ever<bool>(player.isMiniPlayer, (val) {
      if (mounted) {
        setState(() => _visible = val);
      }
    });
  }

  @override
  void dispose() {
    _instanceWorker?.dispose();
    _miniWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: MiniPlayer(
        miniWidth: widget.miniWidth,
        miniHeight: widget.miniHeight,
        onPositionChanged: (pos) {
          _position = pos;
        },
        onDragEnd: (pos) {
          if (mounted) {
            setState(() => _position = pos);
          }
        },
      ),
    );
  }
}
