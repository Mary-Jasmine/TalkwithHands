import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:video_player/video_player.dart';

import '../data/panorama_hotspot_data.dart';
import '../models/panorama_scene.dart';
import '../services/api_config.dart';
import '../services/panorama_service.dart';
import '../services/video_player_service.dart';
import 'tutorial_video_screen.dart';
import '../ui/app_shell.dart';
import '../utils/url_helper.dart';
import '../widgets/transparent_sign_video_overlay.dart';

class PanoramaScreen extends StatefulWidget {
  final String userName;
  final String? initialSceneId;

  const PanoramaScreen({
    super.key,
    required this.userName,
    this.initialSceneId,
  });

  @override
  State<PanoramaScreen> createState() => _PanoramaScreenState();
}

class _PanoramaScreenState extends State<PanoramaScreen> {
  // ── Cross-instance cache ─────────────────────────────────────────────
  // Navigator.push creates a BRAND NEW PanoramaScreen (and thus a brand
  // new State) every time the user opens "180 Pictures" from the menu,
  // even if they were just here before. This `static` field lives on the
  // class, not the State instance, so it survives that recreation: the
  // scene list is only fetched ONCE per app session. Every visit after
  // the first reuses it instantly instead of reloading.
  static List<PanoramaScene>? _cachedScenes;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PanoramaController _panoramaController;
  late Future<List<PanoramaScene>> _sceneFuture;
  List<PanoramaScene> _scenes = [];
  int _selectedIndex = 0;
  bool _viewerMode = false;

  String get _baseUrl {
    final baseUrl = ApiConfig.baseUrl;
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  @override
  void initState() {
    super.initState();
    _panoramaController = PanoramaController();

    if (_cachedScenes != null) {
      // Already fetched during an earlier visit this session — resolve
      // instantly (no spinner).
      // Re-apply the bundled hotspot catalog as cached scene data can predate
      // the latest local hotspot positions.
      _sceneFuture = _mergeLocalHotspots(_cachedScenes!);
    } else {
      _sceneFuture = _fetchScenes();
    }
    _viewerMode = widget.initialSceneId != null;
  }

  void _selectInitialScene() {
    final sceneId = widget.initialSceneId;
    if (sceneId == null) return;
    final index = _scenes.indexWhere((scene) => scene.id == sceneId);
    if (index >= 0) _selectedIndex = index;
  }

  // Wrapped so that ANY failure here — including a synchronous one thrown
  // by PanoramaService()'s constructor itself (e.g. missing base URL) —
  // becomes a normal Future error the FutureBuilder below can show as a
  // "Retry" screen, instead of an uncaught exception escaping initState
  // and taking the whole app down with it.
  Future<List<PanoramaScene>> _fetchScenes() async {
    try {
      final scenesFuture = PanoramaService().listPanoramaScenes();
      final scenes = await scenesFuture;
      return _mergeLocalHotspots(scenes);
    } catch (e) {
      throw Exception('Failed to load 180 pictures: $e');
    }
  }

  Future<List<PanoramaScene>> _mergeLocalHotspots(
    List<PanoramaScene> scenes,
  ) async {
    final hotspotData = await loadPanoramaHotspotData();
    final normalizedScenes = scenes.map((scene) {
      if (scene.id != 'testing') return scene;
      return PanoramaScene(
        id: 'campus',
        key: 'campus',
        title: 'Campus',
        imageAsset: 'assets/360/Campus.jpg',
        imageUrl: scene.imageUrl,
        icon: scene.icon,
        sortOrder: scene.sortOrder,
        hotspots: scene.hotspots,
      );
    }).toList(growable: false);
    final mergedScenes = applyPanoramaHotspotData(
      normalizedScenes,
      hotspotData,
    );
    _cachedScenes = mergedScenes;
    return mergedScenes;
  }

  String _assetUrl(String assetPath) {
    final cleanPath = assetPath.split('/').map(Uri.encodeComponent).join('/');
    return '$_baseUrl/$cleanPath';
  }

  String _sceneImageAsset(PanoramaScene scene) {
    switch (scene.id) {
      case 'classroom':
        return 'assets/360/Classroom_v2_taller.jpg';
      case 'school':
        return 'assets/360/School_blur_fill.jpg';
      default:
        return scene.imageAsset;
    }
  }

  bool _usesBundledPanorama(PanoramaScene scene) =>
      _sceneImageAsset(scene).startsWith('assets/360/');

  String _imageUrl(PanoramaScene scene) {
    if (_usesBundledPanorama(scene)) return _assetUrl(_sceneImageAsset(scene));
    if (scene.imageUrl.trim().isNotEmpty) {
      return getOptimizedUrl(scene.imageUrl, width: 1600);
    }
    return _assetUrl(scene.imageAsset);
  }

  // Equirectangular photos meant for 360°/180° viewing are often huge
  // (6000x3000+). Feeding that straight into a native GL texture (which is
  // what PanoramaViewer does via flutter_cube) can exceed the max texture
  // size on lower-end GPUs and crash the WHOLE app natively — not a
  // catchable Dart exception, just an instant exit. Capping the decoded
  // width here keeps every device safe while still looking sharp.
  static const int _maxPanoramaTextureWidth = 2048;

  ImageProvider _panoramaTextureProvider(PanoramaScene scene) {
    if (_usesBundledPanorama(scene)) {
      return ResizeImage(
        AssetImage(_sceneImageAsset(scene)),
        width: _maxPanoramaTextureWidth,
      );
    }
    return ResizeImage(
      CachedNetworkImageProvider(_imageUrl(scene)),
      width: _maxPanoramaTextureWidth,
    );
  }

  void _openPanorama(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PanoramaScreen(
          userName: widget.userName,
          initialSceneId: _scenes[index].id,
        ),
      ),
    );
  }

  // BENCH.jpg hotspot positions come from backend/data/panorama-scenes.json.
  // Keeping this as a direct pass-through avoids stale hard-coded overrides
  // pulling the marker back to the blue bench table.
  double _hotspotPitch(PanoramaScene scene, int i) => scene.hotspots[i].pitch;

  double _hotspotYaw(PanoramaScene scene, int i) => scene.hotspots[i].yaw;

  // ── Navigate panorama camera to a hotspot (no auto-play — user taps hotspot) ──
  void _navigateToHotspot(PanoramaHotspot hotspot) {
    final scene = _scenes[_selectedIndex];
    final i = scene.hotspots.indexOf(hotspot);
    if (i < 0) {
      _panoramaController.setView(hotspot.pitch, hotspot.yaw);
      return;
    }
    _panoramaController.setView(_hotspotPitch(scene, i), _hotspotYaw(scene, i));
  }

  void _showHotspotVideo(PanoramaHotspot hotspot) {
    if (hotspot.videoAsset.trim().isEmpty && hotspot.videoUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No video is set for ${hotspot.label} yet.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TutorialVideoScreen(
          title: hotspot.label,
          videoAsset: hotspot.videoAsset,
          videoUrl: hotspot.videoUrl,
        ),
      ),
    );
  }

  IconData _sceneIcon(PanoramaScene scene) {
    switch (scene.icon) {
      case 'bench':
        return Icons.chair_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'classroom':
        return Icons.meeting_room_outlined;
      case 'crossing':
        return Icons.directions_walk_rounded;
      case 'cafe':
        return Icons.local_cafe_rounded;
      case 'route':
        return Icons.route_rounded;
      default:
        return Icons.threesixty_rounded;
    }
  }

  void _reload() {
    setState(() {
      _selectedIndex = 0;
      _viewerMode = false;
      _scenes = [];
      // Retry/reload means the user explicitly wants fresh data — clear the
      // cache so this next fetch actually happens again.
      _cachedScenes = null;
      _sceneFuture = _fetchScenes();
    });
  }

  @override
  void dispose() {
    _panoramaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: '180 Pictures',
      ),
      body: ClassroomPageBackground(
        bannerAsset: 'assets/images/180.png',
        boardTopFraction: _viewerMode ? 0.16 : 0.28,
        landscapeBoardTopFraction: _viewerMode ? 0.12 : 0.25,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  AppTopBar(
                    onBack: _viewerMode
                        ? () => Navigator.of(context).maybePop()
                        : null,
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    menuOnLeft: !_viewerMode,
                  ),
                  if (!_viewerMode) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height < 500 ? 72 : 120,
                      width: double.infinity,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: -(115.0 * 0.10),
                            bottom: -12,
                            child: ClassroomBookshelf(
                              width: MediaQuery.sizeOf(context).height < 500
                                  ? 92
                                  : 115,
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, 10),
                            child: SizedBox(
                              width: 240,
                              child: const TransparentSignVideoOverlay(
                                videoAsset: 'assets/180.mp4',
                                fit: BoxFit.contain,
                                scale: 1,
                                volume: 0,
                                threshold: 0.34,
                                smoothing: 0.08,
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 20,
                            child: Icon(Icons.star_rounded,
                                color: Color(0xFFFFB800), size: 23),
                          ),
                          const Positioned(
                            right: 20,
                            child: Icon(Icons.auto_awesome_rounded,
                                color: Color(0xFF11B7CB), size: 21),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: MediaQuery.sizeOf(context).height * 0.055),
                  ] else
                    const SizedBox(height: 4),
                  Expanded(
                    child: FutureBuilder<List<PanoramaScene>>(
                      future: _sceneFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          );
                        }

                        if (snapshot.hasError) {
                          return _ErrorState(
                            message:
                                'Cannot load 180 pictures. Make sure the backend is running.',
                            onRetry: _reload,
                          );
                        }

                        final scenes = snapshot.data ?? const [];
                        if (scenes.isEmpty) {
                          return _ErrorState(
                            message: 'No 180 pictures found.',
                            onRetry: _reload,
                          );
                        }

                        if (_scenes.isEmpty) {
                          _scenes = scenes;
                          _cachedScenes = scenes;
                        }
                        if (widget.initialSceneId != null &&
                            _selectedIndex == 0) {
                          _selectInitialScene();
                        }

                        if (!_viewerMode) {
                          return _buildCategoryGrid();
                        }

                        return _buildViewer();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category landing grid ───────────────────────────────────────────────
  Widget _buildCategoryGrid() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width * 0.10,
        0,
        MediaQuery.sizeOf(context).width * 0.10,
        MediaQuery.sizeOf(context).height * 0.045,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 4, 51, 98).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color.fromARGB(255, 156, 156, 156)
                .withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 186, 182, 182)
                  .withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.92,
          ),
          itemCount: _scenes.length,
          itemBuilder: (context, index) {
            final scene = _scenes[index];
            return _PanoramaCategoryCard(
              title: scene.title,
              imageUrl: _imageUrl(scene),
              imageAsset: _usesBundledPanorama(scene)
                  ? _sceneImageAsset(scene)
                  : null,
              icon: _sceneIcon(scene),
              highlighted: index == 0,
              onView: () => _openPanorama(index),
            );
          },
        ),
      ),
    );
  }

  // ── Words / hotspot list below the 180 viewer ───────────────────────────
  Widget _buildWordsList(List<PanoramaHotspot> hotspots) {
    if (hotspots.isEmpty) return const SizedBox.shrink();

    // Deduplicate by label, sorted alphabetically
    final seen = <String>{};
    final unique = hotspots
        .where((h) => seen.add(h.label.toLowerCase()))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Words',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1500C8),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 4.5,
              mainAxisSpacing: 2,
              crossAxisSpacing: 4,
            ),
            itemCount: unique.length,
            itemBuilder: (context, i) {
              final hotspot = unique[i];
              final original = hotspots.firstWhere(
                (h) => h.label.toLowerCase() == hotspot.label.toLowerCase(),
              );
              return InkWell(
                onTap: () => _navigateToHotspot(original),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 16,
                        color: Color(0xFF0E7C8C),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hotspot.label,
                          style: const TextStyle(
                            color: Color(0xFF0E3D44),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 180 viewer with hotspots + thumbnail strip ─────────────────────────
  Widget _buildViewer() {
    final scene = _scenes[_selectedIndex];
    final currentHotspots = scene.hotspots;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PanoramaViewer(
                        key: ValueKey('panorama-${scene.id}'),
                        latitude: _panoramaController.getLatitude(),
                        longitude: _panoramaController.getLongitude(),
                        zoom: _panoramaController.getZoom(),
                        animSpeed: 0.0,
                        sensorControl: SensorControl.none,
                        panoramaController: _panoramaController,
                        hotspots: [
                          for (var i = 0; i < currentHotspots.length; i++)
                            Hotspot(
                              name: currentHotspots[i].id,
                              latitude: _hotspotPitch(scene, i),
                              longitude: _hotspotYaw(scene, i),
                              width: (130 * currentHotspots[i].size)
                                  .clamp(120.0, 170.0)
                                  .toDouble(),
                              height: (110 * currentHotspots[i].size)
                                  .clamp(104.0, 132.0)
                                  .toDouble(),
                              widget: _HotspotMarker(
                                label: currentHotspots[i].label,
                                onTap: () => _showHotspotVideo(currentHotspots[i]),
                              ),
                            ),
                        ],
                        child: Image(
                          image: _panoramaTextureProvider(scene),
                        ),
                      ),
                    _DragHint(key: ValueKey('hint-${scene.id}')),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildWordsList(currentHotspots),
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.04),
      ],
    );
  }
}

// ── Round play-button hotspot marker placed on the sphere ──────────────────
class _HotspotMarker extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _HotspotMarker({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 160,
        height: 112,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 5,
                    spreadRadius: 0.5,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 4,
              right: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── "Drag to look around" hint that fades out, same as the old JS one ──────
class _DragHint extends StatefulWidget {
  const _DragHint({super.key});

  @override
  State<_DragHint> createState() => _DragHintState();
}

class _DragHintState extends State<_DragHint> {
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 900),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Drag to look around',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanoramaVideoDialog extends StatefulWidget {
  final String title;
  final String videoAsset;
  final String videoUrl;

  const _PanoramaVideoDialog({
    required this.title,
    required this.videoAsset,
    required this.videoUrl,
  });

  @override
  State<_PanoramaVideoDialog> createState() => _PanoramaVideoDialogState();
}

class _PanoramaVideoDialogState extends State<_PanoramaVideoDialog> {
  VideoPlayerController? _controller;
  String? _error;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;

  static const List<double> _speeds = [0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = await VideoPlayerService.createController(
        sources: VideoPlayerService.buildSources(
          videoUrl: widget.videoUrl,
          videoAsset: widget.videoAsset,
        ),
        playbackSpeed: _playbackSpeed,
      );

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _error = null;
      });
    } on VideoLoadException catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot play this video. Please rebuild the app and try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot play this hotspot video.';
      });
    }
  }

  void _setSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _controller?.setPlaybackSpeed(speed);
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: _isFullscreen
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Container(
        width: _isFullscreen ? double.infinity : 620,
        height: _isFullscreen ? double.infinity : null,
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize:
                      _isFullscreen ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isFullscreen)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 56, 8),
                        child: Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    AspectRatio(
                      aspectRatio: controller?.value.aspectRatio ?? 16 / 9,
                      child: _buildVideoBody(controller),
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
                      _PopupVideoControls(
                        controller: controller,
                        playbackSpeed: _playbackSpeed,
                        speeds: _speeds,
                        onSpeedChanged: _setSpeed,
                        isFullscreen: _isFullscreen,
                        onToggleFullscreen: _toggleFullscreen,
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: const Color(0xFFFF2F2F),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
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
        child: Padding(
          padding: const EdgeInsets.all(20),
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

    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: kAccent),
      );
    }

    return VideoPlayer(controller);
  }
}

class _PopupVideoControls extends StatelessWidget {
  final VideoPlayerController controller;
  final double playbackSpeed;
  final List<double> speeds;
  final ValueChanged<double> onSpeedChanged;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  const _PopupVideoControls({
    required this.controller,
    required this.playbackSpeed,
    required this.speeds,
    required this.onSpeedChanged,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  Future<void> _showSpeedMenu(BuildContext context) async {
    final selected = await showMenu<double>(
      context: context,
      color: const Color(0xFF1E1E1E),
      position: const RelativeRect.fromLTRB(80, 80, 20, 20),
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
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
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
                GestureDetector(
                  onTap: () => _showSpeedMenu(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  onPressed: () =>
                      controller.setVolume(value.volume > 0 ? 0 : 1),
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF050505),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: kAccent,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onRetry,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category card (Image + title bar + View button) ────────────────────────
class _PanoramaCategoryCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String? imageAsset;
  final bool highlighted;
  final VoidCallback onView;
  final IconData icon;

  const _PanoramaCategoryCard({
    required this.title,
    required this.imageUrl,
    this.imageAsset,
    required this.onView,
    required this.icon,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onView,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFBFD7FF),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30185FA5),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: Color(0x15000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Backing color shows briefly while the crop loads.
                  Container(color: const Color(0xFFEFF6FF)),
                  // Fills the whole card — a portion of the photo gets
                  // cropped off (top/bottom or sides) instead of
                  // letterboxing, so the card never shows empty bars.
                  Positioned.fill(
                    child: imageAsset != null
                        ? Image.asset(
                            imageAsset!,
                            fit: BoxFit.cover,
                            cacheWidth: 480,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFEFF6FF),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.threesixty_rounded,
                                color: Color(0xFF185FA5),
                                size: 36,
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            memCacheWidth: 480,
                            fadeInDuration: const Duration(milliseconds: 150),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFEFF6FF),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.threesixty_rounded,
                                color: const Color(0xFF185FA5).withValues(alpha: 0.8),
                                size: 36,
                              ),
                            ),
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFEFF6FF),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Color(0xFF185FA5),
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Category icon badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF185FA5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40185FA5),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 10),
              color: const Color.fromARGB(255, 0, 60, 191),
              child: Column(
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  GestureDetector(
                    onTap: onView,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF218E3D),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 7,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_rounded,
                              color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'View',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
// ── Decorative floating bubbles for the background ──────────────────────────
// Purely visual, non-interactive layer — sits behind all existing screen
// content and does not change any other part of the design.
const List<Color> _bubbleColors = [
  Color(0xFF1500C8),
  kAccent,
  Color(0xFF34C759),
  Color(0xFF0B8FFF),
  Color(0xFF9C27B0),
];

class _BubbleSpec {
  final double dx; // horizontal anchor, 0..1 fraction of width
  final double size;
  final double speed; // relative rise speed
  final double phase; // 0..1 start offset so bubbles don't move in sync
  final double wobble; // horizontal sway amount in logical pixels
  final Color color;
  final bool outline; // some bubbles are soft rings instead of filled dots

  const _BubbleSpec({
    required this.dx,
    required this.size,
    required this.speed,
    required this.phase,
    required this.wobble,
    required this.color,
    required this.outline,
  });
}

class _FloatingBubbles extends StatefulWidget {
  const _FloatingBubbles();

  @override
  State<_FloatingBubbles> createState() => _FloatingBubblesState();
}

class _FloatingBubblesState extends State<_FloatingBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_BubbleSpec> _bubbles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();

    // Fixed seed so the layout is stable across rebuilds/hot reloads
    // instead of jumping to a new random arrangement every time.
    final rnd = math.Random(7);
    _bubbles = List.generate(16, (i) {
      final color = _bubbleColors[rnd.nextInt(_bubbleColors.length)];
      return _BubbleSpec(
        dx: rnd.nextDouble(),
        size: 14 + rnd.nextDouble() * 46,
        speed: 0.45 + rnd.nextDouble() * 0.85,
        phase: rnd.nextDouble(),
        wobble: 8 + rnd.nextDouble() * 18,
        color: color,
        outline: rnd.nextDouble() < 0.4,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = constraints.biggest;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: canvasSize,
              painter: _BubblesPainter(
                bubbles: _bubbles,
                progress: _controller.value,
              ),
            );
          },
        );
      },
    );
  }
}

class _BubblesPainter extends CustomPainter {
  final List<_BubbleSpec> bubbles;
  final double progress;

  _BubblesPainter({required this.bubbles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    for (final b in bubbles) {
      // t travels 0 -> 1 -> 0 (loops) at each bubble's own speed/offset.
      final t = (progress * b.speed + b.phase) % 1.0;
      final y = size.height * (1 - t);
      final wobbleX = math.sin((t * 2 * math.pi) + b.phase * 10) * b.wobble;
      final x = size.width * b.dx + wobbleX;
      final radius = b.size / 2;

      // Fades in near the bottom, fades out near the top so bubbles never
      // pop in/out abruptly.
      final envelope = math.sin(math.pi * t).clamp(0.0, 1.0);
      final opacity = 0.08 + 0.16 * envelope;

      if (b.outline) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = b.color.withValues(alpha: opacity * 1.6);
        canvas.drawCircle(Offset(x, y), radius, ring);
      } else {
        final fill = Paint()
          ..style = PaintingStyle.fill
          ..color = b.color.withValues(alpha: opacity);
        canvas.drawCircle(Offset(x, y), radius, fill);
      }

      // Tiny glossy highlight so bubbles read as bubbles, not flat dots.
      final highlight = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: opacity * 1.4);
      canvas.drawCircle(
        Offset(x - radius * 0.32, y - radius * 0.32),
        radius * 0.22,
        highlight,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
