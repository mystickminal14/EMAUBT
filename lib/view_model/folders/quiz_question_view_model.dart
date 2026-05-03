import 'dart:convert';
import 'dart:io';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/quiz_endpoints.dart';
import 'package:ema_app/model/quiz_question_model.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

class QuizSetQuestionsViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();

  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading = false;
  bool isActionLoading = false;
  bool isFetchingMore = false;

  List<QuizQuestionModel> questions = [];
  List<QuizQuestionModel> filteredQuestions = [];
  String _searchQuery = '';

  // ── Pagination ─────────────────────────────────────────────────────────────
  int currentPage = 1;
  int totalPages = 1;
  int totalQuestions = 0;
  static const int perPage = 20;
  bool includeFiles = false;

  bool get hasMorePages => currentPage < totalPages;

  // ── Form fields ────────────────────────────────────────────────────────────
  String? questionText;
  String? correctAnswer;        // "A" | "B" | "C" | "D"
  String? choiceAText;
  String? choiceBText;
  String? choiceCText;
  String? choiceDText;
  String? questionType;         // e.g. "reading"
  String? wordFormatting;       // raw JSON string, e.g. '{"bold":["3"]}'

  // Question file (audio / image)
  File? selectedQuestionFile;
  Uint8List? selectedQuestionFileBytes;
  String? selectedQuestionFileBase64;  // data URI: "data:<mime>;base64,<data>"

  // ── Parse questions ────────────────────────────────────────────────────────
  List<QuizQuestionModel> _parseQuestions(Map<String, dynamic> response) {
    try {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final rawList = data['questions'];
        if (rawList is List) {
          return rawList
              .map((e) => QuizQuestionModel.fromJson(
              Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (e) {
      _logger.e('Error parsing questions: $e');
    }
    return [];
  }

  // ── Parse pagination ───────────────────────────────────────────────────────
  void _parsePagination(Map<String, dynamic> response) {
    try {
      final data = response['data'] as Map<String, dynamic>? ?? {};
      totalQuestions = (data['total'] as num?)?.toInt() ?? totalQuestions;
      final perPageVal = (data['per_page'] as num?)?.toInt() ?? perPage;
      if (totalQuestions > 0 && perPageVal > 0) {
        totalPages = (totalQuestions / perPageVal).ceil();
      }
    } catch (e) {
      _logger.e('Error parsing pagination: $e');
    }
  }

  // ── Build URL ──────────────────────────────────────────────────────────────
  String _buildUrl(int quizSetId, int page) {
    final uri =
    Uri.parse(QuizSetEndpoints.questionsList(quizSetId)).replace(
      queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
        'include_files': includeFiles.toString(),
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      },
    );
    return uri.toString();
  }

  // ── Fetch questions ────────────────────────────────────────────────────────
  Future<void> fetchQuestions(
      BuildContext context,
      int quizSetId, {
        bool refresh = false,
        bool? withFiles,
      }) async {
    if (refresh) {
      currentPage = 1;
      totalPages = 1;
      totalQuestions = 0;
      questions.clear();
      filteredQuestions.clear();
    }
    if (withFiles != null) includeFiles = withFiles;

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
      final url = _buildUrl(quizSetId, nextPage);
      final response = await _apiService.getApiResponse(url);

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

  // ── Create question ────────────────────────────────────────────────────────
  Future<void> addQuestion(
      BuildContext context, int quizSetId) async {
    if (questionText == null || questionText!.trim().isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Question text is required'), context);
      return;
    }
    if (correctAnswer == null || correctAnswer!.trim().isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Correct answer is required'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final body = _buildRequestBody();
      _logger.d('addQuestion body keys → ${body.keys.toList()}');

      final response = await _apiService.getPostApiResponse(
          QuizSetEndpoints.addQuestions(quizSetId), body);

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        clearFields();
        await fetchQuestions(context, quizSetId, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error creating question: $e'), context);
      _logger.e('addQuestion error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Update question ────────────────────────────────────────────────────────
  Future<void> editQuestion(
      BuildContext context,
      QuizQuestionModel question,
      int quizSetId,
      ) async {
    if (questionText == null || questionText!.trim().isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Question text is required'), context);
      return;
    }
    if (correctAnswer == null || correctAnswer!.trim().isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Correct answer is required'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final body = _buildRequestBody();
      final url =
      QuizSetEndpoints.updateQuestions(quizSetId, question.id);
      _logger.d('editQuestion → $url');

      final response = await _apiService.getPostApiResponse(url, body);

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        clearFields();
        await fetchQuestions(context, quizSetId, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error updating question: $e'), context);
      _logger.e('editQuestion error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Delete question ────────────────────────────────────────────────────────
  Future<void> deleteQuestion(
      BuildContext context,
      QuizQuestionModel question,
      int quizSetId,
      ) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final url =
      QuizSetEndpoints.deleteQuestions(quizSetId, question.id);
      final response = await _apiService.getDeleteApiResponse(url);

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        await fetchQuestions(context, quizSetId, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error deleting question: $e'), context);
      _logger.e('deleteQuestion error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Build request body ─────────────────────────────────────────────────────
  Map<String, dynamic> _buildRequestBody() {
    return <String, dynamic>{
      'question_text': questionText!.trim(),
      'correct_answer': correctAnswer!.trim(),
      if (choiceAText != null && choiceAText!.isNotEmpty)
        'choice_A_text': choiceAText,
      if (choiceBText != null && choiceBText!.isNotEmpty)
        'choice_B_text': choiceBText,
      if (choiceCText != null && choiceCText!.isNotEmpty)
        'choice_C_text': choiceCText,
      if (choiceDText != null && choiceDText!.isNotEmpty)
        'choice_D_text': choiceDText,
      if (questionType != null && questionType!.isNotEmpty)
        'question_type': questionType,
      if (wordFormatting != null && wordFormatting!.isNotEmpty)
        'word_formatting': wordFormatting,
      if (selectedQuestionFileBase64 != null &&
          selectedQuestionFileBase64!.isNotEmpty)
        'question_file': selectedQuestionFileBase64,
    };
  }

  // ── File picker (audio / image) ────────────────────────────────────────────
  /// Pass [isAudio] = true for audio files; false for images.
  /// For audio, no compression is applied — raw bytes are base64-encoded.
  Future<void> pickQuestionFile({bool isAudio = false}) async {
    try {
      final picker = ImagePicker();

      if (isAudio) {
        // ImagePicker can pick any file type via pickMedia / pickVideo;
        // for audio use the XFile path directly.
        final picked = await picker.pickMedia();
        if (picked == null) return;

        final bytes = await picked.readAsBytes();
        selectedQuestionFileBytes = bytes;
        selectedQuestionFile = kIsWeb ? null : File(picked.path);

        // Detect mime from extension; default to audio/mpeg
        final ext = picked.path.split('.').last.toLowerCase();
        final mime = ext == 'wav'
            ? 'audio/wav'
            : ext == 'ogg'
            ? 'audio/ogg'
            : 'audio/mpeg';
        final base64Str = base64Encode(bytes);
        selectedQuestionFileBase64 = 'data:$mime;base64,$base64Str';
        _logger.i(
            'pickQuestionFile (audio) → mime: $mime, prefix: ${selectedQuestionFileBase64!.substring(0, 30)}...');
      } else {
        // Image path — compress before encoding
        final pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile == null) return;

        Uint8List? compressedBytes;

        if (kIsWeb) {
          final rawBytes = await pickedFile.readAsBytes();
          compressedBytes = await FlutterImageCompress.compressWithList(
            rawBytes,
            quality: 80,
            minWidth: 512,
            minHeight: 512,
            format: CompressFormat.jpeg,
          );
          selectedQuestionFileBytes = compressedBytes ?? rawBytes;
          selectedQuestionFile = null;
        } else {
          compressedBytes = await FlutterImageCompress.compressWithFile(
            pickedFile.path,
            quality: 80,
            minWidth: 512,
            minHeight: 512,
            format: CompressFormat.jpeg,
          );

          if (compressedBytes != null) {
            final tempDir =
            await Directory.systemTemp.createTemp('quiz_qfile_');
            final file = File(
                '${tempDir.path}/qfile_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await file.writeAsBytes(compressedBytes);
            selectedQuestionFile = file;
            selectedQuestionFileBytes = compressedBytes;
          } else {
            selectedQuestionFile = File(pickedFile.path);
            selectedQuestionFileBytes =
            await selectedQuestionFile!.readAsBytes();
          }
        }

        if (selectedQuestionFileBytes != null) {
          final base64Str = base64Encode(selectedQuestionFileBytes!);
          selectedQuestionFileBase64 = 'data:image/jpeg;base64,$base64Str';
          _logger.i(
              'pickQuestionFile (image) → prefix: ${selectedQuestionFileBase64!.substring(0, 30)}...');
        }
      }

      notifyListeners();
    } catch (e) {
      _logger.e('pickQuestionFile error: $e');
    }
  }

  // ── Search / filter ────────────────────────────────────────────────────────
  void searchQuestions(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterLists();
    notifyListeners();
  }

  void _filterLists() {
    if (_searchQuery.isEmpty) {
      filteredQuestions = List.from(questions);
    } else {
      filteredQuestions = questions.where((q) {
        final text = q.questionText?.toLowerCase() ?? '';
        return text.contains(_searchQuery);
      }).toList();
    }
  }

  // ── Field helpers ──────────────────────────────────────────────────────────
  void setFields({
    String? questionText,
    String? correctAnswer,
    String? choiceAText,
    String? choiceBText,
    String? choiceCText,
    String? choiceDText,
    String? questionType,
    String? wordFormatting,
    String? questionFileBase64,
    bool overwriteFile = true,
  }) {
    this.questionText = questionText;
    this.correctAnswer = correctAnswer;
    this.choiceAText = choiceAText;
    this.choiceBText = choiceBText;
    this.choiceCText = choiceCText;
    this.choiceDText = choiceDText;
    this.questionType = questionType;
    this.wordFormatting = wordFormatting;
    if (overwriteFile) {
      selectedQuestionFileBase64 = questionFileBase64;
    }
    notifyListeners();
  }

  void clearFields() {
    questionText = null;
    correctAnswer = null;
    choiceAText = null;
    choiceBText = null;
    choiceCText = null;
    choiceDText = null;
    questionType = null;
    wordFormatting = null;
    selectedQuestionFileBase64 = null;
    selectedQuestionFileBytes = null;
    try {
      selectedQuestionFile?.deleteSync();
    } catch (_) {}
    selectedQuestionFile = null;
    notifyListeners();
  }
}