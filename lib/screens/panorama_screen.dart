import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/panorama_scene.dart';
import '../services/api_config.dart';
import '../services/panorama_service.dart';
import '../services/video_player_service.dart';
import '../ui/app_shell.dart';

class PanoramaScreen extends StatefulWidget {
  final String userName;
  const PanoramaScreen({super.key, required this.userName});

  @override
  State<PanoramaScreen> createState() => _PanoramaScreenState();
}

class _PanoramaScreenState extends State<PanoramaScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final WebViewController _webViewController;
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
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'HotspotBridge',
        onMessageReceived: _onHotspotMessage,
      )
      ..loadHtmlString(_buildEmptyHtml('Loading 360 pictures...'));
    _sceneFuture = PanoramaService().listPanoramaScenes();
  }

  String _assetUrl(String assetPath) {
    final cleanPath = assetPath.split('/').map(Uri.encodeComponent).join('/');
    return '$_baseUrl/$cleanPath';
  }

  String _imageUrl(PanoramaScene scene) {
    if (scene.imageUrl.trim().isNotEmpty) return scene.imageUrl.trim();
    return _assetUrl(scene.imageAsset);
  }

  void _loadPanorama(int index) {
    if (index < 0 || index >= _scenes.length) return;
    setState(() {
      _selectedIndex = index;
      _viewerMode = true;
    });
    _webViewController.loadHtmlString(_buildHtml(_scenes[index]));
  }

  void _onHotspotMessage(JavaScriptMessage message) {
    final Object? data;
    try {
      data = jsonDecode(message.message);
    } catch (_) {
      return;
    }
    if (data is! Map) return;

    final hotspot = PanoramaHotspot(
      id: (data['id'] ?? '').toString(),
      key: '',
      label: (data['label'] ?? '').toString(),
      videoAsset: (data['videoAsset'] ?? '').toString(),
      videoUrl: (data['videoUrl'] ?? '').toString(),
      yaw: 0,
      pitch: 0,
      size: 1,
      sortOrder: 0,
    );
    _showHotspotVideo(hotspot);
  }

  void _showHotspotVideo(PanoramaHotspot hotspot) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _PanoramaVideoDialog(
        title: hotspot.label,
        videoAsset: hotspot.videoAsset,
        videoUrl: hotspot.videoUrl,
      ),
    );
  }

  String _buildEmptyHtml(String message) => '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body {
    margin: 0; background: #050505; color: white; width: 100vw; height: 100vh;
    display: flex; align-items: center; justify-content: center;
    font-family: Arial, sans-serif; text-align: center;
  }
</style>
</head>
<body>$message</body>
</html>
''';

  String _buildHtml(PanoramaScene sceneData) {
    final hotspotsJson = jsonEncode(
        sceneData.hotspots.map((item) => item.toViewerJson()).toList());
    final imageUrl = _imageUrl(sceneData);

    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { background: #000; overflow: hidden; width: 100vw; height: 100vh; }
  canvas { display: block; }
  #hint {
    position: absolute; bottom: 16px; left: 50%; transform: translateX(-50%);
    background: rgba(0,0,0,0.66); color: white; padding: 7px 16px;
    border-radius: 999px; font-family: Arial, sans-serif; font-size: 13px;
    pointer-events: none; transition: opacity 1s; z-index: 3;
  }
  #hotspots {
    position: absolute; inset: 0; pointer-events: none; overflow: hidden; z-index: 2;
  }
  .hotspot {
    position: absolute; left: 0; top: 0; transform: translate(-50%, -50%);
    width: 48px;
    height: 45px; border-radius: 50%;
    border: 2.5px solid rgba(255,255,255,0.85);
    border-shadow: grey 10px 0px 0px 10px;
    background: transparent;
    cursor: pointer; pointer-events: auto;
    box-shadow: 0 2px 12px rgba(0,0,0,0.25); user-select: none;
    transition: opacity 120ms ease, transform 120ms ease, background 120ms ease;
    display: flex; align-items: center; justify-content: center;
    font-size: 0;
  }
  .hotspot::after {
    content: '';
    width: 0; height: 0;
    border-top: 10px solid transparent;
    border-bottom: 10px solid transparent;
    border-left: 18px solid rgba(255,255,255,0.9);
    margin-left: 4px;
  }
  .hotspot::before {
    display: none;
  }
  .hotspot:hover {
    background: rgba(255,255,255,0.15);
    transform: translate(-50%, -50%) scale(1.1);
  }
</style>
</head>
<body>
<div id="hotspots"></div>
<div id="hint">Drag to look around</div>
<script src="$_baseUrl/assets/three.min.js"></script>
<script>
  const hotspotData = $hotspotsJson;

  setTimeout(() => {
    const h = document.getElementById('hint');
    if (h) { h.style.opacity = '0'; setTimeout(() => h.remove(), 1000); }
  }, 3000);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(75, window.innerWidth/window.innerHeight, 0.1, 1000);
  camera.position.set(0, 0, 0.1);
  const renderer = new THREE.WebGLRenderer({antialias: true});
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(window.devicePixelRatio);
  document.body.appendChild(renderer.domElement);

  const geometry = new THREE.SphereGeometry(500, 60, 40);
  geometry.scale(-1, 1, 1);
  const texture = new THREE.TextureLoader().load('$imageUrl');
  const material = new THREE.MeshBasicMaterial({map: texture});
  const sphere = new THREE.Mesh(geometry, material);
  scene.add(sphere);

  const hotspotRoot = document.getElementById('hotspots');
  const hotspotItems = hotspotData.map(item => {
    const el = document.createElement('button');
    el.type = 'button';
    el.className = 'hotspot';
    el.textContent = item.label;
    el.style.transform = 'translate(-50%, -50%) scale(' + String(item.size || 1) + ')';
    el.addEventListener('pointerdown', e => e.stopPropagation());
    el.addEventListener('click', e => {
      e.stopPropagation();
      HotspotBridge.postMessage(JSON.stringify(item));
    });
    hotspotRoot.appendChild(el);
    return { data: item, el, point: hotspotPoint(item.yaw, item.pitch) };
  });

  let isInteracting = false, autoRotate = true;
  let lon = 0, lat = 0, downX = 0, downY = 0, downLon = 0, downLat = 0;
  let lastPinchDist = 0;

  function hotspotPoint(yaw, pitch) {
    const radius = 460;
    const theta = THREE.MathUtils.degToRad(yaw);
    const phi = THREE.MathUtils.degToRad(pitch);
    return new THREE.Vector3(
      radius * Math.cos(phi) * Math.cos(theta),
      radius * Math.sin(phi),
      radius * Math.cos(phi) * Math.sin(theta)
    );
  }

  function onDown(e) {
    isInteracting = true; autoRotate = false;
    const x = e.touches ? e.touches[0].clientX : e.clientX;
    const y = e.touches ? e.touches[0].clientY : e.clientY;
    downX = x; downY = y; downLon = lon; downLat = lat;
  }
  function onMove(e) {
    if (!isInteracting) return;
    if (e.touches && e.touches.length === 2) {
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      const dist = Math.sqrt(dx*dx + dy*dy);
      if (lastPinchDist > 0) {
        camera.fov = Math.max(30, Math.min(90, camera.fov - (dist - lastPinchDist) * 0.1));
        camera.updateProjectionMatrix();
      }
      lastPinchDist = dist;
      return;
    }
    lastPinchDist = 0;
    const x = e.touches ? e.touches[0].clientX : e.clientX;
    const y = e.touches ? e.touches[0].clientY : e.clientY;
    lon = (downX - x) * 0.2 + downLon;
    lat = (y - downY) * 0.2 + downLat;
  }
  function onUp() { isInteracting = false; lastPinchDist = 0; }

  document.addEventListener('mousedown', onDown);
  document.addEventListener('mousemove', onMove);
  document.addEventListener('mouseup', onUp);
  document.addEventListener('touchstart', onDown, {passive: true});
  document.addEventListener('touchmove', onMove, {passive: true});
  document.addEventListener('touchend', onUp);
  document.addEventListener('wheel', e => {
    camera.fov = Math.max(30, Math.min(90, camera.fov + e.deltaY * 0.05));
    camera.updateProjectionMatrix();
  });
  window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth/window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
  });

  function updateHotspots() {
    const viewDirection = new THREE.Vector3();
    camera.getWorldDirection(viewDirection);
    hotspotItems.forEach(item => {
      const facing = item.point.clone().normalize().dot(viewDirection) > 0;
      const projected = item.point.clone().project(camera);
      const visible = facing && projected.z > -1 && projected.z < 1;
      item.el.style.opacity = visible ? '1' : '0';
      item.el.style.pointerEvents = visible ? 'auto' : 'none';
      if (!visible) return;
      const x = (projected.x * 0.5 + 0.5) * window.innerWidth;
      const y = (-projected.y * 0.5 + 0.5) * window.innerHeight;
      item.el.style.left = x + 'px';
      item.el.style.top = y + 'px';
    });
  }

  function animate() {
    requestAnimationFrame(animate);
    if (autoRotate) lon += 0.05;
    lat = Math.max(-85, Math.min(85, lat));
    const phi = THREE.MathUtils.degToRad(90 - lat);
    const theta = THREE.MathUtils.degToRad(lon);
    camera.lookAt(
      500 * Math.sin(phi) * Math.cos(theta),
      500 * Math.cos(phi),
      500 * Math.sin(phi) * Math.sin(theta)
    );
    renderer.render(scene, camera);
    updateHotspots();
  }
  animate();

  // Called from Flutter to rotate camera to a hotspot
  window.navigateTo = function(yaw, pitch) {
    autoRotate = false;
    lon = yaw;
    lat = -pitch; // pitch is inverted in this coordinate system
  };
</script>
</body>
</html>
''';
  }

  IconData _sceneIcon(PanoramaScene scene) {
    switch (scene.icon) {
      case 'bench':
        return Icons.chair_outlined;
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
      _sceneFuture = PanoramaService().listPanoramaScenes();
      _webViewController
          .loadHtmlString(_buildEmptyHtml('Loading 360 pictures...'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: '360 Pictures',
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                onBack: () {
                  if (_viewerMode) {
                    setState(() => _viewerMode = false);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 12),
                child: Text(
                  _viewerMode && _scenes.isNotEmpty
                      ? _scenes[_selectedIndex].title.toUpperCase()
                      : '360 PICTURES',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1500C8),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<PanoramaScene>>(
                  future: _sceneFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    if (snapshot.hasError) {
                      return _ErrorState(
                        message:
                            'Cannot load 360 pictures. Make sure the backend is running.',
                        onRetry: _reload,
                      );
                    }

                    final scenes = snapshot.data ?? const [];
                    if (scenes.isEmpty) {
                      return _ErrorState(
                        message: 'No 360 pictures found.',
                        onRetry: _reload,
                      );
                    }

                    if (_scenes.isEmpty) {
                      _scenes = scenes;
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
      ),
    );
  }

  // ── Category landing grid ───────────────────────────────────────────────
  Widget _buildCategoryGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.05,
        ),
        itemCount: _scenes.length,
        itemBuilder: (context, index) {
          final scene = _scenes[index];
          return _PanoramaCategoryCard(
            title: scene.title,
            imageUrl: _imageUrl(scene),
            icon: _sceneIcon(scene),
            highlighted: index == 0,
            onView: () => _loadPanorama(index),
          );
        },
      ),
    );
  }

  // ── Navigate panorama camera to a hotspot (no auto-play — user taps hotspot) ──
  void _navigateToHotspot(PanoramaHotspot hotspot) {
    _webViewController.runJavaScript(
      'window.navigateTo(${hotspot.yaw}, ${hotspot.pitch});',
    );
  }

  // ── Words / hotspot list below the 360 viewer ───────────────────────────
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

  // ── 360 viewer with thumbnail strip ─────────────────────────────────────
  Widget _buildViewer() {
    final currentHotspots = _scenes.isNotEmpty ? _scenes[_selectedIndex].hotspots : <PanoramaHotspot>[];

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: WebViewWidget(controller: _webViewController),
            ),
          ),
        ),
        _buildWordsList(currentHotspots),
        const SizedBox(height: 16),
      ],
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
        _error =
            'Cannot play this hotspot video.\nPlease restart the backend and try again.';
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
  final bool highlighted;
  final VoidCallback onView;
  final IconData icon;

  const _PanoramaCategoryCard({
    required this.title,
    required this.imageUrl,
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
          color: const Color(0xFF0E7C8C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted ? kAccent : const Color(0xFFAEEAF2),
            width: highlighted ? 2.5 : 1.6,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE0F7FA),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.threesixty_rounded,
                      color: Color(0xFF0E7C8C),
                      size: 40,
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFFE0F7FA),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF0E7C8C),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: const Color(0xFF34C759),
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: onView,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 86,
                        height: 28,
                        alignment: Alignment.center,
                        child: const Text(
                          'View',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
}