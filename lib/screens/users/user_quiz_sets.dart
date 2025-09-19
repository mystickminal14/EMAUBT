import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, File;
import 'package:ema_app/screens/users/user_folder_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:webview_windows/webview_windows.dart' as webview_windows;
import 'package:webview_windows/webview_windows.dart';

// TimerManager remains unchanged
class TimerManager {
  Timer? _timer;
  int _timeRemaining;
  final List<VoidCallback> _listeners = [];
  TimerManager._privateConstructor({int durationInSeconds = 3000})
      : _timeRemaining = durationInSeconds;

  static TimerManager? _instance;

  factory TimerManager({int durationInSeconds = 3000}) {
    _instance ??=
        TimerManager._privateConstructor(durationInSeconds: durationInSeconds);
    return _instance!;
  }

  int get timeRemaining => _timeRemaining;

  bool get isTimerRunning => _timer != null && _timer!.isActive;

  void startTimer({
    VoidCallback? onTick,
    VoidCallback? onTimeUp,
    VoidCallback? onSubmit,
  }) {
    if (_timer != null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        _timeRemaining--;
        _notifyListeners();
        onTick?.call();
      } else {
        stopTimer();
        _notifyListeners();
        onTimeUp?.call();
        onSubmit?.call();
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void resetTimer() {
    stopTimer();
    _timeRemaining = 3000;
    _notifyListeners();
  }

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

class UserQuizSetsPage extends StatefulWidget {
  final int quizSetId;
  final String quizSetName;
  final String userId;
  final String userName;
  final String userEmail;
  final String role;
  final int folderId;
  final String folderName;
  final bool isAdmin;
  final String userIdentifier;
  final bool preStart;
  final Map<String, String> cachedFiles; // New parameter

 const UserQuizSetsPage({
  super.key,
  required this.quizSetId,
  required this.quizSetName,
  required this.userId,
  required this.userName,
  required this.userEmail,
  required this.role,
  required this.folderId,
  required this.folderName,
  required this.isAdmin,
  required this.userIdentifier,
  required this.preStart,
  required this.cachedFiles, required quizData,
});

  @override
  _UserQuizSetsPageState createState() => _UserQuizSetsPageState();
}

class _UserQuizSetsPageState extends State<UserQuizSetsPage>
    with WidgetsBindingObserver {
  final TimerManager _timerManager = TimerManager();
  late Future<Map<String, dynamic>> _quizDataFuture;
  bool _hasStarted = false;
  final Map<int, bool> _attendedQuestions = {};
  final Map<int, String> _selectedAnswers = {};

  @override
  void initState() {
    super.initState();

    // Force landscape orientation for all Android devices, always
    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    _quizDataFuture = fetchQuizData();
    _timerManager.addListener(_updateTimer);
  }

  @override
  void dispose() {
    _timerManager.removeListener(_updateTimer);
    _timerManager.resetTimer();
_cleanUpTempFiles();
    // Restore all orientations on dispose for Android and iOS
   if (Platform.isAndroid || Platform.isIOS) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
   else if (Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    super.dispose();
  }

  void _updateTimer() {
    if (mounted) {
      setState(() {});
    }
  }
Future<void> _cleanUpTempFiles() async {
  try {
    for (var filePath in widget.cachedFiles.values) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  } catch (e) {
    if (kDebugMode) print('Error cleaning up temp files: $e');
  }
}
Future<Map<String, dynamic>> fetchQuizData() async {
  try {
    final response = await http
        .get(
          Uri.parse(
              'https://theemaeducation.com/quiz_set_detail_page.php?quiz_set_id=${widget.quizSetId}'),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return _processQuizData(data);
    } else {
      throw Exception('Failed to load quiz data: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Network error: $e');
  }
}

  Map<String, dynamic> _processQuizData(Map<String, dynamic> data) {
    List<Map<String, dynamic>> questions = data['questions'] != null
        ? List<Map<String, dynamic>>.from(data['questions'])
        : [];

    int listeningCount = questions
        .where((q) => (q['question_type'] ?? 'Reading') == 'Listening')
        .length;
    int readingCount = questions
        .where((q) => (q['question_type'] ?? 'Reading') == 'Reading')
        .length;

    List<Map<String, dynamic>> readingQuestions = [];
    List<Map<String, dynamic>> listeningQuestions = [];
    int displayNumber = 1;

    for (int i = 0; i < questions.length; i++) {
      var question = questions[i];
      String type = question['question_type'] ?? 'Reading';
      if (type == 'Reading') {
        readingQuestions.add({
          'originalIndex': i,
          'displayNumber': displayNumber++,
        });
      }
    }

    for (int i = 0; i < questions.length; i++) {
      var question = questions[i];
      String type = question['question_type'] ?? 'Reading';
      if (type == 'Listening') {
        listeningQuestions.add({
          'originalIndex': i,
          'displayNumber': displayNumber++,
        });
      }
    }

    return {
      'totalQuestions': questions.length,
      'listeningCount': listeningCount,
      'readingCount': readingCount,
      'readingQuestions': readingQuestions,
      'listeningQuestions': listeningQuestions,
      'questions': questions, // Simpan pertanyaan mentah untuk QuizQuestionPage
    };
  }

  Future<bool> _incrementAccessCount() async {
    if (widget.userId.isEmpty || widget.quizSetId == 1 || widget.isAdmin) {
      return true;
    }
    try {
      final response = await http.post(
        Uri.parse('https://theemaeducation.com/increment_access.php'),
        body: {
          'identifier': widget.userId,
          'is_admin': widget.isAdmin.toString(),
          'item_id': widget.quizSetId.toString(),
          'item_type': 'quiz_set',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _submitQuiz(BuildContext context) {
    if (!_hasStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please start the quiz first!')),
      );
      return;
    }

    // Tampilkan dialog konfirmasi
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Submission'),
          content: const Text('Are you sure you want to submit the quiz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Batal
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                _timerManager.stopTimer();
                final int timeTakenInSeconds =
                    3000 - _timerManager.timeRemaining;
                final int minutesTaken = timeTakenInSeconds ~/ 60;
                final int secondsTaken = timeTakenInSeconds % 60;
                fetchQuestionsAndSubmit(
                    context, timeTakenInSeconds, minutesTaken, secondsTaken);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    _timerManager.stopTimer();

    final int timeTakenInSeconds = 3000 - _timerManager.timeRemaining;
    final int minutesTaken = timeTakenInSeconds ~/ 60;
    final int secondsTaken = timeTakenInSeconds % 60;

    fetchQuestionsAndSubmit(
        context, timeTakenInSeconds, minutesTaken, secondsTaken);
  }

  Future<void> fetchQuestionsAndSubmit(BuildContext context,
      int timeTakenInSeconds, int minutesTaken, int secondsTaken) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://theemaeducation.com/quiz_set_detail_page.php?quiz_set_id=${widget.quizSetId}'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['questions'] != null && data['questions'] is List) {
          List<Map<String, dynamic>> questions =
              List<Map<String, dynamic>>.from(data['questions'])
                  .map((q) => {
                        'id': q['id'],
                        'question': q['question'] ?? '',
                        'correct_answer': q['correct_answer'] ?? 'A',
                      })
                  .toList();

          int correctAnswersCount = 0;
          List<Map<String, String>> correctAnswersList = [];
          for (var entry in _selectedAnswers.entries) {
            final questionIndex = entry.key;
            final selectedChoice = entry.value;
            final correctChoice = questions[questionIndex]['correct_answer'];
            final questionText = questions[questionIndex]['question'];
            if (selectedChoice == correctChoice) correctAnswersCount++;
            correctAnswersList.add({
              'question': (questionIndex + 1).toString(),
              'selected': selectedChoice,
              'correct': correctChoice,
              'question_text': questionText,
            });
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SubmitPage(
                selectedAnswers: _selectedAnswers,
                quizSetId: widget.quizSetId,
                quizSetName: widget.quizSetName,
                timeTaken:
                    '$minutesTaken:${secondsTaken.toString().padLeft(2, '0')}',
                totalQuestions: questions.length,
                totalCorrect: correctAnswersCount,
                correctAnswersList: correctAnswersList,
                folderId: widget.folderId,
                folderName: widget.folderName,
                userIdentifier:
                    widget.isAdmin ? widget.userEmail : widget.userId,
                isAdmin: widget.isAdmin,
                timePerQuestion: {}, cachedFiles: {},
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch quiz data')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

void _startQuiz(BuildContext context) async {
  if (!_hasStarted) {
    bool incremented = true;
    if (!widget.isAdmin && widget.userId.isNotEmpty) {
      incremented = await _incrementAccessCount();
    }
    if (incremented) {
      setState(() {
        _hasStarted = true;
      });
      _timerManager.startTimer(
        onTick: () {
          setState(() {});
        },
        onTimeUp: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Time is up!')),
          );
        },
        onSubmit: () {
          _submitQuiz(context);
        },
      );
      final quizData = await _quizDataFuture; // Wait for quiz data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizQuestionPage(
            questionNumber: 1,
            quizSetId: widget.quizSetId,
            quizSetName: widget.quizSetName,
            folderId: widget.folderId,
            folderName: widget.folderName,
            userIdentifier: widget.isAdmin ? widget.userEmail : widget.userId,
            isAdmin: widget.isAdmin,
            selectedAnswers: _selectedAnswers,
            cachedFiles: widget.cachedFiles,
            quizData: quizData, // Pass fetched quiz data
            onQuestionAttended: (displayNumber) {
              setState(() {
                _attendedQuestions[displayNumber] = true;
              });
            },
            onAnswerSelected: (originalIndex, choice) {
              setState(() {
                _selectedAnswers[originalIndex] = choice;
                final question = [
                  ...quizData['readingQuestions'],
                  ...quizData['listeningQuestions'],
                ].firstWhere(
                  (q) => q['originalIndex'] == originalIndex,
                  orElse: () => null,
                );
                if (question != null) {
                  int displayNumber = question['displayNumber'];
                  _attendedQuestions[displayNumber] = true;
                }
              });
            },
            Function: (questionIndex, choice) {},
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update access count')),
      );
    }
  } else {
    final quizData = await _quizDataFuture; // Wait for quiz data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizQuestionPage(
          questionNumber: 1,
          quizSetId: widget.quizSetId,
          quizSetName: widget.quizSetName,
          folderId: widget.folderId,
          folderName: widget.folderName,
          userIdentifier: widget.isAdmin ? widget.userEmail : widget.userId,
          isAdmin: widget.isAdmin,
          selectedAnswers: _selectedAnswers,
          cachedFiles: widget.cachedFiles,
          quizData: quizData, // Pass fetched quiz data
          onQuestionAttended: (displayNumber) {
            setState(() {
              _attendedQuestions[displayNumber] = true;
            });
          },
          onAnswerSelected: (originalIndex, choice) {
            setState(() {
              _selectedAnswers[originalIndex] = choice;
              final question = [
                ...quizData['readingQuestions'],
                ...quizData['listeningQuestions'],
              ].firstWhere(
                (q) => q['originalIndex'] == originalIndex,
                orElse: () => null,
              );
              if (question != null) {
                int displayNumber = question['displayNumber'];
                _attendedQuestions[displayNumber] = true;
              }
            });
          },
          Function: (questionIndex, choice) {},
        ),
      ),
    );
  }
}

void _navigateToQuestion(int displayNumber, BuildContext context) async {
  if (!_hasStarted) {
    bool incremented = true;
    if (!widget.isAdmin && widget.userId.isNotEmpty) {
      incremented = await _incrementAccessCount();
    }
    if (incremented) {
      setState(() {
        _hasStarted = true;
      });
      _timerManager.startTimer(
        onTick: () {
          setState(() {});
        },
        onTimeUp: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Time is up!')),
          );
        },
        onSubmit: () {
          _submitQuiz(context);
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update access count')),
      );
      return;
    }
  }
  final quizData = await _quizDataFuture; // Wait for quiz data
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => QuizQuestionPage(
        questionNumber: displayNumber,
        quizSetId: widget.quizSetId,
        quizSetName: widget.quizSetName,
        folderId: widget.folderId,
        folderName: widget.folderName,
        userIdentifier: widget.isAdmin ? widget.userEmail : widget.userId,
        isAdmin: widget.isAdmin,
        selectedAnswers: _selectedAnswers,
        cachedFiles: widget.cachedFiles,
        quizData: quizData, // Pass fetched quiz data
        onQuestionAttended: (displayNumber) {
          setState(() {
            _attendedQuestions[displayNumber] = true;
          });
        },
        onAnswerSelected: (originalIndex, choice) {
          setState(() {
            _selectedAnswers[originalIndex] = choice;
            final question = [
              ...quizData['readingQuestions'],
              ...quizData['listeningQuestions'],
            ].firstWhere(
              (q) => q['originalIndex'] == originalIndex,
              orElse: () => null,
            );
            if (question != null) {
              int displayNumber = question['displayNumber'];
              _attendedQuestions[displayNumber] = true;
            }
          });
        },
        Function: (questionIndex, choice) {},
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    // Force landscape for Android even if hot-reload or navigation occurs
    if (Platform.isAndroid) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    // Responsive font size based on screen width
    double baseFontSize = MediaQuery.of(context).size.width * 0.018;
    double buttonFontSize = MediaQuery.of(context).size.width * 0.016;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: AppBar(
          elevation: 2,
          backgroundColor: Colors.blue[700],
          title: Text(
            widget.quizSetName,
            style: TextStyle(fontSize: baseFontSize + 2, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Center(
                child: Text(
                  'Time Left: ${_timerManager.timeRemaining ~/ 60}:${(_timerManager.timeRemaining % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: baseFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 16.0),
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use constraints to adjust font size and layout
            final fontSize = constraints.maxWidth * 0.018;
            return Stack(
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: _quizDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    int totalQuestions = snapshot.data?['totalQuestions'] ?? 0;
                    int listeningCount = snapshot.data?['listeningCount'] ?? 0;
                    int readingCount = snapshot.data?['readingCount'] ?? 0;

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        constraints.maxWidth * 0.01,
                        0,
                        constraints.maxWidth * 0.01,
                        constraints.maxHeight * 0.01,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => _startQuiz(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              padding: EdgeInsets.symmetric(
                                  horizontal: fontSize * 2, vertical: fontSize),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 2,
                            ),
                            child: Text(
                              'Start Quiz',
                              style: TextStyle(
                                fontSize: buttonFontSize + 2,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.01),
                          Expanded(
                            child: _buildQuestionGroups(
                              totalQuestions,
                              listeningCount,
                              readingCount,
                              fontSize: fontSize,
                              buttonFontSize: buttonFontSize,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                FutureBuilder<Map<String, dynamic>>(
                  future: _quizDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                  color: Colors.white),
                              const SizedBox(height: 16),
                              Text(
                                'Fetching Questions...',
                                style: TextStyle(
                                  fontSize: baseFontSize + 2,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Add fontSize and buttonFontSize as optional parameters for responsiveness
  Widget _buildQuestionGroups(
    int totalQuestions,
    int listeningCount,
    int readingCount, {
    double fontSize = 16,
    double buttonFontSize = 14,
  }) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _quizDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading quiz data'));
        }

        List<Map<String, dynamic>> readingQuestions =
            snapshot.data?['readingQuestions'] ?? [];
        List<Map<String, dynamic>> listeningQuestions =
            snapshot.data?['listeningQuestions'] ?? [];

        String leftLabel = readingCount > 0 ? 'Reading' : '';
        String rightLabel = listeningCount > 0 ? 'Listening' : '';

        return LayoutBuilder(
          builder: (context, constraints) {
            final localFontSize = constraints.maxWidth * 0.018;

            return Column(
              children: [
                // Question Grid
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reading Section
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(localFontSize * 0.5),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.grey[300]!, width: 1),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (leftLabel.isNotEmpty)
                                Text(
                                  leftLabel,
                                  style: TextStyle(
                                    fontSize: localFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              if (leftLabel.isNotEmpty)
                                SizedBox(height: localFontSize * 0.5),
                              Expanded(
                                child: _buildNumberGrid(
                                  readingQuestions,
                                  context,
                                  snapshot.data,
                                  fontSize: localFontSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: constraints.maxWidth * 0.01),
                      // Listening Section
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(localFontSize * 0.5),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.grey[300]!, width: 1),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (rightLabel.isNotEmpty)
                                Text(
                                  rightLabel,
                                  style: TextStyle(
                                    fontSize: localFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              if (rightLabel.isNotEmpty)
                                SizedBox(height: localFontSize * 0.5),
                              Expanded(
                                child: _buildNumberGrid(
                                  listeningQuestions,
                                  context,
                                  snapshot.data,
                                  fontSize: localFontSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: constraints.maxHeight * 0.01),
                // Submit Button
                ElevatedButton(
                  onPressed: _hasStarted ? () => _submitQuiz(context) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    padding: EdgeInsets.symmetric(
                        horizontal: buttonFontSize * 2,
                        vertical: buttonFontSize),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  child: Text(
                    'Submit Quiz',
                    style: TextStyle(
                      fontSize: buttonFontSize + 2,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Add fontSize as an optional parameter for responsiveness
  Widget _buildNumberGrid(
    List<Map<String, dynamic>> questions,
    BuildContext context,
    Map<String, dynamic>? data, {
    double fontSize = 16,
  }) {
    if (questions.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait =
            MediaQuery.of(context).orientation == Orientation.portrait;
        final maxWidth = constraints.maxWidth;

        // Calculate crossAxisCount to fit up to 40 questions
        final totalQuestions = questions.length;
        final crossAxisCount = isPortrait
            ? (totalQuestions <= 20 ? 5 : 6)
            : (totalQuestions <= 20 ? 7 : 8);
        final buttonSize = maxWidth / crossAxisCount - 8; // Adjust for spacing

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 4.0,
            crossAxisSpacing: 4.0,
            childAspectRatio: 1.0,
          ),
          itemCount: questions.length,
          itemBuilder: (context, index) {
            final question = questions[index];
            final displayNumber = question['displayNumber'];
            return _buildSquareButton(
                displayNumber, context, data, buttonSize * 0.4);
          },
        );
      },
    );
  }

  Widget _buildSquareButton(int displayNumber, BuildContext context,
      Map<String, dynamic>? data, double fontSize) {
    bool isAttended = _attendedQuestions[displayNumber] ?? false;
    bool isAnswered = false;

    if (data != null) {
      final questionData = [
        ...(data['readingQuestions'] ?? []),
        ...(data['listeningQuestions'] ?? []),
      ].firstWhere(
        (q) => q['displayNumber'] == displayNumber,
        orElse: () => null,
      );

      if (questionData != null) {
        final originalIndex = questionData['originalIndex'];
        isAnswered = _selectedAnswers.containsKey(originalIndex);
      }
    }

    return GestureDetector(
      onTap: () => _navigateToQuestion(displayNumber, context),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          border: Border.all(color: Colors.black, width: 1),
          color: isAnswered
              ? Colors.green[600]
              : (isAttended ? Colors.blue[600] : Colors.grey[600]),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          displayNumber.toString(),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}


class QuizQuestionPage extends StatefulWidget {
  final int questionNumber;
  final int quizSetId;
  final String quizSetName;
  final int folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final Function(int)? onQuestionAttended;
  final Function(int, String)? onAnswerSelected;
  final Map<int, String> selectedAnswers;
  final Map<String, String> cachedFiles;
  final Map<String, dynamic> quizData;
  final Function(dynamic questionIndex, dynamic choice) Function;

  const QuizQuestionPage({
    super.key,
    required this.questionNumber,
    required this.quizSetId,
    required this.quizSetName,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    required this.selectedAnswers,
    this.onQuestionAttended,
    this.onAnswerSelected,
    required this.cachedFiles,
    required this.quizData,
    required this.Function,
  });

  @override
  _QuizQuestionPageState createState() => _QuizQuestionPageState();
}

class _QuizQuestionPageState extends State<QuizQuestionPage> {
  final TimerManager _timerManager = TimerManager();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  bool _isAudioPlaying = false;
  final Set<String> _playedMedia = {};
  bool _isBackButtonNavigation = false;
  VideoPlayerController? _videoController;
  int get attendedCount => widget.selectedAnswers.length;
  bool _isDrawingMode = false;
  final List<Offset?> _mainPoints = [];
  final List<Offset?> _audioPoints = [];
  final List<Offset?> _choicePoints = [];
  static const String baseUrl = 'https://theemaeducation.com/';
  String? _currentAudioFile;
  List<int> displayNumbers = [];
  Map<int, int> displayNumberToIndex = {};
  bool _isDialogOpen = false;
  final Map<int, int> _timePerQuestion = {};
  final Stopwatch _questionStopwatch = Stopwatch();

  bool _isImageFile(String? filePath) {
    if (filePath == null) return false;
    final ext = filePath.toLowerCase();
    return ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.gif');
  }

  bool _isVideoFile(String? filePath) {
    if (filePath == null) return false;
    final ext = filePath.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.mov');
  }

  double _getFontSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1024 ? 12.0 : 10.0;
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    _timerManager.addListener(_updateTimer);
    _processQuestions(widget.quizData);
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _isAudioPlaying = false;
            _currentAudioFile = null;
          }
        });
      }
    });
    _startQuestionTimer();
  }

  @override
  void dispose() {
    _timerManager.removeListener(_updateTimer);
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _videoController?.dispose();
    _stopQuestionTimer();
    super.dispose();
  }

  void _updateTimer() {
    if (mounted) setState(() {});
  }

  void _startQuestionTimer() {
    _questionStopwatch.reset();
    _questionStopwatch.start();
  }

  void _stopQuestionTimer() {
    if (_questionStopwatch.isRunning) {
      _questionStopwatch.stop();
      final elapsedSeconds = _questionStopwatch.elapsed.inSeconds;
      final originalIndex = questions[currentQuestionIndex]['originalIndex'];
      setState(() {
        _timePerQuestion[originalIndex] = elapsedSeconds;
      });
    }
  }

  void _processQuestions(Map<String, dynamic> data) {
    if (data['questions'] != null && data['questions'] is List) {
      List<Map<String, dynamic>> fetchedQuestions =
          List<Map<String, dynamic>>.from(data['questions'])
              .map((q) => {
                    'id': q['id'],
                    'question': q['question'] ?? '',
                    'optional_text': q['optional_text'] ?? '',
                    'question_file': q['question_file'] ?? '',
                    'question_type': q['question_type'] ?? 'Reading',
                    'question_word_formatting': List<Map<String, dynamic>>.from(
                        q['question_word_formatting'] ?? []),
                    'optional_word_formatting': List<Map<String, dynamic>>.from(
                        q['optional_word_formatting'] ?? []),
                    'choices': {
                      'A': {
                        'choice_text': q['choice_A_text'] ?? '',
                        'choice_file': q['choice_A_file'] ?? '',
                        'word_formatting': List<Map<String, dynamic>>.from(
                            q['choice_A_word_formatting'] ?? []),
                      },
                      'B': {
                        'choice_text': q['choice_B_text'] ?? '',
                        'choice_file': q['choice_B_file'] ?? '',
                        'word_formatting': List<Map<String, dynamic>>.from(
                            q['choice_B_word_formatting'] ?? []),
                      },
                      'C': {
                        'choice_text': q['choice_C_text'] ?? '',
                        'choice_file': q['choice_C_file'] ?? '',
                        'word_formatting': List<Map<String, dynamic>>.from(
                            q['choice_C_word_formatting'] ?? []),
                      },
                      'D': {
                        'choice_text': q['choice_D_text'] ?? '',
                        'choice_file': q['choice_D_file'] ?? '',
                        'word_formatting': List<Map<String, dynamic>>.from(
                            q['choice_D_word_formatting'] ?? []),
                      },
                    },
                    'correct_answer': q['correct_answer'] ?? 'A',
                  })
              .toList();

      List<Map<String, dynamic>> readingQuestions = [];
      List<Map<String, dynamic>> listeningQuestions = [];
      int displayNumber = 1;

      for (int i = 0; i < fetchedQuestions.length; i++) {
        var question = fetchedQuestions[i];
        String type = question['question_type'] ?? 'Reading';
        if (type == 'Reading') {
          readingQuestions.add({
            ...question,
            'originalIndex': i,
            'displayNumber': displayNumber++,
          });
        }
      }

      for (int i = 0; i < fetchedQuestions.length; i++) {
        var question = fetchedQuestions[i];
        String type = question['question_type'] ?? 'Reading';
        if (type == 'Listening') {
          listeningQuestions.add({
            ...question,
            'originalIndex': i,
            'displayNumber': displayNumber++,
          });
        }
      }

      if (mounted) {
        setState(() {
          questions = [...readingQuestions, ...listeningQuestions];
          displayNumbers =
              questions.map((q) => q['displayNumber'] as int).toList();
          displayNumberToIndex = {};
          for (int i = 0; i < questions.length; i++) {
            displayNumberToIndex[questions[i]['displayNumber']] = i;
          }
          if (questions.isNotEmpty) {
            int targetDisplayNumber = widget.questionNumber;
            currentQuestionIndex =
                displayNumberToIndex[targetDisplayNumber] ?? 0;
          }
        });
      }
    }
  }

  void _goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      _stopQuestionTimer();
      if (_isAudioPlaying) {
        _audioPlayer.stop();
        setState(() {
          _isAudioPlaying = false;
          _currentAudioFile = null;
        });
      }
      setState(() {
        currentQuestionIndex--;
        _startQuestionTimer();
      });
    }
  }

  void _goToNextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      _stopQuestionTimer();
      if (_isAudioPlaying) {
        _audioPlayer.stop();
        setState(() {
          _isAudioPlaying = false;
          _currentAudioFile = null;
        });
      }
      setState(() {
        currentQuestionIndex++;
        _startQuestionTimer();
      });
    }
  }

  void _selectAnswer(String choice) {
    _stopQuestionTimer();
    setState(() {
      widget.onAnswerSelected
          ?.call(questions[currentQuestionIndex]['originalIndex'], choice);
      widget.onQuestionAttended
          ?.call(questions[currentQuestionIndex]['displayNumber']);
      _startQuestionTimer();
    });
  }

  Future<void> _playAudio(String filePath) async {
    final isLocal = widget.cachedFiles.containsKey(filePath) || !filePath.startsWith('http');
    final source = isLocal
        ? DeviceFileSource(widget.cachedFiles[filePath] ?? filePath)
        : UrlSource(filePath);
    try {
      if (_timerManager.timeRemaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time is up. Audio cannot be played.')),
        );
        return;
      }
      if (!widget.isAdmin && _playedMedia.contains(filePath)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio already played.')),
        );
        return;
      }
      if (_isAudioPlaying && _currentAudioFile != filePath) {
        await _audioPlayer.stop();
        await _audioPlayer.release();
      }
      setState(() {
        _isAudioPlaying = true;
        _currentAudioFile = filePath;
        if (!widget.isAdmin) _playedMedia.add(filePath);
      });

      await _audioPlayer.play(source);

      _audioPlayer.onPlayerComplete.listen((_) async {
        try {
          await _audioPlayer.stop();
          await _audioPlayer.release();
        } catch (e) {
          if (kDebugMode) print('Error during cleanup: $e');
        }
        if (mounted) {
          setState(() {
            _isAudioPlaying = false;
            _currentAudioFile = null;
          });
        }
      });
      _audioPlayer.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAudioPlaying = false;
          _currentAudioFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play audio: $e')),
        );
      }
    }
  }

  Future<void> _pauseAudio() async {
    try {
      await _audioPlayer.pause();
      setState(() {
        _isAudioPlaying = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pause audio: $e')),
      );
    }
  }

  Future<void> _fastForwardAudio() async {
    try {
      final currentPosition =
          await _audioPlayer.getCurrentPosition() ?? Duration.zero;
      final newPosition = currentPosition + const Duration(seconds: 10);
      await _audioPlayer.seek(newPosition);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fast forward: $e')),
      );
    }
  }

  Future<void> _rewindAudio() async {
    try {
      final currentPosition =
          await _audioPlayer.getCurrentPosition() ?? Duration.zero;
      final newPosition = currentPosition - const Duration(seconds: 10);
      await _audioPlayer
          .seek(newPosition < Duration.zero ? Duration.zero : newPosition);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rewind: $e')),
      );
    }
  }

  Widget _buildFileBox(String filePath) {
    if (filePath.isEmpty) return const SizedBox.shrink();
    final fullUrl = filePath.startsWith('http') ? filePath : '$baseUrl$filePath';
    final localPath = widget.cachedFiles[fullUrl] ?? '';
    final fileExtension = filePath.split('.').last.toLowerCase();
    final fileName = filePath.split('/').last;
    final fontSize = _getFontSize(context);

    if (_isImageFile(filePath)) {
      return GestureDetector(
        onTap: () => _showFullImage(localPath.isNotEmpty ? localPath : fullUrl),
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: localPath.isNotEmpty
              ? Image.file(
                  File(localPath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    if (kDebugMode) print('Image load error: $error');
                    return const Icon(Icons.broken_image, size: 20);
                  },
                )
              : Image.network(
                  fullUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    if (kDebugMode) print('Image load error: $error');
                    return const Icon(Icons.broken_image, size: 20);
                  },
                ),
        ),
      );
    } else if (['mp3', 'wav'].contains(fileExtension)) {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.start,
        children: [
          if (!widget.isAdmin) ...[
            IconButton(
              icon: Icon(
                _playedMedia.contains(filePath)
                    ? Icons.check
                    : (_isAudioPlaying ? Icons.play_circle_filled : Icons.play_arrow),
                color: _isAudioPlaying ? Colors.grey : Colors.black54,
                size: 20,
              ),
              onPressed: _playedMedia.contains(filePath) || _isAudioPlaying
                  ? null
                  : () => _playAudio(localPath.isNotEmpty ? localPath : fullUrl),
            ),
            Text(
              fileName,
              style: TextStyle(
                fontSize: fontSize * 0.8,
                color: _isAudioPlaying ? Colors.grey : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                _isAudioPlaying && _currentAudioFile == filePath ? Icons.pause : Icons.play_arrow,
                color: Colors.black54,
                size: 20,
              ),
              onPressed: () {
                if (_isAudioPlaying && _currentAudioFile == filePath) {
                  _pauseAudio();
                } else {
                  _playAudio(localPath.isNotEmpty ? localPath : fullUrl);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.fast_rewind, color: Colors.black54, size: 20),
              onPressed: _isAudioPlaying && _currentAudioFile == filePath ? _rewindAudio : null,
            ),
            IconButton(
              icon: const Icon(Icons.fast_forward, color: Colors.black54, size: 20),
              onPressed: _isAudioPlaying && _currentAudioFile == filePath ? _fastForwardAudio : null,
            ),
            Text(
              fileName,
              style: TextStyle(
                fontSize: fontSize * 0.8,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    } else if (_isVideoFile(filePath)) {
      return GestureDetector(
        onTap: () {
          if (localPath.isNotEmpty) {
            final controller = VideoPlayerController.file(File(localPath));
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerPage(
                  url: localPath,
                  fileName: fileName,
                  controller: controller,
                  isAdmin: widget.isAdmin,
                ),
              ),
            );
          } else {
            final controller = VideoPlayerController.network(fullUrl);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerPage(
                  url: fullUrl,
                  fileName: fileName,
                  controller: controller,
                  isAdmin: widget.isAdmin,
                ),
              ),
            );
          }
          if (!widget.isAdmin) _playedMedia.add(filePath);
        },
        child: Container(
          width: MediaQuery.of(context).size.width * 0.3,
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _playedMedia.contains(filePath) && !widget.isAdmin ? Colors.grey[400] : Colors.grey[200],
            boxShadow: const [
              BoxShadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1)
            ],
          ),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.start,
            children: [
              Icon(
                _playedMedia.contains(filePath) && !widget.isAdmin ? Icons.check : Icons.play_circle_filled,
                color: _playedMedia.contains(filePath) && !widget.isAdmin ? Colors.grey : Colors.black54,
                size: 14,
              ),
              Flexible(
                child: Text(
                  fileName,
                  style: TextStyle(
                    fontSize: fontSize * 0.7,
                    color: _playedMedia.contains(filePath) && !widget.isAdmin ? Colors.grey : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (['pdf', 'doc', 'docx'].contains(fileExtension)) {
      return Container(
        width: MediaQuery.of(context).size.width * 0.3,
        height: 50,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey[200],
          boxShadow: const [
            BoxShadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1)
          ],
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.start,
          children: [
            const Icon(Icons.description, color: Colors.black54, size: 14),
            Flexible(
              child: Text(
                fileName,
                style: TextStyle(fontSize: fontSize * 0.7, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: MediaQuery.of(context).size.width * 0.3,
        height: 50,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey[200],
          boxShadow: const [
            BoxShadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 1)
          ],
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.start,
          children: [
            const Icon(Icons.attach_file, color: Colors.black54, size: 14),
            Flexible(
              child: Text(
                fileName,
                style: TextStyle(fontSize: fontSize * 0.7, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLastQuestion = currentQuestionIndex == questions.length - 1;
    bool isFirstQuestion = currentQuestionIndex == 0;

    if (!kIsWeb && Platform.isAndroid) {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }

    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final appBarHeight = 30.0;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomNavHeight = 50.0;

    Widget content = AbsorbPointer(
      absorbing: _isDialogOpen,
      child: WillPopScope(
        onWillPop: () async {
          if (_isBackButtonNavigation) {
            _isBackButtonNavigation = false;
            return true;
          }
          if (_isAudioPlaying && !widget.isAdmin) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Please wait until the audio finishes')),
            );
            return false;
          }
          return true;
        },
        child: Stack(
          children: [
            Scaffold(
              extendBodyBehindAppBar: true,
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(appBarHeight),
                child: AppBar(
                  backgroundColor: Colors.blue[100],
                  title: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: screenSize.width * 0.4,
                    ),
                    child: Text(
                      "Q${displayNumbers.isNotEmpty && currentQuestionIndex < displayNumbers.length ? displayNumbers[currentQuestionIndex] : (currentQuestionIndex + 1)} - ${widget.quizSetName}",
                      style: TextStyle(
                        fontSize: screenSize.width * 0.015,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  automaticallyImplyLeading: false,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 24),
                    onPressed: (currentQuestionIndex == 0 ||
                            (_isAudioPlaying && !widget.isAdmin))
                        ? null
                        : _goToPreviousQuestion,
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLandscape)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: screenSize.width * 0.3,
                              ),
                              child: Text(
                                'इमा एजुकेशन, बागबजार, फोन नम्बर: +9779851213520',
                                style: TextStyle(
                                  fontSize: screenSize.width * 0.012,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (isLandscape) const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_timerManager.timeRemaining ~/ 60}:${(_timerManager.timeRemaining % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: screenSize.width * 0.015,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              body: questions.isEmpty
                  ? const SizedBox.shrink()
                  : Container(
                      padding: EdgeInsets.only(
                        top: appBarHeight + statusBarHeight + 8,
                        bottom: 8,
                        left: 12.0,
                        right: 12.0,
                      ),
                      height: double.infinity,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: isLandscape ? 1 : 1,
                            child: _buildLeftSide(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: isLandscape ? 1 : 1,
                            child: _buildRightSide(),
                          ),
                        ],
                      ),
                    ),
              bottomNavigationBar: Container(
                height: bottomNavHeight,
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
                      onPressed: isFirstQuestion || (!widget.isAdmin && _isAudioPlaying)
                          ? null
                          : _goToPreviousQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size(screenSize.width * 0.12, 34),
                      ),
                      child: Text(
                        "Previous",
                        style: TextStyle(fontSize: screenSize.width * 0.014),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: (!widget.isAdmin && _isAudioPlaying)
                          ? null
                          : () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size(screenSize.width * 0.15, 34),
                      ),
                      child: Text(
                        "Go to Questions",
                        style: TextStyle(fontSize: screenSize.width * 0.014),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isLastQuestion || (!widget.isAdmin && _isAudioPlaying)
                          ? null
                          : _goToNextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLastQuestion ? Colors.grey : Colors.blue,
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size(screenSize.width * 0.12, 34),
                      ),
                      child: Text(
                        "Next",
                        style: TextStyle(fontSize: screenSize.width * 0.014),
                      ),
                    ),
                  ],
                ),
              ),
              floatingActionButton: widget.isAdmin
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FloatingActionButton(
                          onPressed: () {
                            setState(() {
                              _isDrawingMode = !_isDrawingMode;
                              if (!_isDrawingMode) {
                                _mainPoints.clear();
                                _audioPoints.clear();
                                _choicePoints.clear();
                              }
                            });
                          },
                          tooltip: _isDrawingMode ? 'Exit Drawing' : 'Enter Drawing',
                          child: Icon(
                              _isDrawingMode ? Icons.edit_off : Icons.edit,
                              size: 20),
                        ),
                        const SizedBox(height: 8),
                        if (_isDrawingMode)
                          FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                _mainPoints.clear();
                                _audioPoints.clear();
                                _choicePoints.clear();
                              });
                            },
                            tooltip: 'Clear Drawing',
                            child: const Icon(Icons.clear, size: 20),
                          ),
                      ],
                    )
                  : null,
            ),
            if (questions.isEmpty)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'Fetching Questions...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return widget.isAdmin && Platform.isWindows
        ? InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 3.0,
            child: content,
          )
        : content;
  }

Widget _buildFormattedText(String text, List<Map<String, dynamic>> formatting) {
  final screenSize = MediaQuery.of(context).size;
  final baseFontSize = screenSize.width < 1200 ? 14.0 : 16.0;
  final adjustedFontSize = baseFontSize; // Changed from baseFontSize * 2

  if (text.isEmpty) {
    return const SizedBox.shrink();
  }

  if (formatting.isEmpty) {
    return SelectableText(
      text,
      style: TextStyle(
        fontSize: adjustedFontSize,
        height: 1.3,
        color: Colors.black87,
      ),
    );
  }

  List<TextSpan> spans = [];
  List<String> words = text.split(' ');

  for (int i = 0; i < words.length; i++) {
    bool isBold = i < formatting.length ? formatting[i]['bold'] ?? false : false;
    bool isUnderline = i < formatting.length ? formatting[i]['underline'] ?? false : false;

    spans.add(TextSpan(
      text: words[i] + (i < words.length - 1 ? ' ' : ''),
      style: TextStyle(
        fontSize: adjustedFontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
        color: Colors.black87,
        height: 1.3,
      ),
    ));
  }

  return SelectableText.rich(
    TextSpan(children: spans),
  );
}

  Widget _buildLeftSide() {
    final questionData = questions[currentQuestionIndex];
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
          image: const DecorationImage(
              image: AssetImage("assets/ema.jpg"),
              fit: BoxFit.cover,
              opacity: 0.05),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormattedText(
                          "${displayNumbers[currentQuestionIndex]}. ${questionData['question']}",
                          questionData['question_word_formatting'],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (questionData['question_file']?.isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade50,
                      ),
                      child: _buildFileBox(questionData['question_file']),
                    ),
                  if (questionData['optional_text']?.isNotEmpty == true)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.amber.shade200),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.amber.shade50,
                      ),
                      child: _buildFormattedText(
                        questionData['optional_text'],
                        questionData['optional_word_formatting'],
                      ),
                    ),
                ],
              ),
            ),
            if (widget.isAdmin && _isDrawingMode)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (details) {
                    setState(() {
                      _mainPoints.add(details.localPosition);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _mainPoints.add(details.localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _mainPoints.add(null);
                    });
                  },
                  child: CustomPaint(painter: DrawingPainter(_mainPoints)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSide() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white.withOpacity(0.8),
          image: const DecorationImage(
            image: AssetImage("assets/ema.jpg"),
            fit: BoxFit.cover,
            opacity: 0.05,
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var choice in ['A', 'B', 'C', 'D'])
                    if (questions[currentQuestionIndex]['choices'][choice] != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.selectedAnswers[questions[currentQuestionIndex]['originalIndex']] == choice
                                ? Colors.blue.shade400
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: widget.selectedAnswers[questions[currentQuestionIndex]['originalIndex']] == choice
                              ? Colors.blue.shade50
                              : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => _selectAnswer(choice),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildChoiceBox(
                                  choice,
                                  widget.selectedAnswers[questions[currentQuestionIndex]['originalIndex']] == choice,
                                ),
                                if (questions[currentQuestionIndex]['choices'][choice]['choice_file']?.isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: _buildFileBox(
                                      questions[currentQuestionIndex]['choices'][choice]['choice_file'],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
            if (widget.isAdmin && _isDrawingMode)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (details) {
                    setState(() {
                      _choicePoints.add(details.localPosition);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _choicePoints.add(details.localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _choicePoints.add(null);
                    });
                  },
                  child: CustomPaint(painter: DrawingPainter(_choicePoints)),
                ),
              ),
          ],
        ),
      ),
    );
  }

void _showFullImage(String imageUrl) {
  List<Offset?> imagePoints = [];
  bool isDrawingMode = _isDrawingMode;
  setState(() {
    _isDialogOpen = true;
  });
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          if (kDebugMode) print('Full image load error: $error');
                          return const Icon(Icons.broken_image, size: 50);
                        },
                      )
                    : Image.file(
                        File(imageUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          if (kDebugMode) print('Full image load error: $error');
                          return const Icon(Icons.broken_image, size: 50);
                        },
                      ),
              ),
            ),
            if (widget.isAdmin && isDrawingMode)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) {
                  setDialogState(() {
                    imagePoints.add(details.localPosition);
                  });
                },
                onPanUpdate: (details) {
                  setDialogState(() {
                    imagePoints.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  setDialogState(() {
                    imagePoints.add(null);
                  });
                },
                child: CustomPaint(painter: DrawingPainter(imagePoints)),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black, size: 24),
                onPressed: () {
                  setState(() {
                    _isDialogOpen = false;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            if (widget.isAdmin)
              Positioned(
                bottom: 8,
                right: 48,
                child: IconButton(
                  icon: Icon(isDrawingMode ? Icons.edit_off : Icons.edit,
                      color: Colors.black, size: 24),
                  onPressed: () {
                    setDialogState(() {
                      isDrawingMode = !isDrawingMode;
                      if (!isDrawingMode) imagePoints.clear();
                    });
                  },
                ),
              ),
            if (widget.isAdmin && isDrawingMode)
              Positioned(
                bottom: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black, size: 24),
                  onPressed: () {
                    setDialogState(() {
                      imagePoints.clear();
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildChoiceBox(String choice, bool isSelected) {
    final choiceNumber = {'A': 1, 'B': 2, 'C': 3, 'D': 4}[choice]!;
    final choiceData = questions[currentQuestionIndex]['choices'][choice];
    final screenSize = MediaQuery.of(context).size;
    final fontSize = screenSize.width < 1200 ? 14.0 : 16.0;

    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30, // Circle size remains unchanged
            height: 30, // Circle size remains unchanged
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.blue[600] : Colors.grey[200],
              border: Border.all(
                color: isSelected ? Colors.blue[600]! : Colors.grey[400]!,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSelected ? Colors.blue : Colors.grey).withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  choiceNumber.toString(),
                  style: TextStyle(
                    fontSize: fontSize * 0.8, // Doubled from fontSize * 0.4
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black54,
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
                    child: const Icon(
                      Icons.check,
                      color: Colors.blue,
                      size: 10,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildFormattedText(
                choiceData['choice_text'] ?? '',
                choiceData['word_formatting'] ?? [],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WindowsWebViewPage extends StatefulWidget {
  final String url;
  final String fileName;
  final bool? isVideo;
  final bool isAdmin;

  const WindowsWebViewPage(
      {super.key,
      required this.url,
      required this.fileName,
      this.isVideo,
      required this.isAdmin});

  @override
  _WindowsWebViewPageState createState() => _WindowsWebViewPageState();
}

class _WindowsWebViewPageState extends State<WindowsWebViewPage> {
  final _controller = WebviewController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    try {
      await _controller.initialize().timeout(const Duration(seconds: 3),
          onTimeout: () {
        throw TimeoutException('WebView initialization timed out');
      });
      _controller.setJavaScriptEnabled(true);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      if (widget.isVideo == true) {
        await _controller.loadStringContent('''
          <!DOCTYPE html>
          <html>
          <body style="margin:0;background:black;">
            <video id="videoPlayer" src="${widget.url}" ${widget.isAdmin ? 'controls' : ''} controlsList="nodownload" disablePictureInPicture style="width:100%;height:100vh;object-fit:contain;">
            </video>
            <script>
              var video = document.getElementById('videoPlayer');
              video.play();
              document.oncontextmenu = function() { return false; };
              function seekBackward() { video.currentTime = Math.max(0, video.currentTime - 10); }
              function seekForward() { video.currentTime = Math.min(video.duration, video.currentTime + 10); }
            </script>
          </body>
          </html>
        ''');
        if (mounted) setState(() => _isInitialized = true);
      } else {
        await _controller.loadUrl(widget.url);
        if (mounted) setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (kDebugMode) print('Windows WebView error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(20),
        child: AppBar(
          title: Text(widget.fileName, style: const TextStyle(fontSize: 10)),
          actions: widget.isVideo == true && widget.isAdmin
              ? [
                  Wrap(
                    spacing: 2,
                    runSpacing: 2,
                    alignment: WrapAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10, size: 12),
                        onPressed: () async {
                          try {
                            await _controller.executeScript('seekBackward();');
                          } catch (e) {
                            if (kDebugMode) print('Seek backward error: $e');
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10, size: 12),
                        onPressed: () async {
                          try {
                            await _controller.executeScript('seekForward();');
                          } catch (e) {
                            if (kDebugMode) print('Seek forward error: $e');
                          }
                        },
                      ),
                    ],
                  ),
                ]
              : null,
        ),
      ),
      body: _isInitialized && _controller.value.isInitialized
          ? Webview(_controller)
          : const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

extension on webview_windows.WebviewController {
  void setJavaScriptEnabled(bool bool) {}
}

class VideoPlayerPage extends StatefulWidget {
  final String url;
  final String fileName;
  final VideoPlayerController controller;
  final bool isAdmin;

  const VideoPlayerPage(
      {super.key,
      required this.url,
      required this.fileName,
      required this.controller,
      required this.isAdmin});

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  bool _isInitialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.controller.value.isInitialized) {
      _isInitialized = true;
      _duration = widget.controller.value.duration;
    } else {
      widget.controller.initialize().timeout(const Duration(seconds: 5),
          onTimeout: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video initialization timed out')));
        }
      }).then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _duration = widget.controller.value.duration;
          });
        }
      }).catchError((e) {
        if (kDebugMode) print('Video init error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error initializing video: $e')));
        }
      });
    }
    widget.controller.addListener(() {
      if (mounted) {
        setState(() {
          _position = widget.controller.value.position;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(20),
        child: AppBar(
          title: Text(widget.fileName, style: const TextStyle(fontSize: 10)),
        ),
      ),
      body: Center(
        child: _isInitialized
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: widget.controller.value.aspectRatio,
                    child: VideoPlayer(widget.controller),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          icon: Icon(
                            widget.controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 16,
                          ),
                          onPressed: () {
                            setState(() {
                              if (widget.controller.value.isPlaying) {
                                widget.controller.pause();
                              } else {
                                widget.controller.play();
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay_10, size: 16),
                          onPressed: () {
                            final newPosition =
                                _position - const Duration(seconds: 10);
                            widget.controller.seekTo(newPosition < Duration.zero
                                ? Duration.zero
                                : newPosition);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10, size: 16),
                          onPressed: () {
                            final newPosition =
                                _position + const Duration(seconds: 10);
                            widget.controller.seekTo(newPosition > _duration
                                ? _duration
                                : newPosition);
                          },
                        ),
                      ],
                    ),
                    Slider(
                      value: _position.inSeconds.toDouble(),
                      max: _duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        widget.controller
                            .seekTo(Duration(seconds: value.toInt()));
                      },
                    ),
                    Text(
                      '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / '
                      '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(() {});
    super.dispose();
  }
}

class DrawingPainter extends CustomPainter {
  final List<Offset?> points;

  DrawingPainter(this.points);

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
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}


class SubmitPage extends StatelessWidget {
  final Map<int, String> selectedAnswers;
  final int quizSetId;
  final String quizSetName;
  final String timeTaken;
  final int totalQuestions;
  final int totalCorrect;
  final List<Map<String, String>> correctAnswersList;
  final int folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final Map<int, int> timePerQuestion;
  final Map<String, String> cachedFiles; // Add cachedFiles parameter

  const SubmitPage({
    super.key,
    required this.selectedAnswers,
    required this.quizSetId,
    required this.quizSetName,
    required this.timeTaken,
    required this.totalQuestions,
    required this.totalCorrect,
    required this.correctAnswersList,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    required this.timePerQuestion,
    required this.cachedFiles, // Add to constructor
  });

  // Method to clean up temporary files
  Future<void> _cleanUpTempFiles() async {
    try {
      for (var filePath in cachedFiles.values) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error cleaning up temp files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.of(context).size.width * 0.025;

    // Call cleanup when the page is built
    _cleanUpTempFiles();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(30),
        child: AppBar(
          title: Text(
            quizSetName,
            style: TextStyle(fontSize: fontSize),
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.blue[700],
          automaticallyImplyLeading: false,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quiz Results',
              style: TextStyle(
                fontSize: fontSize * 1.2,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Questions: $totalQuestions',
              style: TextStyle(fontSize: fontSize),
            ),
            Text(
              'Correct Answers: $totalCorrect',
              style: TextStyle(fontSize: fontSize),
            ),
            Text(
              'Time Taken: $timeTaken',
              style: TextStyle(fontSize: fontSize),
            ),
            const SizedBox(height: 16),
            Text(
              'Answer Details:',
              style: TextStyle(
                fontSize: fontSize * 1.1,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (var answer in correctAnswersList)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${answer['question']}: ${answer['question_text']}',
                        style: TextStyle(
                          fontSize: fontSize * 0.9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Selected: ${answer['selected']}',
                        style: TextStyle(
                          fontSize: fontSize * 0.8,
                          color: answer['selected'] == answer['correct']
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      Text(
                        'Correct: ${answer['correct']}',
                        style: TextStyle(fontSize: fontSize * 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to UserFolderDetailsPage and remove all previous routes
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserFolderDetailsPage(
                            folderId: folderId,
                            folderName: folderName,
                            userIdentifier: userIdentifier,
                            isAdmin: isAdmin,
                            userId: '',
                            userName: '',
                            role: '',
                          ),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      'Back to Folder',
                      style: TextStyle(fontSize: fontSize),
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