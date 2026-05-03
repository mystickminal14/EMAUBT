import 'dart:convert';
import 'dart:io';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/quiz_endpoints.dart';
import 'package:ema_app/model/folder_mode_v2/new_quiz_set_model.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

class FolderQuizSetsViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();

  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading = false;
  bool isActionLoading = false;
  bool isFetchingMore = false;

  List<QuizSetModel> quizSets = [];
  List<QuizSetModel> filteredQuizSets = [];
  String _searchQuery = '';

  // ── Pagination ─────────────────────────────────────────────────────────────
  int currentPage = 1;
  int totalPages = 1;
  int totalQuizSets = 0;
  static const int perPage = 12;

  bool get hasMorePages => currentPage < totalPages;

  // ── Form fields ────────────────────────────────────────────────────────────
  String? name;
  String? description;
  int? durationMinutes;
  int? passingScore;
  bool isPublished = false;
  File? selectedIconFile;
  Uint8List? selectedIconBytes;
  String? selectedIconBase64;

  // ── Parse quiz sets ────────────────────────────────────────────────────────
  List<QuizSetModel> _parseQuizSets(Map<String, dynamic> response) {
    try {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final rawList = data['quiz_sets'];
        if (rawList is List) {
          return rawList
              .map((e) =>
              QuizSetModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (e) {
      _logger.e('Error parsing quiz sets: $e');
    }
    return [];
  }

  // ── Parse pagination ───────────────────────────────────────────────────────
  void _parsePagination(Map<String, dynamic> response) {
    try {
      final data = response['data'] as Map<String, dynamic>? ?? {};
      totalQuizSets = (data['total'] as num?)?.toInt() ?? totalQuizSets;
      currentPage = (data['page'] as num?)?.toInt() ?? currentPage;
      final perPageVal = (data['per_page'] as num?)?.toInt() ?? perPage;
      if (totalQuizSets > 0 && perPageVal > 0) {
        totalPages = (totalQuizSets / perPageVal).ceil();
      }
    } catch (e) {
      _logger.e('Error parsing pagination: $e');
    }
  }

  // ── Build URL ──────────────────────────────────────────────────────────────
  String _buildUrl(int folderId, int page) {
    final uri = Uri.parse(QuizSetEndpoints.quizSetList).replace(
      queryParameters: {
        'folder_id': folderId.toString(),
        'page': page.toString(),
        'per_page': perPage.toString(),
        'published_only': 'false',
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      },
    );
    return uri.toString();
  }

  // ── Fetch quiz sets ────────────────────────────────────────────────────────
  Future<void> fetchQuizSets(BuildContext context, int folderId,
      {bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      totalPages = 1;
      totalQuizSets = 0;
      quizSets.clear();
      filteredQuizSets.clear();
    }

    isLoading = true;
    notifyListeners();

    try {
      final url = _buildUrl(folderId, currentPage);
      _logger.i('fetchQuizSets → $url');
      final response = await _apiService.getApiResponse(url);

      if (response['success'] == true) {
        _parsePagination(response);
        quizSets = _parseQuizSets(response);
        _filterLists();
      } else {
        if (refresh) {
          quizSets = [];
          _filterLists();
        }
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      if (refresh) {
        quizSets = [];
        _filterLists();
      }
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching quiz sets: $e'), context);
      _logger.e('fetchQuizSets error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Load next page ─────────────────────────────────────────────────────────
  Future<void> fetchNextPage(BuildContext context, int folderId) async {
    if (isFetchingMore || isLoading || !hasMorePages) return;

    isFetchingMore = true;
    notifyListeners();

    try {
      final nextPage = currentPage + 1;
      final url = _buildUrl(folderId, nextPage);
      final response = await _apiService.getApiResponse(url);

      if (response['success'] == true) {
        _parsePagination(response);
        final fetched = _parseQuizSets(response);
        quizSets.addAll(fetched);
        _filterLists();
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error loading more quiz sets: $e'), context);
      _logger.e('fetchNextPage error: $e');
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  // ── Create quiz set ────────────────────────────────────────────────────────
  Future<void> addQuizSet(BuildContext context, int folderId) async {
    if (name == null || name!.trim().isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Quiz set name is required'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final body = <String, dynamic>{
        'folder_id': folderId,
        'name': name!.trim(),
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        if (passingScore != null) 'passing_score': passingScore,
        'is_published': isPublished,
        // FIX: always send selectedIconBase64 which is already in "data:image/jpeg;base64,..." format
        if (selectedIconBase64 != null && selectedIconBase64!.isNotEmpty)
          'icon': selectedIconBase64,
      };
      _logger.d("addQuizSet body icon prefix → ${selectedIconBase64?.substring(0, 50)}");

      final response = await _apiService.getPostApiResponse(
          QuizSetEndpoints.createQuizSet, body);

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        clearFields();
        await fetchQuizSets(context, folderId, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error creating quiz set: $e'), context);
      _logger.e('addQuizSet error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Update quiz set ────────────────────────────────────────────────────────
  Future<void> editQuizSet(
      BuildContext context, QuizSetModel quizSet, int folderId) async {
    if (name == null || name!.trim().isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Quiz set name is required'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final body = <String, dynamic>{
        'name': name!.trim(),
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        if (passingScore != null) 'passing_score': passingScore,
        'is_published': isPublished,
        // FIX: always send selectedIconBase64 which is already in "data:image/jpeg;base64,..." format
        if (selectedIconBase64 != null && selectedIconBase64!.isNotEmpty)
          'icon': selectedIconBase64,
      };
      _logger.d("editQuizSet body icon prefix → ${selectedIconBase64?.substring(0, 50)}");

      final response = await _apiService.getPutResponse(
        '${QuizSetEndpoints.updateQuizSet}${quizSet.id}',
        body,
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        clearFields();
        await fetchQuizSets(context, folderId, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error updating quiz set: $e'), context);
      _logger.e('editQuizSet error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Delete quiz set ────────────────────────────────────────────────────────
  Future<void> deleteQuizSet(
      BuildContext context, QuizSetModel quizSet, int folderId) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.getDeleteApiResponse(
          '${QuizSetEndpoints.deleteQuizSet}${quizSet.id}');

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        await fetchQuizSets(context, folderId, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error deleting quiz set: $e'), context);
      _logger.e('deleteQuizSet error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Image picker ───────────────────────────────────────────────────────────
  Future<void> pickIcon() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      Uint8List? compressedBytes;

      if (kIsWeb) {
        final rawBytes = await pickedFile.readAsBytes();
        compressedBytes = await FlutterImageCompress.compressWithList(
          rawBytes,
          quality: 80,
          minWidth: 256,
          minHeight: 256,
          format: CompressFormat.jpeg,
        );
        selectedIconBytes = compressedBytes ?? rawBytes;
        selectedIconFile = null;
      } else {
        compressedBytes = await FlutterImageCompress.compressWithFile(
          pickedFile.path,
          quality: 80,
          minWidth: 256,
          minHeight: 256,
          format: CompressFormat.jpeg,
        );

        if (compressedBytes != null) {
          final tempDir = await Directory.systemTemp.createTemp('quiz_icon_');
          final file = File(
              '${tempDir.path}/icon_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(compressedBytes);
          selectedIconFile = file;
          selectedIconBytes = compressedBytes;
        } else {
          selectedIconFile = File(pickedFile.path);
          selectedIconBytes = await selectedIconFile!.readAsBytes();
        }
      }

      // FIX: Encode to base64 with data URI prefix — "data:image/jpeg;base64,<data>"
      if (selectedIconBytes != null) {
        final base64Str = base64Encode(selectedIconBytes!);
        selectedIconBase64 = 'data:image/jpeg;base64,$base64Str';
        _logger.i('pickIcon → icon set, prefix: ${selectedIconBase64!.substring(0, 30)}...');
      }

      notifyListeners();
    } catch (e) {
      _logger.e('pickIcon error: $e');
    }
  }

  // ── Search / filter ────────────────────────────────────────────────────────
  void searchQuizSets(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterLists();
    notifyListeners();
  }

  void _filterLists() {
    if (_searchQuery.isEmpty) {
      filteredQuizSets = List.from(quizSets);
    } else {
      filteredQuizSets = quizSets.where((q) {
        final n = q.name?.toLowerCase() ?? '';
        return n.contains(_searchQuery);
      }).toList();
    }
  }

  // ── Field helpers ──────────────────────────────────────────────────────────
  void setFields({
    String? name,
    String? description,
    int? durationMinutes,
    int? passingScore,
    bool? isPublished,
    // FIX: iconBase64 is optional — if null, do NOT overwrite existing selectedIconBase64
    String? iconBase64,
    bool overwriteIcon = true,
  }) {
    this.name = name;
    this.description = description;
    this.durationMinutes = durationMinutes;
    this.passingScore = passingScore;
    this.isPublished = isPublished ?? false;
    if (overwriteIcon) {
      selectedIconBase64 = iconBase64;
    }
    notifyListeners();
  }

  void clearFields() {
    name = null;
    description = null;
    durationMinutes = null;
    passingScore = null;
    isPublished = false;
    selectedIconBase64 = null;
    selectedIconBytes = null;
    try {
      selectedIconFile?.deleteSync();
    } catch (_) {}
    selectedIconFile = null;
    notifyListeners();
  }
}