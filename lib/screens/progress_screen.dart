import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/user_progress.dart';
import '../services/progress_service.dart';
import '../ui/app_shell.dart';

// ── Colour tokens (same as alphabets/numbers) ─────────────────────────────────
const kVividBlue = Color(0xFF1500C8);
const kAccent = Color(0xFF11B7CB);
const kGreen = Color(0xFF34C759);
const kCardBlue = Color(0xFF2563EB);

// ── Iconify helper ────────────────────────────────────────────────────────────
// Uses the Iconify API: https://api.iconify.design/{prefix}/{name}.svg
// Browse icons at https://icon-sets.iconify.design
class _IIcon extends StatelessWidget {
  final String icon; // e.g. 'mdi:fire'
  final double size;
  final Color? color;

  const _IIcon(this.icon, {this.size = 24, this.color});

  String get _url {
    final parts = icon.split(':');
    final prefix = parts[0];
    final name = parts[1];
    final colorHex = color != null
        ? '%23${color!.toARGB32().toRadixString(16).substring(2)}'
        : '%23ffffff';
    return 'https://api.iconify.design/$prefix/$name.svg?color=$colorHex';
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.network(
      _url,
      width: size,
      height: size,
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}

class ProgressScreen extends StatefulWidget {
  final String userName;

  const ProgressScreen({
    super.key,
    required this.userName,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ProgressService _progressService;
  late Future<UserProgress> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressService = ProgressService();
    _progressFuture = _progressService.getProgress();
  }

  Future<void> _refreshProgress() async {
    final future = _progressService.getProgress();
    setState(() {
      _progressFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        onClose: () => Navigator.of(context).pop(),
        activeScreen: 'Progress',
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ───────────────────────────────────────────────────
              AppTopBar(
                onBack: () => Navigator.of(context).pop(),
                onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),

              // ── Title ─────────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 10),
                child: Text(
                  'PROGRESS',
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

              // ── Character banner ───────────────────────────────────────────
              SizedBox(
                height: 110,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      left: 64,
                      top: 8,
                      child: _FloatingIcon(
                          icon: 'noto:trophy', size: 25),
                    ),
                    const Positioned(
                      left: 25,
                      bottom: 10,
                      child: _FloatingIcon(
                          icon: 'noto:star', size: 18),
                    ),
                    const Positioned(
                      right: 48,
                      bottom: 10,
                      child: _FloatingIcon(
                          icon: 'noto:sparkles', size: 16),
                    ),
                    const Positioned(
                      left: 90,
                      top: 4,
                      child: _FloatingIcon(
                          icon: 'noto:dizzy', size: 14),
                    ),
                    Center(
                      child: Image.asset(
                        'assets/images/characters.png',
                        height: 110,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const _AvatarFigure(height: 100),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Main content panel ─────────────────────────────────────────
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
                    child: RefreshIndicator(
                      onRefresh: _refreshProgress,
                      child: FutureBuilder<UserProgress>(
                        future: _progressFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _ProgressLoading();
                          }
                          if (snapshot.hasError || snapshot.data == null) {
                            return _ProgressError(
                              onRetry: _refreshProgress,
                            );
                          }
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                            child: _ProgressContent(
                              firstName: _firstName,
                              progress: snapshot.data!,
                            ),
                          );
                        },
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

  String get _firstName {
    final parts = (widget.userName).trim().split(' ');
    return parts.isNotEmpty ? parts.first : widget.userName;
  }
}

// ── Floating emoji ────────────────────────────────────────────────────────────
class _ProgressContent extends StatelessWidget {
  final String firstName;
  final UserProgress progress;

  const _ProgressContent({required this.firstName, required this.progress});

  @override
  Widget build(BuildContext context) {
    final stats = progress.stats;
    final usage = progress.usage;
    final monthly = progress.monthlyActivity;

    return Column(
      children: [
        _WelcomeCard(firstName: firstName),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StatBadge(
                icon: 'mdi:book-open-page-variant',
                value: stats.totalSigns > 0
                    ? '${stats.signsLearned}/${stats.totalSigns}'
                    : stats.signsLearned.toString(),
                label: 'Signs\nLearned',
                color: kCardBlue,
              ),
              const SizedBox(width: 8),
              _StatBadge(
                icon: 'mdi:gamepad-variant',
                value: stats.gamesPlayed.toString(),
                label: 'Games\nPlayed',
                color: const Color(0xFF8B3FBE),
              ),
              const SizedBox(width: 8),
              _StreakBadge(days: stats.streakDays),
              const SizedBox(width: 8),
              _StatBadge(
                icon: 'mdi:timer-outline',
                value: _formatDuration(stats.secondsSpent),
                label: 'Time\nSpent',
                color: const Color(0xFFE0317A),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SlidingChartRow(usage: usage, monthly: monthly),
        if (stats.signsLearned == 0 &&
            stats.gamesPlayed == 0 &&
            stats.secondsSpent == 0) ...[
          const SizedBox(height: 14),
          const _EmptyProgressCard(),
        ],
      ],
    );
  }
}


// ── Sliding chart row (Most Used + Monthly Activity) ─────────────────────────
class _SlidingChartRow extends StatefulWidget {
  final List<ProgressUsageItem> usage;
  final List<MonthlyProgressPoint> monthly;

  const _SlidingChartRow({required this.usage, required this.monthly});

  @override
  State<_SlidingChartRow> createState() => _SlidingChartRowState();
}

class _SlidingChartRowState extends State<_SlidingChartRow> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  // Donut tap state
  int? _selectedDonutIndex;

  // Line chart tap state
  int? _selectedLineIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _SectionCard(
        title: const _SectionTitle(
          icon: 'mdi:chart-donut',
          label: 'Most Used',
        ),
        child: Row(
          children: [
            _TappableDonut(
              usage: widget.usage,
              selectedIndex: _selectedDonutIndex,
              onTap: (idx) => setState(() {
                _selectedDonutIndex = (_selectedDonutIndex == idx) ? null : idx;
              }),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.usage.length; i++) ...[
                    _LegendDot(
                      color: _usageColors[i % _usageColors.length],
                      label: '${widget.usage[i].label} (${widget.usage[i].count})',
                      highlighted: _selectedDonutIndex == i,
                    ),
                    if (i != widget.usage.length - 1) const SizedBox(height: 10),
                  ],
                  if (widget.usage.isEmpty)
                    const Text(
                      'No activity recorded yet.',
                      style: TextStyle(color: Color(0xFF5B6371), fontSize: 13),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      _SectionCard(
        title: const _SectionTitle(
          icon: 'mdi:chart-line',
          label: 'Monthly Activity',
        ),
        child: _TappableLineChart(
          monthly: widget.monthly,
          selectedIndex: _selectedLineIndex,
          onTap: (idx) => setState(() {
            _selectedLineIndex = (_selectedLineIndex == idx) ? null : idx;
          }),
        ),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pageController,
            itemCount: pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: pages[index],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pages.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? kAccent
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String firstName;

  const _WelcomeCard({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color.fromARGB(102, 20, 0, 200), Color.fromARGB(204, 74, 47, 224), Color(0xFF11B7CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1500C8).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Icon(Icons.waving_hand, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kumusta, $firstName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Keep up the great work!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IIcon('noto:star', size: 13),
                SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int days;

  const _StreakBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C00), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C00).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _IIcon('noto:fire', size: 20),
          const SizedBox(height: 4),
          Text(
            days.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Streak',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLoading extends StatelessWidget {
  const _ProgressLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

class _ProgressError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ProgressError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          title: const _SectionTitle(
            icon: 'mdi:alert-circle-outline',
            label: 'Progress unavailable',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Could not load your progress. Check your connection and try again.',
                style: TextStyle(color: Color(0xFF5B6371), height: 1.3),
              ),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyProgressCard extends StatelessWidget {
  const _EmptyProgressCard();

  @override
  Widget build(BuildContext context) {
    // ignore: prefer_const_constructors
    return _SectionCard(
      title: const _SectionTitle(
        icon: 'mdi:emoticon-sad-outline',
        label: 'No saved activity yet',
      ),
      child: const Text(
        'Start learning signs or playing games and your progress will appear here after it is recorded.',
        style: TextStyle(color: Color(0xFF5B6371), height: 1.3),
      ),
    );
  }
}

String _formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '${minutes}m';
  final hours = seconds / 3600;
  return hours >= 10 ? '${hours.round()}h' : '${hours.toStringAsFixed(1)}h';
}

const _usageColors = [
  Color(0xFF2DA6F2),
  Color(0xFF4BDD74),
  Color(0xFFB66AE8),
  Color(0xFFF3B144),
];

class _FloatingIcon extends StatelessWidget {
  final String icon;
  final double size;
  const _FloatingIcon({required this.icon, required this.size});
  @override
  Widget build(BuildContext context) =>
      _IIcon(icon, size: size);
}

// ── Stat badge ────────────────────────────────────────────────────────────────
class _StatBadge extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) { 
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IIcon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final Widget title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6D6D6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 1),
          child,
        ],
      ),
    );
  }
}

// ── Section card title with icon ──────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IIcon(icon, size: 18, color: kVividBlue),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: kVividBlue,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ── Avatar figure (fallback) ──────────────────────────────────────────────────
class _AvatarFigure extends StatelessWidget {
  final double height;
  const _AvatarFigure({this.height = 300});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 0.6,
      height: height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 180,
          height: 300,
          child: CustomPaint(painter: _AvatarPainter()),
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final skin = Paint()..color = const Color(0xFFFF9A6A);
    final shirt = Paint()..color = const Color.fromARGB(255, 36, 110, 119);
    final pants = Paint()..color = const Color.fromARGB(255, 100, 105, 124);
    final hair = Paint()..color = const Color.fromARGB(25, 5, 5, 4);
    final shoe = Paint()..color = const Color(0xFFF0A51A);
    final stroke = Paint()
      ..color = const Color.fromARGB(255, 179, 93, 58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cx = size.width / 2;
    canvas.drawCircle(Offset(cx, 45), 34, skin);
    final hairPath = Path()
      ..moveTo(cx - 40, 44)
      ..quadraticBezierTo(cx - 25, 0, cx + 30, 20)
      ..quadraticBezierTo(cx + 45, 85, cx + 46, 85)
      ..lineTo(cx - 45, 76)
      ..close();
    canvas.drawPath(hairPath, hair);
    canvas.drawCircle(Offset(cx - 12, 44), 5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + 12, 44), 5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx - 12, 44), 2.4, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(cx + 12, 44), 2.4, Paint()..color = Colors.black);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, 56), width: 26, height: 16),
      0,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF7A4035)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, 92), width: 18, height: 29), skin);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, 150), width: 90, height: 120),
        const Radius.circular(24),
      ),
      shirt,
    );
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx - 54, 160), width: 18, height: 100),
        skin);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx + 54, 160), width: 18, height: 100),
        skin);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx - 18, 246), width: 26, height: 112),
        pants);
    canvas.drawRect(
        Rect.fromCenter(center: Offset(cx + 18, 246), width: 26, height: 112),
        pants);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx - 18, 292), width: 34, height: 16),
            const Radius.circular(8)),
        shoe);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(cx + 18, 292), width: 34, height: 16),
            const Radius.circular(8)),
        shoe);
    canvas.drawLine(Offset(cx - 56, 210), Offset(cx - 62, 242), stroke);
    canvas.drawLine(Offset(cx + 56, 210), Offset(cx + 62, 242), stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Legend dot ────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool highlighted;
  const _LegendDot({required this.color, required this.label, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: highlighted
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
          : EdgeInsets.zero,
      decoration: highlighted
          ? BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: highlighted ? 14 : 12,
            height: highlighted ? 14 : 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: highlighted
                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: highlighted ? color : const Color(0xFF5B6371),
                fontSize: highlighted ? 14 : 13,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tappable donut widget ─────────────────────────────────────────────────────
class _TappableDonut extends StatelessWidget {
  final List<ProgressUsageItem> usage;
  final int? selectedIndex;
  final ValueChanged<int?> onTap;

  const _TappableDonut({
    required this.usage,
    required this.selectedIndex,
    required this.onTap,
  });

  int? _hitTest(Offset localPos, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2.4;
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < radius - 16 || dist > radius + 16) return null;

    final total = usage.fold<int>(0, (sum, item) => sum + item.count);
    if (total <= 0) return null;

    var angle = math.atan2(dy, dx);
    angle = (angle + math.pi / 2 + math.pi * 2) % (math.pi * 2);

    var start = 0.0;
    for (var i = 0; i < usage.length; i++) {
      final sweep = math.pi * 2 * (usage[i].count / total);
      if (angle >= start && angle < start + sweep) return i;
      start += sweep;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        final idx = _hitTest(local, box.size);
        if (idx != null) onTap(selectedIndex == idx ? null : idx);
      },
      child: SizedBox(
        width: 100,
        height: 100,
        child: CustomPaint(
          painter: _DonutPainter(usage, selectedIndex: selectedIndex),
        ),
      ),
    );
  }
}

// ── Donut painter ─────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<ProgressUsageItem> usage;
  final int? selectedIndex;

  const _DonutPainter(this.usage, {this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.width / 2.4;
    final total = usage.fold<int>(0, (sum, item) => sum + item.count);

    if (total <= 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: baseRadius),
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..color = const Color(0xFFE7EBF2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26,
      );
      return;
    }

    var start = -math.pi / 2;
    for (var i = 0; i < usage.length; i++) {
      final sweep = math.pi * 2 * (usage[i].count / total);
      final isSelected = selectedIndex == i;
      final radius = isSelected ? baseRadius + 4 : baseRadius;
      final strokeWidth = isSelected ? 30.0 : 26.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        Paint()
          ..color = _usageColors[i % _usageColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );

      // Draw percentage label on the selected segment
      if (isSelected) {
        final pct = (usage[i].count / total * 100).round();
        final midAngle = start + sweep / 2;
        final labelRadius = radius + strokeWidth / 2 + 14;
        final labelX = center.dx + labelRadius * math.cos(midAngle);
        final labelY = center.dy + labelRadius * math.sin(midAngle);

        final tp = TextPainter(
          text: TextSpan(
            text: '$pct%',
            style: TextStyle(
              color: _usageColors[i % _usageColors.length],
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // White pill background
        final rect = Rect.fromCenter(
          center: Offset(labelX, labelY),
          width: tp.width + 8,
          height: tp.height + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = Colors.white.withValues(alpha: 0.95),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()
            ..color = _usageColors[i % _usageColors.length].withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );

        tp.paint(canvas, Offset(labelX - tp.width / 2, labelY - tp.height / 2));

        // Draw percentage in center of donut
        final centerTp = TextPainter(
          text: TextSpan(
            text: '$pct%',
            style: TextStyle(
              color: _usageColors[i % _usageColors.length],
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        centerTp.paint(
          canvas,
          Offset(
            center.dx - centerTp.width / 2,
            center.dy - centerTp.height / 2,
          ),
        );
      }

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex || oldDelegate.usage != usage;
}

// ── Tappable line chart widget ────────────────────────────────────────────────
class _TappableLineChart extends StatelessWidget {
  final List<MonthlyProgressPoint> monthly;
  final int? selectedIndex;
  final ValueChanged<int?> onTap;

  const _TappableLineChart({
    required this.monthly,
    required this.selectedIndex,
    required this.onTap,
  });

  int? _hitTest(Offset localPos, Size size) {
    if (monthly.isEmpty) return null;
    final maxEvents = monthly.fold<int>(1, (max, p) => p.events > max ? p.events : max);
    int? nearest;
    double minDist = 24;
    for (var i = 0; i < monthly.length; i++) {
      final x = monthly.length == 1
          ? size.width / 2
          : size.width * i / (monthly.length - 1);
      final y = size.height * 0.84 -
          (size.height * 0.68 * (monthly[i].events / maxEvents));
      final dist = (localPos - Offset(x, y)).distance;
      if (dist < minDist) {
        minDist = dist;
        nearest = i;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        // Offset for the 150-height chart area (labels are below)
        final chartLocal = Offset(local.dx, local.dy);
        final idx = _hitTest(chartLocal, Size(box.size.width, 150));
        if (idx != null) onTap(selectedIndex == idx ? null : idx);
      },
      child: SizedBox(
        height: 150,
        child: CustomPaint(
          painter: _LineChartPainter(monthly, selectedIndex: selectedIndex),
          child: SizedBox.expand(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 126),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < monthly.length; i++)
                      Text(
                        monthly[i].month,
                        style: TextStyle(
                          color: selectedIndex == i
                              ? kAccent
                              : const Color(0xFF5B6371),
                          fontSize: 10,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Line chart painter ────────────────────────────────────────────────────────
class _LineChartPainter extends CustomPainter {
  final List<MonthlyProgressPoint> points;
  final int? selectedIndex;

  const _LineChartPainter(this.points, {this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE7EBF2)
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = const Color(0xFFC9D0DC)
      ..strokeWidth = 1.2;
    final line = Paint()
      ..color = kAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 0; i < 4; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), axis);

    if (points.isEmpty) return;

    final maxEvents = points.fold<int>(
      1,
      (max, point) => point.events > max ? point.events : max,
    );
    final chartPoints = <Offset>[
      for (var i = 0; i < points.length; i++)
        Offset(
          points.length == 1
              ? size.width / 2
              : size.width * i / (points.length - 1),
          size.height * 0.84 -
              (size.height * 0.68 * (points[i].events / maxEvents)),
        ),
    ];

    final path = Path()..moveTo(chartPoints.first.dx, chartPoints.first.dy);
    for (final p in chartPoints.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);

    for (var i = 0; i < chartPoints.length; i++) {
      final p = chartPoints[i];
      final isSelected = selectedIndex == i;
      if (isSelected) {
        // Glow ring
        canvas.drawCircle(
          p,
          10,
          Paint()..color = kAccent.withValues(alpha: 0.2),
        );
      }
      canvas.drawCircle(p, isSelected ? 7 : 5, Paint()..color = kAccent);
      canvas.drawCircle(p, isSelected ? 4 : 3, Paint()..color = Colors.white);

      if (isSelected) {
        // Draw tooltip above the point
        final label = '${points[i].events}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        const padding = 6.0;
        final tooltipW = tp.width + padding * 2;
        final tooltipH = tp.height + padding * 1.5;
        var tooltipX = p.dx - tooltipW / 2;
        // Keep within bounds
        tooltipX = tooltipX.clamp(0, size.width - tooltipW);
        final tooltipY = p.dy - tooltipH - 10;

        final tooltipRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(tooltipX, tooltipY.clamp(0, size.height - tooltipH),
              tooltipW, tooltipH),
          const Radius.circular(8),
        );
        canvas.drawRRect(tooltipRect, Paint()..color = kAccent);

        // Arrow
        final arrowX = p.dx.clamp(tooltipX + 6, tooltipX + tooltipW - 6);
        final arrowTop = tooltipRect.bottom;
        final arrowPath = Path()
          ..moveTo(arrowX - 5, arrowTop)
          ..lineTo(arrowX + 5, arrowTop)
          ..lineTo(arrowX, arrowTop + 5)
          ..close();
        canvas.drawPath(arrowPath, Paint()..color = kAccent);

        tp.paint(
          canvas,
          Offset(tooltipX + padding,
              tooltipRect.top + (tooltipH - tp.height) / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex || oldDelegate.points != points;
}