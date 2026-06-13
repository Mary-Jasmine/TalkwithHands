// =============================================================
//  guess_me_screen.dart  –  "Guess Me?" The Ultimate Guessing Game
//  Single-file, production-ready Flutter widget.
//  No external dependencies beyond Flutter core.
//
//  _AnimatedQuestionCanvas replaces the video player until your
//  .mp4 files are ready.  Search "SWAP FOR VIDEO" to find the
//  exact widget to replace.
// =============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../ui/app_shell.dart';

// ─────────────────────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GuessMeApp());
}

class GuessMeApp extends StatelessWidget {
  const GuessMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guess Me?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: const GuessMeScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────
class Question {
  /// Identifies the question; maps to an emoji now, a video asset later.
  final String prompt;
  final List<String> options;
  final String correctAnswer;

  Question({
    required this.prompt,
    required this.options,
    required this.correctAnswer,
  });
}

// ─────────────────────────────────────────────────────────────
//  MOCK DATA
// ─────────────────────────────────────────────────────────────
List<Question> _buildQuestionList() => [
      Question(
        prompt: 'how_are_you',
        options: ['How Are You', 'Thank You', 'Good Night'],
        correctAnswer: 'How Are You',
      ),
      Question(
        prompt: 'see_you_later',
        options: ['See You Later', 'Good Morning', 'Good Night'],
        correctAnswer: 'See You Later',
      ),
      Question(
        prompt: 'i_love_you',
        options: ['I Hate You', 'I Love You', 'I Miss You'],
        correctAnswer: 'I Love You',
      ),
    ];

// ─────────────────────────────────────────────────────────────
//  THEME CONSTANTS
// ─────────────────────────────────────────────────────────────
const _kBlueLight = Color(0xFF27AAEB);
const _kBlueMid = Color(0xFF1E9EDB);
const _kBlueDark = Color(0xFF0D6FAB);
const _kGold = Color(0xFFFFD700);

// ═════════════════════════════════════════════════════════════
//  GAME SCREEN
// ═════════════════════════════════════════════════════════════
class GuessMeScreen extends StatefulWidget {
  final VoidCallback? onGameFinished;

  const GuessMeScreen({super.key, this.onGameFinished});

  @override
  State<GuessMeScreen> createState() => _GuessMeScreenState();
}

class _GuessMeScreenState extends State<GuessMeScreen>
    with TickerProviderStateMixin {
  late final List<Question> _questions;

  int _lives = 3;
  int _score = 0;
  int _remainingSeconds = 15;
  int _questionIndex = 0;
  String? _selectedAnswer;

  Timer? _countdownTimer;

  late AnimationController _heartShakeCtrl;
  late AnimationController _scorePopCtrl;
  late Animation<double> _scorePopAnim;

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _questions = _buildQuestionList()..shuffle(Random());
    _shuffleOptions(_questionIndex);

    _heartShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scorePopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scorePopAnim = Tween<double>(begin: 1.0, end: 1.45).animate(
      CurvedAnimation(parent: _scorePopCtrl, curve: Curves.elasticOut),
    );

    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _heartShakeCtrl.dispose();
    _scorePopCtrl.dispose();
    super.dispose();
  }

  // ─── Timer ───────────────────────────────────────────────────
  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _remainingSeconds = 25;
          _applyLifeLoss(); // time's up → lose a life
        }
      });
    });
  }

  void _resetTimer() => setState(() => _remainingSeconds = 25);

  // ─── Helpers ─────────────────────────────────────────────────
  Question get _currentQ => _questions[_questionIndex];
  bool get _isLastQuestion => _questionIndex >= _questions.length - 1;

  String get _formattedTime {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _shuffleOptions(int idx) => _questions[idx].options.shuffle(Random());

  // ─── Answer handling ─────────────────────────────────────────
  void _onAnswerSelected(String answer) {
    if (_selectedAnswer != null) return; // guard double-tap

    final correct = answer == _currentQ.correctAnswer;
    setState(() => _selectedAnswer = answer);

    if (correct) {
      _score++;
      _scorePopCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 700), _advance);
    } else {
      _heartShakeCtrl.forward(from: 0);
      // FIX: was two identical branches controlled by a useless bool param.
      // Now one clean path: lose life, then advance.
      _applyLifeLoss();
    }
  }

  /// Deducts a life. Ends the game if none remain; otherwise advances
  /// to the next question after a short feedback delay.
  void _applyLifeLoss() {
    setState(() => _lives = (_lives - 1).clamp(0, 3));
    if (_lives <= 0) {
      _endGame(won: false);
    } else {
      Future.delayed(const Duration(milliseconds: 700), _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    if (_isLastQuestion) {
      _endGame(won: true);
      return;
    }
    setState(() {
      _questionIndex++;
      _selectedAnswer = null;
      _shuffleOptions(_questionIndex);
      _resetTimer();
    });
  }

  // ─── End game ────────────────────────────────────────────────
  void _endGame({required bool won}) {
    _countdownTimer?.cancel();
    widget.onGameFinished?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: won
                ? WinScreen(score: _score, total: _questions.length)
                : DefeatScreen(score: _score, total: _questions.length),
          ),
        ),
      );
    });
  }

  // ─── Button state ────────────────────────────────────────────
  _ButtonState _stateOf(String option) {
    if (_selectedAnswer == null) return _ButtonState.idle;
    if (option == _currentQ.correctAnswer) return _ButtonState.correct;
    if (option == _selectedAnswer) return _ButtonState.wrong;
    return _ButtonState.dimmed;
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const _StripedBackground(),
            Column(
              children: [
                _buildAppBar(),
                const SizedBox(height: 6),
                _buildStatusRow(),
                _buildProgressBar(),
                const SizedBox(height: 12),
                Expanded(flex: 3, child: _buildAnswerArea()),
                Expanded(flex: 4, child: _buildQuestionCanvas()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppBackIconButton(
            onTap: () => Navigator.of(context).maybePop(),
            size: 44,
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _kBlueDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white30, width: 1.5),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
              ],
            ),
            child: const _LogoWidget(),
          ),
          AppMenuIconButton(onTap: () {}),
        ],
      ),
    );
  }

  // ─── Status row ──────────────────────────────────────────────
  Widget _buildStatusRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _heartShakeCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(sin(_heartShakeCtrl.value * pi * 6) * 7, 0),
              child: child,
            ),
            child: Row(
              children: List.generate(
                  3,
                  (i) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          i < _lives ? Icons.favorite : Icons.favorite_border,
                          color: i < _lives ? Colors.red : Colors.red.shade200,
                          size: 30,
                          shadows: const [
                            Shadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                      )),
            ),
          ),
          Expanded(
            child: Center(
              child: ScaleTransition(
                scale: _scorePopAnim,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(children: [
                    const TextSpan(
                      text: 'Score:\n',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.2),
                    ),
                    TextSpan(
                      text: '$_score',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          _TimerPill(
              formattedTime: _formattedTime, isWarning: _remainingSeconds <= 5),
        ],
      ),
    );
  }

  // ─── Progress bar ────────────────────────────────────────────
  Widget _buildProgressBar() {
    final progress = (_questionIndex + 1) / _questions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Question ${_questionIndex + 1} / ${_questions.length}',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Answer buttons ──────────────────────────────────────────
  Widget _buildAnswerArea() {
    final opts = _currentQ.options;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (opts.length >= 2)
            Row(children: [
              Expanded(
                  child: _AnswerButton(
                label: opts[0],
                state: _stateOf(opts[0]),
                onTap: () => _onAnswerSelected(opts[0]),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _AnswerButton(
                label: opts[1],
                state: _stateOf(opts[1]),
                onTap: () => _onAnswerSelected(opts[1]),
              )),
            ]),
          const SizedBox(height: 12),
          for (int i = 2; i < opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.55,
                child: _AnswerButton(
                  label: opts[i],
                  state: _stateOf(opts[i]),
                  onTap: () => _onAnswerSelected(opts[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Question canvas ─────────────────────────────────────────
  Widget _buildQuestionCanvas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _QuestionVideoPlayer(
            key: ValueKey(_questionIndex),
            prompt: _currentQ.prompt,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  ANIMATED QUESTION CANVAS
//  A polished animated placeholder until you have your videos.
//  Each prompt gets its own emoji + gradient + drifting particles.
// ═════════════════════════════════════════════════════════════

const _kPromptEmoji = {
  'happy_birthday': '🎂',
  'good_morning': '☀️',
  'congratulations': '🏆',
  'how_are_you': '🤔',
  'i_love_you': '❤️',
  'see_you_later': '👋',
  'thank_you': '🙏',
};

const _kPromptGradients = {
  'happy_birthday': [Color(0xFFFFF9C4), Color(0xFFFFE0B2)],
  'good_morning': [Color(0xFFFFF3E0), Color(0xFFB3E5FC)],
  'congratulations': [Color(0xFFF3E5F5), Color(0xFFE8F5E9)],
  'how_are_you': [Color(0xFFE1F5FE), Color(0xFFB3E5FC)],
  'i_love_you': [Color(0xFFFFE4E4), Color(0xFFFFCDD2)],
  'see_you_later': [Color(0xFFFFF3E0), Color(0xFFFFE082)],
  'thank_you': [Color(0xFFE8F5E9), Color(0xFFB2DFDB)],
};

const _kPromptVideoAssets = {
  'how_are_you': 'assets/guess_me/videos/how_are_you.mp4',
  'i_love_you': 'assets/guess_me/videos/i_love_you.mp4',
  'see_you_later': 'assets/guess_me/videos/see_you_later.mp4',
};

class _QuestionVideoPlayer extends StatefulWidget {
  final String prompt;
  const _QuestionVideoPlayer({super.key, required this.prompt});

  @override
  State<_QuestionVideoPlayer> createState() => _QuestionVideoPlayerState();
}

class _QuestionVideoPlayerState extends State<_QuestionVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  bool _showAutoPlayBadge = false;
  Duration _previousPosition = Duration.zero;
  Timer? _badgeTimer;

  String? get _assetPath => _kPromptVideoAssets[widget.prompt];
  bool get _hasVideoAsset => _assetPath != null;

  @override
  void initState() {
    super.initState();
    if (_hasVideoAsset) {
      _initializeController();
    }
  }

  void _initializeController() {
    _controller = VideoPlayerController.asset(_assetPath!);
    _initializeFuture = _controller!.initialize().then((_) {
      if (!mounted) return;
      _controller!
        ..setLooping(true)
        ..setVolume(0)
        ..play();
      _controller!.addListener(_handleLoopDetection);
      setState(() {});
    });
  }

  void _handleLoopDetection() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final current = _controller!.value.position;
    final previous = _previousPosition;

    if (current < previous && previous > const Duration(seconds: 1)) {
      _badgeTimer?.cancel();
      setState(() => _showAutoPlayBadge = true);
      _badgeTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _showAutoPlayBadge = false);
      });
    }

    _previousPosition = current;
  }

  @override
  void didUpdateWidget(covariant _QuestionVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prompt != widget.prompt) {
      _badgeTimer?.cancel();
      _showAutoPlayBadge = false;
      _previousPosition = Duration.zero;
      _controller?.removeListener(_handleLoopDetection);
      _controller?.dispose();
      _controller = null;
      _initializeFuture = null;
      if (_hasVideoAsset) {
        _initializeController();
      }
    }
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _controller?.removeListener(_handleLoopDetection);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasVideoAsset) {
      return _AnimatedQuestionCanvas(prompt: widget.prompt);
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError ||
            _controller == null ||
            !_controller!.value.isInitialized) {
          return _AnimatedQuestionCanvas(prompt: widget.prompt);
        }

        return Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: IgnorePointer(
                  ignoring: true,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            if (_showAutoPlayBadge)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '▶ Auto-playing again',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Watch and guess the phrase!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Particle configs: [leftFraction, topFraction, fontSize, phaseOffset]
const _kParticles = [
  [0.10, 0.12, 26.0, 0.00],
  [0.78, 0.08, 20.0, 0.33],
  [0.82, 0.68, 18.0, 0.67],
  [0.06, 0.74, 22.0, 0.50],
  [0.52, 0.82, 19.0, 0.20],
];

class _AnimatedQuestionCanvas extends StatefulWidget {
  final String prompt;
  const _AnimatedQuestionCanvas({required this.prompt});

  @override
  State<_AnimatedQuestionCanvas> createState() =>
      _AnimatedQuestionCanvasState();
}

class _AnimatedQuestionCanvasState extends State<_AnimatedQuestionCanvas>
    with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _particleCtrl;

  late Animation<double> _bounceY;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _bounceY = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _kPromptEmoji[widget.prompt] ?? '🤔';
    final colors = _kPromptGradients[widget.prompt] ??
        [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      // LayoutBuilder gives us the real canvas size for particle offsets.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Drifting background particles ──────────────
              ..._kParticles.map((c) {
                final lf = c[0];
                final tf = c[1];
                final fs = c[2];
                final ph = c[3];

                return AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (_, __) {
                    final t = (_particleCtrl.value + ph) % 1.0;
                    final dy = sin(t * pi * 2) * 12;
                    final dx = cos(t * pi * 2) * 6;
                    return Positioned(
                      left: lf * w + dx,
                      top: tf * h + dy,
                      child: Opacity(
                        opacity: 0.20,
                        child: Text(emoji, style: TextStyle(fontSize: fs)),
                      ),
                    );
                  },
                );
              }),

              // ── Main bouncing emoji ─────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_bounceCtrl, _pulseCtrl]),
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _bounceY.value),
                    child: Transform.scale(
                      scale: _scale.value,
                      child: Text(emoji, style: const TextStyle(fontSize: 88)),
                    ),
                  ),
                ),
              ),

              // ── Bottom label ────────────────────────────────
              Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline_rounded,
                            size: 14, color: _kBlueDark),
                        SizedBox(width: 5),
                        Text(
                          'Watch and guess the phrase!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kBlueDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── "Video coming soon" badge ───────────────────
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kBlueDark.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '▶  Video coming soon',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  WIN SCREEN
// ═════════════════════════════════════════════════════════════
class WinScreen extends StatefulWidget {
  final int score;
  final int total;
  const WinScreen({super.key, required this.score, required this.total});

  @override
  State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen> with TickerProviderStateMixin {
  late AnimationController _starCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _starSpin;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _starCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _starSpin = Tween<double>(begin: 0, end: 1).animate(_starCtrl);

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
            CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));
    _contentCtrl.forward();
  }

  @override
  void dispose() {
    _starCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.score / widget.total * 100).round();
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A4F82), Color(0xFF1478B5), Color(0xFF1E9EDB)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: FadeTransition(
            opacity: _contentFade,
            child: SlideTransition(
              position: _contentSlide,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RotationTransition(
                        turns: _starSpin,
                        child: const Icon(
                          Icons.star_rounded,
                          size: 90,
                          color: _kGold,
                          shadows: [
                            Shadow(
                                color: Colors.black26,
                                blurRadius: 16,
                                offset: Offset(0, 4))
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'YOU WIN!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                                color: Colors.black38,
                                blurRadius: 10,
                                offset: Offset(0, 4))
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Amazing! You guessed all ${widget.total} correctly!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 16),
                      ),
                      const SizedBox(height: 32),
                      _WinScoreCard(
                          score: widget.score, total: widget.total, pct: pct),
                      const SizedBox(height: 36),
                      _BigButton(
                        label: 'Play Again',
                        icon: Icons.replay_rounded,
                        color: _kGold,
                        textColor: Colors.black87,
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const GuessMeScreen()),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                        child: const Text('Exit',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 14)),
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

class _WinScoreCard extends StatelessWidget {
  final int score, total, pct;
  const _WinScoreCard(
      {required this.score, required this.total, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white30, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
              label: 'Score',
              value: '$score / $total',
              icon: Icons.star_rounded,
              color: _kGold),
          Container(width: 1, height: 48, color: Colors.white24),
          _StatChip(
              label: 'Accuracy',
              value: '$pct%',
              icon: Icons.track_changes_rounded,
              color: Colors.greenAccent),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  DEFEAT SCREEN
// ═════════════════════════════════════════════════════════════
class DefeatScreen extends StatefulWidget {
  final int score;
  final int total;
  const DefeatScreen({super.key, required this.score, required this.total});

  @override
  State<DefeatScreen> createState() => _DefeatScreenState();
}

class _DefeatScreenState extends State<DefeatScreen>
    with TickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _iconBounce;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _iconBounce = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));

    _contentCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _shakeCtrl.forward();
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0A0A), Color(0xFF5C1A1A), Color(0xFFAB2E2E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: FadeTransition(
            opacity: _contentFade,
            child: SlideTransition(
              position: _contentSlide,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _iconBounce,
                        child: const Icon(
                          Icons.heart_broken_rounded,
                          size: 100,
                          color: Colors.red,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                blurRadius: 16,
                                offset: Offset(0, 6))
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'DEFEATED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, 4))
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You ran out of lives. Better luck next time!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 15),
                      ),
                      const SizedBox(height: 32),
                      _DefeatScoreCard(
                          score: widget.score, total: widget.total),
                      const SizedBox(height: 36),
                      _BigButton(
                        label: 'Try Again',
                        icon: Icons.refresh_rounded,
                        color: Colors.red.shade700,
                        textColor: Colors.white,
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const GuessMeScreen()),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
                        child: const Text('Exit',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 14)),
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

class _DefeatScoreCard extends StatelessWidget {
  final int score, total;
  const _DefeatScoreCard({required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
              label: 'Answered',
              value: '$score',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.orangeAccent),
          Container(width: 1, height: 48, color: Colors.white12),
          _StatChip(
              label: 'Remaining',
              value: '${total - score}',
              icon: Icons.cancel_outlined,
              color: Colors.red.shade300),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatChip(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
        ],
      );
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, textColor;
  final VoidCallback onTap;
  const _BigButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.textColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════
//  STRIPED BACKGROUND
// ═════════════════════════════════════════════════════════════
class _StripedBackground extends StatelessWidget {
  const _StripedBackground();
  @override
  Widget build(BuildContext context) =>
      SizedBox.expand(child: CustomPaint(painter: _StripePainter()));
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kBlueMid);
    final p = Paint()..color = _kBlueLight;
    const sw = 44.0;
    for (double x = 0; x < size.width; x += sw * 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, sw, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ═════════════════════════════════════════════════════════════
//  LOGO WIDGET
// ═════════════════════════════════════════════════════════════
class _LogoWidget extends StatelessWidget {
  const _LogoWidget();
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: _kBlueDark,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('GUESS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                Text('ME?',
                    style: TextStyle(
                        color: _kGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ],
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════
//  TIMER PILL
// ═════════════════════════════════════════════════════════════
class _TimerPill extends StatelessWidget {
  final String formattedTime;
  final bool isWarning;
  const _TimerPill({required this.formattedTime, required this.isWarning});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isWarning ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
              color: isWarning ? Colors.red : Colors.transparent, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        child: Text(
          'TIME: $formattedTime',
          style: TextStyle(
            color: isWarning ? Colors.red : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════
//  ANSWER BUTTON
// ═════════════════════════════════════════════════════════════
enum _ButtonState { idle, correct, wrong, dimmed }

class _AnswerButton extends StatefulWidget {
  final String label;
  final _ButtonState state;
  final VoidCallback onTap;
  const _AnswerButton(
      {required this.label, required this.state, required this.onTap});

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Color get _bg => switch (widget.state) {
        _ButtonState.correct => const Color(0xFFD4EDDA),
        _ButtonState.wrong => const Color(0xFFF8D7DA),
        _ButtonState.dimmed => Colors.white.withValues(alpha: 0.45),
        _ButtonState.idle => Colors.white,
      };

  Color get _border => switch (widget.state) {
        _ButtonState.correct => Colors.green.shade600,
        _ButtonState.wrong => Colors.red.shade600,
        _ButtonState.dimmed => const Color(0xFF1565C0),
        _ButtonState.idle => const Color(0xFF1565C0),
      };

  IconData? get _icon => switch (widget.state) {
        _ButtonState.correct => Icons.check_circle_outline_rounded,
        _ButtonState.wrong => Icons.cancel_outlined,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.state == _ButtonState.idle) _press.reverse();
      },
      onTapUp: (_) {
        _press.forward();
        widget.onTap();
      },
      onTapCancel: () => _press.forward(),
      child: ScaleTransition(
        scale: _press,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: _border.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: widget.state == _ButtonState.dimmed
                        ? Colors.black38
                        : Colors.black87,
                  ),
                ),
              ),
              if (_icon != null) ...[
                const SizedBox(width: 6),
                Icon(_icon,
                    size: 18,
                    color: widget.state == _ButtonState.correct
                        ? Colors.green.shade700
                        : Colors.red.shade700),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
