import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/quiz_endpoints.dart';
import 'package:ema_app/model/quiz_question_model.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewQuizSetQuestionsViewModel extends ChangeNotifier {
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
  static const int perPage = 8; // Match server default per_page

  bool get hasMorePages => currentPage < totalPages;

  String? existingQuestionFilePath;

  // ── Question-level fields ──────────────────────────────────────────────────
  String? questionText;
  String? correctAnswer;
  String? questionType;

  WordFormattingRanges _questionWordFormatting = WordFormattingRanges();
  WordFormattingRanges get questionWordFormatting => _questionWordFormatting;
  set questionWordFormatting(WordFormattingRanges v) {
    _questionWordFormatting = v;
  }

  String? optionalText;

  WordFormattingRanges _optionalWordFormatting = WordFormattingRanges();
  WordFormattingRanges get optionalWordFormatting => _optionalWordFormatting;
  set optionalWordFormatting(WordFormattingRanges v) {
    _optionalWordFormatting = v;
  }

  // ── Question file ──────────────────────────────────────────────────────────
  File? selectedQuestionFile;
  Uint8List? selectedQuestionFileBytes;
  String? selectedQuestionFileMimeType;
  String? selectedQuestionFileName;

  // ── Per-choice inputs (A=0, B=1, C=2, D=3) ───────────────────────────────
  final List<QuizChoiceInput> choices = List.generate(4, (_) => QuizChoiceInput());

  QuizChoiceInput get choiceA => choices[0];
  QuizChoiceInput get choiceB => choices[1];
  QuizChoiceInput get choiceC => choices[2];
  QuizChoiceInput get choiceD => choices[3];

  // ── Parse helpers ──────────────────────────────────────────────────────────
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

  // ── Pagination parser ──────────────────────────────────────────────────────
  // API response shape:
  // { "data": { "total": 3, "page": 1, "per_page": 20, "questions": [...] } }
  void _parsePagination(Map<String, dynamic> response) {
    try {
      final data = response['data'] as Map<String, dynamic>? ?? {};

      // total number of questions across all pages
      final total = (data['total'] as num?)?.toInt();
      if (total != null) totalQuestions = total;

      // per_page comes from server (may differ from our request)
      final serverPerPage = (data['per_page'] as num?)?.toInt() ?? perPage;

      // calculate total pages from total + per_page
      if (serverPerPage > 0 && totalQuestions > 0) {
        totalPages = (totalQuestions / serverPerPage).ceil();
      } else {
        totalPages = 1;
      }

      _logger.i(
          'Pagination → page $currentPage/$totalPages '
              'total=$totalQuestions perPage=$serverPerPage hasMore=$hasMorePages');
    } catch (e) {
      _logger.e('Error parsing pagination: $e');
    }
  }

  // ── URL builder ────────────────────────────────────────────────────────────
  String _buildUrl(int quizSetId, int page) {
    final uri = Uri.parse(QuizSetEndpoints.questionsList(quizSetId)).replace(
      queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
      },
    );
    return uri.toString();
  }

  // ── Auth headers ──────────────────────────────────────────────────────────
  Future<Map<String, String>> _getAuthHeaders() async {
    final sp = await SharedPreferences.getInstance();
    final session = sp.getString('session');
    final csrf = sp.getString('csrf');
    final headers = <String, String>{};
    if (session != null && session.isNotEmpty) {
      headers['Cookie'] = 'EMA_SESSION=$session';
    }
    if (csrf != null && csrf.isNotEmpty) {
      headers['X-CSRF-Token'] = csrf;
    }
    return headers;
  }

  // ── Multipart request builder ─────────────────────────────────────────────
  Future<Map<String, dynamic>> _sendMultipartRequest({
    required String url,
    required String method,
    required int quizSetId,
  }) async {
    final headers = await _getAuthHeaders();
    final request = http.MultipartRequest(method, Uri.parse(url));
    request.headers.addAll(headers);

    request.fields['quiz_set_id'] = quizSetId.toString();

    if (questionText != null && questionText!.trim().isNotEmpty) {
      request.fields['question'] = questionText!.trim();
    }

    request.fields['correct_answer'] = correctAnswer!.trim().toUpperCase();

    if (questionType != null && questionType!.isNotEmpty) {
      request.fields['question_type'] = questionType!.toLowerCase();
    }

    if (optionalText != null && optionalText!.trim().isNotEmpty) {
      request.fields['optional_text'] = optionalText!.trim();
    }

    final questionFmtJson = _questionWordFormatting.toJsonString();
    if (questionFmtJson != null) {
      request.fields['question_word_formatting'] = questionFmtJson;
    }

    final optionalFmtJson = _optionalWordFormatting.toJsonString();
    if (optionalFmtJson != null) {
      request.fields['optional_word_formatting'] = optionalFmtJson;
    }

    // Question file
    if (selectedQuestionFileBytes != null &&
        selectedQuestionFileMimeType != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'question_file',
          selectedQuestionFileBytes!,
          filename: selectedQuestionFileName ?? 'question_file',
          contentType: MediaType.parse(selectedQuestionFileMimeType!),
        ),
      );
    }

    // Choice fields
    for (int i = 0; i < 4; i++) {
      final letter = String.fromCharCode(65 + i);
      final choice = choices[i];

      if (choice.hasText) {
        request.fields['choice_${letter}_text'] = choice.text!.trim();
      }

      if (choice.hasFile) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'choice_${letter}_file',
            choice.fileBytes!,
            filename: choice.fileName ?? 'choice_$letter',
            contentType: MediaType.parse(choice.mimeType!),
          ),
        );
      }
    }

    _logger.i('[$method] $url');
    _logger.i('Fields: ${request.fields}');
    for (final f in request.files) {
      _logger.i(
          '${f.field} => filename=${f.filename}, contentType=${f.contentType}, length=${f.length}');
    }

    try {
      final streamed =
      await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      _logger.i('Response ${response.statusCode}: ${response.body}');

      if (response.body.isEmpty) {
        return response.statusCode == 200 || response.statusCode == 201
            ? {'success': true, 'message': 'Operation successful', 'data': {}}
            : {'success': false, 'message': 'Empty response from server'};
      }

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'success': false, 'message': 'Unexpected response format'};
      } on FormatException {
        return {'success': false, 'message': 'Invalid JSON from server'};
      }
    } catch (e) {
      _logger.e('Multipart request error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ── Fetch questions (first page / refresh) ────────────────────────────────
  Future<void> fetchQuestions(
      BuildContext context,
      int quizSetId, {
        bool refresh = false,
      }) async {
    if (refresh) {
      currentPage = 1;
      totalPages = 1;
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
      _logger.i('fetchQuestions response: $response');

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
      _logger.e('fetchQuestions error: $e');
      if (refresh) {
        questions = [];
        _filterLists();
      }
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching questions: $e'), context);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Load next page ─────────────────────────────────────────────────────────
  Future<void> fetchNextPage(BuildContext context, int quizSetId) async {
    // Guard: don't fetch if already loading, or no more pages
    if (isFetchingMore || isLoading || !hasMorePages) {
      _logger.i(
          'fetchNextPage skipped: isFetchingMore=$isFetchingMore isLoading=$isLoading hasMorePages=$hasMorePages');
      return;
    }

    isFetchingMore = true;
    notifyListeners();

    final nextPage = currentPage + 1;

    try {
      final url = _buildUrl(quizSetId, nextPage);
      _logger.i('fetchNextPage → page $nextPage → $url');

      final response = await _apiService.getApiResponse(url);

      if (response['success'] == true) {
        currentPage = nextPage;
        _parsePagination(response);
        final newItems = _parseQuestions(response);
        questions.addAll(newItems);
        _filterLists();
        _logger.i(
            'fetchNextPage success: loaded ${newItems.length} items, total=${questions.length}');
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

  // ── Add question ───────────────────────────────────────────────────────────
  Future<void> addQuestion(BuildContext context, int quizSetId) async {
    if (!_validateQuestion(context)) return;

    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _sendMultipartRequest(
        url: QuizSetEndpoints.addQuestions(quizSetId),
        method: 'POST',
        quizSetId: quizSetId,
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        clearFields();
        await fetchQuestions(context, quizSetId, refresh: true);
      }
    } catch (e) {
      _logger.e('addQuestion error: $e');
      Utils.showApiResponse(
          Utils.errorResponse('Error creating question: $e'), context);
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Edit question ──────────────────────────────────────────────────────────
  Future<void> editQuestion(
      BuildContext context,
      QuizQuestionModel question,
      int quizSetId,
      ) async {
    if (!_validateQuestion(context)) return;

    try {
      isActionLoading = true;
      notifyListeners();

      final url = QuizSetEndpoints.updateQuestions(quizSetId, question.id);
      final response = await _sendMultipartRequest(
        url: url,
        method: 'POST',
        quizSetId: quizSetId,
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        clearFields();
        await fetchQuestions(context, quizSetId, refresh: true);
      }
    } catch (e) {
      _logger.e('editQuestion error: $e');
      Utils.showApiResponse(
          Utils.errorResponse('Error updating question: $e'), context);
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

      final url = QuizSetEndpoints.deleteQuestions(quizSetId, question.id);
      _logger.i('deleteQuestion URL: $url');

      final response = await _apiService.getDeleteApiResponse(url);
      _logger.i('deleteQuestion response: $response');

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        await fetchQuestions(context, quizSetId, refresh: true);
      }
    } catch (e) {
      _logger.e('deleteQuestion error: $e');
      Utils.showApiResponse(
          Utils.errorResponse('Error deleting question: $e'), context);
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validateQuestion(BuildContext context) {
    final hasQuestionText =
        questionText != null && questionText!.trim().isNotEmpty;
    final hasQuestionFile = selectedQuestionFileBytes != null;

    if (!hasQuestionText && !hasQuestionFile) {
      Utils.showApiResponse(
        Utils.errorResponse('Question must have text or a file (or both)'),
        context,
      );
      return false;
    }

    if (correctAnswer == null || correctAnswer!.trim().isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Correct answer is required'), context);
      return false;
    }

    for (int i = 0; i < 4; i++) {
      final letter = String.fromCharCode(65 + i);
      if (!choices[i].hasContent) {
        Utils.showApiResponse(
          Utils.errorResponse('Choice $letter must have text or a file'),
          context,
        );
        return false;
      }
    }
    return true;
  }

  // ── Word formatting helpers ────────────────────────────────────────────────
  void toggleQuestionBold(TextRange range) {
    _questionWordFormatting = _questionWordFormatting.toggleBold(range);
    notifyListeners();
  }

  void toggleQuestionUnderline(TextRange range) {
    _questionWordFormatting = _questionWordFormatting.toggleUnderline(range);
    notifyListeners();
  }

  void toggleQuestionItalic(TextRange range) {
    _questionWordFormatting = _questionWordFormatting.toggleItalic(range);
    notifyListeners();
  }

  void toggleOptionalBold(TextRange range) {
    _optionalWordFormatting = _optionalWordFormatting.toggleBold(range);
    notifyListeners();
  }

  void toggleOptionalUnderline(TextRange range) {
    _optionalWordFormatting = _optionalWordFormatting.toggleUnderline(range);
    notifyListeners();
  }

  void toggleOptionalItalic(TextRange range) {
    _optionalWordFormatting = _optionalWordFormatting.toggleItalic(range);
    notifyListeners();
  }

  void clearQuestionFormatting() {
    _questionWordFormatting = WordFormattingRanges();
    notifyListeners();
  }

  void clearOptionalFormatting() {
    _optionalWordFormatting = WordFormattingRanges();
    notifyListeners();
  }

  // ── Question file ──────────────────────────────────────────────────────────
  void setQuestionFileFromBytes(
      Uint8List bytes,
      String mimeType,
      File? sourceFile, {
        String? fileName,
      }) {
    selectedQuestionFileBytes = bytes;
    selectedQuestionFile = sourceFile;
    selectedQuestionFileMimeType = mimeType;
    selectedQuestionFileName =
        fileName ?? sourceFile?.path.split('/').last ?? 'question_file';
    _logger.i(
        'setQuestionFileFromBytes mime=$mimeType size=${bytes.length} name=$selectedQuestionFileName');
    notifyListeners();
  }

  void clearQuestionFile() {
    try {
      selectedQuestionFile?.deleteSync();
    } catch (_) {}
    selectedQuestionFile = null;
    selectedQuestionFileBytes = null;
    selectedQuestionFileMimeType = null;
    selectedQuestionFileName = null;
    notifyListeners();
  }

  // ── Choice files ───────────────────────────────────────────────────────────
  void setChoiceFileFromBytes(
      int choiceIndex,
      Uint8List bytes,
      String mimeType,
      File? sourceFile, {
        String? fileName,
      }) {
    assert(choiceIndex >= 0 && choiceIndex <= 3);
    final letter = String.fromCharCode(65 + choiceIndex);
    choices[choiceIndex].setFile(
      bytes: bytes,
      mime: mimeType,
      sourceFile: sourceFile,
      name: fileName ??
          sourceFile?.path.split('/').last ??
          'choice_${letter}_file',
    );
    _logger.i(
        'setChoiceFileFromBytes $letter mime=$mimeType size=${bytes.length}');
    notifyListeners();
  }

  void clearChoiceFile(int choiceIndex) {
    assert(choiceIndex >= 0 && choiceIndex <= 3);
    choices[choiceIndex].clearFile();
    notifyListeners();
  }

  // ── Pick question file ─────────────────────────────────────────────────────
  Future<void> pickQuestionFile({String fileType = 'image'}) async {
    try {
      if (fileType == 'image') {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile == null) return;

        if (kIsWeb) {
          final raw = await pickedFile.readAsBytes();
          final compressed = await FlutterImageCompress.compressWithList(
            raw,
            quality: 80,
            minWidth: 1024,
            minHeight: 1024,
            format: CompressFormat.jpeg,
          );
          if (compressed != null) {
            setQuestionFileFromBytes(compressed, 'image/jpeg', null,
                fileName: 'question_file.jpg');
          }
        } else {
          final compressed = await FlutterImageCompress.compressWithFile(
            pickedFile.path,
            quality: 80,
            minWidth: 1024,
            minHeight: 1024,
            format: CompressFormat.jpeg,
          );
          if (compressed != null) {
            final tmp =
            await Directory.systemTemp.createTemp('quiz_qfile_');
            final f = File(
                '${tmp.path}/qfile_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await f.writeAsBytes(compressed);
            setQuestionFileFromBytes(compressed, 'image/jpeg', f,
                fileName: f.path.split('/').last);
          }
        }
      } else {
        final FileType ft =
        fileType == 'audio' ? FileType.audio : FileType.video;
        final result = await FilePicker.platform.pickFiles(type: ft);
        if (result == null || result.files.isEmpty) return;
        final file = result.files.first;

        final bytes = file.bytes ??
            (file.path != null
                ? await File(file.path!).readAsBytes()
                : null);
        if (bytes == null) return;

        final mimeType = _getMimeType(file.extension ?? 'bin',
            isAudio: fileType == 'audio', isVideo: fileType == 'video');
        setQuestionFileFromBytes(
          bytes,
          mimeType,
          file.path != null ? File(file.path!) : null,
          fileName: file.name,
        );
      }
    } catch (e) {
      _logger.e('pickQuestionFile error: $e');
    }
  }

  // ── Pick choice file ───────────────────────────────────────────────────────
  Future<void> pickChoiceFile(int choiceIndex,
      {String fileType = 'image'}) async {
    assert(choiceIndex >= 0 && choiceIndex <= 3);
    final letter = String.fromCharCode(65 + choiceIndex);
    try {
      if (fileType == 'image') {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile == null) return;

        if (kIsWeb) {
          final raw = await pickedFile.readAsBytes();
          final compressed = await FlutterImageCompress.compressWithList(
            raw,
            quality: 80,
            minWidth: 1024,
            minHeight: 1024,
            format: CompressFormat.jpeg,
          );
          if (compressed != null) {
            setChoiceFileFromBytes(
                choiceIndex, compressed, 'image/jpeg', null,
                fileName: 'choice_${letter}_file.jpg');
          }
        } else {
          final compressed = await FlutterImageCompress.compressWithFile(
            pickedFile.path,
            quality: 80,
            minWidth: 1024,
            minHeight: 1024,
            format: CompressFormat.jpeg,
          );
          if (compressed != null) {
            final tmp =
            await Directory.systemTemp.createTemp('quiz_choice_');
            final f = File(
                '${tmp.path}/choice_${letter}_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await f.writeAsBytes(compressed);
            setChoiceFileFromBytes(choiceIndex, compressed, 'image/jpeg', f,
                fileName: f.path.split('/').last);
          }
        }
      } else {
        final FileType ft =
        fileType == 'audio' ? FileType.audio : FileType.video;
        final result = await FilePicker.platform.pickFiles(type: ft);
        if (result == null || result.files.isEmpty) return;
        final file = result.files.first;

        final bytes = file.bytes ??
            (file.path != null
                ? await File(file.path!).readAsBytes()
                : null);
        if (bytes == null) return;

        final mimeType = _getMimeType(file.extension ?? 'bin',
            isAudio: fileType == 'audio', isVideo: fileType == 'video');
        setChoiceFileFromBytes(
          choiceIndex,
          bytes,
          mimeType,
          file.path != null ? File(file.path!) : null,
          fileName: file.name,
        );
      }
    } catch (e) {
      _logger.e('pickChoiceFile $letter error: $e');
    }
  }

  // ── MIME type helper ───────────────────────────────────────────────────────
  String _getMimeType(String ext,
      {bool isAudio = false, bool isVideo = false}) {
    final e = ext.toLowerCase();
    if (isAudio) {
      switch (e) {
        case 'mp3':
          return 'audio/mpeg';
        case 'wav':
          return 'audio/wav';
        case 'ogg':
          return 'audio/ogg';
        case 'm4a':
          return 'audio/mp4';
        case 'aac':
          return 'audio/aac';
        default:
          return 'audio/mpeg';
      }
    }
    if (isVideo) {
      switch (e) {
        case 'mp4':
          return 'video/mp4';
        case 'mov':
          return 'video/quicktime';
        case 'avi':
          return 'video/x-msvideo';
        case 'mkv':
          return 'video/x-matroska';
        default:
          return 'video/mp4';
      }
    }
    switch (e) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
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
    String? questionType,
    String? questionWordFormattingJson,
    String? optionalText,
    String? optionalWordFormattingJson,
    String? choiceAText,
    String? choiceBText,
    String? choiceCText,
    String? choiceDText,
    String? choiceAFilePath,
    String? choiceBFilePath,
    String? choiceCFilePath,
    String? choiceDFilePath,
  }) {
    this.questionText = questionText;
    this.correctAnswer = correctAnswer;
    this.questionType = questionType;
    this.optionalText = optionalText;

    _questionWordFormatting =
        WordFormattingRanges.fromJsonString(questionWordFormattingJson);
    _optionalWordFormatting =
        WordFormattingRanges.fromJsonString(optionalWordFormattingJson);

    _setChoiceField(0, choiceAText, choiceAFilePath);
    _setChoiceField(1, choiceBText, choiceBFilePath);
    _setChoiceField(2, choiceCText, choiceCFilePath);
    _setChoiceField(3, choiceDText, choiceDFilePath);

    notifyListeners();
  }

  void _setChoiceField(int index, String? text, String? existingFilePath) {
    final choice = choices[index];
    choice.clear();

    if (text != null && text.isNotEmpty) {
      choice.text = text;
    }

    if (existingFilePath != null && existingFilePath.isNotEmpty) {
      choice.existingFilePath = existingFilePath;
      choice.fileName = existingFilePath.split('/').last;
      choice.mimeType = _guessMimeFromPath(existingFilePath);
    }
  }

  String _guessMimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return 'image/$ext';
    }
    if (['mp3', 'wav', 'ogg', 'aac'].contains(ext)) return 'audio/$ext';
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) return 'video/$ext';
    return 'application/octet-stream';
  }

  void clearFields() {
    questionText = null;
    correctAnswer = null;
    questionType = null;
    optionalText = null;
    existingQuestionFilePath = null;
    _questionWordFormatting = WordFormattingRanges();
    _optionalWordFormatting = WordFormattingRanges();

    clearQuestionFile();

    for (final c in choices) {
      c.clear();
    }

    notifyListeners();
  }

  void logCurrentState() {
    _logger.i('''
┌─── Current State ─────────────────────────────────
│ Question: $questionText
│ Answer:   $correctAnswer
│ Type:     $questionType
│ Q. Formatting: ${_questionWordFormatting.toJsonString()}
│ Optional text: $optionalText
│ Opt Formatting: ${_optionalWordFormatting.toJsonString()}
│ Q. File: $selectedQuestionFileName (${selectedQuestionFileBytes?.length ?? 0} bytes)
│
│ Choice A: text=${choiceA.text}, file=${choiceA.hasFile} (${choiceA.fileName})
│ Choice B: text=${choiceB.text}, file=${choiceB.hasFile} (${choiceB.fileName})
│ Choice C: text=${choiceC.text}, file=${choiceC.hasFile} (${choiceC.fileName})
│ Choice D: text=${choiceD.text}, file=${choiceD.hasFile} (${choiceD.fileName})
└────────────────────────────────────────────────────
    ''');
  }
}