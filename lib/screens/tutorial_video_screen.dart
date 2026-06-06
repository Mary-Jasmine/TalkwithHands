import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../ui/app_shell.dart';
import '../utils/video_url_utils.dart';

class TutorialVideoScreen extends StatefulWidget {
  final String title;
  final String videoAsset;
  final String videoUrl;

  const TutorialVideoScreen({
    super.key,
    required this.title,
    required this.videoAsset,
    this.videoUrl = '',
  });

  @override
  State<TutorialVideoScreen> createState() => _TutorialVideoScreenState();
}

class _TutorialVideoScreenState extends State<TutorialVideoScreen> {
  VideoPlayerController? _controller;
  String? _error;
  double _playbackSpeed = 1.0;
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _previousOffset = Offset.zero;
  bool _isFullscreen = false;

  static const List<double> _speeds = [0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final errors = <String>[];

    for (final source in _videoSources()) {
      VideoPlayerController? controller;
      try {
        controller = source.isNetwork
            ? VideoPlayerController.networkUrl(Uri.parse(source.value))
            : VideoPlayerController.asset(source.value);
        await controller.initialize();
        await controller.setLooping(false);
        await controller.setPlaybackSpeed(_playbackSpeed);

        if (!mounted) {
          await controller.dispose();
          return;
        }

        setState(() {
          _controller = controller;
          _error = null;
        });
        await controller.play();
        return;
      } catch (error, stackTrace) {
        errors.add('${source.label}: $error');
        debugPrint('Tutorial video failed from ${source.label}: $error');
        debugPrintStack(stackTrace: stackTrace);
        await controller?.dispose();
      }
    }

    if (mounted) {
      setState(() {
        _error = errors.isEmpty
            ? 'No tutorial video has been uploaded for this lesson yet.'
            : 'Cannot play this tutorial video.\nPlease restart the backend and try again.';
      });
    }
  }

  List<_VideoSource> _videoSources() {
    final sources = <_VideoSource>[];
    final videoUrl = normalizePlayableVideoUrl(widget.videoUrl);
    final videoAsset = widget.videoAsset.trim();
    final backendAssetUrl = backendVideoUrl(videoAsset);

    if (videoUrl.isNotEmpty) {
      sources.add(_VideoSource.network('saved video URL', videoUrl));
    }
    if (backendAssetUrl != null) {
      sources.add(_VideoSource.network('backend asset URL', backendAssetUrl));
    }
    if (isBundledVideoAsset(videoAsset)) {
      sources.add(_VideoSource.asset('bundled asset', videoAsset));
    }

    return sources;
  }

  void _setSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _controller?.setPlaybackSpeed(speed);
  }

  void _resetZoom() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  Future<void> _toggleFullscreen() async {
    if (_isFullscreen) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    setState(() => _isFullscreen = !_isFullscreen);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildZoomableVideo(VideoPlayerController? controller) {
    return GestureDetector(
      onScaleStart: (details) {
        _previousScale = _scale;
        _previousOffset = _offset;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_previousScale * details.scale).clamp(1.0, 4.0);
          if (_scale > 1.0) {
            _offset = _previousOffset + details.focalPointDelta;
          } else {
            _offset = Offset.zero;
          }
        });
      },
      onDoubleTap: _resetZoom,
      child: ClipRect(
        child: Transform(
          transform: Matrix4.identity()
            ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
            ..scaleByDouble(_scale, _scale, 1, 1),
          alignment: Alignment.center,
          child: _buildVideoBody(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: controller != null
                  ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: _buildZoomableVideo(controller),
                    )
                  : const SizedBox(),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  color: Colors.black54,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller != null)
                        VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: kAccent,
                            bufferedColor: Colors.white54,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      if (controller != null)
                        _VideoControls(
                          controller: controller,
                          playbackSpeed: _playbackSpeed,
                          speeds: _speeds,
                          onSpeedChanged: _setSpeed,
                          scale: _scale,
                          onResetZoom: _resetZoom,
                          isFullscreen: _isFullscreen,
                          onToggleFullscreen: _toggleFullscreen,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: _CloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: AppBackground(
        dimmed: true,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 620),
                    color: Colors.black,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 8),
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        AspectRatio(
                          aspectRatio: controller?.value.aspectRatio ?? 16 / 9,
                          child: _buildZoomableVideo(controller),
                        ),
                        if (controller != null)
                          VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: kAccent,
                              bufferedColor: Colors.white54,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        if (controller != null)
                          _VideoControls(
                            controller: controller,
                            playbackSpeed: _playbackSpeed,
                            speeds: _speeds,
                            onSpeedChanged: _setSpeed,
                            scale: _scale,
                            onResetZoom: _resetZoom,
                            isFullscreen: _isFullscreen,
                            onToggleFullscreen: _toggleFullscreen,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: _CloseButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBody(VideoPlayerController? controller) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: kAccent),
      );
    }

    return VideoPlayer(controller);
  }
}

class _VideoSource {
  final String label;
  final String value;
  final bool isNetwork;

  const _VideoSource._({
    required this.label,
    required this.value,
    required this.isNetwork,
  });

  factory _VideoSource.network(String label, String value) {
    return _VideoSource._(label: label, value: value, isNetwork: true);
  }

  factory _VideoSource.asset(String label, String value) {
    return _VideoSource._(label: label, value: value, isNetwork: false);
  }
}

class _VideoControls extends StatelessWidget {
  final VideoPlayerController controller;
  final double playbackSpeed;
  final List<double> speeds;
  final ValueChanged<double> onSpeedChanged;
  final double scale;
  final VoidCallback onResetZoom;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  const _VideoControls({
    required this.controller,
    required this.playbackSpeed,
    required this.speeds,
    required this.onSpeedChanged,
    required this.scale,
    required this.onResetZoom,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  Future<void> _showSpeedMenu(BuildContext context) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final button = context.findRenderObject() as RenderBox?;
    if (overlay == null || button == null) return;

    final offset = button.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      button.size.width,
      button.size.height,
    );
    final selected = await showMenu<double>(
      context: context,
      color: const Color(0xFF1E1E1E),
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: speeds.map((speed) {
        final isSelected = speed == playbackSpeed;
        return PopupMenuItem<double>(
          value: speed,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  speed == 1.0 ? 'Normal (1x)' : '${speed}x',
                  style: TextStyle(
                    color: isSelected ? kAccent : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected) const Icon(Icons.check, color: kAccent),
            ],
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      onSpeedChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final leftControls = <Widget>[
          IconButton(
            color: Colors.white,
            onPressed: () {
              value.isPlaying ? controller.pause() : controller.play();
            },
            icon: Icon(
              value.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
            ),
            tooltip: value.isPlaying ? 'Pause' : 'Play',
          ),
          IconButton(
            color: Colors.white,
            onPressed: () => controller.seekTo(Duration.zero),
            icon: const Icon(Icons.replay_rounded),
            tooltip: 'Replay',
          ),
        ];
        final rightControls = <Widget>[
          if (scale > 1.0)
            IconButton(
              color: kAccent,
              onPressed: onResetZoom,
              icon: const Icon(Icons.zoom_out_map_rounded),
              tooltip: 'Reset Zoom',
            ),
          GestureDetector(
            onTap: () => _showSpeedMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: kAccent, width: 1.4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                playbackSpeed == 1.0 ? '1x' : '${playbackSpeed}x',
                style: const TextStyle(
                  color: kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            color: Colors.white,
            onPressed: () => controller.setVolume(value.volume > 0 ? 0 : 1),
            icon: Icon(
              value.volume > 0
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
            tooltip: value.volume > 0 ? 'Mute' : 'Unmute',
          ),
          IconButton(
            color: Colors.white,
            onPressed: onToggleFullscreen,
            icon: Icon(
              isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
            tooltip: isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
          ),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final controls = [
                ...leftControls,
                const SizedBox(width: 12),
                ...rightControls,
              ];
              if (constraints.maxWidth < 380) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: controls,
                  ),
                );
              }

              return Row(
                children: [
                  ...leftControls,
                  const Spacer(),
                  ...rightControls,
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFF2F2F),
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.close_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
