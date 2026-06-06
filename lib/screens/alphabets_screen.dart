import 'package:flutter/material.dart';

import '../models/alphabet_sign.dart';
import '../services/alphabet_service.dart';
import '../services/progress_service.dart';
import '../ui/app_shell.dart';
import '../utils/video_url_utils.dart';
import 'sign_detector_screen.dart';
import 'tutorial_video_screen.dart';

// ── Colour tokens ────────────────────────────────────────────────────────────
const kVividBlue = Color(0xFF1500C8);
const kAccent = Color(0xFF11B7CB);
const kGreen = Color(0xFF34C759);
const kCardBlue = Color(0xFF2563EB); // card footer blue (matches mockup)

class AlphabetsScreen extends StatefulWidget {
  final String userName;

  const AlphabetsScreen({
    super.key,
    required this.userName,
  });

  @override
  State<AlphabetsScreen> createState() => _AlphabetsScreenState();
}

class _AlphabetsScreenState extends State<AlphabetsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  List<AlphabetSign> _allSigns = [];
  bool _isLoading = true;
  String? _loadError;
  String _query = '';

  Future<void> _recordLearned(AlphabetSign sign) async {
    try {
      await ProgressService().recordActivity(
        category: 'alphabet',
        itemKey: sign.letter,
      );
    } catch (_) {
      // Progress sync should never block opening the lesson.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSigns();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  Future<void> _loadSigns() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final signs = await AlphabetService().listAlphabetSigns();
      setState(() {
        _allSigns = signs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() => _loadSigns();

  List<AlphabetSign> get _filteredSigns {
    final query = _normalizeSearch(_query);
    if (query.isEmpty) return _allSigns;

    return _allSigns.where((s) {
      final letter = _normalizeSearch(s.letter);
      final title = _normalizeSearch(s.title);

      if (query.length == 1) {
        return letter == query || title == query;
      }

      return letter.startsWith(query) ||
          title == query ||
          title.endsWith(' $query');
    }).toList();
  }

  String _normalizeSearch(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _openTutorial(AlphabetSign sign) {
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
          title: sign.letter,
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
        activeScreen: 'Alphabets',
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────────────────────────
              AppTopBar(
                onBack: () => Navigator.of(context).pop(),
                onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),

              // ── Title ────────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 10),
                child: Text(
                  'ALPHABETS',
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

              // ── Search + Practice row ────────────────────────────────────
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

              // ── Character illustration banner ────────────────────────────
              SizedBox(
                height: 130,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // decorative bubbles / hearts
                    const Positioned(
                      left: 18,
                      top: 10,
                      child: _FloatingEmoji(emoji: '🤟', size: 32),
                    ),
                    const Positioned(
                      left: 48,
                      bottom: 18,
                      child: _FloatingEmoji(emoji: '💙', size: 20),
                    ),
                    const Positioned(
                      right: 22,
                      top: 8,
                      child: _FloatingEmoji(emoji: '✨', size: 22),
                    ),
                    const Positioned(
                      right: 44,
                      bottom: 22,
                      child: _FloatingEmoji(emoji: '🌟', size: 18),
                    ),
                    // main characters (placeholder — swap with your asset)
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

              // ── Grid container (rounded card panel) ──────────────────────
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildGrid(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_loadError != null) {
      return _ErrorState(
        message: 'Cannot load alphabets. Make sure the backend is running.',
        onRetry: _reload,
      );
    }
    final signs = _filteredSigns;
    if (signs.isEmpty && _query.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'No results for "$_query"',
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
    if (signs.isEmpty) {
      return _ErrorState(
        message: 'No alphabet signs found.',
        onRetry: _reload,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.78,
        ),
        itemCount: signs.length,
        itemBuilder: (context, i) => _AlphabetCard(
          sign: signs[i],
          onView: () => _showAlphabetDetails(context, signs[i]),
        ),
      ),
    );
  }

  void _showAlphabetDetails(BuildContext context, AlphabetSign sign) {
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
                      width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                      child: Text(
                        sign.letter,
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
                      child: _AlphabetImage(sign: sign, fit: BoxFit.contain),
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
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
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

// ── Floating emoji / decoration ───────────────────────────────────────────────
class _FloatingEmoji extends StatelessWidget {
  final String emoji;
  final double size;

  const _FloatingEmoji({required this.emoji, required this.size});

  @override
  Widget build(BuildContext context) {
    return Text(emoji, style: TextStyle(fontSize: size));
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
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────────
class _SearchField extends StatefulWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

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
              controller: widget.controller,
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
          if (_hasText)
            GestureDetector(
              onTap: () => widget.controller.clear(),
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
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Alphabet card ─────────────────────────────────────────────────────────────
class _AlphabetCard extends StatelessWidget {
  final AlphabetSign sign;
  final VoidCallback onView;

  const _AlphabetCard({required this.sign, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 156, 38, 38),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // image area
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF5F8FF),
              padding: const EdgeInsets.all(6),
              child: _AlphabetImage(sign: sign, fit: BoxFit.contain),
            ),
          ),
          // footer
          Container(
            width: double.infinity,
            color: const Color.fromARGB(255, 20, 74, 190),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sign.letter,
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

// ── Alphabet image ────────────────────────────────────────────────────────────
class _AlphabetImage extends StatelessWidget {
  final AlphabetSign sign;
  final BoxFit fit;

  const _AlphabetImage({required this.sign, required this.fit});

  @override
  Widget build(BuildContext context) {
    if (sign.imageUrl.isNotEmpty) {
      return Image.network(
        sign.imageUrl,
        fit: fit,
        errorBuilder: (_, __, ___) => _ImageFallback(letter: sign.letter),
      );
    }
    return Image.asset(
      sign.imageAsset,
      fit: fit,
      errorBuilder: (_, __, ___) => _ImageFallback(letter: sign.letter),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final String letter;
  const _ImageFallback({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
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
                fontWeight: FontWeight.w700,
              ),
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
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
