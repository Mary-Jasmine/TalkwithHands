import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/number_sign.dart';
import '../services/number_service.dart';
import '../services/background_music_service.dart';
import '../services/progress_service.dart';
import '../ui/background_music_region.dart';
import '../ui/app_shell.dart';
import '../utils/url_helper.dart';
import '../utils/video_url_utils.dart';
import '../widgets/transparent_sign_video_overlay.dart';
import 'sign_detector_screen.dart';
import 'tutorial_video_screen.dart';

// ── Colour tokens ─────────────────────────────────────────────────────────────
const kVividBlue = Color(0xFF1500C8);
const kAccent = Color(0xFF11B7CB);
const kGreen = Color(0xFF34C759);
const kActionGreen = Color(0xFF218E3D);
const kCardBlue = Color(0xFF2563EB);

class NumbersScreen extends StatefulWidget {
  final String userName;

  const NumbersScreen({
    super.key,
    required this.userName,
  });

  @override
  State<NumbersScreen> createState() => _NumbersScreenState();
}

class _NumbersScreenState extends State<NumbersScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late Future<List<NumberSign>> _numberFuture;
  String _query = '';
  bool _searchMode = false;

  Future<void> _recordLearned(NumberSign sign) async {
    try {
      await ProgressService().recordActivity(
        category: 'number',
        itemKey: sign.number.toString(),
      );
    } catch (_) {
      // Progress sync should never block opening the lesson.
    }
  }

  @override
  void initState() {
    super.initState();
    _numberFuture = NumberService().listNumberSigns();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _searchController.addListener(
      () =>
          setState(() => _query = _searchController.text.trim().toLowerCase()),
    );
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    setState(() {
      if (_searchFocusNode.hasFocus) _searchMode = true;
    });
  }

  void _exitSearchMode() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _searchMode = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _numberFuture = NumberService().listNumberSigns();
      });

  List<NumberSign> _filter(List<NumberSign> signs) {
    if (_query.isEmpty) return signs;
    return signs
        .where((s) =>
            s.title.toLowerCase().contains(_query) ||
            s.number.toString().contains(_query) ||
            s.description.toLowerCase().contains(_query))
        .toList();
  }

  void _openTutorial(NumberSign sign) {
    if (!hasPlayableVideoSource(
      videoAsset: sign.videoAsset,
      videoUrl: sign.videoUrl,
      frontVideoUrl: sign.frontVideoUrl,
      leftVideoUrl: sign.leftVideoUrl,
      rightVideoUrl: sign.rightVideoUrl,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tutorial video has been uploaded for this lesson yet.'),
        ),
      );
      return;
    }

    _recordLearned(sign);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TutorialVideoScreen(
          title: sign.title,
          imageAsset: sign.imageAsset,
          imageUrl: sign.imageUrl,
          videoAsset: sign.videoAsset,
          videoUrl: sign.videoUrl,
          frontVideoUrl: sign.frontVideoUrl,
          leftVideoUrl: sign.leftVideoUrl,
          rightVideoUrl: sign.rightVideoUrl,
          activityCategory: 'number',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearching =
        _query.isNotEmpty || _searchMode || _searchFocusNode.hasFocus;
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      drawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Numbers',
      ),
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: ClassroomPageBackground(
          bannerAsset: 'assets/images/num.png',
          boardTopFraction: 0.402,
          landscapeBoardTopFraction: 0.34,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mq = MediaQuery.of(context);
                final landscape = constraints.maxWidth > constraints.maxHeight;
                final compact = constraints.maxHeight < 620;
                final horizontalInset =
                    math.max(20.0, constraints.maxWidth * 0.10).toDouble();

                Widget searchRow() => Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalInset,
                        compact ? 16 : 22,
                        horizontalInset,
                        compact ? 8 : 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SearchField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              isSearchMode: isSearching,
                              onExitSearch: _exitSearchMode,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _PracticeButton(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignDetectorScreen(
                                  initialMode: DetectionMode.num,
                                  lockMode: true,
                                  captureKind: CaptureKind.image,
                                  title: 'Number Practice',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                Widget avatarRow(double avatarHeight) => SizedBox(
                      height: avatarHeight,
                      width: double.infinity,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: -(150.0 * 0.25),
                            bottom: -12,
                            child: ClassroomBookshelf(
                              width: MediaQuery.sizeOf(context).height < 500
                                  ? 112
                                  : 150,
                            ),
                          ),
                          const TransparentSignVideoOverlay(
                            videoAsset: 'assets/Num.mp4',
                            fit: BoxFit.contain,
                            scale: 1.30,
                            volume: 0,
                            threshold: 0.34,
                            smoothing: 0.08,
                          ),
                          const Positioned(
                            left: 35,
                            top: -25,
                            child: _StickerNumber(
                              number: '1',
                              color: Color(0xFF20E8F6),
                              angle: -0.16,
                              size: 32,
                            ),
                          ),
                          const Positioned(
                            right: 54,
                            top: -40,
                            child: _StickerNumber(
                              number: '2',
                              color: Color(0xFFFFA900),
                              angle: 0.12,
                              size: 30,
                            ),
                          ),
                          const Positioned(
                            right: 16,
                            bottom: 2,
                            child: _StickerNumber(
                              number: '3',
                              color: Color(0xFFE7A8F6),
                              angle: -0.10,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    );

                Widget panel() => Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 4, 51, 98)
                            .withValues(alpha: 0.18),
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
                      child: _buildNumberGrid(),
                    );

                if (landscape) {
                  final avatarHeight = constraints.maxHeight < 560
                      ? 76.0
                      : constraints.maxHeight < 720
                          ? 108.0
                          : 140.0;
                  return Column(
                    children: [
                      AppTopBar(
                        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                        menuOnLeft: true,
                      ),
                      searchRow(),
                      if (isSearching)
                        SizedBox(height: constraints.maxHeight * 0.05)
                      else ...[
                        SizedBox(height: constraints.maxHeight * 0.03),
                        avatarRow(avatarHeight),
                        SizedBox(height: constraints.maxHeight * 0.05),
                      ],
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            constraints.maxWidth * 0.10,
                            0,
                            constraints.maxWidth * 0.10,
                            constraints.maxHeight * 0.075,
                          ),
                          child: panel(),
                        ),
                      ),
                    ],
                  );
                }

                final boardTop = 0.402;
                final sh = mq.size.height;
                final topInset = mq.padding.top;
                final keyboardInset = mq.viewInsets.bottom;
                final avatarHeight =
                    (sh * 0.15).clamp(84.0, 150.0).toDouble();
                final avatarTop = sh * 0.365 - topInset - avatarHeight;
                final bottomInset = mq.padding.bottom;
                final panelTop = sh * (boardTop + 0.009) - topInset;
                final panelBottom = keyboardInset > 0
                    ? keyboardInset
                    : math.max(0.0, sh * 0.03 - bottomInset);

                return Stack(
                  children: [
                    Column(
                      children: [
                        AppTopBar(
                          onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                          menuOnLeft: true,
                        ),
                        searchRow(),
                      ],
                    ),
                    Positioned(
                      top: avatarTop,
                      left: 0,
                      right: 0,
                      height: avatarHeight,
                      child: avatarRow(avatarHeight),
                    ),
                    Positioned(
                      top: panelTop,
                      left: constraints.maxWidth * 0.08,
                      right: constraints.maxWidth * 0.08,
                      bottom: panelBottom,
                      child: panel(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberGrid() {
    return FutureBuilder<List<NumberSign>>(
      future: _numberFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: 'Cannot load numbers. Make sure the backend is running.',
            onRetry: _reload,
          );
        }
        final signs = _filter(snapshot.data ?? const []);
        if (signs.isEmpty) {
          return _ErrorState(
            message: 'No number signs found.',
            onRetry: _reload,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 22 - 20) / 3;
              const boardTop = 0.402;
              final fullHeight = MediaQuery.sizeOf(context).height;
              const panelTopFraction = boardTop + 0.009;
              final normalPanelHeight =
                  fullHeight * (0.97 - panelTopFraction);
              final cardHeight = (normalPanelHeight - 24 - 20) / 2.5;
              final ratio = cardWidth / cardHeight;
              final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: keyboardOpen ? 4 : 12,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: keyboardOpen ? 8 : 10,
                  childAspectRatio: ratio,
                ),
                itemCount: signs.length,
                itemBuilder: (context, i) => _NumberCard(
                  sign: signs[i],
                  onView: () => _showNumberDetails(context, signs[i]),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showNumberDetails(BuildContext context, NumberSign sign) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 38),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFD7FF), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                      child: Text(
                        sign.title,
                        style: const TextStyle(
                          color: Color(0xFF071A3F),
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: _NumberImage(sign: sign, fit: BoxFit.contain),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 19),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF185FA5), Color(0xFF0B8FFF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Center(
                        child: _TutorialButton(
                          onTap: () {
                            Navigator.of(context).pop();
                            _openTutorial(sign);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Material(
                  color: const Color(0xFFFF2F2F),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Floating emoji ────────────────────────────────────────────────────────────
class _FloatingEmoji extends StatelessWidget {
  final String emoji;
  final double size;
  const _FloatingEmoji({required this.emoji, required this.size});
  @override
  Widget build(BuildContext context) =>
      Text(
        emoji,
        style: TextStyle(
          fontSize: size,
          shadows: [
            Shadow(
              color: const Color(0xFF12365A).withValues(alpha: 0.34),
              offset: const Offset(1.5, 2.5),
              blurRadius: 4,
            ),
          ],
        ),
      );
}

// ── Avatar without a speech balloon ──────────────────────────────────────────
class _NumberAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          height: 150,
          width: 240,
          child: const TransparentSignVideoOverlay(
            videoAsset: 'assets/Num.mp4',
            fit: BoxFit.contain,
            scale: 1.00,
            volume: 0,
            threshold: 0.34,
            smoothing: 0.08,
          ),
        ),
      );
}

// ── Sticker number ────────────────────────────────────────────────────────────
class _StickerNumber extends StatelessWidget {
  final String number;
  final Color color;
  final double angle;
  final double size;
  const _StickerNumber({
    required this.number,
    required this.color,
    required this.angle,
    required this.size,
  });
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Text(
        number,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: [
            Shadow(
              color: const Color(0xFF12365A).withValues(alpha: 0.34),
              offset: const Offset(1.5, 2.5),
              blurRadius: 4,
            ),
            Shadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tutorial button ───────────────────────────────────────────────────────────
class _TutorialButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TutorialButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kActionGreen,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 156,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Text(
            'VIDEO TUTORIAL',
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────────
class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearchMode;
  final VoidCallback onExitSearch;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.isSearchMode,
    required this.onExitSearch,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kVividBlue, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child:
                Icon(Icons.search_rounded, color: Color(0xFF9DA4AD), size: 18),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Color(0xFF9DA4AD)),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              ),
            ),
          ),
          if (_hasText || widget.isSearchMode)
            GestureDetector(
              onTap: widget.onExitSearch,
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.close_rounded,
                    color: Color(0xFF9DA4AD), size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Practice button ───────────────────────────────────────────────────────────
class _PracticeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PracticeButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kActionGreen,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Text(
            'Practice',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ── Number card ───────────────────────────────────────────────────────────────
class _NumberCard extends StatelessWidget {
  final NumberSign sign;
  final VoidCallback onView;
  const _NumberCard({required this.sign, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.19),
            blurRadius: 6,
            offset: const Offset(4, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── image area with light grey border — tappable ──
          Expanded(
            child: GestureDetector(
              onTap: onView,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF9F9),
                  border: Border.all(
                    color: const Color(0xFFD6D6D6),
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(1),
                child: _NumberImage(sign: sign, fit: BoxFit.contain),
              ),
            ),
          ),
          // ── footer ──
          Container(
            width: double.infinity,
            color: const Color.fromARGB(255, 0, 60, 191),
            padding: const EdgeInsets.fromLTRB(8, 3, 8, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sign.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                  fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                GestureDetector(
                  onTap: onView,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: kActionGreen,
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
    );
  }
}

// ── Number image ──────────────────────────────────────────────────────────────
class _NumberImage extends StatelessWidget {
  final NumberSign sign;
  final BoxFit fit;
  const _NumberImage({required this.sign, required this.fit});
  @override
  Widget build(BuildContext context) {
    if (sign.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: getOptimizedUrl(sign.imageUrl, width: 400),
        fit: fit,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => _ImageFallback(label: sign.title),
      );
    }
    return Image.asset(
      sign.imageAsset,
      fit: fit,
      errorBuilder: (_, __, ___) => _ImageFallback(label: sign.title),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final String label;
  const _ImageFallback({required this.label});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.black, fontSize: 34, fontWeight: FontWeight.w900),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _RetryButton(onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RetryButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: kVividBlue,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black, width: 1.4),
          ),
          child: const Text(
            'Retry',
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
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
  kVividBlue,
  kAccent,
  kGreen,
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
