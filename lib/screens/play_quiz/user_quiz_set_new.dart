import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/view_model/folders/user_question_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ─── Quiz Timer ────────────────────────────────────────────────────────────────
class QuizTimer {
  Timer? _timer;
  int _secondsRemaining;
  final List<VoidCallback> _listeners = [];

  QuizTimer({int totalSeconds = 3000}) : _secondsRemaining = totalSeconds;

  int get secondsRemaining => _secondsRemaining;
  bool get isRunning => _timer?.isActive == true;

  void start({VoidCallback? onTick, VoidCallback? onTimeUp}) {
    if (isRunning) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        _notify();
        onTick?.call();
      } else {
        stop();
        _notify();
        onTimeUp?.call();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void addListener(VoidCallback cb) {
    if (!_listeners.contains(cb)) _listeners.add(cb);
  }

  void removeListener(VoidCallback cb) => _listeners.remove(cb);

  void _notify() {
    for (final l in List<VoidCallback>.from(_listeners)) {
      l();
    }
  }

  String get formatted =>
      '${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}';
}

// ─── Quiz Overview Page ────────────────────────────────────────────────────────
class UserQuizOverviewPage extends StatefulWidget {
  final int quizSetId;
  final String quizSetName;
  final String folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final String fullName;
  final String userEmail;

  const UserQuizOverviewPage({
    super.key,
    required this.quizSetId,
    required this.quizSetName,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    required this.fullName,
    required this.userEmail,
  });

  @override
  State<UserQuizOverviewPage> createState() => _UserQuizOverviewPageState();
}

class _UserQuizOverviewPageState extends State<UserQuizOverviewPage> {
  final QuizTimer _timer = QuizTimer(totalSeconds: 3000);
  bool _hasStarted = false;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _lockLandscape();
    _timer.addListener(_onTick);
  }

  void _lockLandscape() {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer.removeListener(_onTick);
    _timer.stop();
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    super.dispose();
  }

  Future<void> _startQuiz() async {
    if (_hasStarted || _isStarting) return;
    if (!mounted) return;
    setState(() => _isStarting = true);

    final vm = context.read<UserQuizViewModel>();

    if (vm.allQuestions.isEmpty) {
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Questions not loaded yet. Please wait.')),
        );
      }
      return;
    }

    final ok = await vm.startQuizAttempt(widget.quizSetId);
    if (!mounted) return;

    if (!ok) {
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start quiz. Please retry.')),
      );
      return;
    }

    setState(() {
      _hasStarted = true;
      _isStarting = false;
    });

    _timer.start(
      onTick: () {
        if (mounted) setState(() {});
      },
      onTimeUp: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Time is up! Submitting...')));
          _submitQuiz();
        }
      },
    );

    _pushToQuestion(1, vm);
  }

  void _goToQuestion(int displayNumber) {
    if (!_hasStarted) {
      _startQuiz();
      return;
    }
    final vm = context.read<UserQuizViewModel>();
    _pushToQuestion(displayNumber, vm);
  }

  void _pushToQuestion(int displayNumber, UserQuizViewModel vm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<UserQuizViewModel>.value(
          value: vm,
          child: QuizQuestionPage(
            initialDisplayNumber: displayNumber,
            quizSetName: widget.quizSetName,
            isAdmin: widget.isAdmin,
            timer: _timer,
            onSubmit: _submitQuiz,
          ),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _submitQuiz() async {
    _timer.stop();
    final vm = context.read<UserQuizViewModel>();
    final timeTaken = 3000 - _timer.secondsRemaining;
    final result = await vm.submitQuiz(widget.quizSetId, timeTaken);
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<UserQuizViewModel>.value(
          value: vm,
          child: QuizResultsPage(
            quizSetName: widget.quizSetName,
            folderId: widget.folderId,
            folderName: widget.folderName,
            userIdentifier: widget.userIdentifier,
            isAdmin: widget.isAdmin,
            timeTakenSeconds: timeTaken,
            apiResult: result,
          ),
        ),
      ),
          (route) => false,
    );
  }

  void _confirmSubmit() {
    if (!_hasStarted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit Quiz?'),
        content: const Text('Are you sure you want to submit your answers?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitQuiz();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    final sw = MediaQuery.of(context).size.width;
    final baseFontSize = sw * 0.018;

    return Consumer<UserQuizViewModel>(
      builder: (context, vm, _) {
        final reading = vm.readingQuestions;
        final listening = vm.listeningQuestions;

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: AppBar(
              backgroundColor: Colors.blue[700],
              elevation: 2,
              title: Text(
                widget.quizSetName,
                style:
                TextStyle(fontSize: baseFontSize + 2, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      'Time: ${_timer.formatted}',
                      style: TextStyle(
                          fontSize: baseFontSize,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: LayoutBuilder(builder: (context, constraints) {
            final fs = constraints.maxWidth * 0.018;
            return Column(
              children: [
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: (_hasStarted || _isStarting) ? null : _startQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    disabledBackgroundColor:
                    _hasStarted ? Colors.green[300] : Colors.grey[400],
                    padding: EdgeInsets.symmetric(
                        horizontal: fs * 2, vertical: fs * 0.8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isStarting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : Text(
                    _hasStarted ? 'Quiz Started ✓' : 'Start Quiz',
                    style: TextStyle(
                        fontSize: fs + 2,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      if (reading.isNotEmpty)
                        Expanded(
                          child: _buildSection(
                            label: 'Reading',
                            questions: reading,
                            vm: vm,
                            fontSize: fs,
                            sectionStartIndex: 0,
                          ),
                        ),
                      if (reading.isNotEmpty && listening.isNotEmpty)
                        SizedBox(width: constraints.maxWidth * 0.01),
                      if (listening.isNotEmpty)
                        Expanded(
                          child: _buildSection(
                            label: 'Listening',
                            questions: listening,
                            vm: vm,
                            fontSize: fs,
                            sectionStartIndex: reading.length,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _hasStarted ? _confirmSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    disabledBackgroundColor: Colors.grey[400],
                    padding: EdgeInsets.symmetric(
                        horizontal: fs * 2, vertical: fs * 0.8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Submit Quiz',
                    style: TextStyle(
                        fontSize: fs + 2,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          }),
        );
      },
    );
  }

  Widget _buildSection({
    required String label,
    required List<UserQuizQuestion> questions,
    required UserQuizViewModel vm,
    required double fontSize,
    required int sectionStartIndex,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.all(fontSize * 0.5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(label,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            SizedBox(height: fontSize * 0.4),
          ],
          Expanded(
            child: _buildNumberGrid(
              questions: questions,
              vm: vm,
              fontSize: fontSize,
              sectionStartIndex: sectionStartIndex,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberGrid({
    required List<UserQuizQuestion> questions,
    required UserQuizViewModel vm,
    required double fontSize,
    required int sectionStartIndex,
  }) {
    if (questions.isEmpty) return const SizedBox.shrink();

    final total = questions.length;
    final cols = total <= 20 ? 7 : 8;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: questions.length,
      itemBuilder: (_, i) {
        final displayNumber = sectionStartIndex + i + 1;
        final originalIndex = vm.allQuestions.indexOf(questions[i]);
        final isAnswered = vm.selectedAnswers.containsKey(originalIndex);
        final isAttended = vm.attendedQuestions[displayNumber] == true;

        return GestureDetector(
          onTap: () => _goToQuestion(displayNumber),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isAnswered
                  ? Colors.green[600]
                  : isAttended
                  ? Colors.blue[600]
                  : Colors.grey[500],
              border: Border.all(color: Colors.black, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(builder: (_, bc) {
              return Text(
                displayNumber.toString(),
                style: TextStyle(
                    fontSize: bc.maxWidth * 0.38,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              );
            }),
          ),
        );
      },
    );
  }
}

// ─── Quiz Question Page ────────────────────────────────────────────────────────
class QuizQuestionPage extends StatefulWidget {
  final int initialDisplayNumber;
  final String quizSetName;
  final bool isAdmin;
  final QuizTimer timer;
  final VoidCallback onSubmit;

  const QuizQuestionPage({
    super.key,
    required this.initialDisplayNumber,
    required this.quizSetName,
    required this.isAdmin,
    required this.timer,
    required this.onSubmit,
  });

  @override
  State<QuizQuestionPage> createState() => _QuizQuestionPageState();
}

class _QuizQuestionPageState extends State<QuizQuestionPage> {
  late int _currentDisplay;
  final AudioPlayer _audio = AudioPlayer();
  bool _isAudioPlaying = false;
  String? _currentAudioPath;
  final Set<String> _playedMedia = {};
  final Stopwatch _stopwatch = Stopwatch();
  bool _isDialogOpen = false;

  // Drawing support (admin only)
  bool _isDrawingMode = false;
  final List<Offset?> _leftPoints = [];
  final List<Offset?> _rightPoints = [];

  @override
  void initState() {
    super.initState();
    _currentDisplay = widget.initialDisplayNumber;
    _stopwatch.start();
    _audio.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _isAudioPlaying = false;
            _currentAudioPath = null;
          }
        });
      }
    });
    widget.timer.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.timer.removeListener(_onTick);
    _saveTime();
    _audio.stop();
    _audio.dispose();
    super.dispose();
  }

  void _saveTime() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      final vm = context.read<UserQuizViewModel>();
      final idx = vm.displayNumberToIndex[_currentDisplay];
      if (idx != null) {
        vm.recordTimeForQuestion(idx, _stopwatch.elapsed.inSeconds);
      }
    }
  }

  UserQuizQuestion? _currentQuestion(UserQuizViewModel vm) {
    final idx = vm.displayNumberToIndex[_currentDisplay];
    if (idx == null || idx >= vm.allQuestions.length) return null;
    return vm.allQuestions[idx];
  }

  void _goTo(int displayNumber) {
    _saveTime();
    setState(() {
      _currentDisplay = displayNumber;
      _stopwatch.reset();
      _stopwatch.start();
    });
  }

  void _previous() {
    if (_currentDisplay > 1) _goTo(_currentDisplay - 1);
  }

  void _next(UserQuizViewModel vm) {
    if (_currentDisplay < vm.allQuestions.length) {
      _goTo(_currentDisplay + 1);
    }
  }

  void _selectAnswer(String choice, UserQuizViewModel vm) {
    final idx = vm.displayNumberToIndex[_currentDisplay];
    if (idx == null) return;
    vm.selectAnswer(idx, choice);
    vm.markAttended(_currentDisplay);
  }

  Future<void> _playAudio(String mediaPath, UserQuizViewModel vm) async {
    if (!widget.isAdmin && _playedMedia.contains(mediaPath)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Audio already played.')));
      return;
    }

    final localFile = vm.localPath(mediaPath);
    Source source;
    if (localFile != null && await File(localFile).exists()) {
      source = DeviceFileSource(localFile);
    } else {
      source = UrlSource(vm.buildMediaUrl(mediaPath));
    }

    if (_isAudioPlaying && _currentAudioPath == mediaPath) {
      await _audio.pause();
      return;
    }

    await _audio.stop();
    _playedMedia.add(mediaPath);
    setState(() {
      _isAudioPlaying = true;
      _currentAudioPath = mediaPath;
    });
    await _audio.play(source);
  }

  Future<void> _rewindAudio() async {
    final pos = await _audio.getCurrentPosition() ?? Duration.zero;
    final newPos = pos - const Duration(seconds: 10);
    await _audio.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  Future<void> _fastForwardAudio() async {
    final pos = await _audio.getCurrentPosition() ?? Duration.zero;
    await _audio.seek(pos + const Duration(seconds: 10));
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size;
    const appBarH = 30.0;
    final statusH = MediaQuery.of(context).padding.top;

    return Consumer<UserQuizViewModel>(builder: (context, vm, _) {
      final q = _currentQuestion(vm);
      final isFirst = _currentDisplay == 1;
      final isLast = _currentDisplay == vm.allQuestions.length;
      final originalIdx = vm.displayNumberToIndex[_currentDisplay];
      final selectedAnswer =
      originalIdx != null ? vm.selectedAnswers[originalIdx] : null;

      return WillPopScope(
        onWillPop: () async {
          if (_isAudioPlaying && !widget.isAdmin) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please wait for audio to finish')));
            return false;
          }
          return true;
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(appBarH),
            child: AppBar(
              backgroundColor: Colors.blue[100],
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, size: 22),
                onPressed: (isFirst || (_isAudioPlaying && !widget.isAdmin))
                    ? null
                    : _previous,
              ),
              title: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: sw.width * 0.4),
                child: Text(
                  'Q$_currentDisplay - ${widget.quizSetName}',
                  style: TextStyle(
                      fontSize: sw.width * 0.015,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              actions: [
                if (sw.width > sw.height)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: sw.width * 0.3),
                    child: Center(
                      child: Text(
                        'इमा एजुकेशन, बागबजार, फोन नम्बर: +9779851213520',
                        style: TextStyle(
                            fontSize: sw.width * 0.012,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.timer.formatted,
                    style: TextStyle(
                        fontSize: sw.width * 0.015,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          body: q == null
              ? Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Loading question...',
                      style:
                      TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          )
              : Container(
            padding: EdgeInsets.only(
              top: appBarH + statusH + 8,
              left: 12,
              right: 12,
              bottom: 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildLeftPanel(
                        q, vm, sw, originalIdx, selectedAnswer)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildRightPanel(
                        q, vm, sw, selectedAnswer, originalIdx)),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(sw, vm, isFirst, isLast),
          floatingActionButton: widget.isAdmin
              ? Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: 'draw_toggle',
                mini: true,
                onPressed: () {
                  setState(() {
                    _isDrawingMode = !_isDrawingMode;
                    if (!_isDrawingMode) {
                      _leftPoints.clear();
                      _rightPoints.clear();
                    }
                  });
                },
                tooltip:
                _isDrawingMode ? 'Exit Drawing' : 'Enter Drawing',
                child: Icon(
                    _isDrawingMode ? Icons.edit_off : Icons.edit,
                    size: 20),
              ),
              if (_isDrawingMode) ...[
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'draw_clear',
                  mini: true,
                  onPressed: () {
                    setState(() {
                      _leftPoints.clear();
                      _rightPoints.clear();
                    });
                  },
                  tooltip: 'Clear Drawing',
                  child: const Icon(Icons.clear, size: 20),
                ),
              ],
            ],
          )
              : null,
        ),
      );
    });
  }

  Widget _buildLeftPanel(
      UserQuizQuestion q,
      UserQuizViewModel vm,
      Size sw,
      int? originalIdx,
      String? selectedAnswer,
      ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
          image: const DecorationImage(
            image: AssetImage('assets/ema.jpg'),
            fit: BoxFit.cover,
            opacity: 0.05,
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.blue.shade50,
                    ),
                    child: _buildFormattedText(
                      '$_currentDisplay. ${q.question}',
                      q.questionWordFormatting,
                      sw,
                    ),
                  ),
                  if (q.questionFile.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade50,
                      ),
                      child: _buildFileWidget(q.questionFile, vm),
                    ),
                  ],
                  if (q.optionalText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.amber.shade200),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.amber.shade50,
                      ),
                      child: _buildFormattedText(
                          q.optionalText, q.optionalWordFormatting, sw),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.isAdmin && _isDrawingMode)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (d) =>
                      setState(() => _leftPoints.add(d.localPosition)),
                  onPanUpdate: (d) =>
                      setState(() => _leftPoints.add(d.localPosition)),
                  onPanEnd: (_) => setState(() => _leftPoints.add(null)),
                  child: CustomPaint(painter: _DrawingPainter(_leftPoints)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel(
      UserQuizQuestion q,
      UserQuizViewModel vm,
      Size sw,
      String? selectedAnswer,
      int? originalIdx,
      ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.white.withOpacity(0.9),
          image: const DecorationImage(
            image: AssetImage('assets/ema.jpg'),
            fit: BoxFit.cover,
            opacity: 0.05,
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final letter in ['A', 'B', 'C', 'D'])
                    _buildChoiceTile(
                        letter, q, vm, sw, selectedAnswer, originalIdx),
                ],
              ),
            ),
            if (widget.isAdmin && _isDrawingMode)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (d) =>
                      setState(() => _rightPoints.add(d.localPosition)),
                  onPanUpdate: (d) =>
                      setState(() => _rightPoints.add(d.localPosition)),
                  onPanEnd: (_) => setState(() => _rightPoints.add(null)),
                  child: CustomPaint(painter: _DrawingPainter(_rightPoints)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceTile(
      String letter,
      UserQuizQuestion q,
      UserQuizViewModel vm,
      Size sw,
      String? selectedAnswer,
      int? originalIdx,
      ) {
    final text = q.choices[letter] ?? '';
    final file = q.choiceFiles[letter] ?? '';
    final fmt = q.choiceWordFormattings[letter] ?? [];
    final isSelected = selectedAnswer == letter;
    final choiceNumber = {'A': 1, 'B': 2, 'C': 3, 'D': 4}[letter]!;
    final fontSize = sw.width < 1200 ? 14.0 : 16.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _selectAnswer(letter, vm),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 12, top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                      isSelected ? Colors.blue[600] : Colors.grey[200],
                      border: Border.all(
                        color: isSelected
                            ? Colors.blue[600]!
                            : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          choiceNumber.toString(),
                          style: TextStyle(
                            fontSize: fontSize * 0.8,
                            fontWeight: FontWeight.bold,
                            color:
                            isSelected ? Colors.white : Colors.black54,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.blue, size: 10),
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildFormattedText(text, fmt, sw)),
                ],
              ),
              if (file.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildFileWidget(file, vm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FILE WIDGET
  // FIX: Videos no longer open a modal — they display inline as a
  // rectangle with play controls. A zoom button in the bottom-right
  // corner opens the full-screen _VideoPage when tapped.
  // ─────────────────────────────────────────────────────────────
  Widget _buildFileWidget(String mediaPath, UserQuizViewModel vm) {
    final ext = mediaPath.split('.').last.toLowerCase();
    final localFile = vm.localPath(mediaPath);
    final fullUrl = vm.buildMediaUrl(mediaPath);

    // ── Image ──────────────────────────────────────────────────
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
      return GestureDetector(
        onTap: () => _showFullImage(
          localFile != null && File(localFile).existsSync()
              ? localFile
              : fullUrl,
          isLocal: localFile != null && File(localFile).existsSync(),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: localFile != null && File(localFile).existsSync()
              ? Image.file(File(localFile),
              height: 180,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image))
              : CachedNetworkImage(
              imageUrl: fullUrl,
              height: 180,
              fit: BoxFit.contain,
              placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) =>
              const Icon(Icons.broken_image)),
        ),
      );
    }

    // ── Audio ──────────────────────────────────────────────────
    if (['mp3', 'wav', 'ogg', 'm4a', 'aac'].contains(ext)) {
      final isThisPlaying =
          _isAudioPlaying && _currentAudioPath == mediaPath;
      final alreadyPlayed =
          !widget.isAdmin && _playedMedia.contains(mediaPath);

      return Wrap(
        spacing: 8,
        children: [
          IconButton(
            icon: Icon(
              alreadyPlayed
                  ? Icons.check
                  : isThisPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              color: alreadyPlayed ? Colors.green : Colors.black54,
              size: 22,
            ),
            onPressed:
            alreadyPlayed ? null : () => _playAudio(mediaPath, vm),
          ),
          if (widget.isAdmin && isThisPlaying) ...[
            IconButton(
              icon: const Icon(Icons.fast_rewind, size: 20),
              onPressed: _rewindAudio,
            ),
            IconButton(
              icon: const Icon(Icons.fast_forward, size: 20),
              onPressed: _fastForwardAudio,
            ),
          ],
          Text(
            mediaPath.split('/').last,
            style: TextStyle(
                fontSize: 12,
                color: alreadyPlayed ? Colors.grey : Colors.black87),
          ),
        ],
      );
    }

    // ── Video — inline rectangle with zoom button ──────────────
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
      return _InlineVideoWidget(
        mediaPath: mediaPath,
        localFile: localFile,
        fullUrl: fullUrl,
        isAdmin: widget.isAdmin,
        alreadyPlayed: !widget.isAdmin && _playedMedia.contains(mediaPath),
        onFirstPlay: () => setState(() => _playedMedia.add(mediaPath)),
        onZoom: () {
          _playedMedia.add(mediaPath);
          final ctrl = localFile != null && File(localFile).existsSync()
              ? VideoPlayerController.file(File(localFile))
              : VideoPlayerController.networkUrl(Uri.parse(fullUrl));
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _VideoPage(
                controller: ctrl,
                fileName: mediaPath.split('/').last,
                isAdmin: widget.isAdmin,
              ),
            ),
          );
        },
      );
    }

    // ── Generic file attachment ────────────────────────────────
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blue.shade200)),
      child: Row(children: [
        const Icon(Icons.attach_file, size: 16, color: Colors.blueAccent),
        const SizedBox(width: 6),
        Expanded(
            child: Text(mediaPath.split('/').last,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  void _showFullImage(String path, {bool isLocal = false}) {
    setState(() => _isDialogOpen = true);
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: isLocal
                    ? Image.file(File(path), fit: BoxFit.contain)
                    : CachedNetworkImage(imageUrl: path, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () {
                  setState(() => _isDialogOpen = false);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(
      Size sw, UserQuizViewModel vm, bool isFirst, bool isLast) {
    final audioBlocked = _isAudioPlaying && !widget.isAdmin;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 1,
              offset: const Offset(0, -1))
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: (isFirst || audioBlocked) ? null : _previous,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              disabledBackgroundColor: Colors.grey,
              minimumSize: Size(sw.width * 0.12, 34),
            ),
            child:
            Text('Previous', style: TextStyle(fontSize: sw.width * 0.014)),
          ),
          ElevatedButton(
            onPressed: audioBlocked ? null : () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              disabledBackgroundColor: Colors.grey,
              minimumSize: Size(sw.width * 0.15, 34),
            ),
            child: Text('Go to Questions',
                style: TextStyle(fontSize: sw.width * 0.014)),
          ),
          ElevatedButton(
            onPressed: (isLast || audioBlocked) ? null : () => _next(vm),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLast ? Colors.grey : Colors.blue,
              disabledBackgroundColor: Colors.grey,
              minimumSize: Size(sw.width * 0.12, 34),
            ),
            child: Text('Next',
                style: TextStyle(fontSize: sw.width * 0.014)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedText(
      String text, List<Map<String, dynamic>> fmt, Size sw) {
    final fontSize = sw.width < 1200 ? 14.0 : 16.0;
    if (text.isEmpty) return const SizedBox.shrink();
    if (fmt.isEmpty) {
      return SelectableText(text,
          style: TextStyle(
              fontSize: fontSize, height: 1.3, color: Colors.black87));
    }
    final words = text.split(' ');
    final spans = <TextSpan>[];
    for (int i = 0; i < words.length; i++) {
      final bold = i < fmt.length ? fmt[i]['bold'] == true : false;
      final under = i < fmt.length ? fmt[i]['underline'] == true : false;
      final italic = i < fmt.length ? fmt[i]['italic'] == true : false;
      spans.add(TextSpan(
        text: words[i] + (i < words.length - 1 ? ' ' : ''),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          decoration: under ? TextDecoration.underline : null,
          color: Colors.black87,
          height: 1.3,
        ),
      ));
    }
    return SelectableText.rich(TextSpan(children: spans));
  }
}

// ─── Inline Video Widget ───────────────────────────────────────────────────────
// Displays video as a rectangle inline (no modal).
// Bottom-right has a zoom icon that opens the full-screen player.
class _InlineVideoWidget extends StatefulWidget {
  final String mediaPath;
  final String? localFile;
  final String fullUrl;
  final bool isAdmin;
  final bool alreadyPlayed;
  final VoidCallback onFirstPlay;
  final VoidCallback onZoom;

  const _InlineVideoWidget({
    required this.mediaPath,
    required this.localFile,
    required this.fullUrl,
    required this.isAdmin,
    required this.alreadyPlayed,
    required this.onFirstPlay,
    required this.onZoom,
  });

  @override
  State<_InlineVideoWidget> createState() => _InlineVideoWidgetState();
}

class _InlineVideoWidgetState extends State<_InlineVideoWidget> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _hasStarted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void dispose() {
    _ctrl?.removeListener(_onVideoUpdate);
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _initAndPlay() async {
    if (_hasStarted) {
      // Toggle play/pause
      if (_ctrl!.value.isPlaying) {
        await _ctrl!.pause();
      } else {
        await _ctrl!.play();
      }
      return;
    }

    // Non-admin: block replay
    if (widget.alreadyPlayed && !widget.isAdmin) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Video already played.')));
      return;
    }

    widget.onFirstPlay();
    setState(() => _hasStarted = true);

    final localOk = widget.localFile != null &&
        File(widget.localFile!).existsSync();
    _ctrl = localOk
        ? VideoPlayerController.file(File(widget.localFile!))
        : VideoPlayerController.networkUrl(Uri.parse(widget.fullUrl));

    await _ctrl!.initialize();
    _ctrl!.addListener(_onVideoUpdate);
    setState(() {
      _initialized = true;
      _duration = _ctrl!.value.duration;
    });
    await _ctrl!.play();
  }

  void _onVideoUpdate() {
    if (mounted) {
      setState(() => _position = _ctrl!.value.position);
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final fileName = widget.mediaPath.split('/').last;
    final isPlaying = _ctrl?.value.isPlaying ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Video frame ────────────────────────────────────
          AspectRatio(
            aspectRatio: (_initialized && _ctrl!.value.isInitialized)
                ? _ctrl!.value.aspectRatio
                : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_initialized && _ctrl!.value.isInitialized)
                  VideoPlayer(_ctrl!)
                else
                  Container(
                    color: Colors.black87,
                    child: Center(
                      child: Icon(
                        widget.alreadyPlayed && !widget.isAdmin
                            ? Icons.check_circle
                            : Icons.play_circle_fill,
                        color: widget.alreadyPlayed && !widget.isAdmin
                            ? Colors.green
                            : Colors.white70,
                        size: 52,
                      ),
                    ),
                  ),

                // Big play/pause overlay (tap anywhere on the frame)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _initAndPlay,
                    child: Container(color: Colors.transparent),
                  ),
                ),

                // ── Zoom button — bottom right ───────────────
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: widget.onZoom,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.fullscreen,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Controls bar ───────────────────────────────────
          Container(
            color: Colors.grey[900],
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Play / pause button
                GestureDetector(
                  onTap: _initAndPlay,
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 6),

                // Seek bar (admin only; non-admin sees plain progress)
                Expanded(
                  child: _initialized
                      ? (widget.isAdmin
                      ? Slider(
                    value: _position.inSeconds
                        .toDouble()
                        .clamp(0,
                        _duration.inSeconds.toDouble()),
                    max: _duration.inSeconds > 0
                        ? _duration.inSeconds.toDouble()
                        : 1.0,
                    activeColor: Colors.teal,
                    inactiveColor: Colors.teal.withOpacity(0.3),
                    onChanged: (v) => _ctrl!
                        .seekTo(Duration(seconds: v.toInt())),
                  )
                      : LinearProgressIndicator(
                    value: _duration.inSeconds > 0
                        ? (_position.inSeconds /
                        _duration.inSeconds)
                        .clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor:
                    Colors.teal.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(
                        Colors.teal),
                  ))
                      : const SizedBox.shrink(),
                ),

                const SizedBox(width: 6),

                // Time label
                if (_initialized)
                  Text(
                    '${_fmt(_position)} / ${_fmt(_duration)}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 10),
                  ),

                const SizedBox(width: 6),

                // Admin: rewind / fast-forward
                if (widget.isAdmin && _initialized) ...[
                  GestureDetector(
                    onTap: () async {
                      final p = _ctrl!.value.position;
                      final np = p - const Duration(seconds: 10);
                      await _ctrl!.seekTo(
                          np < Duration.zero ? Duration.zero : np);
                    },
                    child: const Icon(Icons.replay_10,
                        color: Colors.white70, size: 18),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      final p = _ctrl!.value.position;
                      final np = p + const Duration(seconds: 10);
                      await _ctrl!
                          .seekTo(np > _duration ? _duration : np);
                    },
                    child: const Icon(Icons.forward_10,
                        color: Colors.white70, size: 18),
                  ),
                ],

                // File name
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
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

// ─── Drawing Painter ───────────────────────────────────────────────────────────
class _DrawingPainter extends CustomPainter {
  final List<Offset?> points;
  _DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) => true;
}

// ─── Full-screen Video Page ────────────────────────────────────────────────────
class _VideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final String fileName;
  final bool isAdmin;

  const _VideoPage(
      {required this.controller,
        required this.fileName,
        required this.isAdmin});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  bool _initialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _initialized = true;
          _duration = widget.controller.value.duration;
        });
        widget.controller.play();
      }
    });
    widget.controller.addListener(() {
      if (mounted) {
        setState(() => _position = widget.controller.value.position);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(() {});
    widget.controller.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(30),
        child: AppBar(
          backgroundColor: Colors.black,
          title:
          Text(widget.fileName, style: const TextStyle(fontSize: 13)),
        ),
      ),
      body: Center(
        child: _initialized
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
            const SizedBox(height: 8),
            // Always show scrubber in full-screen; admin gets extra controls
            Slider(
              value: _position.inSeconds
                  .toDouble()
                  .clamp(0, _duration.inSeconds.toDouble()),
              max: _duration.inSeconds > 0
                  ? _duration.inSeconds.toDouble()
                  : 1.0,
              activeColor: Colors.teal[700],
              inactiveColor: Colors.teal[100],
              onChanged: widget.isAdmin
                  ? (v) => widget.controller
                  .seekTo(Duration(seconds: v.toInt()))
                  : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isAdmin)
                  IconButton(
                    icon: const Icon(Icons.replay_10,
                        color: Colors.teal, size: 20),
                    onPressed: () {
                      final np = _position -
                          const Duration(seconds: 10);
                      widget.controller.seekTo(
                          np < Duration.zero ? Duration.zero : np);
                    },
                  ),
                IconButton(
                  icon: Icon(
                      widget.controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.teal,
                      size: 20),
                  onPressed: () {
                    if (widget.controller.value.isPlaying) {
                      widget.controller.pause();
                    } else {
                      widget.controller.play();
                    }
                  },
                ),
                if (widget.isAdmin)
                  IconButton(
                    icon: const Icon(Icons.forward_10,
                        color: Colors.teal, size: 20),
                    onPressed: () {
                      final np = _position +
                          const Duration(seconds: 10);
                      widget.controller.seekTo(
                          np > _duration ? _duration : np);
                    },
                  ),
              ],
            ),
            Text(
              '${_fmt(_position)} / ${_fmt(_duration)}',
              style: const TextStyle(
                  fontSize: 12, color: Colors.white70),
            ),
          ],
        )
            : const CircularProgressIndicator(color: Colors.teal),
      ),
    );
  }
}

// ─── Quiz Results Page ─────────────────────────────────────────────────────────
class QuizResultsPage extends StatelessWidget {
  final String quizSetName;
  final String folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final int timeTakenSeconds;
  final Map<String, dynamic>? apiResult;

  const QuizResultsPage({
    super.key,
    required this.quizSetName,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    required this.timeTakenSeconds,
    this.apiResult,
  });

  @override
  Widget build(BuildContext context) {
    final result = apiResult?['result'] as Map<String, dynamic>? ?? {};
    final score = result['score'] ?? 0;
    final total = result['total_questions'] ?? 0;
    final correct = result['correct_answers'] ?? 0;
    final percentage = result['percentage'] ?? 0;
    final mins = timeTakenSeconds ~/ 60;
    final secs = (timeTakenSeconds % 60).toString().padLeft(2, '0');
    final sw = MediaQuery.of(context).size.width;
    final fs = sw * 0.025;

    final vm = context.read<UserQuizViewModel>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(30),
        child: AppBar(
          title: Text(quizSetName,
              style: TextStyle(fontSize: fs), overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.blue[700],
          automaticallyImplyLeading: false,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal[700]!, Colors.teal[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Quiz Results',
                      style: TextStyle(
                          fontSize: fs * 1.2,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 16),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                        fontSize: fs * 2.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatChip(
                          label: 'Correct',
                          value: '$correct/$total',
                          color: Colors.green[200]!),
                      _StatChip(
                          label: 'Time',
                          value: '$mins:$secs',
                          color: Colors.blue[200]!),
                      _StatChip(
                          label: 'Score',
                          value: '$score',
                          color: Colors.orange[200]!),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (vm.selectedAnswers.isNotEmpty) ...[
              Text('Answer Details:',
                  style: TextStyle(
                      fontSize: fs * 1.1,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 10),
              for (int displayNum = 1;
              displayNum <= vm.allQuestions.length;
              displayNum++)
                Builder(builder: (_) {
                  final origIdx = vm.displayNumberToIndex[displayNum];
                  if (origIdx == null) return const SizedBox.shrink();
                  final q = vm.allQuestions[origIdx];
                  final selected = vm.selectedAnswers[origIdx];
                  final isCorrect = selected == q.correctAnswer;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q$displayNum: ${q.question}',
                            style: TextStyle(
                                fontSize: fs * 0.85,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(
                              'Your answer: ${selected ?? 'Not answered'}',
                              style: TextStyle(
                                  fontSize: fs * 0.75,
                                  color:
                                  isCorrect ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            if (!isCorrect && selected != null)
                              Text(
                                'Correct: ${q.correctAnswer}',
                                style: TextStyle(
                                    fontSize: fs * 0.75,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600),
                              ),
                          ]),
                        ],
                      ),
                    ),
                  );
                }),
            ],
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.home, color: Colors.white),
                label: const Text('Back to Home',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }
}