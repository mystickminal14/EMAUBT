import 'dart:async';
import 'dart:io';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/file_endpoints.dart';
import 'package:ema_app/model/folder_mode_v2/new_file_model.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ema_app/utils/image_compress_util.dart';
import 'package:logger/logger.dart';

class FolderFilesViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();

  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading      = false;
  bool isActionLoading = false;
  bool isFetchingMore  = false;

  List<FileModel> files         = [];
  List<FileModel> filteredFiles = [];
  String _searchQuery = '';

  // ── Pagination ─────────────────────────────────────────────────────────────
  int currentPage = 1;
  int totalPages  = 1;
  int totalFiles  = 0;
  static const int perPage = 8;

  bool get hasMorePages => currentPage < totalPages;

  // ── Upload / Edit form state ───────────────────────────────────────────────
  PlatformFile? selectedFile;   // the PDF / document
  File?         selectedIcon;   // icon image chosen from gallery
  String?       uploadFileName; // custom display name

  // ── Parse helpers ──────────────────────────────────────────────────────────
  List<FileModel> _parseFiles(Map<String, dynamic> response) {
    try {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final rawList = data['files'];
        if (rawList is List) {
          return rawList
              .map((e) => FileModel.fromJson(
              Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      if (data is List) {
        return data
            .map((e) => FileModel.fromJson(
            Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      _logger.e('Error parsing files: $e');
    }
    return [];
  }

  void _parsePagination(Map<String, dynamic> response) {
    try {
      final data       = response['data'] as Map<String, dynamic>? ?? {};
      final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

      totalFiles = (pagination['total_items'] as num?)?.toInt() ?? totalFiles;  // ← was 'total'
      final lastPage = (pagination['total_pages'] as num?)?.toInt();             // ← was 'last_page'
      if (lastPage != null && lastPage > 0) totalPages = lastPage;

      _logger.i('Pagination → page $currentPage/$totalPages total $totalFiles hasMore: $hasMorePages');
    } catch (e) {
      _logger.e('Error parsing pagination: $e');
    }
  }
  String? statusFilter;
  /// Builds: /api/folder/{folderId}/files?page=1&per_page=15&search=...
  String _buildUrl(int folderId, int page) {
    return Uri.parse(FileEndpoints.folderFiles(folderId)).replace(
      queryParameters: {
        'page':     page.toString(),
        'per_page': perPage.toString(),
        if (statusFilter != null && statusFilter!.isNotEmpty)
          'status': statusFilter,
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      },
    ).toString();
  }

  // ── GET files ──────────────────────────────────────────────────────────────
  Future<void> fetchFiles(BuildContext context, int folderId,
      {bool refresh = false}) async {
    _lastContext  = context;   // ← save for debounce
    _lastFolderId = folderId;  // ← save for debounce
    if (refresh) {
      currentPage = 1;
      totalPages  = 1;
      totalFiles  = 0;
      files.clear();
      filteredFiles.clear();
    }

    isLoading = true;
    notifyListeners();

    try {
      final response =
      await _apiService.getApiResponse(_buildUrl(folderId, currentPage));

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

    final nextPage = currentPage + 1; // ← own it here

    try {
      final response =
      await _apiService.getApiResponse(_buildUrl(folderId, nextPage));

      if (response['success'] == true) {
        currentPage = nextPage; // ← set it here, not in _parsePagination
        _parsePagination(response);
        files.addAll(_parseFiles(response));
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

  // ── Pick PDF / document then auto-upload ─────────────────────────────────
  Future<void> pickAndUploadFile(BuildContext context, int folderId) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;

      selectedFile   = result.files.first;
      uploadFileName = result.files.first.name
          .replaceAll(RegExp(r'\.[^.]+$'), '');
      notifyListeners();

      // Auto-upload immediately after picking
      await uploadFile(context, folderId);
    } catch (e) {
      _logger.e('pickAndUploadFile error: $e');
    }
  }

  // ── Pick PDF / document (manual, kept for compatibility) ──────────────────
  Future<void> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.isNotEmpty) {
        selectedFile = result.files.first;
        // Only auto-fill name if the user hasn't typed one yet.
        // This preserves the name the user already entered in the field.
        if (uploadFileName == null || uploadFileName!.isEmpty) {
          uploadFileName = result.files.first.name
              .replaceAll(RegExp(r'\.[^.]+$'), '');
        }
        notifyListeners();
      }
    } catch (e) {
      _logger.e('pickFile error: $e');
    }
  }

  // ── Pick icon image from gallery ───────────────────────────────────────────
  Future<void> pickIcon() async {
    try {
      final picker     = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      // Compress before upload
      final compressedBytes = await ImageCompressUtil.compressFile(
        pickedFile.path,
        quality:   85,
        minWidth:  512,
        minHeight: 512,
      );

      if (compressedBytes != null) {
        final tempDir = await Directory.systemTemp.createTemp();
        final file    = File(
            '${tempDir.path}/icon_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(compressedBytes);
        selectedIcon = file;
      } else {
        selectedIcon = File(pickedFile.path);
      }
      notifyListeners();
    } catch (e) {
      _logger.e('pickIcon error: $e');
    }
  }

  void setFileName(String value) {
    uploadFileName = value.trim();
    notifyListeners();
  }

  /// Full reset — clears file, icon AND name. Used when upload succeeds or cancels.
  void clearSelectedFile() {
    selectedFile   = null;
    selectedIcon?.deleteSync();
    selectedIcon   = null;
    uploadFileName = null;
    _debounceTimer?.cancel(); // ← cancel pending search on clear
    notifyListeners();
  }
  /// Clears only the picked file/icon — preserves [uploadFileName].
  /// Use this before opening the edit sheet so the pre-filled name survives.
  void clearSelectionOnly() {
    selectedFile = null;
    selectedIcon?.deleteSync();
    selectedIcon = null;
    notifyListeners();
  }

  // ── Upload file (POST with name + icon + file + folder_id) ────────────────
  Future<void> uploadFile(BuildContext context, int folderId) async {
    if (selectedFile == null) {
      Utils.showApiResponse(
          Utils.errorResponse('Please select a file first'), context);
      return;
    }
    if (uploadFileName == null || uploadFileName!.isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Please enter a file name'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.postFileMultipart(
        FileEndpoints.uploadFile,
        <String, dynamic>{
          'folder_id': folderId.toString(),
          'name':      uploadFileName!,
        },
        // The actual document
        mainFileBytes: selectedFile!.bytes,
        mainFilePath:  selectedFile!.path,
        mainFileName:  selectedFile!.name,
        // Optional icon
        iconFile: selectedIcon,
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('File uploaded: $uploadFileName');
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

  // ── Edit file (POST/PATCH name + optional new icon + optional new file) ────
  /// Sends a multipart request to update an existing file record.
  /// Only fields that have changed are sent:
  ///   • name         — always sent (the display name)
  ///   • icon_file    — only if the user picked a new icon (selectedIcon != null)
  ///   • file         — only if the user picked a replacement document (selectedFile != null)
  Future<void> editFile(
      BuildContext context, FileModel file, int folderId) async {
    if (uploadFileName == null || uploadFileName!.isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Please enter a file name'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.postFileMultipart(
        '${FileEndpoints.editFIle}${file.id}',
        <String, dynamic>{
          'name': uploadFileName!,
        },
        // Replace file only if user picked a new one
        mainFileBytes: selectedFile?.bytes,
        mainFilePath:  selectedFile?.path,
        mainFileName:  selectedFile?.name,
        // Replace icon only if user picked a new one
        iconFile: selectedIcon,
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('File edited: $uploadFileName');
        clearSelectedFile();
        await fetchFiles(context, folderId, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error editing file: $e'), context);
      _logger.e('editFile error: $e');
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
  Future<void> changeStatus(
      BuildContext context, FileModel file, int folderId, String status) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService
          .getPostApiResponse('${FileEndpoints.changeStatus(file.id!)}',{
            "status":status
      });

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
  Timer? _debounceTimer;
  BuildContext? _lastContext;
  int? _lastFolderId;

  void searchFiles(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterLists();       // instant local filter for snappy UI
    notifyListeners();
    _debounceSearch();    // then hit the API after 500ms pause
  }
  void _debounceSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final ctx      = _lastContext;
      final folderId = _lastFolderId;
      if (ctx == null || folderId == null) return;
      try {
        if (ctx is Element && !ctx.mounted) return;
      } catch (_) {
        return;
      }
      fetchFiles(ctx, folderId, refresh: true);
    });
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
  void reset() {
    files = [];        // or whatever your backing list is
    isLoading = false;
    notifyListeners();
  }


  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}