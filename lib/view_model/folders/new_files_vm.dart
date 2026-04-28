import 'dart:io';
import 'dart:typed_data';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/file_endpoints.dart';
import 'package:ema_app/model/folder_mode_v2/new_file_model.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class FolderFilesViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();

  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading = false;
  bool isActionLoading = false;
  bool isFetchingMore = false;

  List<FileModel> files = [];
  List<FileModel> filteredFiles = [];
  String _searchQuery = '';

  // ── Pagination ─────────────────────────────────────────────────────────────
  int currentPage = 1;
  int totalPages = 1;
  int totalFiles = 0;
  static const int perPage = 15;

  bool get hasMorePages => currentPage < totalPages;

  // ── Upload state ───────────────────────────────────────────────────────────
  PlatformFile? selectedFile;
  double uploadProgress = 0.0;

  // ── Parse files ────────────────────────────────────────────────────────────
  List<FileModel> _parseFiles(Map<String, dynamic> response) {
    try {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final rawList = data['files'];
        if (rawList is List) {
          return rawList
              .map((e) => FileModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      if (data is List) {
        return data
            .map((e) => FileModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      _logger.e('Error parsing files: $e');
    }
    return [];
  }

  // ── Parse pagination ───────────────────────────────────────────────────────
  void _parsePagination(Map<String, dynamic> response) {
    try {
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
      totalFiles = (pagination['total'] as num?)?.toInt() ?? totalFiles;
      currentPage = (pagination['current_page'] as num?)?.toInt() ?? currentPage;
      totalPages = (pagination['last_page'] as num?)?.toInt() ?? totalPages;
    } catch (e) {
      _logger.e('Error parsing pagination: $e');
    }
  }

  // ── Build URL ──────────────────────────────────────────────────────────────
  String _buildUrl(int folderId, int page) {
    final uri = Uri.parse('${FileEndpoints.fileDetail}').replace(
      path: '/api/files',
      queryParameters: {
        'folder_id': folderId.toString(),
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      },
    );
    return uri.toString();
  }

  // ── Fetch files by folder ──────────────────────────────────────────────────
  Future<void> fetchFiles(BuildContext context, int folderId,
      {bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      totalPages = 1;
      totalFiles = 0;
      files.clear();
      filteredFiles.clear();
    }

    isLoading = true;
    notifyListeners();

    try {
      final url = _buildUrl(folderId, currentPage);
      _logger.i('fetchFiles → $url');
      final response = await _apiService.getApiResponse(url);

      if (response['success'] == true) {
        _parsePagination(response);
        files = _parseFiles(response);
        _filterLists();
      } else {
        if (refresh) {
          files = [];
          _filterLists();
        }
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      if (refresh) {
        files = [];
        _filterLists();
      }
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching files: $e'), context);
      _logger.e('fetchFiles error: $e');
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
        final fetched = _parseFiles(response);
        files.addAll(fetched);
        _filterLists();
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error loading more files: $e'), context);
      _logger.e('fetchNextPage error: $e');
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  // ── Pick file ──────────────────────────────────────────────────────────────
  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.isNotEmpty) {
        selectedFile = result.files.first;
        notifyListeners();
      }
    } catch (e) {
      _logger.e('pickFile error: $e');
    }
  }

  void clearSelectedFile() {
    selectedFile = null;
    uploadProgress = 0.0;
    notifyListeners();
  }

  // ── Upload file ────────────────────────────────────────────────────────────
  Future<void> uploadFile(BuildContext context, int folderId) async {
    if (selectedFile == null) {
      Utils.showApiResponse(
          Utils.errorResponse('Please select a file first'), context);
      return;
    }

    try {
      isActionLoading = true;
      uploadProgress = 0.0;
      notifyListeners();

      final fields = <String, dynamic>{
        'folder_id': folderId.toString(),
      };

      final response = await _apiService.postMultipartNoticeFiles(
        FileEndpoints.uploadFile,
        fields,
        files: [selectedFile!],
        fieldName: 'file',
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('File uploaded successfully');
        clearSelectedFile();
        await fetchFiles(context, folderId, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error uploading file: $e'), context);
      _logger.e('uploadFile error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Delete file ────────────────────────────────────────────────────────────
  Future<void> deleteFile(
      BuildContext context, FileModel file, int folderId) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService
          .getDeleteApiResponse('${FileEndpoints.deleteFile}${file.id}');

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        await fetchFiles(context, folderId, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error deleting file: $e'), context);
      _logger.e('deleteFile error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Search / filter ────────────────────────────────────────────────────────
  void searchFiles(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterLists();
    notifyListeners();
  }

  void _filterLists() {
    if (_searchQuery.isEmpty) {
      filteredFiles = List.from(files);
    } else {
      filteredFiles = files.where((f) {
        final n = f.name?.toLowerCase() ?? '';
        return n.contains(_searchQuery);
      }).toList();
    }
  }
}