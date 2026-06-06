import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../ui/app_shell.dart';

void main() {
  runApp(const GuessASLApp());
}

class GuessASLApp extends StatelessWidget {
  const GuessASLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GUESS ASL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A3FFF)),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

const kElectricBlue = Color(0xFF1A6BFF);
const kDeepNavy = Color(0xFF03104A);
const kAccentCyan = Color(0xFF00E5FF);
const kAccentGold = Color(0xFFFFD93D);
const kRed = Color(0xFFFF4E4E);
const kGreen = Color(0xFF22C55E);
const kGlassBorder = Color(0x66FFFFFF);

const List<String> kAlphabetPool = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

const List<String> kNumberPool = [
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  '11',
  '12',
  '13',
  '14',
  '15',
];

enum GameMode { alphabets, numbers }

class ScoreBoard {
  static int todayBest = 0;
  static int weekBest = 0;
  static int allTimeBest = 0;

  static void submit(int score) {
    if (score > todayBest) todayBest = score;
    if (score > weekBest) weekBest = score;
    if (score > allTimeBest) allTimeBest = score;
  }
}

class ArcadeBackground extends StatelessWidget {
  final Widget child;
  const ArcadeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1F6E), kDeepNavy, Color(0xFF041235)],
        ),
      ),
      child: CustomPaint(painter: _StripePainter(), child: child),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0A1A6BFF)
      ..strokeWidth = 28
      ..style = PaintingStyle.stroke;
    for (double x = -size.height; x < size.width + size.height; x += 52) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => false;
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? const Color(0xBBFFFFFF),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: kGlassBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 24,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAME SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class GameScreen extends StatefulWidget {
  final VoidCallback? onExit;
  final void Function({
    required bool won,
    required int score,
    required int completed,
    required int total,
  })? onGameFinished;

  const GameScreen({super.key, this.onExit, this.onGameFinished});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int kMaxLives = 3;
  static const int kStartTime = 25;
  static const int kNumChoices = 5;
  static const int kMaxHints = 3;

  GameMode _gameMode = GameMode.alphabets;
  late List<GameMode> _modeOrder;
  int _modeIndex = 0;
  bool _modeLocked = false;
  bool _showStartPrompt = true;

  int _lives = kMaxLives;
  int _score = 0;
  int _timeLeft = kStartTime;
  bool _gameOver = false;
  bool _gameWon = false;
  int _hintsLeft = kMaxHints;

  // ── Unique-item queue ───────────────────────────────────────────────────────
  late List<String> _remainingLetters;
  int _completedCount = 0; // how many letters correctly answered this session

  late String _roundLetter;
  late List<String> _choices;
  String? _selectedChoice;
  final Set<String> _eliminated = {};

  Timer? _timer;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _popCtrl;
  late Animation<double> _popScale;
  late AnimationController _winPopCtrl;
  late Animation<double> _winPopScale;
  late AnimationController _imageRevealCtrl;
  late AnimationController _hintPulseCtrl;
  late AnimationController _startPromptCtrl;
  late Animation<double> _startPromptScale;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);

    _popCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _popScale = CurvedAnimation(parent: _popCtrl, curve: Curves.elasticOut);

    _winPopCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _winPopScale =
        CurvedAnimation(parent: _winPopCtrl, curve: Curves.elasticOut);

    _imageRevealCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _hintPulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
        lowerBound: 0.92,
        upperBound: 1.0)
      ..repeat(reverse: true);

    _startPromptCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _startPromptScale = CurvedAnimation(
      parent: _startPromptCtrl,
      curve: Curves.easeOutBack,
    );

    _modeOrder = [GameMode.alphabets, GameMode.numbers];
    _initLetterQueue();
    _setupRound();
    _startPromptCtrl.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    _popCtrl.dispose();
    _winPopCtrl.dispose();
    _imageRevealCtrl.dispose();
    _hintPulseCtrl.dispose();
    _startPromptCtrl.dispose();
    super.dispose();
  }

  // ── LETTER QUEUE ─────────────────────────────────────────────────────────────
  List<String> get _currentPool =>
      _gameMode == GameMode.alphabets ? kAlphabetPool : kNumberPool;

  void _initLetterQueue() {
    _remainingLetters = List<String>.from(_currentPool)..shuffle(Random());
    _completedCount = 0;
  }

  void _selectGameMode(GameMode mode) {
    if (_modeLocked) return;

    _timer?.cancel();
    final other =
        mode == GameMode.alphabets ? GameMode.numbers : GameMode.alphabets;

    _modeOrder = [mode, other];
    _modeIndex = 0;

    _startPromptCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _showStartPrompt = false;
        _modeLocked = true;
        _gameMode = mode;
        _lives = kMaxLives;
        _score = 0;
        _timeLeft = kStartTime;
        _gameOver = false;
        _gameWon = false;
        _hintsLeft = kMaxHints;
      });
      _initLetterQueue();
      _setupRound();
      _startTimer();
    });
  }

  // ── ROUND SETUP ─────────────────────────────────────────────────────────────
  void _setupRound() {
    // Pull next unique letter from queue (it was already removed on correct answer,
    // so the front of the list is always the current letter until answered correctly)
    _roundLetter = _remainingLetters.first;
    _choices = _generateChoices(_roundLetter);
    _selectedChoice = null;
    _eliminated.clear();
    _imageRevealCtrl.forward(from: 0);
  }

  List<String> _generateChoices(String correct) {
    final rng = Random();
    final pool = List<String>.from(_currentPool)..remove(correct);
    pool.shuffle(rng);
    final distractors = pool.take(kNumChoices - 1).toList();
    return ([correct, ...distractors]..shuffle(rng));
  }

  // ── HINT ─────────────────────────────────────────────────────────────────────
  void _useHint() {
    if (_hintsLeft <= 0 || _selectedChoice != null || _gameOver || _gameWon) {
      return;
    }

    final wrong = _choices
        .where((c) => c != _roundLetter && !_eliminated.contains(c))
        .toList();

    if (wrong.isEmpty) return;

    wrong.shuffle(Random());
    final toRemove = wrong.take(2).toList();

    setState(() {
      _eliminated.addAll(toRemove);
      _hintsLeft--;
    });
  }

  // ── TIMER ────────────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_gameOver || _gameWon) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _triggerGameOver();
        }
      });
    });
  }

  // ── ANSWER ───────────────────────────────────────────────────────────────────
  void _onChoiceTap(String choice) {
    if (_selectedChoice != null || _gameOver || _gameWon) return;
    if (_eliminated.contains(choice)) return;

    final correct = choice == _roundLetter;

    setState(() {
      _selectedChoice = choice;
      if (correct) {
        _score += 10 + _timeLeft;
      } else {
        _lives--;
        _shakeCtrl.forward(from: 0).then((_) => _shakeCtrl.reset());
      }
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;

      if (!correct && _lives <= 0) {
        _triggerGameOver();
        return;
      }

      if (correct) {
        // Advance the queue
        _remainingLetters.removeAt(0);
        _completedCount++;

        if (_remainingLetters.isEmpty) {
          // Player answered every letter — they win!
          _triggerWin();
          return;
        }
      }

      // Wrong answer but still has lives → retry same letter (don't advance queue)
      // Correct answer with letters remaining → move to next letter
      setState(() {
        _timeLeft = kStartTime;
        _setupRound();
      });
    });
  }

  void _triggerGameOver() {
    if (_gameOver || _gameWon) return;
    _timer?.cancel();
    ScoreBoard.submit(_score);
    widget.onGameFinished?.call(
      won: false,
      score: _score,
      completed: _completedCount,
      total: _currentPool.length,
    );
    setState(() => _gameOver = true);
    _popCtrl.forward(from: 0);
  }

  void _triggerWin() {
    if (_gameOver || _gameWon) return;
    _timer?.cancel();
    ScoreBoard.submit(_score);
    widget.onGameFinished?.call(
      won: true,
      score: _score,
      completed: _completedCount,
      total: _currentPool.length,
    );
    setState(() => _gameWon = true);
    _winPopCtrl.forward(from: 0);
  }

  void _advanceSection() {
    _winPopCtrl.reverse().then((_) {
      if (!mounted) return;
      _modeIndex++;
      _gameMode = _modeOrder[_modeIndex];
      setState(() {
        _lives = kMaxLives;
        _timeLeft = kStartTime;
        _gameOver = false;
        _gameWon = false;
        _hintsLeft = kMaxHints;
      });
      _initLetterQueue();
      _setupRound();
      _startTimer();
    });
  }

  void _restart() {
    // Dismiss whichever modal is showing
    final isWin = _gameWon;
    final ctrl = isWin ? _winPopCtrl : _popCtrl;

    ctrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _lives = kMaxLives;
        _score = 0;
        _timeLeft = kStartTime;
        _gameOver = false;
        _gameWon = false;
        _hintsLeft = kMaxHints;
        _modeLocked = false;
        _showStartPrompt = true;
        _modeOrder = [GameMode.alphabets, GameMode.numbers];
        _modeIndex = 0;
        _gameMode = _modeOrder[_modeIndex];
      });
      _initLetterQueue();
      _setupRound();
      _startPromptCtrl.forward(from: 0);
    });
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 650;
    final maxW = isWide ? 480.0 : size.width;

    return Scaffold(
      body: PopScope(
        canPop: !_showStartPrompt,
        child: ArcadeBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          _buildTopBar(),
                          const SizedBox(height: 10),
                          _buildProgressBar(),
                          const SizedBox(height: 10),
                          _buildHeader(),
                          const SizedBox(height: 10),
                          _buildModeSelector(),
                          const SizedBox(height: 14),
                          Expanded(child: _buildImageCard()),
                          const SizedBox(height: 16),
                          _buildHintBar(),
                          const SizedBox(height: 14),
                          _buildChoices(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_gameOver) _buildGameOverOverlay(),
                if (_gameWon) _buildWinOverlay(),
                if (_showStartPrompt) _buildStartPromptOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 20,
      child: Row(
        children: [
          if (widget.onExit != null) ...[
            AppBackIconButton(
              onTap: widget.onExit!,
              size: 34,
            ),
            const SizedBox(width: 10),
          ],
          Row(
            children: List.generate(kMaxLives, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    i < _lives
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey('${i}_$_lives'),
                    color: i < _lives ? kRed : Colors.grey.shade300,
                    size: 26,
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          Column(
            children: [
              const Text(
                'SCORE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: kDeepNavy,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '$_score',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: kDeepNavy,
                ),
              ),
            ],
          ),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _timeLeft <= 5 ? kRed : kElectricBlue,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: (_timeLeft <= 5 ? kRed : kElectricBlue)
                      .withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  'TIME: 0:${_timeLeft.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PROGRESS BAR ─────────────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    final total = _currentPool.length;
    final completed = _completedCount;
    final progress = completed / total;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('📋 ', style: TextStyle(fontSize: 13)),
                  Text(
                    'PROGRESS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: kDeepNavy.withValues(alpha: 0.55),
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Text(
                  '$completed / $total Completed',
                  key: ValueKey(completed),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: kDeepNavy,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (ctx, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: kDeepNavy.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    value < 0.5 ? kElectricBlue : kGreen,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Mini letter dots
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: List.generate(total, (i) {
              final done = i < completed;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: done ? 12 : 8,
                height: done ? 12 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? kGreen
                      : (i == completed
                          ? kElectricBlue
                          : kDeepNavy.withValues(alpha: 0.12)),
                  border: Border.all(
                    color: i == completed
                        ? kElectricBlue.withValues(alpha: 0.6)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: done
                      ? [
                          BoxShadow(
                            color: kGreen.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 0,
                          )
                        ]
                      : [],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── HEADER ───────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [kAccentCyan, Colors.white, kAccentGold],
      ).createShader(bounds),
      child: const Text(
        '✋  WHAT SIGN IS THIS?',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 2.5,
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildModeButton(GameMode.alphabets, 'Alphabets'),
              const SizedBox(width: 10),
              _buildModeButton(GameMode.numbers, 'Numbers'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _modeLocked
                ? 'Finish the selected section first.'
                : 'Choose the first section to begin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(GameMode mode, String label) {
    final selected = _gameMode == mode;
    final locked = _modeLocked && !selected;
    return Expanded(
      child: GestureDetector(
        onTap: locked ? null : () => _selectGameMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color:
                selected ? kElectricBlue : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected ? kAccentCyan : Colors.white.withValues(alpha: 0.16),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : locked
                        ? Colors.white.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── IMAGE CARD ───────────────────────────────────────────────────────────────
  Widget _buildImageCard() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (ctx, child) {
        final offset =
            sin(_shakeAnim.value * pi * 6) * 8 * (1 - _shakeAnim.value);
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: FadeTransition(
        opacity: _imageRevealCtrl,
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          borderRadius: 32,
          color: Colors.white,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: _buildSignImage(),
          ),
        ),
      ),
    );
  }

  String _assetPathFor(String item) {
    final isNumber = int.tryParse(item) != null;
    final extension = isNumber ? 'jpg' : 'png';
    return 'assets/guess_asl/$item.$extension';
  }

  Widget _buildSignImage() {
    return Image.asset(
      _assetPathFor(_roundLetter),
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, st) => _placeholderSign(),
    );
  }

  Widget _placeholderSign() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kElectricBlue.withValues(alpha: 0.08),
            kDeepNavy.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: kElectricBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: kElectricBlue.withValues(alpha: 0.25), width: 2),
              ),
              child: Center(
                child: Text(
                  '✋',
                  style: TextStyle(
                    fontSize: 72,
                    shadows: [
                      Shadow(
                          color: kElectricBlue.withValues(alpha: 0.3),
                          blurRadius: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ASL SIGN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kDeepNavy.withValues(alpha: 0.4),
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [kElectricBlue, Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _roundLetter,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _assetPathFor(_roundLetter),
              style: TextStyle(
                fontSize: 10,
                color: kDeepNavy.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HINT BAR ─────────────────────────────────────────────────────────────────
  Widget _buildHintBar() {
    final canUse = _hintsLeft > 0 &&
        _selectedChoice == null &&
        !_gameOver &&
        !_gameWon &&
        _choices
            .where((c) => c != _roundLetter && !_eliminated.contains(c))
            .isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: List.generate(kMaxHints, (i) {
            final used = i >= _hintsLeft;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: used
                      ? Colors.white.withValues(alpha: 0.18)
                      : const Color(0xFFFFD93D),
                  boxShadow: used
                      ? []
                      : [
                          BoxShadow(
                            color: kAccentGold.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: canUse ? _useHint : null,
          child: ScaleTransition(
            scale: canUse ? _hintPulseCtrl : const AlwaysStoppedAnimation(1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: canUse
                    ? const LinearGradient(
                        colors: [Color(0xFFFFD93D), Color(0xFFFF9F1C)],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: canUse
                      ? kAccentGold.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: canUse
                    ? [
                        BoxShadow(
                          color: kAccentGold.withValues(alpha: 0.45),
                          blurRadius: 14,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '💡',
                    style: TextStyle(
                      fontSize: 16,
                      color: canUse
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    canUse
                        ? 'HINT  ($_hintsLeft left)'
                        : _hintsLeft == 0
                            ? 'NO HINTS LEFT'
                            : 'HINT USED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: canUse
                          ? kDeepNavy
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── CHOICES ──────────────────────────────────────────────────────────────────
  Widget _buildChoices() {
    final top = _choices.sublist(0, 3);
    final bottom = _choices.sublist(3);

    Widget tile(String c) => SizedBox(
          width: 90,
          height: 72,
          child: _ChoiceTile(
            letter: c,
            state: _eliminated.contains(c)
                ? _TileState.eliminated
                : _selectedChoice == null
                    ? _TileState.idle
                    : c == _roundLetter
                        ? _TileState.correct
                        : c == _selectedChoice
                            ? _TileState.wrong
                            : _TileState.idle,
            onTap: () => _onChoiceTap(c),
            enabled: _selectedChoice == null &&
                !_gameOver &&
                !_gameWon &&
                !_eliminated.contains(c),
          ),
        );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: top
              .map((c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: tile(c),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: bottom
              .map((c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: tile(c),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── GAME OVER OVERLAY ────────────────────────────────────────────────────────
  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: ScaleTransition(
          scale: _popScale,
          child: _GameOverModal(
            score: _score,
            completed: _completedCount,
            total: _currentPool.length,
            onRestart: _restart,
          ),
        ),
      ),
    );
  }

  // ── WIN OVERLAY ──────────────────────────────────────────────────────────────
  Widget _buildWinOverlay() {
    final sectionComplete = _modeIndex < _modeOrder.length - 1;
    final currentLabel =
        _gameMode == GameMode.alphabets ? 'Alphabets' : 'Numbers';
    final nextLabel = _modeOrder[_modeIndex + 1] == GameMode.alphabets
        ? 'Alphabets'
        : 'Numbers';
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: ScaleTransition(
          scale: _winPopScale,
          child: _WinModal(
            score: _score,
            total: _currentPool.length,
            message: sectionComplete
                ? 'You completed all $currentLabel signs! Next up: $nextLabel.'
                : 'You completed all $currentLabel signs!',
            actionLabel:
                sectionComplete ? 'Continue to $nextLabel' : 'Play Again',
            onRestart: sectionComplete ? _advanceSection : _restart,
          ),
        ),
      ),
    );
  }

  Widget _buildStartPromptOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {}, // absorb taps so modal cannot be dismissed
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: ScaleTransition(
              scale: _startPromptScale,
              child: GlassCard(
                borderRadius: 28,
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GUESS ASL',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: kDeepNavy.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose what you want to play first',
                        style: TextStyle(
                          fontSize: 14,
                          color: kDeepNavy.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _StartChoiceButton(
                              icon: '🔤',
                              label: 'Alphabets',
                              gradient: const LinearGradient(
                                colors: [kAccentCyan, kElectricBlue],
                              ),
                              onTap: () => _selectGameMode(GameMode.alphabets),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: _StartChoiceButton(
                              icon: '🔢',
                              label: 'Numbers',
                              gradient: const LinearGradient(
                                colors: [kAccentGold, Color(0xFFFF9F1C)],
                              ),
                              onTap: () => _selectGameMode(GameMode.numbers),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHOICE TILE
// ─────────────────────────────────────────────────────────────────────────────
enum _TileState { idle, correct, wrong, eliminated }

class _ChoiceTile extends StatefulWidget {
  final String letter;
  final _TileState state;
  final VoidCallback onTap;
  final bool enabled;

  const _ChoiceTile({
    required this.letter,
    required this.state,
    required this.onTap,
    required this.enabled,
  });

  @override
  State<_ChoiceTile> createState() => _ChoiceTileState();
}

class _ChoiceTileState extends State<_ChoiceTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Color get _bgColor {
    switch (widget.state) {
      case _TileState.correct:
        return const Color(0xFF22C55E);
      case _TileState.wrong:
        return kRed;
      case _TileState.eliminated:
        return Colors.transparent;
      case _TileState.idle:
        return _hovering ? const Color(0xFFF0F4FF) : Colors.white;
    }
  }

  Color get _textColor {
    switch (widget.state) {
      case _TileState.correct:
      case _TileState.wrong:
        return Colors.white;
      case _TileState.eliminated:
        return Colors.transparent;
      case _TileState.idle:
        return kDeepNavy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEliminated = widget.state == _TileState.eliminated;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) _press.forward();
        },
        onTapUp: (_) {
          _press.reverse();
          if (widget.enabled) widget.onTap();
        },
        onTapCancel: () => _press.reverse(),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 0.9).animate(
            CurvedAnimation(parent: _press, curve: Curves.easeOut),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isEliminated
                    ? Colors.white.withValues(alpha: 0.12)
                    : widget.state == _TileState.idle
                        ? (_hovering
                            ? kElectricBlue.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.8))
                        : Colors.transparent,
                width: isEliminated ? 1.5 : 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
              boxShadow: isEliminated
                  ? []
                  : [
                      BoxShadow(
                        color:
                            (_bgColor == Colors.white ? Colors.black : _bgColor)
                                .withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      )
                    ],
            ),
            child: Center(
              child: isEliminated
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          widget.letter,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.18),
                            letterSpacing: 1,
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      widget.letter,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: _textColor,
                        letterSpacing: 1,
                        shadows: widget.state != _TileState.idle
                            ? const [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIN MODAL
// ─────────────────────────────────────────────────────────────────────────────
class _WinModal extends StatelessWidget {
  final int score;
  final int total;
  final String message;
  final String actionLabel;
  final VoidCallback onRestart;

  const _WinModal({
    required this.score,
    required this.total,
    required this.message,
    required this.actionLabel,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 40,
            spreadRadius: 4,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Banner ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Center(
              child: Text(
                '🎉  YOU WIN!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Trophy ──
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: kAccentGold.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: kAccentGold, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentGold.withValues(alpha: 0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 50)),
                ),
              ),
              const Positioned(
                top: 0,
                right: 0,
                child: Text('✨', style: TextStyle(fontSize: 22)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Subtitle ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kDeepNavy.withValues(alpha: 0.65),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Score badge ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: kGreen.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 1),
              ],
            ),
            child: Text(
              'Final Score  $score',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── Leaderboard ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kGreen.withValues(alpha: 0.2)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  _scoreRow('🏆', "Today's Best", ScoreBoard.todayBest),
                  const Divider(height: 16),
                  _scoreRow('🥈', "Week's Best", ScoreBoard.weekBest),
                  const Divider(height: 16),
                  _scoreRow('👑', 'All-time Best', ScoreBoard.allTimeBest),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── Play Again ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ModalButton(
              label: actionLabel,
              onTap: onRestart,
              gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
              textColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _scoreRow(String emoji, String label, int value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kDeepNavy.withValues(alpha: 0.6),
            ),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: kDeepNavy,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAME OVER MODAL
// ─────────────────────────────────────────────────────────────────────────────
class _GameOverModal extends StatelessWidget {
  final int score;
  final int completed;
  final int total;
  final VoidCallback onRestart;

  const _GameOverModal({
    required this.score,
    required this.completed,
    required this.total,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 40,
            spreadRadius: 4,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient:
                  LinearGradient(colors: [kElectricBlue, Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Center(
              child: Text(
                'GAME OVER',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: kAccentGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: kAccentGold, width: 3),
                ),
                child: const Center(
                  child: Text('😉', style: TextStyle(fontSize: 48)),
                ),
              ),
              const Positioned(
                top: 0,
                right: 0,
                child: Text('👑', style: TextStyle(fontSize: 24)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Completed count sub-label
          Text(
            '$completed / $total signs completed',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kDeepNavy.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [kAccentGold, Color(0xFFFF9F1C)]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: kAccentGold.withValues(alpha: 0.5),
                    blurRadius: 14,
                    spreadRadius: 1),
              ],
            ),
            child: Text(
              'Score  $score',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: kElectricBlue.withValues(alpha: 0.12)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  _scoreRow('🏆', "Today's Best", ScoreBoard.todayBest),
                  const Divider(height: 16),
                  _scoreRow('🥈', "Week's Best", ScoreBoard.weekBest),
                  const Divider(height: 16),
                  _scoreRow('👑', 'All-time Best', ScoreBoard.allTimeBest),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _ModalButton(
              label: '🔄  Play Again',
              onTap: onRestart,
              gradient: const LinearGradient(
                  colors: [kElectricBlue, Color(0xFF7C3AED)]),
              textColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _scoreRow(String emoji, String label, int value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kDeepNavy.withValues(alpha: 0.6),
            ),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: kDeepNavy,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODAL BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _ModalButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Gradient gradient;
  final Color textColor;

  const _ModalButton({
    required this.label,
    required this.onTap,
    required this.gradient,
    required this.textColor,
  });

  @override
  State<_ModalButton> createState() => _ModalButtonState();
}

class _ModalButtonState extends State<_ModalButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.94).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
        ),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: widget.textColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Large start-choice button used in the initial modal
class _StartChoiceButton extends StatefulWidget {
  final String icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _StartChoiceButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_StartChoiceButton> createState() => _StartChoiceButtonState();
}

class _StartChoiceButtonState extends State<_StartChoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final halo = widget.gradient is LinearGradient
        ? (widget.gradient as LinearGradient).colors.first
        : kElectricBlue;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 0.96).animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 88,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: halo.withValues(alpha: _hovering ? 0.48 : 0.18),
                  blurRadius: _hovering ? 28 : 12,
                  spreadRadius: _hovering ? 6 : 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
