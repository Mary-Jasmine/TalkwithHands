import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:video_player/video_player.dart';

import '../services/background_music_service.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  static Future<ui.FragmentProgram>? _sharedShaderProgram;
  late final AnimationController _frameTicker;
  Timer? _playbackWatchdog;
  VideoPlayerController? _controller;
  ui.FragmentShader? _shader;
  bool _isReady = false;
  bool _playRequestInFlight = false;
  bool _disposed = false;
  bool _routeVisible = true;
  bool _appActive = true;
  int _loadGeneration = 0;
  PageRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _frameTicker = AnimationController(
      vsync: this,
      // Keep the chroma sampler close to video frame rate instead of 60 fps.
      // This reduces queued GPU and decoder buffers on memory-limited phones.
      duration: const Duration(milliseconds: 66),
    )..repeat();
    _playbackWatchdog = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _ensurePlaying(),
    );
    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _routeVisible = false;
    _pausePlayback();
  }

  @override
  void didPopNext() {
    if (mounted && !_disposed) {
      _routeVisible = true;
      _frameTicker.repeat();
      _ensurePlaying();
    }
  }

  void _pausePlayback() {
    _frameTicker.stop();
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.pause());
    }
  }

  Future<void> _loadAll() async {
    final generation = ++_loadGeneration;
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.asset(
        widget.videoAsset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.volume.clamp(0, 1));
      if (_routeVisible && _appActive) {
        await controller.play();
      }
      controller.addListener(_handleControllerChange);

      ui.FragmentShader? shader;
      try {
        final program = await (_sharedShaderProgram ??=
            ui.FragmentProgram.fromAsset('shaders/chroma_key.frag'));
        shader = program.fragmentShader();
      } catch (shaderError, shaderStackTrace) {
        debugPrint('Chroma key disabled for ${widget.videoAsset}: $shaderError');
        debugPrintStack(stackTrace: shaderStackTrace);
      }

      if (!mounted || _disposed || generation != _loadGeneration) {
        controller.dispose();
        return;
      }
      final oldController = _controller;
      oldController?.removeListener(_handleControllerChange);
      setState(() {
        _controller = controller;
        _shader = shader;
        _isReady = true;
      });
      await oldController?.dispose();
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePlaying());
    } catch (error, stackTrace) {
      debugPrint('Failed to load ${widget.videoAsset}: $error');
      debugPrintStack(stackTrace: stackTrace);
      await controller?.dispose();
      if (mounted && generation == _loadGeneration) {
        setState(() => _isReady = false);
      }
    }
  }

  void _handleControllerChange() {
    final controller = _controller;
    if (_disposed ||
        !mounted ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final duration = controller.value.duration;
    final position = controller.value.position;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 200)) {
      unawaited(controller.seekTo(Duration.zero));
      if (_routeVisible && _appActive && !controller.value.isPlaying) {
        unawaited(controller.play());
      }
      return;
    }

    if (!controller.value.isPlaying) {
      unawaited(_ensurePlaying());
    }
  }

  Future<void> _ensurePlaying() async {
    final controller = _controller;
    if (!mounted ||
        _disposed ||
        !_routeVisible ||
        !_appActive ||
        _playRequestInFlight ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    _playRequestInFlight = true;
    try {
      final duration = controller.value.duration;
      final position = controller.value.position;
      if (duration > Duration.zero &&
          position >= duration - const Duration(milliseconds: 200)) {
        await controller.seekTo(Duration.zero);
      }

      if (!controller.value.isPlaying) {
        await controller.play();
      }
    } catch (error) {
      debugPrint(
        'Video playback recovery failed for ${widget.videoAsset}: $error',
      );
    } finally {
      if (!_disposed) {
        _playRequestInFlight = false;
      }
    }
  }

  @override
  void didUpdateWidget(covariant TransparentSignVideoOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoAsset != widget.videoAsset) {
      setState(() => _isReady = false);
      _loadAll();
      return;
    }

    if (oldWidget.volume != widget.volume) {
      _controller?.setVolume(widget.volume.clamp(0, 1));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appActive = true;
      _frameTicker.repeat();
      _ensurePlaying();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appActive = false;
      _pausePlayback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final shader = _shader;

    if (!_isReady || controller == null || !controller.value.isInitialized) {
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
                  child: shader == null
                      ? VideoPlayer(controller)
                      : AnimatedBuilder(
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
    _disposed = true;
    _loadGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    _playbackWatchdog?.cancel();
    _frameTicker.dispose();
    _controller?.removeListener(_handleControllerChange);
    _controller?.dispose();
    super.dispose();
  }
}
