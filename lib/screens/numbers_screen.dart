import 'package:flutter/material.dart';

import '../models/number_sign.dart';
import '../services/number_service.dart';
import '../services/progress_service.dart';
import '../ui/app_shell.dart';
import '../utils/video_url_utils.dart';
import 'sign_detector_screen.dart';
import 'tutorial_video_screen.dart';

// ── Colour tokens ─────────────────────────────────────────────────────────────
const kVividBlue = Color(0xFF1500C8);
const kAccent = Color(0xFF11B7CB);
const kGreen = Color(0xFF34C759);
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
  late Future<List<NumberSign>> _numberFuture;
  String _query = '';

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
    _searchController.addListener(
      () =>
          setState(() => _query = _searchController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
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
          videoAsset: sign.videoAsset,
          videoUrl: sign.videoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Numbers',
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                onBack: () => Navigator.of(context).pop(),
                onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 10),
                child: Text(
                  'NUMBERS',
                  style: TextStyle(
                    color: Color(0xFF1500C8),
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    shadows: [
                      Shadow(
                        color: Colors.white,
                        offset: Offset(3, 4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                        child: _SearchField(controller: _searchController)),
                    const SizedBox(width: 12),
                    _PracticeButton(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SignDetectorScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 130,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      left: 10,
                      top: 8,
                      child: _StickerNumber(
                        number: '1',
                        color: Color.fromARGB(185, 139, 63, 190),
                        angle: -0.18,
                        size: 38,
                      ),
                    ),
                    const Positioned(
                      left: 52,
                      bottom: 12,
                      child: _StickerNumber(
                        number: '2',
                        color: Color.fromARGB(190, 224, 49, 122),
                        angle: 0.12,
                        size: 32,
                      ),
                    ),
                    const Positioned(
                      right: 52,
                      top: 10,
                      child: _StickerNumber(
                        number: '3',
                        color: Color.fromARGB(192, 33, 149, 243),
                        angle: 0.15,
                        size: 30,
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      bottom: 14,
                      child: _StickerNumber(
                        number: '4',
                        color: Color.fromARGB(201, 67, 160, 72),
                        angle: -0.10,
                        size: 34,
                      ),
                    ),
                    const Positioned(
                      left: 38,
                      top: 6,
                      child: _FloatingEmoji(emoji: '✨', size: 16),
                    ),
                    const Positioned(
                      right: 38,
                      bottom: 8,
                      child: _FloatingEmoji(emoji: '💫', size: 14),
                    ),
                    Center(
                      child: Image.asset(
                        'assets/images/characters.png',
                        height: 130,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 5, 111, 209)
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: FutureBuilder<List<NumberSign>>(
                      future: _numberFuture,
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
                                'Cannot load numbers. Make sure the backend is running.',
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
                          child: GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(10),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: signs.length,
                            itemBuilder: (context, i) => _NumberCard(
                              sign: signs[i],
                              onView: () =>
                                  _showNumberDetails(context, signs[i]),
                            ),
                          ),
                        );
                      },
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
                  border: Border.all(
                    color: const Color.fromARGB(255, 216, 215, 221),
                    width: 2,
                  ),
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
                      color: const Color(0xFF11B7CB),
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
      Text(emoji, style: TextStyle(fontSize: size));
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
            const Shadow(
                color: Colors.white, offset: Offset(2, 2), blurRadius: 4),
            Shadow(
                color: color.withValues(alpha: 0.4),
                offset: const Offset(3, 3),
                blurRadius: 6),
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
      color: const Color.fromARGB(255, 7, 47, 179),
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
            border: Border.all(
                color: const Color.fromARGB(255, 235, 236, 238), width: 2),
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
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black26, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Color(0xFF9DA4AD)),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
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
      color: kGreen,
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'Practice',
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
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
          // ── image area with light grey border ──
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFDF9F9),
                border: Border.all(
                  color: const Color(0xFFD6D6D6), // light grey
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.all(6),
              child: _NumberImage(sign: sign, fit: BoxFit.contain),
            ),
          ),
          // ── footer ──
          Container(
            width: double.infinity,
            color: const Color.fromARGB(255, 0, 60, 191),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sign.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: onView,
                  child: Container(
                    width: 48,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kGreen,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
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
      return Image.network(
        sign.imageUrl,
        fit: fit,
        errorBuilder: (_, __, ___) => _ImageFallback(label: sign.title),
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
