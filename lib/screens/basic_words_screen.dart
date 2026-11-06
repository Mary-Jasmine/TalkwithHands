import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/basic_word.dart';
import '../services/background_music_service.dart';
import '../services/basic_word_service.dart';
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

const Set<String> _excludedBasicWordCategories = {
  'alphabet',
  'alphabets',
  'number',
  'numbers',
  'emotions',
};

// ── Sign language sets ──────────────────────────────────────────────────────
// Categories shown when the user switches the toggle to "FSL Signs".
const Map<String, IconData> _categoryIcons = {
  'Animals': Icons.pets_rounded,
  'Colors': Icons.palette_outlined,
  'Days of the week': Icons.calendar_view_week_outlined,
  'Direction and Location': Icons.explore_outlined,
  'Emotion': Icons.sentiment_satisfied_alt_outlined,
  'Environment': Icons.park_outlined,
  'Family': Icons.family_restroom_rounded,
  'Feelings': Icons.favorite_border_rounded,
  'Foods': Icons.restaurant_outlined,
  'Food Taste': Icons.local_dining_outlined,
  'Fruits': Icons.apple_outlined,
  'Greetings': Icons.waving_hand_outlined,
  'Health and Emergency': Icons.medical_services_outlined,
  'Kitchenware': Icons.blender_outlined,
  'Money and Shopping': Icons.shopping_cart_outlined,
  'Months': Icons.calendar_month_outlined,
  'NOT EDIT': Icons.block_outlined,
  'Not Edited': Icons.block_outlined,
  'Operations': Icons.calculate_outlined,
  'Person': Icons.person_outline_rounded,
  'Personal Things': Icons.person_outline_rounded,
  'Questions': Icons.help_outline_rounded,
  'Religion and Values': Icons.auto_awesome_outlined,
  'Responses and Reactions': Icons.thumbs_up_down_outlined,
  'School': Icons.school_outlined,
  'School Supplies': Icons.backpack_outlined,
  'Shapes': Icons.category_outlined,
  'Technology and Communication': Icons.devices_outlined,
  'Temperature': Icons.thermostat_rounded,
  'Time': Icons.schedule_outlined,
  'Transportations': Icons.directions_car_outlined,
};

const Map<String, String> _categoryDisplayNames = {
  'animal': 'Animals',
  'color': 'Colors',
  'school supply': 'School Supplies',
  'shape': 'Shapes',
  'transportation': 'Transportations',
};

String _displayCategoryName(String category) =>
    _categoryDisplayNames[category.trim().toLowerCase()] ?? category;

IconData _iconForCategory(String category) =>
    _categoryIcons[_displayCategoryName(category)] ??
    _categoryIcons[category] ??
    Icons.category_outlined;

class BasicWordsScreen extends StatefulWidget {
  final String userName;
  final String? initialCategory;

  const BasicWordsScreen({
    super.key,
    required this.userName,
    this.initialCategory,
  });

  @override
  State<BasicWordsScreen> createState() => _BasicWordsScreenState();
}

class _BasicWordsScreenState extends State<BasicWordsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late Future<List<BasicWord>> _wordFuture;
  String _query = '';
  bool _searchMode = false;

  // null = show category landing grid; non-null = show word list for that category
  String? _selectedCategory;

  Future<void> _recordLearned(BasicWord word) async {
    try {
      await ProgressService().recordActivity(
        category: 'basic_word',
        itemKey: word.key,
      );
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _wordFuture = BasicWordService().listBasicWords();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      setState(() {
        _query = q;
      });
    });
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    setState(() {
      if (_searchFocusNode.hasFocus) _searchMode = true;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _wordFuture = BasicWordService().listBasicWords();
      });

  bool _isBasicWordCategory(BasicWord word) {
    return !_excludedBasicWordCategories.contains(
      word.category.trim().toLowerCase(),
    );
  }

  List<String> _categories(List<BasicWord> words) {
    final playableWords = words
        .where((word) => _isBasicWordCategory(word) && _hasTutorialVideo(word))
        .toList();
    final cats = <String>{};
    for (final w in playableWords) {
      if (w.category.trim().isNotEmpty) cats.add(w.category);
    }
    return cats.toList()..sort();
  }

  List<BasicWord> _wordsForCategory(List<BasicWord> words, String category) =>
      words
          .where((w) =>
              _isBasicWordCategory(w) &&
              w.category == category &&
              _hasTutorialVideo(w))
          .toList();

  List<BasicWord> _searchResults(List<BasicWord> words) {
    if (_query.isEmpty) return [];
    return words.where((w) {
      if (!_isBasicWordCategory(w)) return false;
      if (!_hasTutorialVideo(w)) return false;
      return w.title.toLowerCase().contains(_query) ||
          w.category.toLowerCase().contains(_query) ||
          w.description.toLowerCase().contains(_query);
    }).toList();
  }

  bool _hasTutorialVideo(BasicWord word) {
    return hasPlayableVideoSource(
      videoAsset: word.videoAsset,
      videoUrl: word.videoUrl,
      frontVideoUrl: word.frontVideoUrl,
      leftVideoUrl: word.leftVideoUrl,
      rightVideoUrl: word.rightVideoUrl,
    );
  }

  void _openVideo(BasicWord word) {
    if (!_hasTutorialVideo(word)) return;
    _recordLearned(word);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TutorialVideoScreen(
        title: word.title,
        imageAsset: word.imageAsset,
        imageUrl: word.imageUrl,
        videoAsset: word.videoAsset,
        videoUrl: word.videoUrl,
        frontVideoUrl: word.frontVideoUrl,
        leftVideoUrl: word.leftVideoUrl,
        rightVideoUrl: word.rightVideoUrl,
        activityCategory: 'basic_word',
      ),
    ));
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _query = '';
      _searchMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      drawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Basic Words',
      ),
      body: BackgroundMusicRegion(
        track: BackgroundMusicTrack.page,
        child: ClassroomPageBackground(
          bannerAsset: 'assets/images/bas.png',
          boardTopFraction:
              _selectedCategory != null ? 0.24 : 0.37,
          landscapeBoardTopFraction: 0.34,
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, pageConstraints) {
                  final safeInsets = MediaQuery.viewPaddingOf(context);
                  final pageHeight = pageConstraints.maxHeight +
                      safeInsets.top + safeInsets.bottom;
                  return FutureBuilder<List<BasicWord>>(
            future: _wordFuture,
            builder: (context, snapshot) {
              final words = snapshot.data ?? [];
              final categories = _categories(words);
              final isSearching = _query.isNotEmpty ||
                  _searchMode ||
                  _searchFocusNode.hasFocus;
              final showAvatarRow = _selectedCategory == null &&
                  (isSearching || _query.isEmpty);
              final listAnchorFraction = _selectedCategory != null
                  ? 0.28
                  : 0.37;
              final preferredAvatarRowHeight = pageHeight < 500 ? 82.0 : 128.0;
              final headerHeight =
                  (MediaQuery.sizeOf(context).shortestSide < 360 ? 82.0 : 67.0) +
                      4 +
                      math.max(44.0, pageHeight * 0.055) +
                      6;
              final boardLocalTop =
                  pageHeight * listAnchorFraction - safeInsets.top;
              // Keep the avatar at its regular page position and size while
              // searching; keyboard visibility should not pull it upward.
              final avatarOverflow = isSearching && pageHeight >= 500
                  ? 22.0
                  : isSearching
                      ? 0.0
                      : 22.0;
              final avatarRowHeight = preferredAvatarRowHeight;
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final hasError = snapshot.hasError;

              return Column(
                children: [
                  AppTopBar(
                    onBack: _selectedCategory == null
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    menuOnLeft: _selectedCategory == null,
                  ),
                  const SizedBox(height: 4),

                  // ── Search bar ────────────────────────────────────────────
                  Transform.translate(
                    offset: const Offset(0, 18),
                    child: SizedBox(
                      height: math.max(
                        44.0,
                        MediaQuery.sizeOf(context).height * 0.055,
                      ),
                      child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.sizeOf(context).width * 0.10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: kVividBlue,
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 11,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 9),
                                    child: Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF9DA4AD),
                                      size: 24,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Search words..',
                                        hintStyle:
                                            TextStyle(color: Color(0xFF9DA4AD)),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 0, vertical: 9),
                                      ),
                                    ),
                                  ),
                                  if (_query.isNotEmpty || _searchMode)
                                    GestureDetector(
                                      onTap: _clearSearch,
                                      child: const Padding(
                                        padding: EdgeInsets.only(right: 10),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: Color(0xFF9DA4AD),
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Practice button — compact and responsive: scales
                          // with screen width (capped) so it stays small on
                          // phones but doesn't look cramped on tablets, while
                          // the search bar keeps the majority of the space.
                          SizedBox(
                            width: math.min(
                              120.0,
                              math.max(
                                92.0,
                                MediaQuery.sizeOf(context).width * 0.24,
                              ),
                            ),
                            child: Material(
                              color: kGreen,
                              borderRadius: BorderRadius.circular(32),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => const SignDetectorScreen(
                                      initialMode: DetectionMode.words,
                                      lockMode: true,
                                      captureKind: CaptureKind.video,
                                      title: 'Basic Word Practice',
                                    ),
                                  ));
                                },
                                borderRadius: BorderRadius.circular(32),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha: 0.30),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Practice',
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),

                  if (showAvatarRow) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                    height: avatarRowHeight,
                    width: double.infinity,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (!isSearching)
                          Positioned(
                          left: -(MediaQuery.sizeOf(context).height < 500
                                  ? 80.0
                                  : 118.0) *
                              0.25,
                          bottom: -25,
                          child: ClassroomBookshelf(
                            width: MediaQuery.sizeOf(context).height < 500
                                ? 80.0
                                : 118.0,
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(0, avatarOverflow),
                          child: SizedBox(
                            height: isSearching
                                ? (pageHeight >= 500
                                    ? avatarRowHeight + 30
                                    : avatarRowHeight)
                                : (pageHeight < 500 ? 104 : 172),
                            width: math.min(
                              280.0,
                              MediaQuery.sizeOf(context).width * 0.8,
                            ),
                            child: const TransparentSignVideoOverlay(
                              videoAsset: 'assets/Basic.mp4',
                              fit: BoxFit.contain,
                              scale: 1.04,
                              volume: 0,
                              threshold: 0.34,
                              smoothing: 0.08,
                            ),
                          ),
                        ),
                        if (!isSearching) ...[
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
                      ],
                    ),
                    ),
                    SizedBox(
                      height: math.max(
                        0.0,
                        isSearching
                            ? boardLocalTop -
                                headerHeight -
                                10 -
                                avatarRowHeight
                            : pageHeight * 0.06,
                      ),
                    ),
                  ] else
                    SizedBox(
                      height: math.max(0.0, boardLocalTop - headerHeight),
                    ),

                  // ── Main content ──────────────────────────────────────────
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white))
                        : hasError
                            ? _ErrorState(
                                message:
                                    'Cannot load basic words. Make sure the backend is running.',
                                onRetry: _reload,
                              )
                            : _query.isNotEmpty
                                ? _buildSearchResults(
                                    _searchResults(words), categories)
                                : _selectedCategory == null
                                    ? _buildCategoryGrid(categories, words)
                                    : _buildWordList(
                                        _wordsForCategory(
                                            words, _selectedCategory!),
                                        _selectedCategory!,
                                      ),
                  ),
                ],
              );
            },
                  );
                },
              ),
        ),
          ],
        ),
        ),
      ),
    );
  }

  // ── Category selection grid (Image 1) ──────────────────────────────────────
  Widget _buildCategoryGrid(List<String> categories, List<BasicWord> allWords) {
    // Count words per category for badge
    final wordCount = <String, int>{};
    for (final w in allWords.where(
      (word) => _isBasicWordCategory(word) && _hasTutorialVideo(word),
    )) {
      wordCount[w.category] = (wordCount[w.category] ?? 0) + 1;
    }

    final size = MediaQuery.sizeOf(context);
    return GestureDetector(
      onTap: _searchFocusNode.unfocus,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          size.width * 0.06,
          0,
          size.width * 0.06,
          size.height * 0.04,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 18, 14, 2),
                child: Center(
                  child: Text(
                    'Categories',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24 ,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 5,
                          offset: Offset(1, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 700
                        ? 4
                        : constraints.maxWidth >= 460
                            ? 3
                            : 2;
                    final tileWidth = (constraints.maxWidth - 44 -
                            10 * (columns - 1)) /
                        columns;
                    // Keep the same card size while the keyboard is open and
                    // fit about two and a quarter rows in the fixed panel.
                    final tileHeight =
                        (constraints.maxHeight - 24 - 20) / 2.25;
                    return GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: tileWidth / tileHeight,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, i) {
                        final cat = categories[i];
                        final icon =
                            _categoryIcons[cat] ?? Icons.category_outlined;
                        final count = wordCount[cat] ?? 0;
                        return _CategoryTile(
                          label: cat,
                          icon: icon,
                          count: count,
                          onTap: () {
                            _searchFocusNode.unfocus();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BasicWordsScreen(
                                  userName: widget.userName,
                                  initialCategory: cat,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Word list for a selected category ──────────────────────────────────────
  Widget _buildWordList(List<BasicWord> words, String category) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final wordCardHeight = ((screenHeight * (1 - 0.28 - 0.03) - 112) / 2.5)
        .clamp(96.0, 180.0)
        .toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width * 0.08,
        0,
        MediaQuery.sizeOf(context).width * 0.08,
        MediaQuery.sizeOf(context).height * 0.04,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 4, 51, 98).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                const Color.fromARGB(255, 156, 156, 156).withValues(alpha: 0.55),
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
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 36),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _iconForCategory(category),
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _displayCategoryName(category),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 5,
                          offset: Offset(1, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (words.isEmpty)
                _EmptyCategory(category: category, hasQuery: false)
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 9.0;
                    const columns = 3;
                    final itemWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: 12,
                      children: words
                          .map((word) => SizedBox(
                                width: itemWidth,
                                height: wordCardHeight,
                                child: _BasicWordCard(
                                  word: word,
                                  showCategory: false,
                                  onView: () =>
                                      _showWordDetails(context, word),
                                  onWatch: () => _openVideo(word),
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filtered results grouped as category sections while searching ──────────
  Widget _buildSearchResults(List<BasicWord> results, List<String> categories) {
    if (results.isEmpty) {
      return const _EmptyCategory(category: '', hasQuery: true);
    }

    final byCategory = <String, List<BasicWord>>{};
    for (final w in results) {
      byCategory.putIfAbsent(w.category, () => []).add(w);
    }
    final orderedCats = categories.where(byCategory.containsKey).toList();
    for (final c in byCategory.keys) {
      if (!orderedCats.contains(c)) orderedCats.add(c);
    }
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width * 0.12,
        keyboardOpen ? 0 : 14,
        MediaQuery.sizeOf(context).width * 0.12,
        keyboardOpen ? 0 : MediaQuery.sizeOf(context).height * 0.025,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color.fromARGB(181, 88, 170, 248).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                const Color.fromARGB(255, 156, 156, 156).withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: keyboardOpen
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(12, 16, 12, 24),
          children: [
            for (final cat in orderedCats) ...[
              if (!keyboardOpen) ...[
                Row(
                  children: [
                    Icon(
                      _categoryIcons[cat] ?? Icons.category_outlined,
                      color: const Color.fromARGB(255, 14, 0, 137),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cat,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 9.0;
                  final columns = constraints.maxWidth >= 700
                      ? 4
                      : constraints.maxWidth >= 420
                          ? 3
                          : 2;
                  final itemWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 12,
                    children: byCategory[cat]!
                        .map((word) => SizedBox(
                              width: itemWidth,
                              height: 180,
                              child: _BasicWordCard(
                                word: word,
                                // Category headings are hidden while the
                                // keyboard is open to save space, so keep the
                                // category label on each result card instead.
                                showCategory: keyboardOpen,
                                onView: () => _showWordDetails(context, word),
                                onWatch: () => _openVideo(word),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              SizedBox(height: keyboardOpen ? 8 : 20),
            ],
          ],
        ),
      ),
    );
  }

  void _showWordDetails(BuildContext context, BasicWord word) {
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
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                      child: Text(
                        word.title,
                        style: const TextStyle(
                          color: Color(0xFF071A3F),
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 190,
                      width: double.infinity,
                      child: _WordThumbnail(word: word),
                    ),
                    if (word.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                        child: Text(
                          word.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF071A3F),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF185FA5), Color(0xFF0B8FFF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Center(
                        child: _TutorialButton(
                          label: 'VIDEO TUTORIAL',
                          onTap: () {
                            Navigator.of(context).pop();
                            _openVideo(word);
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

// ── Category tile for the grid landing ────────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF72C989), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF12365A).withValues(alpha: 0.28),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 3, 3, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5F0DD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF218E3D),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF176B42).withValues(alpha: 0.20),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 30,
                      color: const Color(0xFF14532D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF14532D),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$count words',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF4B6654),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class _BasicWordCard extends StatelessWidget {
  final BasicWord word;
  final VoidCallback onView;
  final VoidCallback onWatch;
  final bool showCategory;

  const _BasicWordCard({
    required this.word,
    required this.onView,
    required this.onWatch,
    this.showCategory = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(9),
        child: Container(
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
              Expanded(
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
                  child: _WordThumbnail(word: word),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                color: const Color.fromARGB(255, 0, 60, 191),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showCategory) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _iconForCategory(word.category),
                              color: Colors.white,
                              size: 9,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                _displayCategoryName(word.category),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      word.title,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TinyAction(
                          label: 'Watch',
                          icon: Icons.play_circle_outline_rounded,
                          onTap: onWatch,
                          color: kActionGreen,
                        ),
                      ],
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

class _TinyAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _TinyAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = kVividBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 66,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 12),
              const SizedBox(width: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Lightweight static thumbnail — no video init on list, keeps UI fast
class _WordThumbnail extends StatelessWidget {
  final BasicWord word;
  const _WordThumbnail({required this.word});

  @override
  Widget build(BuildContext context) {
    if (word.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: getOptimizedUrl(word.imageUrl, width: 400),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => _PlaceholderThumb(title: word.title),
      );
    }
    if (word.imageAsset.isNotEmpty) {
      return Image.asset(
        word.imageAsset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _PlaceholderThumb(title: word.title),
      );
    }
    // Video-only word: show a static play placeholder — no VideoPlayerController
    return _PlaceholderThumb(title: word.title, showPlay: true);
  }
}

class _PlaceholderThumb extends StatelessWidget {
  final String title;
  final bool showPlay;
  const _PlaceholderThumb({required this.title, this.showPlay = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFDCEDFF),
      child: showPlay
          ? Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF185FA5).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Color(0xFF185FA5),
                  size: 32,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _TutorialButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TutorialButton({
    required this.label,
    required this.onTap,
  });

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
          child: Text(
            label,
            style: const TextStyle(
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

class _EmptyCategory extends StatelessWidget {
  final String category;
  final bool hasQuery;

  const _EmptyCategory({
    required this.category,
    required this.hasQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Text(
        hasQuery
            ? 'No basic words match your search.'
            : 'No videos in $category yet.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
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
            Material(
              color: const Color.fromARGB(255, 20, 74, 190),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onRetry,
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
            ),
          ],
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
