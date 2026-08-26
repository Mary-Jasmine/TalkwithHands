import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:video_player/video_player.dart';

class TransparentSignVideoOverlay extends StatefulWidget {
  final String videoAsset;
  final BoxFit fit;
  final double scale;
  final double volume;
  final double threshold;
  final double smoothing;
  final double edgeCrop;
  final double verticalCrop;

  const TransparentSignVideoOverlay({
    super.key,
    this.videoAsset = 'assets/Kumusta.mp4',
    this.fit = BoxFit.contain,
    this.scale = 1,
    this.volume = 1,
    this.threshold = 0.35,
    this.smoothing = 0.15,
    this.edgeCrop = 0.045,
    this.verticalCrop = 0,
  });

  @override
  State<TransparentSignVideoOverlay> createState() =>
      _TransparentSignVideoOverlayState();
}

class _TransparentSignVideoOverlayState
    extends State<TransparentSignVideoOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _frameTicker;
  VideoPlayerController? _controller;
  ui.FragmentShader? _shader;
  bool _isReady = false;
  bool _playRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _frameTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(_ensurePlaying)
      ..repeat();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final programFuture =
          ui.FragmentProgram.fromAsset('shaders/chroma_key.frag');
      final controller = VideoPlayerController.asset(
        widget.videoAsset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      final results = await Future.wait([
        programFuture,
        controller.initialize().then((_) => null),
      ]);
      final shader = (results.first as ui.FragmentProgram).fragmentShader();

      await controller.setLooping(true);
      await controller.setVolume(widget.volume.clamp(0, 1));
      await controller.play();

      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _shader = shader;
        _isReady = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePlaying());
    } catch (error, stackTrace) {
      debugPrint('Failed to load ${widget.videoAsset}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _isReady = false);
    }
  }

  Future<void> _ensurePlaying() async {
    final controller = _controller;
    if (!mounted ||
        _playRequestInFlight ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    if (!controller.value.isPlaying) {
      _playRequestInFlight = true;
      try {
        await controller.play();
      } finally {
        _playRequestInFlight = false;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensurePlaying();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final shader = _shader;

    if (!_isReady ||
        controller == null ||
        shader == null ||
        !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: SizedBox.expand(
        child: Transform.scale(
          scale: widget.scale,
          alignment: Alignment.bottomCenter,
          child: FittedBox(
            fit: widget.fit,
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: ClipRect(
                child: Transform.scale(
                  scaleX: 1 + widget.edgeCrop.clamp(0, 0.2),
                  scaleY: 1 + widget.verticalCrop.clamp(0, 0.4),
                  child: AnimatedBuilder(
                    animation: _frameTicker,
                    child: VideoPlayer(controller),
                    builder: (context, child) {
                      return AnimatedSampler(
                        (image, size, canvas) {
                          shader
                            ..setFloat(0, size.width)
                            ..setFloat(1, size.height)
                            ..setFloat(2, widget.threshold)
                            ..setFloat(3, widget.smoothing)
                            ..setImageSampler(0, image);

                          canvas.drawRect(
                            Rect.fromLTWH(0, 0, size.width, size.height),
                            Paint()..shader = shader,
                          );
                        },
                        child: child ?? const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frameTicker.dispose();
    _controller?.dispose();
    super.dispose();
  }
}
