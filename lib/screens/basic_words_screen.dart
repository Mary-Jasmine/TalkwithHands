import 'package:flutter/material.dart';

import '../models/basic_word.dart';
import '../services/basic_word_service.dart';
import '../services/progress_service.dart';
import '../ui/app_shell.dart';
import 'sign_detector_screen.dart';
import 'tutorial_video_screen.dart';

// ── Colour tokens ─────────────────────────────────────────────────────────────
const kVividBlue = Color(0xFF1500C8);
const kAccent = Color(0xFF11B7CB);
const kGreen = Color(0xFF34C759);

const List<String> _knownCategories = [
  'Alphabet',
  'Animal',
  'Color',
  'Days of the week',
  'Direction and Location',
  'Emotion',
  'Emotions',
  'Environment',
  'Family',
  'Feelings',
  'Food',
  'Food Taste',
  'Fruits',
  'Greetings',
  'Health and Emergency',
  'Kitchenware',
  'Money and Shopping',
  'Months',
  'NOT EDIT',
  'Not Edited',
  'Numbers',
  'Operations',
  'Person',
  'Personal Things',
  'Questions',
  'Religion and Values',
  'Responses and Reactions',
  'School',
  'School Supply',
  'Shape',
  'Technology and Communication',
  'Temperature',
  'Time',
  'Transportation',
];

// ── Sign language sets ──────────────────────────────────────────────────────
// Categories shown when the user switches the toggle to "FSL Signs".
const List<String> _fslCategories = [
  'Animal',
  'Color',
  'Days of the week',
  'Emotions',
  'Fruits',
  'Months',
  'Person',
  'Questions',
  'School',
];

enum SignLanguage { asl, fsl }

const Map<String, IconData> _categoryIcons = {
  'Alphabet': Icons.abc_rounded,
  'Animal': Icons.pets_rounded,
  'Color': Icons.palette_outlined,
  'Days of the week': Icons.calendar_view_week_outlined,
  'Direction and Location': Icons.explore_outlined,
  'Emotion': Icons.sentiment_satisfied_alt_outlined,
  'Emotions': Icons.sentiment_satisfied_alt_outlined,
  'Environment': Icons.park_outlined,
  'Family': Icons.family_restroom_rounded,
  'Feelings': Icons.favorite_border_rounded,
  'Food': Icons.restaurant_outlined,
  'Food Taste': Icons.local_dining_outlined,
  'Fruits': Icons.apple_outlined,
  'Greetings': Icons.waving_hand_outlined,
  'Health and Emergency': Icons.medical_services_outlined,
  'Kitchenware': Icons.blender_outlined,
  'Money and Shopping': Icons.shopping_cart_outlined,
  'Months': Icons.calendar_month_outlined,
  'NOT EDIT': Icons.block_outlined,
  'Not Edited': Icons.block_outlined,
  'Numbers': Icons.tag_rounded,
  'Operations': Icons.calculate_outlined,
  'Person': Icons.person_outline_rounded,
  'Personal Things': Icons.person_outline_rounded,
  'Questions': Icons.help_outline_rounded,
  'Religion and Values': Icons.auto_awesome_outlined,
  'Responses and Reactions': Icons.thumbs_up_down_outlined,
  'School': Icons.school_outlined,
  'School Supply': Icons.backpack_outlined,
  'Shape': Icons.category_outlined,
  'Technology and Communication': Icons.devices_outlined,
  'Temperature': Icons.thermostat_rounded,
  'Time': Icons.schedule_outlined,
  'Transportation': Icons.directions_car_outlined,
};

class BasicWordsScreen extends StatefulWidget {
  final String userName;

  const BasicWordsScreen({
    super.key,
    required this.userName,
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

  // null = show category landing grid; non-null = show word list for that category
  String? _selectedCategory;
  SignLanguage _signLanguage = SignLanguage.asl;

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
    _wordFuture = BasicWordService().listBasicWords();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      setState(() {
        _query = q;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _wordFuture = BasicWordService().listBasicWords();
      });

  List<String> _categories(List<BasicWord> words) {
    final cats = <String>{..._knownCategories};
    for (final w in words) {
      if (w.category.trim().isNotEmpty) cats.add(w.category);
    }
    final filtered = cats.where((c) {
      final isFsl = _fslCategories.contains(c);
      return _signLanguage == SignLanguage.fsl ? isFsl : !isFsl;
    });
    return filtered.toList()..sort();
  }

  List<BasicWord> _wordsForCategory(List<BasicWord> words, String category) =>
      words.where((w) => w.category == category).toList();

  List<BasicWord> _searchResults(List<BasicWord> words) {
    if (_query.isEmpty) return [];
    return words.where((w) {
      final isFsl = _fslCategories.contains(w.category);
      final matchesLanguage =
          _signLanguage == SignLanguage.fsl ? isFsl : !isFsl;
      if (!matchesLanguage) return false;
      return w.title.toLowerCase().contains(_query) ||
          w.category.toLowerCase().contains(_query) ||
          w.description.toLowerCase().contains(_query);
    }).toList();
  }

  void _openVideo(BasicWord word) {
    _recordLearned(word);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TutorialVideoScreen(
        title: word.title,
        videoAsset: word.videoAsset,
        videoUrl: word.videoUrl,
        activityCategory: 'basic_word',
      ),
    ));
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Basic Words',
      ),
      body: AppBackground(
        child: SafeArea(
          child: FutureBuilder<List<BasicWord>>(
            future: _wordFuture,
            builder: (context, snapshot) {
              final words = snapshot.data ?? [];
              final categories = _categories(words);
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final hasError = snapshot.hasError;

              return Column(
                children: [
                  AppTopBar(
                    onBack: _selectedCategory != null
                        ? () => setState(() => _selectedCategory = null)
                        : () => Navigator.of(context).pop(),
                    onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 2, bottom: 14),
                    child: Text(
                      'BASIC WORDS',
                      style: TextStyle(
                        color: Color(0xFF1500C8),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),

                  // ── ASL / FSL switch ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFFCCCCCC), width: 1.4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SignLanguageOption(
                              label: 'ASL Signs',
                              selected: _signLanguage == SignLanguage.asl,
                              onTap: () => setState(() {
                                _signLanguage = SignLanguage.asl;
                                _selectedCategory = null;
                              }),
                            ),
                            _SignLanguageOption(
                              label: 'FSL Signs',
                              selected: _signLanguage == SignLanguage.fsl,
                              onTap: () => setState(() {
                                _signLanguage = SignLanguage.fsl;
                                _selectedCategory = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Search bar ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _query.isNotEmpty
                                    ? kVividBlue
                                    : const Color(0xFFCCCCCC),
                                width: 1.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14),
                                  child: Icon(Icons.search_rounded,
                                      color: Color(0xFF9DA4AD), size: 22),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    style: const TextStyle(
                                        color: Colors.black87, fontSize: 14),
                                    decoration: const InputDecoration(
                                      hintText: 'Search words here...',
                                      hintStyle:
                                          TextStyle(color: Color(0xFF9DA4AD)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 0, vertical: 7),
                                    ),
                                  ),
                                ),
                                if (_query.isNotEmpty)
                                  GestureDetector(
                                    onTap: _clearSearch,
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 14),
                                      child: Icon(Icons.close_rounded,
                                          color: Color(0xFF9DA4AD), size: 20),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Practice button
                        Material(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const SignDetectorScreen(),
                              ));
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 40,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
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
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

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
          ),
        ),
      ),
    );
  }

  // ── Category selection grid (Image 1) ──────────────────────────────────────
  Widget _buildCategoryGrid(List<String> categories, List<BasicWord> allWords) {
    // Count words per category for badge
    final wordCount = <String, int>{};
    for (final w in allWords) {
      wordCount[w.category] = (wordCount[w.category] ?? 0) + 1;
    }

    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 21, top: 7),
              child: Text(
                'Categories',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.72,
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
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Word list for a selected category ──────────────────────────────────────
  Widget _buildWordList(List<BasicWord> words, String category) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 14, 15, 10),
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
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _categoryIcons[category] ?? Icons.category_outlined,
                    color: const Color.fromARGB(255, 14, 0, 137),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    category,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      
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
                                height: 160,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 14, 15, 10),
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
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
          children: [
            for (final cat in orderedCats) ...[
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
                    children: byCategory[cat]!
                        .map((word) => SizedBox(
                              width: itemWidth,
                              height: 160,
                              child: _BasicWordCard(
                                word: word,
                                showCategory: false,
                                onView: () => _showWordDetails(context, word),
                                onWatch: () => _openVideo(word),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
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
                  border: Border.all(color: kAccent, width: 2),
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
                      color: const Color(0xFF11B7CB),
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

// ── ASL / FSL toggle pill option ───────────────────────────────────────────
class _SignLanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SignLanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kVividBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF9DA4AD),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBBDDBB), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                    width: 1.2),
              ),
              child: Icon(icon, size: 24, color: const Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFD7FF), width: 1.5),
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
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFEFF6FF),
                  child: _WordThumbnail(word: word),
                ),
              ),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF185FA5), Color(0xFF0B8FFF)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
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
                              _categoryIcons[word.category] ??
                                  Icons.category_outlined,
                              color: Colors.white,
                              size: 9,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                word.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const SizedBox(width: 6),
                        Expanded(
                          child: _TinyAction(
                            label: 'Watch',
                            icon: Icons.play_circle_outline_rounded,
                            onTap: onWatch,
                            color: Color(0xFF1E8C3A),
                          ),
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
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 11),
              const SizedBox(width: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
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
      return Image.network(
        word.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _PlaceholderThumb(title: word.title),
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
      color: const Color(0xFFF2A8E8),
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
            border: Border.all(color: const Color(0xFF72326E), width: 2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
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