import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/quiz_endpoints.dart';
import 'package:ema_app/model/question_model.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class QuizSetDetailViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();

  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading       = false;
  bool isActionLoading = false;
  bool isFetchingMore  = false;

  List<QuestionModel> questions         = [];
  List<QuestionModel> filteredQuestions = [];
  String _searchQuery = '';

  // ── Pagination ─────────────────────────────────────────────────────────────
  int currentPage    = 1;
  int totalPages     = 1;
  int totalQuestions = 0;
  static const int perPage = 15;

  bool get hasMorePages => currentPage < totalPages;

  // ── Upload / form state ────────────────────────────────────────────────────
  PlatformFile? selectedQuestionFile;
  List<PlatformFile?> selectedChoiceFiles = List.filled(4, null);

  double saveProgress = 0.0;
  bool   isSaving     = false;

  // ── Parse helpers ──────────────────────────────────────────────────────────
  List<QuestionModel> _parseQuestions(Map<String, dynamic> response) {
    try {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final rawList = data['questions'];
        if (rawList is List) {
          return rawList
              .map((e) => QuestionModel.fromJson(
              Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      // Flat list fallback
      final rawList = response['questions'];
      if (rawList is List) {
        return rawList
            .map((e) =>
            QuestionModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      _logger.e('Error parsing questions: $e');
    }
    return [];
  }

  void _parsePagination(Map<String, dynamic> response) {
    try {
      final data       = response['data'] as Map<String, dynamic>? ?? {};
      final pagination = data['pagination'] as Map<String, dynamic>? ?? data;

      totalQuestions =
          (pagination['total_items'] as num?)?.toInt() ??
              (pagination['total']      as num?)?.toInt() ??
              totalQuestions;

      final lastPage =
          (pagination['total_pages'] as num?)?.toInt() ??
              (pagination['last_page']   as num?)?.toInt();

      if (lastPage != null && lastPage > 0) totalPages = lastPage;

      _logger.i(
          'Pagination → page $currentPage/$totalPages '
              'total $totalQuestions hasMore: $hasMorePages');
    } catch (e) {
      _logger.e('Error parsing pagination: $e');
    }
  }

  // ── Build URL ──────────────────────────────────────────────────────────────
  String _buildUrl(int quizSetId, int page) {
    return Uri.parse(QuizSetEndpoints.questionsList(quizSetId)).replace(
      queryParameters: {
        'page':     page.toString(),
        'per_page': perPage.toString(),
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      },
    ).toString();
  }

  // ── Fetch questions ────────────────────────────────────────────────────────
  Future<void> fetchQuestions(BuildContext context, int quizSetId,
      {bool refresh = false}) async {
    _lastContext  = context;
    _lastQuizSetId = quizSetId;

    if (refresh) {
      currentPage    = 1;
      totalPages     = 1;
      totalQuestions = 0;
      questions.clear();
      filteredQuestions.clear();
    }

    isLoading = true;
    notifyListeners();

    try {
      final url = _buildUrl(quizSetId, currentPage);
      _logger.i('fetchQuestions → $url');
      final response = await _apiService.getApiResponse(url);

      if (response['success'] == true) {
        _parsePagination(response);
        questions = _parseQuestions(response);
        _filterLists();
      } else {
        if (refresh) {
          questions = [];
          _filterLists();
        }
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      if (refresh) {
        questions = [];
        _filterLists();
      }
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching questions: $e'), context);
      _logger.e('fetchQuestions error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Load next page ─────────────────────────────────────────────────────────
  Future<void> fetchNextPage(BuildContext context, int quizSetId) async {
    if (isFetchingMore || isLoading || !hasMorePages) return;

    isFetchingMore = true;
    notifyListeners();

    final nextPage = currentPage + 1;

    try {
      final response =
      await _apiService.getApiResponse(_buildUrl(quizSetId, nextPage));

      if (response['success'] == true) {
        currentPage = nextPage;
        _parsePagination(response);
        questions.addAll(_parseQuestions(response));
        _filterLists();
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error loading more questions: $e'), context);
      _logger.e('fetchNextPage error: $e');
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  // ── File upload ────────────────────────────────────────────────────────────
  Future<String?> _uploadFile({
    required PlatformFile? platformFile,
    required File? ioFile,
    required int quizSetId,
    required String fileKey,
    required void Function(double) onProgress,
  }) async {
    // Prefer PlatformFile (from file_picker); fall back to raw File
    final hasFile = platformFile != null || ioFile != null;
    if (!hasFile) return null;

    try {
      final ext = (platformFile?.name ?? ioFile!.path)
          .split('.')
          .last
          .toLowerCase();
      final imageExts = ['jpg', 'jpeg', 'png', 'gif'];
      final isImage   = imageExts.contains(ext);

      Uint8List? bytes;
      String?    filePath;
      String?    fileName;

      if (platformFile != null) {
        bytes    = platformFile.bytes;
        filePath = platformFile.path;
        fileName = platformFile.name;
      } else {
        filePath = ioFile!.path;
        fileName = ioFile.path.split(Platform.pathSeparator).last;
      }

      // Compress images where supported
      if (isImage && !kIsWeb && !(Platform.isWindows || Platform.isLinux)) {
        _logger.i('🗜️ Compressing image: $filePath');
        Uint8List? compressed;

        if (bytes != null) {
          compressed = await FlutterImageCompress.compressWithList(
            bytes,
            quality:   85,
            minWidth:  1024,
            minHeight: 1024,
            format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
          );
        } else if (filePath != null) {
          compressed = await FlutterImageCompress.compressWithFile(
            filePath,
            quality:   85,
            minWidth:  1024,
            minHeight: 1024,
            format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
          );
        }

        if (compressed != null && compressed.isNotEmpty) {
          bytes = compressed;
          _logger.i('✅ Compressed to ${compressed.length} bytes');
        }
      }

      // Build multipart upload
      final response = await _apiService.postFileMultipart(
        QuizSetEndpoints.uploadQuestionFile,
        {'quiz_set_id': quizSetId.toString(), 'file_key': fileKey},
        mainFileBytes: bytes,
        mainFilePath:  filePath,
        mainFileName:  fileName,
        onProgress:    onProgress,
      );

      if (response['success'] == true) {
        final name = response['filename'] as String?;
        _logger.i('🎉 Uploaded $fileKey → $name');
        return name;
      } else {
        throw Exception(response['error'] ?? 'Upload failed');
      }
    } catch (e, stack) {
      _logger.e('⛔ Upload error for $fileKey', error: e, stackTrace: stack);
      Utils.showApiResponse(
          Utils.errorResponse('Failed to upload file: $e'), _lastContext!);
      return null;
    }
  }

  // ── Add question ───────────────────────────────────────────────────────────
  Future<void> addQuestion(
      BuildContext context,
      Map<String, dynamic> questionData,
      File? questionFile,
      List<File?> choiceFiles,
      ) async {
    try {
      isSaving     = true;
      saveProgress = 0.0;
      notifyListeners();

      _logger.i('🚀 addQuestion → uploading files…');

      final questionFileName = await _uploadFile(
        platformFile: selectedQuestionFile,
        ioFile:       questionFile,
        quizSetId:    questionData['quiz_set_id'],
        fileKey:      'question_file',
        onProgress: (p) {
          saveProgress = p * 0.25;
          notifyListeners();
        },
      ) ?? questionData['question_file'] ?? '';

      final choiceFileNames = await Future.wait(
        List.generate(4, (i) async {
          final name = await _uploadFile(
            platformFile: selectedChoiceFiles.length > i
                ? selectedChoiceFiles[i]
                : null,
            ioFile:    choiceFiles.length > i ? choiceFiles[i] : null,
            quizSetId: questionData['quiz_set_id'],
            fileKey:   'choice_${String.fromCharCode(65 + i)}',
            onProgress: (p) {
              saveProgress = 0.25 + (i / 4.0 + p / 4.0) * 0.5;
              notifyListeners();
            },
          );
          return name ??
              questionData['choices'][String.fromCharCode(65 + i)]
              ['choice_file'] ??
              '';
        }),
      );

      final body = _buildQuestionBody(
        questionData:    questionData,
        questionFile:    questionFileName,
        choiceFileNames: choiceFileNames,
        action:          'add',
      );

      _logger.i('📡 addQuestion POST: $body');
      final response = await _apiService.getPostApiResponse(
          QuizSetEndpoints.addQuestions(id), body);

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        saveProgress = 100.0;
        clearFileSelections();
        await fetchQuestions(context, questionData['quiz_set_id'],
            refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error adding question: $e'), context);
      _logger.e('addQuestion error: $e');
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // ── Edit question ──────────────────────────────────────────────────────────
  Future<void> editQuestion(
      BuildContext context,
      int id,
      Map<String, dynamic> questionData,
      File? questionFile,
      List<File?> choiceFiles,
      ) async {
    // Optimistic update
    final index = questions.indexWhere((q) => q.id == id);
    QuestionModel? snapshot;
    if (index != -1) {
      snapshot = questions[index];
      questions[index] = QuestionModel(
        id:           id,
        quizSetId:    questionData['quiz_set_id'],
        question:     questionData['question'],
        optionalText: questionData['optional_text'],
        questionFile: questionFile?.path ?? snapshot.questionFile,
        questionType: questionData['question_type'],
        choices: {
          'A': Choice.fromJson(questionData['choices']['A']),
          'B': Choice.fromJson(questionData['choices']['B']),
          'C': Choice.fromJson(questionData['choices']['C']),
          'D': Choice.fromJson(questionData['choices']['D']),
        },
        correctAnswer: questionData['correct_answer'],
        formatting:    questionData['formatting'],
      );
      notifyListeners();
    }

    try {
      isSaving     = true;
      saveProgress = 0.0;
      notifyListeners();

      _logger.i('🚀 editQuestion $id → uploading files…');

      final questionFileName = await _uploadFile(
        platformFile: selectedQuestionFile,
        ioFile:       questionFile,
        quizSetId:    questionData['quiz_set_id'],
        fileKey:      'question_file',
        onProgress: (p) {
          saveProgress = p * 0.25;
          notifyListeners();
        },
      ) ?? questionData['question_file'] ?? '';

      final choiceFileNames = await Future.wait(
        List.generate(4, (i) async {
          final key = String.fromCharCode(65 + i);
          final name = await _uploadFile(
            platformFile: selectedChoiceFiles.length > i
                ? selectedChoiceFiles[i]
                : null,
            ioFile:    choiceFiles.length > i ? choiceFiles[i] : null,
            quizSetId: questionData['quiz_set_id'],
            fileKey:   'choice_$key',
            onProgress: (p) {
              saveProgress = 0.25 + (i / 4.0 + p / 4.0) * 0.5;
              notifyListeners();
            },
          );
          return name ?? questionData['choices'][key]['choice_file'] ?? '';
        }),
      );

      final body = _buildQuestionBody(
        questionData:    questionData,
        questionFile:    questionFileName,
        choiceFileNames: choiceFileNames,
        action:          'edit',
        id:              id,
      );

      _logger.i('📡 editQuestion POST: $body');
      final response = await _apiService.getPostApiResponse(
          QuizSetEndpoints.updateQuestions(id), body);

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        saveProgress = 100.0;
        clearFileSelections();
        await fetchQuestions(context, questionData['quiz_set_id'],
            refresh: true);
      } else {
        // Revert optimistic update on failure
        if (snapshot != null && index != -1) {
          questions[index] = snapshot;
          notifyListeners();
        }
      }
    } catch (e) {
      if (snapshot != null && index != -1) {
        questions[index] = snapshot;
        notifyListeners();
      }
      Utils.showApiResponse(
          Utils.errorResponse('Error editing question: $e'), context);
      _logger.e('editQuestion error: $e');
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // ── Delete question ────────────────────────────────────────────────────────
  Future<void> deleteQuestion(
      BuildContext context, int quizSetId, int id) async {
    // Optimistic removal
    final index = questions.indexWhere((q) => q.id == id);
    QuestionModel? snapshot;
    if (index != -1) {
      snapshot = questions[index];
      questions.removeAt(index);
      filteredQuestions.removeWhere((q) => q.id == id);
      notifyListeners();
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.getDeleteApiResponse(
          '${QuizSetEndpoints.deleteQuestions(id)}');

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        await fetchQuestions(context, quizSetId, refresh: true);
      } else {
        // Revert on failure
        if (snapshot != null && index != -1) {
          questions.insert(index, snapshot);
          _filterLists();
          notifyListeners();
        }
      }
    } catch (e) {
      if (snapshot != null && index != -1) {
        questions.insert(index, snapshot);
        _filterLists();
        notifyListeners();
      }
      Utils.showApiResponse(
          Utils.errorResponse('Error deleting question: $e'), context);
      _logger.e('deleteQuestion error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Body builder (DRY) ─────────────────────────────────────────────────────
  Map<String, dynamic> _buildQuestionBody({
    required Map<String, dynamic> questionData,
    required String questionFile,
    required List<String> choiceFileNames,
    required String action,
    int? id,
  }) {
    return {
      if (id != null) 'id': id,
      'action':        action,
      'quiz_set_id':   questionData['quiz_set_id'],
      'question':      questionData['question'],
      'optional_text': questionData['optional_text'],
      'question_file': questionFile,
      'question_type': questionData['question_type'],
      'correct_answer': questionData['correct_answer'],
      'formatting':    questionData['formatting'],
      'choices': {
        for (int i = 0; i < 4; i++)
          String.fromCharCode(65 + i): {
            'choice_text': questionData['choices']
            [String.fromCharCode(65 + i)]['choice_text'],
            'choice_file': choiceFileNames[i],
            'word_formatting': questionData['choices']
            [String.fromCharCode(65 + i)]['word_formatting'],
          },
      },
    };
  }

  // ── File selection helpers ─────────────────────────────────────────────────
  Future<void> pickQuestionFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.isNotEmpty) {
        selectedQuestionFile = result.files.first;
        notifyListeners();
      }
    } catch (e) {
      _logger.e('pickQuestionFile error: $e');
    }
  }

  Future<void> pickChoiceFile(int index) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.isNotEmpty) {
        if (selectedChoiceFiles.length <= index) {
          selectedChoiceFiles = List.filled(4, null);
        }
        selectedChoiceFiles[index] = result.files.first;
        notifyListeners();
      }
    } catch (e) {
      _logger.e('pickChoiceFile[$index] error: $e');
    }
  }

  void clearQuestionFile() {
    selectedQuestionFile = null;
    notifyListeners();
  }

  void clearChoiceFile(int index) {
    if (index < selectedChoiceFiles.length) {
      selectedChoiceFiles[index] = null;
      notifyListeners();
    }
  }

  void clearFileSelections() {
    selectedQuestionFile = null;
    selectedChoiceFiles  = List.filled(4, null);
    saveProgress         = 0.0;
    notifyListeners();
  }

  // ── Search / filter ────────────────────────────────────────────────────────
  Timer?        _debounceTimer;
  BuildContext? _lastContext;
  int?          _lastQuizSetId;

  void searchQuestions(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterLists();
    notifyListeners();
    _debounceSearch();
  }

  void _debounceSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final ctx       = _lastContext;
      final quizSetId = _lastQuizSetId;
      if (ctx == null || quizSetId == null) return;
      try {
        if (ctx is Element && !ctx.mounted) return;
      } catch (_) {
        return;
      }
      fetchQuestions(ctx, quizSetId, refresh: true);
    });
  }

  void _filterLists() {
    if (_searchQuery.isEmpty) {
      filteredQuestions = List.from(questions);
    } else {
      filteredQuestions = questions.where((q) {
        final text = q.question?.toLowerCase() ?? '';
        return text.contains(_searchQuery);
      }).toList();
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}