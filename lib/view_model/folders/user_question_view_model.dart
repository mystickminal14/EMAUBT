import 'dart:convert';
import 'dart:io';

import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────
// QUESTION MODEL
// ─────────────────────────────────────────────────────────────

class UserQuizQuestion {
  final int id;
  final String question;
  final String optionalText;
  final String questionFile;
  final String questionType;

  final String choiceAText;
  final String choiceBText;
  final String choiceCText;
  final String choiceDText;

  final String choiceAFile;
  final String choiceBFile;
  final String choiceCFile;
  final String choiceDFile;

  final String correctAnswer;

  final List<Map<String, dynamic>> questionWordFormatting;
  final List<Map<String, dynamic>> optionalWordFormatting;
  final List<Map<String, dynamic>> choiceAWordFormatting;
  final List<Map<String, dynamic>> choiceBWordFormatting;
  final List<Map<String, dynamic>> choiceCWordFormatting;
  final List<Map<String, dynamic>> choiceDWordFormatting;

  UserQuizQuestion({
    required this.id,
    required this.question,
    this.optionalText = '',
    this.questionFile = '',
    this.questionType = 'Reading',
    this.choiceAText = '',
    this.choiceBText = '',
    this.choiceCText = '',
    this.choiceDText = '',
    this.choiceAFile = '',
    this.choiceBFile = '',
    this.choiceCFile = '',
    this.choiceDFile = '',
    this.correctAnswer = 'A',
    this.questionWordFormatting = const [],
    this.optionalWordFormatting = const [],
    this.choiceAWordFormatting = const [],
    this.choiceBWordFormatting = const [],
    this.choiceCWordFormatting = const [],
    this.choiceDWordFormatting = const [],
  });

  factory UserQuizQuestion.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseFormatting(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    String choiceText(String letter) {
      final nested = json['choice_$letter'];
      if (nested is Map) return (nested['text'] as String?) ?? '';
      return (json['choice_${letter}_text'] as String?) ?? '';
    }

    String choiceFile(String letter) {
      final nested = json['choice_$letter'];
      if (nested is Map) return (nested['file'] as String?) ?? '';
      return (json['choice_${letter}_file'] as String?) ?? '';
    }

    List<Map<String, dynamic>> choiceFormatting(String letter) {
      final nested = json['choice_$letter'];
      if (nested is Map) return parseFormatting(nested['word_formatting']);
      return parseFormatting(json['choice_${letter}_word_formatting']);
    }

    return UserQuizQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      question: json['question'] ?? '',
      optionalText: json['optional_text'] ?? '',
      questionFile: json['question_file'] ?? '',
      questionType: _normaliseType(json['question_type']),
      choiceAText: choiceText('A'),
      choiceBText: choiceText('B'),
      choiceCText: choiceText('C'),
      choiceDText: choiceText('D'),
      choiceAFile: choiceFile('A'),
      choiceBFile: choiceFile('B'),
      choiceCFile: choiceFile('C'),
      choiceDFile: choiceFile('D'),
      correctAnswer: json['correct_answer'] ?? 'A',
      questionWordFormatting: parseFormatting(json['question_word_formatting']),
      optionalWordFormatting: parseFormatting(json['optional_word_formatting']),
      choiceAWordFormatting: choiceFormatting('A'),
      choiceBWordFormatting: choiceFormatting('B'),
      choiceCWordFormatting: choiceFormatting('C'),
      choiceDWordFormatting: choiceFormatting('D'),
    );
  }

  static String _normaliseType(dynamic raw) {
    if (raw == null) return 'Reading';
    final s = raw.toString().trim();
    if (s.isEmpty) return 'Reading';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  Map<String, String> get choices => {
    'A': choiceAText,
    'B': choiceBText,
    'C': choiceCText,
    'D': choiceDText,
  };

  Map<String, String> get choiceFiles => {
    'A': choiceAFile,
    'B': choiceBFile,
    'C': choiceCFile,
    'D': choiceDFile,
  };

  Map<String, List<Map<String, dynamic>>> get choiceWordFormattings => {
    'A': choiceAWordFormatting,
    'B': choiceBWordFormatting,
    'C': choiceCWordFormatting,
    'D': choiceDWordFormatting,
  };
}

// ─────────────────────────────────────────────────────────────
// STATUS
// ─────────────────────────────────────────────────────────────

enum QuizLoadStatus {
  idle,
  fetchingQuestions,
  downloadingMedia,
  ready,
  inProgress,
  submitting,
  completed,
  error,
}

// ─────────────────────────────────────────────────────────────
// VIEW MODEL
// ─────────────────────────────────────────────────────────────

class UserQuizViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _api = NetworkApiService();
  bool _isDisposed = false;

  void safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // ── State ──────────────────────────────────────────────────
  QuizLoadStatus status = QuizLoadStatus.idle;
  String statusMessage = '';
  String? errorMessage;

  // ── Questions ──────────────────────────────────────────────
  List<UserQuizQuestion> allQuestions = [];
  int totalQuestionsCount = 0;

  // ── Download ───────────────────────────────────────────────
  int downloadedFiles = 0;
  int totalFilesToDownload = 0;
  int fetchedPages = 0;
  int totalPages = 0;
  Map<String, String> cachedFiles = {};

  // ── Quiz session ───────────────────────────────────────────
  int? attemptId;
  Map<int, String> selectedAnswers = {};
  Map<int, bool> attendedQuestions = {};
  Map<int, int> timePerQuestion = {};

  // ── Display order ──────────────────────────────────────────
  List<UserQuizQuestion> readingQuestions = [];
  List<UserQuizQuestion> listeningQuestions = [];
  Map<int, int> displayNumberToIndex = {};
  List<int> displayNumbers = [];

  static const int _perPage = 10;

  // ── Progress ───────────────────────────────────────────────
  double get downloadProgress =>
      totalFilesToDownload == 0 ? 1.0 : downloadedFiles / totalFilesToDownload;

  double get fetchProgress =>
      totalPages == 0 ? 0.0 : fetchedPages / totalPages;

  // ─────────────────────────────────────────────────────────────
  // FIX: buildMediaUrl now uses BaseUrl.imageUrl as the base for
  // all media files (images, audio, video, pdf).
  //
  // BaseUrl.baseUrl  = "http://10.10.100.144:8000/api"   ← API calls
  // BaseUrl.imageUrl = "http://10.10.100.144:8000/api/res" ← was the old base
  //
  // BUT the 404 shows the server actually serves files under
  // "http://10.10.100.144:8000/api/choices/..." so the file paths
  // returned by the API (e.g. "choices/choice_D_xxx.mp3") only need the
  // API root prepended, NOT the /res suffix.
  //
  // Rule:
  //   • If path already starts with "http"  → use as-is
  //   • If path starts with "res/"          → prepend BaseUrl.imageUrl parent
  //                                           (strip /res from imageUrl)
  //   • Otherwise                           → prepend BaseUrl.baseUrl
  // ─────────────────────────────────────────────────────────────
  String buildMediaUrl(String path) {
    if (path.isEmpty) return '';

    // Already full URL
    if (path.startsWith('http')) {
      return path;
    }

    // Remove starting slash
    final clean = path.startsWith('/')
        ? path.substring(1)
        : path;

    // If path already contains res/
    if (clean.startsWith('res/')) {
      return '${BaseUrl.baseUrl}/$clean';
    }

    // ALL media files should go through /res/
    return '${BaseUrl.baseUrl}/res/$clean';
  }

  String? localPath(String mediaPath) {
    if (mediaPath.isEmpty) return null;
    return cachedFiles[buildMediaUrl(mediaPath)];
  }

  // ── Load quiz ───────────────────────────────────────────────
  Future<void> loadQuizSet(int quizSetId) async {
    try {
      status = QuizLoadStatus.fetchingQuestions;
      statusMessage = 'Fetching questions...';
      errorMessage = null;
      allQuestions.clear();
      cachedFiles.clear();
      selectedAnswers.clear();
      attendedQuestions.clear();
      fetchedPages = 0;
      totalPages = 0;
      safeNotify();

      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final url =
            '${BaseUrl.baseUrl}/quiz-sets/$quizSetId/questions?page=$page&per_page=$_perPage';
        _logger.i('Fetching page $page: $url');

        final response = await _api.getApiResponse(url);
        if (_isDisposed) return;

        if (response['success'] != true) {
          throw Exception(response['message'] ?? 'Failed to fetch questions');
        }

        final data = response['data'] as Map<String, dynamic>? ?? {};
        final rawQuestions = data['questions'] as List<dynamic>? ?? [];
        final total = (data['total'] as num?)?.toInt() ?? rawQuestions.length;
        final serverPerPage =
            (data['per_page'] as num?)?.toInt() ?? _perPage;

        if (totalQuestionsCount == 0) totalQuestionsCount = total;
        totalPages =
        serverPerPage > 0 ? (total / serverPerPage).ceil() : 1;

        for (final q in rawQuestions) {
          allQuestions
              .add(UserQuizQuestion.fromJson(Map<String, dynamic>.from(q)));
        }

        fetchedPages = page;
        statusMessage =
        'Fetching questions... ($fetchedPages/$totalPages pages)';
        safeNotify();

        page++;
        hasMore = page <= totalPages && rawQuestions.isNotEmpty;
      }

      // ── Collect ALL media URLs ──────────────────────────────
      status = QuizLoadStatus.downloadingMedia;
      final mediaUrls = <String>{};

      for (final q in allQuestions) {
        // Question file (image / audio / video / pdf)
        if (q.questionFile.isNotEmpty) {
          mediaUrls.add(buildMediaUrl(q.questionFile));
        }
        // Choice files
        for (final file in q.choiceFiles.values) {
          if (file.isNotEmpty) mediaUrls.add(buildMediaUrl(file));
        }
      }

      totalFilesToDownload = mediaUrls.length;
      downloadedFiles = 0;
      safeNotify();

      if (mediaUrls.isNotEmpty && !kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        if (_isDisposed) return;

        final urlList = mediaUrls.toList();
        // Download in batches of 3 to avoid overwhelming the server
        for (int i = 0; i < urlList.length; i += 3) {
          final batch = urlList.sublist(i, (i + 3).clamp(0, urlList.length));
          await Future.wait(batch.map((url) => _downloadFile(url, tempDir)));
          if (_isDisposed) return;
        }
      } else {
        // Web: skip local download, stream directly from URL
        downloadedFiles = totalFilesToDownload;
        safeNotify();
      }

      _buildDisplayOrder();
      status = QuizLoadStatus.ready;
      statusMessage = 'Ready! ${allQuestions.length} questions loaded.';
      safeNotify();
    } catch (e) {
      _logger.e('loadQuizSet error: $e');
      if (_isDisposed) return;
      status = QuizLoadStatus.error;
      errorMessage = e.toString();
      statusMessage = 'Error: $e';
      safeNotify();
    }
  }

  // ── Start quiz ─────────────────────────────────────────────
// ── Start quiz ─────────────────────────────────────────────
  Future<bool> startQuizAttempt(int quizSetId) async {
    try {
      if (_isDisposed) return false;
      if (allQuestions.isEmpty) {
        _logger.w('startQuizAttempt called but allQuestions is empty');
        return false;
      }

      status = QuizLoadStatus.inProgress;
      statusMessage = 'Starting quiz...';
      safeNotify();

      final response = await _api.getPostApiResponse(
        '${BaseUrl.baseUrl}/quiz-sets/$quizSetId/start',
        {'question_count': allQuestions.length},
      );

      if (_isDisposed) return false;

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to start quiz attempt');
      }

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final attempt = data['attempt'] as Map<String, dynamic>? ?? {};
      attemptId = (attempt['id'] as num?)?.toInt();

      if (attemptId == null) {
        throw Exception('Server did not return a valid attempt ID');
      }

      _logger.i('Quiz attempt started — attemptId: $attemptId');
      statusMessage = 'Quiz in progress';
      safeNotify();
      return true;
    } catch (e) {
      _logger.e('startQuizAttempt error: $e');
      if (_isDisposed) return false;
      status = QuizLoadStatus.error;
      errorMessage = e.toString();
      statusMessage = 'Failed to start quiz: $e';
      safeNotify();
      return false;
    }
  }
  // ── Submit quiz ────────────────────────────────────────────
  Future<Map<String, dynamic>?> submitQuiz(
      int quizSetId, int timeTakenSeconds) async {
    attemptId ??= DateTime.now().millisecondsSinceEpoch;

    try {
      status = QuizLoadStatus.submitting;
      statusMessage = 'Submitting quiz...';
      safeNotify();

      int correctCount = 0;
      final answers = <Map<String, dynamic>>[];

      for (final entry in selectedAnswers.entries) {
        final originalIndex = entry.key;
        if (originalIndex < 0 || originalIndex >= allQuestions.length) {
          continue;
        }
        final q = allQuestions[originalIndex];
        final selected = entry.value;
        if (selected == q.correctAnswer) correctCount++;
        answers.add({
          'question_id': q.id,
          'answer': selected,
          'time_spent_seconds': timePerQuestion[originalIndex] ?? 0,
        });
      }

      final total = allQuestions.length;
      final percentage =
      total > 0 ? ((correctCount / total) * 100).round() : 0;

      try {
        await _api.getPostApiResponse(
          '${BaseUrl.baseUrl}/quiz-sets/$quizSetId/submit',
          {'attempt_id': attemptId, 'answers': answers},
        );
      } catch (e) {
        _logger.w('Submit POST failed (non-fatal): $e');
      }

      if (_isDisposed) return null;

      status = QuizLoadStatus.completed;
      statusMessage = 'Quiz completed!';
      safeNotify();
      await _cleanUpTempFiles();

      return {
        'result': {
          'score': correctCount,
          'total_questions': total,
          'correct_answers': correctCount,
          'percentage': percentage,
        }
      };
    } catch (e) {
      _logger.e('submitQuiz error: $e');
      if (_isDisposed) return null;
      status = QuizLoadStatus.error;
      errorMessage = e.toString();
      safeNotify();
      return null;
    }
  }

  // ── Download a single file ─────────────────────────────────
  Future<void> _downloadFile(String url, Directory tempDir) async {
    try {
      // Use the last path segment as the local filename
      final fileName = Uri.parse(url).pathSegments.last;
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w.]'), '_');
      final filePath = '${tempDir.path}/$safeFileName';
      final file = File(filePath);

      if (await file.exists()) {
        // Already cached from a previous session
        cachedFiles[url] = filePath;
        _logger.i('Cache hit: $fileName');
      } else {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (_isDisposed) return;

        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
          cachedFiles[url] = filePath;
          _logger.i('Downloaded: $fileName (${response.bodyBytes.length} bytes)');
        } else {
          // Log warning but do NOT crash — the widget will fall back to
          // streaming the URL directly.
          _logger.w('⚠️ Failed to download $url: ${response.statusCode}');
        }
      }
    } catch (e) {
      _logger.e('Download error for $url: $e');
    } finally {
      if (!_isDisposed) {
        downloadedFiles++;
        statusMessage =
        'Downloading media ($downloadedFiles/$totalFilesToDownload)...';
        safeNotify();
      }
    }
  }

  // ── Build display order ────────────────────────────────────
  void _buildDisplayOrder() {
    readingQuestions = allQuestions
        .where((q) => q.questionType.toLowerCase() == 'reading')
        .toList();
    listeningQuestions = allQuestions
        .where((q) => q.questionType.toLowerCase() == 'listening')
        .toList();

    displayNumbers.clear();
    displayNumberToIndex.clear();
    int display = 1;

    for (final q in readingQuestions) {
      final idx = allQuestions.indexOf(q);
      displayNumbers.add(display);
      displayNumberToIndex[display] = idx;
      display++;
    }
    for (final q in listeningQuestions) {
      final idx = allQuestions.indexOf(q);
      displayNumbers.add(display);
      displayNumberToIndex[display] = idx;
      display++;
    }
  }

  // ── Answer helpers ─────────────────────────────────────────
  void selectAnswer(int originalIndex, String choice) {
    if (_isDisposed) return;
    selectedAnswers[originalIndex] = choice;
    safeNotify();
  }

  void markAttended(int displayNumber) {
    if (_isDisposed) return;
    attendedQuestions[displayNumber] = true;
    safeNotify();
  }

  void recordTimeForQuestion(int originalIndex, int seconds) {
    if (_isDisposed) return;
    timePerQuestion[originalIndex] = seconds;
  }

  // ── Cleanup ────────────────────────────────────────────────
  Future<void> _cleanUpTempFiles() async {
    try {
      for (final path in cachedFiles.values) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      _logger.e('Cleanup error: $e');
    }
  }

  // ── Reset ──────────────────────────────────────────────────
  void reset() {
    if (_isDisposed) return;
    status = QuizLoadStatus.idle;
    statusMessage = '';
    errorMessage = null;
    allQuestions.clear();
    cachedFiles.clear();
    selectedAnswers.clear();
    attendedQuestions.clear();
    timePerQuestion.clear();
    readingQuestions.clear();
    listeningQuestions.clear();
    displayNumbers.clear();
    displayNumberToIndex.clear();
    attemptId = null;
    totalQuestionsCount = 0;
    downloadedFiles = 0;
    totalFilesToDownload = 0;
    fetchedPages = 0;
    totalPages = 0;
    safeNotify();
  }
}