import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/mini_player.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
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
  // 位置由 overlay 唯一持有。MiniPlayer 不再保存自己的副本,
  // 避免“拖一下就跳回上次起点”的问题。
  Offset? _position;
  bool _initialized = false;
  Size? _lastScreenSize;

  @override
  void initState() {
    super.initState();
    // 监听单例实例的创建/销毁:instance 可能晚于本组件创建(首播视频时),
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
    final size = MediaQuery.sizeOf(context);
    if (!_initialized) {
      _initialized = true;
      _position = _resolveInitialPosition(size);
      _lastScreenSize = size;
    } else if (_lastScreenSize != size && _position != null) {
      // 屏幕尺寸变化(旋转/分屏)后,重新夹到可视区域内,
      // 避免小窗跑到屏幕外。
      _position = _clamp(_position!, size);
      _lastScreenSize = size;
    }
  }

  Offset _resolveInitialPosition(Size size) {
    final savedX = Pref.miniPlayerPosX;
    final savedY = Pref.miniPlayerPosY;
    if (savedX != null && savedY != null) {
      return _clamp(Offset(savedX, savedY), size);
    }
    // 默认贴右侧,垂直方向偏上 30%。
    return Offset(
      size.width - widget.miniWidth - 16,
      size.height * 0.3,
    );
  }

  Offset _clamp(Offset pos, Size size) {
    final maxX = (size.width - widget.miniWidth).clamp(0.0, double.infinity);
    final maxY = (size.height - widget.miniHeight - kToolbarHeight)
        .clamp(0.0, double.infinity);
    return Offset(
      pos.dx.clamp(0.0, maxX),
      pos.dy.clamp(0.0, maxY),
    );
  }

  void _bindPlayer() {
    // 先解绑旧的内部 worker,避免泄漏以及对已销毁 Rx 的监听。
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

  void _onPanStart(DragStartDetails _) {}

  void _onPanUpdate(DragUpdateDetails details) {
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _position = _clamp(
        (_position ?? Offset.zero) + details.delta,
        size,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final size = MediaQuery.sizeOf(context);
    final velocityY = details.primaryVelocity ?? 0;
    final cur = _position ?? Offset.zero;

    // 急速上/下抛接近边缘时关闭(沿用原行为)。
    final atTopOrBottom =
        cur.dy < 8 || cur.dy > size.height - widget.miniHeight - 8;
    if (velocityY.abs() > 800 && atTopOrBottom) {
      final ctrl = PlPlayerController.instance;
      ctrl?.pause(notify: false);
      ctrl?.isMiniPlayer.value = false;
      ctrl?.dispose();
      return;
    }

    // 水平边缘吸附,纵向夹到可视区内。
    final snapLeft = cur.dx + widget.miniWidth / 2 < size.width / 2;
    final snapped = Offset(
      snapLeft ? 8.0 : size.width - widget.miniWidth - 8,
      cur.dy,
    );
    final next = _clamp(snapped, size);
    setState(() => _position = next);
    Pref.setMiniPlayerPos(next.dx, next.dy);
  }

  @override
  Widget build(BuildContext context) {
    final pos = _position;
    if (!_visible || pos == null) return const SizedBox.shrink();
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: MiniPlayer(
        miniWidth: widget.miniWidth,
        miniHeight: widget.miniHeight,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
      ),
    );
  }
}
