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
  Worker? _worker;
  bool _visible = false;
  Offset _position = const Offset(16, 100);
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _bindPlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initPosition();
      _bindPlayer();
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
    _worker?.dispose();
    _worker = null;
    final player = PlPlayerController.instance;
    if (player == null) {
      _visible = false;
      return;
    }
    _visible = player.isMiniPlayer.value;
    _worker = ever<bool>(player.isMiniPlayer, (val) {
      if (mounted) {
        setState(() => _visible = val);
      }
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
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
