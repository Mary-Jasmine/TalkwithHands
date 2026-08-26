import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';

import '../services/progress_service.dart';
import '../services/video_player_service.dart';
import '../ui/background_music_region.dart';
import '../ui/app_shell.dart';
import '../utils/url_helper.dart';
import '../utils/video_url_utils.dart';

enum _TutorialView { left, front, right }

class TutorialVideoScreen extends StatefulWidget {
  final String title;
  final String imageAsset;
  final String imageUrl;
  final String videoAsset;
  final String videoUrl;
  final String frontVideoUrl;
  final String leftVideoUrl;
  final String rightVideoUrl;
  final String? activityCategory;

  const TutorialVideoScreen({
    super.key,
    required this.title,
    this.imageAsset = '',
    this.imageUrl = '',
    required this.videoAsset,
    this.videoUrl = '',
    this.frontVideoUrl = '',
    this.leftVideoUrl = '',
    this.rightVideoUrl = '',
    this.activityCategory,
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
  bool _controlsVisible = false;
  bool _loadingVideo = true;
  bool _frontSlowQueued = false;
  Timer? _controlsTimer;
  late final DateTime _sessionStartedAt;
  _TutorialView _activeView = _TutorialView.front;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.5, 2.0];

  bool get _hasDefault =>
      normalizePlayableVideoUrl(widget.videoUrl).isNotEmpty ||
      widget.videoAsset.trim().isNotEmpty;
  bool get _hasFront =>
      normalizePlayableVideoUrl(widget.frontVideoUrl).isNotEmpty;
  bool get _hasLeft =>
      normalizePlayableVideoUrl(widget.leftVideoUrl).isNotEmpty;
  bool get _hasRight =>
      normalizePlayableVideoUrl(widget.rightVideoUrl).isNotEmpty;

  @override
  void initState() {
    super.initState();
    _sessionStartedAt = DateTime.now();
    _playFrontSequence();
  }

  Future<void> _playFrontSequence() async {
    setState(() {
      _activeView = _TutorialView.front;
      _frontSlowQueued = _hasFront;
    });

    if (_hasDefault) {
      await _loadVideo(
        videoUrl: widget.videoUrl,
        videoAsset: widget.videoAsset,
        playbackSpeed: 1.0,
        autoPlayFrontSlow: _hasFront,
      );
      return;
    }

    await _loadVideo(
      videoUrl: widget.frontVideoUrl,
      videoAsset: '',
      playbackSpeed: 0.75,
    );
  }

  Future<void> _playView(_TutorialView view) async {
    if (view == _TutorialView.front) {
      await _playFrontSequence();
      return;
    }

    final url =
        view == _TutorialView.left ? widget.leftVideoUrl : widget.rightVideoUrl;
    if (url.trim().isEmpty) return;

    setState(() {
      _activeView = view;
      _frontSlowQueued = false;
    });
    await _loadVideo(videoUrl: url, videoAsset: '', playbackSpeed: 1.0);
  }

  Future<void> _loadVideo({
    required String videoUrl,
    required String videoAsset,
    required double playbackSpeed,
    bool autoPlayFrontSlow = false,
  }) async {
    final oldController = _controller;
    oldController?.removeListener(_handlePlaybackUpdate);
    setState(() {
      _controller = null;
      _error = null;
      _loadingVideo = true;
      _playbackSpeed = playbackSpeed;
      _scale = 1.0;
      _offset = Offset.zero;
    });
    await oldController?.dispose();

    try {
      final controller = await VideoPlayerService.createController(
        sources: VideoPlayerService.buildSources(
          videoUrl: videoUrl,
          videoAsset: videoAsset,
        ),
        playbackSpeed: playbackSpeed,
      );

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setVolume(0);
      controller.addListener(_handlePlaybackUpdate);
      setState(() {
        _controller = controller;
        _loadingVideo = false;
        _frontSlowQueued = autoPlayFrontSlow;
      });
    } on VideoLoadException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingVideo = false;
        _error = error.errors.isEmpty
            ? 'No tutorial video has been uploaded for this lesson yet.'
            : 'Cannot play this tutorial video.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingVideo = false;
        _error = 'Cannot play this tutorial video.';
      });
    }
  }

  void _handlePlaybackUpdate() {
    final controller = _controller;
    if (controller == null || !_frontSlowQueued || !_hasFront) return;

    final value = controller.value;
    final duration = value.duration;
    if (!value.isInitialized || duration == Duration.zero) return;
    if (value.position < duration - const Duration(milliseconds: 250)) return;

    _frontSlowQueued = false;
    unawaited(_loadVideo(
      videoUrl: widget.frontVideoUrl,
      videoAsset: '',
      playbackSpeed: 0.75,
    ));
  }

  void _setSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      _frontSlowQueued = false;
    });
    _controller?.setPlaybackSpeed(speed);
    _showControlsTemporarily();
  }

  void _resetZoom() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();
    setState(() => _controlsVisible = true);
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
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

  Future<void> _recordSessionTime() async {
    final category = widget.activityCategory;
    if (category == null || category.isEmpty) return;

    final seconds = DateTime.now().difference(_sessionStartedAt).inSeconds;
    if (seconds < 3) return;

    try {
      await ProgressService().recordActivity(
        category: category,
        secondsSpent: seconds,
      );
    } catch (_) {
      // Progress sync should never block leaving the lesson.
    }
  }

  @override
  void dispose() {
    unawaited(_recordSessionTime());
    _controlsTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.removeListener(_handlePlaybackUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: BackgroundMusicRegion(
          track: null,
          showToggle: false,
          child: _buildVideoPanel(fullscreen: true),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: BackgroundMusicRegion(
        track: null,
        showToggle: false,
        child: AppBackground(
          dimmed: true,
          child: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 720;
                    final videoWidth =
                        (constraints.maxWidth - 16)
                            .clamp(280.0, 760.0)
                            .toDouble();
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        8,
                        compact ? 24 : 34,
                        8,
                        18,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight -
                              MediaQuery.paddingOf(context).vertical -
                              80,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            if (_hasSignImage) ...[
                              _buildSignImage(compact: compact),
                              SizedBox(height: compact ? 8 : 12),
                            ],
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 30 : 36,
                                fontWeight: FontWeight.w900,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x99000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? 14 : 18),
                            Center(
                              child: SizedBox(
                                width: videoWidth,
                                child: AspectRatio(
                                  aspectRatio:
                                      _controller?.value.aspectRatio ?? 16 / 9,
                                  child: _buildVideoPanel(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 34),
                            _buildViewButtons(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                child: SafeArea(
                  child: _HighlightedBackButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasSignImage =>
      widget.imageUrl.trim().isNotEmpty || widget.imageAsset.trim().isNotEmpty;

  Widget _buildSignImage({required bool compact}) {
    final size = compact ? 104.0 : 128.0;
    final image = _signImage();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050505), Color(0xFF323232), Color(0xFF000000)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: image,
        ),
      ),
    );
  }

  Widget _signImage() {
    final imageUrl = widget.imageUrl.trim();
    final imageAsset = widget.imageAsset.trim();
    if (imageUrl.toLowerCase().endsWith('.svg')) {
      return SvgPicture.network(
        imageUrl,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox.shrink(),
      );
    }
    if (imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: getOptimizedUrl(imageUrl, width: 480),
        fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    if (imageAsset.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        imageAsset,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox.shrink(),
      );
    }
    if (imageAsset.isNotEmpty) {
      return Image.asset(
        imageAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildVideoPanel({bool fullscreen = false}) {
    final controller = _controller;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showControlsTemporarily,
      onDoubleTap: _resetZoom,
      onScaleStart: (details) {
        _previousScale = _scale;
        _previousOffset = _offset;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_previousScale * details.scale).clamp(1.0, 4.0).toDouble();
          _offset = _scale > 1.0
              ? _previousOffset + details.focalPointDelta
              : Offset.zero;
        });
      },
      child: ClipRect(
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(_offset.dx, _offset.dy)
                    ..scale(_scale),
                  alignment: Alignment.center,
                  child: _buildVideoBody(controller),
                ),
              ),
              if (controller != null && (_controlsVisible || fullscreen))
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildControlsOverlay(controller),
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
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    if (_loadingVideo || controller == null) {
      return const Center(child: CircularProgressIndicator(color: kAccent));
    }

    return VideoPlayer(controller);
  }

  Widget _buildControlsOverlay(VideoPlayerController controller) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xCC000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: kAccent,
              bufferedColor: Colors.white54,
              backgroundColor: Colors.white24,
            ),
          ),
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
    );
  }

  Widget _buildViewButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _ViewButton(
                  label: 'Left view',
                  iconAsset: 'assets/images/Left.png',
                  selected: _activeView == _TutorialView.left,
                  enabled: _hasLeft,
                  onTap: () => _playView(_TutorialView.left),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _ViewButton(
                  label: 'Front view',
                  iconAsset: 'assets/images/Front.png',
                  selected: _activeView == _TutorialView.front,
                  enabled: _hasDefault || _hasFront,
                  onTap: () => _playView(_TutorialView.front),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _ViewButton(
                  label: 'Right view',
                  iconAsset: 'assets/images/Right.png',
                  selected: _activeView == _TutorialView.right,
                  enabled: _hasRight,
                  onTap: () => _playView(_TutorialView.right),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ViewButton extends StatelessWidget {
  final String label;
  final String iconAsset;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ViewButton({
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = !enabled
        ? const Color(0xFF202020)
        : selected
            ? const Color(0xFF0D6FDB)
            : Colors.black;
    return Opacity(
      opacity: enabled ? 1 : 0.28,
      child: Material(
        color: activeColor,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color:
                    enabled ? const Color(0xFF0D6FDB) : const Color(0xFF555555),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  color: Colors.transparent,
                  child: Image.asset(
                    iconAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.accessibility_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
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

    if (selected != null) onSpeedChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final controls = [
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
            onPressed: () {
              controller
                ..seekTo(Duration.zero)
                ..play();
            },
            icon: const Icon(Icons.replay_rounded),
            tooltip: 'Replay',
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(mainAxisSize: MainAxisSize.min, children: controls),
          ),
        );
      },
    );
  }
}

class _HighlightedBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HighlightedBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2ED7E6),
      elevation: 8,
      shadowColor: const Color(0x66000000),
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
      ),
    );
  }
}
