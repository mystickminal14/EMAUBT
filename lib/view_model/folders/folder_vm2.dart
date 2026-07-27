import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/folder_endpoints.dart';
import 'package:ema_app/model/folder_mode_v2/folder_model_v2.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';

class UpdatedFolderViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();

  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading = false;
  bool isActionLoading = false;
  bool isFetchingMore = false;

  List<FolderModelv2> folders = [];
  List<FolderModelv2> filteredFolders = [];
  String _searchQuery = '';

  // ── Pagination ─────────────────────────────────────────────────────────────
  int currentPage = 1;
  int totalPages = 1;
  int totalFolders = 0;
  static const int perPage = 7;

  bool get hasMorePages => currentPage < totalPages;

  // ── Form fields ────────────────────────────────────────────────────────────
  String? name;

  /// Picked image file (mobile/desktop)
  File? selectedIconFile;

  /// Raw bytes of the picked image (used on web & as preview source)
  Uint8List? selectedIconBytes;

  /// Base64-encoded image string sent to the API as `icon`
  String? selectedIconBase64;

  // ── Parse folders list ────────────────────────────────────────────────────
  List<FolderModelv2> _parseFolders(Map<String, dynamic> response) {
    try {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final rawList = data['folders'];
        if (rawList is List) {
          return rawList
              .map((e) =>
              FolderModelv2.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      if (data is List) {
        return data
            .map((e) =>
            FolderModelv2.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      _logger.e('Error parsing folders: $e');
    }
    return [];
  }

  // ── Parse pagination ──────────────────────────────────────────────────────
  void _parsePagination(Map<String, dynamic> response) {
    try {
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

      totalFolders =
          (pagination['total'] as num?)?.toInt() ?? totalFolders;
      currentPage =
          (pagination['current_page'] as num?)?.toInt() ?? currentPage;
      totalPages =
          (pagination['last_page'] as num?)?.toInt() ?? totalPages;

      _logger.i(
          'Pagination → page $currentPage / $totalPages, total $totalFolders');
    } catch (e) {
      _logger.e('Error parsing pagination: $e');
    }
  }

  // ── Build URL ─────────────────────────────────────────────────────────────
  String _buildUrl(int page) {
    final uri = Uri.parse(FolderEndpoints.folderList).replace(
      queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
        'sort_by': 'created_at',
        'sort_order': 'DESC',
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      },
    );
    return uri.toString();
  }

  // ── Initial / refresh fetch ───────────────────────────────────────────────
  Future<void> fetchFolders(BuildContext context,
      {bool refresh = false}) async {
    _lastContext = context;
    if (refresh) {
      currentPage = 1;
      totalPages = 1;
      totalFolders = 0;
      folders.clear();
      filteredFolders.clear();
    }

    isLoading = true;
    notifyListeners();

    try {
      final url = _buildUrl(currentPage);
      _logger.i('fetchFolders → $url');
      final response = await _apiService.getApiResponse(url);

      if (response['success'] == true) {
        _parsePagination(response);
        folders = _parseFolders(response);
        _filterLists();
        _logger.i(
            'Loaded ${folders.length} folders (page $currentPage / $totalPages)');
      } else {
        if (refresh) {
          folders = [];
          _filterLists();
        }
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      if (refresh) {
        folders = [];
        _filterLists();
      }
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching folders: $e'), context);
      _logger.e('fetchFolders error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Load next page ─────────────────────────────────────────────────────────
  Future<void> fetchNextPage(BuildContext context) async {
    if (isFetchingMore || isLoading || !hasMorePages) return;

    isFetchingMore = true;
    notifyListeners();

    try {
      final nextPage = currentPage + 1;
      final url = _buildUrl(nextPage);
      _logger.i('fetchNextPage → page $nextPage → $url');

      final response = await _apiService.getApiResponse(url);

      if (response['success'] == true) {
        _parsePagination(response);
        final fetched = _parseFolders(response);
        folders.addAll(fetched);
        _filterLists();
        _logger.i(
            'Appended ${fetched.length} — list total: ${folders.length}');
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error loading more folders: $e'), context);
      _logger.e('fetchNextPage error: $e');
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  // ── POST /api/folders ─────────────────────────────────────────────────────
  Future<void> addFolder(BuildContext context) async {
    if (name == null || name!.trim().isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Folder name is required'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final body = <String, dynamic>{
        'name': name!.trim(),
        if (selectedIconBase64 != null && selectedIconBase64!.isNotEmpty)
          'icon': selectedIconBase64,
      };

      if (kDebugMode) {
        _logger.i(
            'addFolder → name: ${name}, icon base64 length: ${selectedIconBase64?.length ?? 0}');
      }

      final response =
      await _apiService.getPostApiResponse(FolderEndpoints.createFolder, body);

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('Folder created successfully');
        clearFields();
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchFolders(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error creating folder: $e'), context);
      _logger.e('addFolder error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── PUT /api/folders/{id} ─────────────────────────────────────────────────
  Future<void> editFolder(BuildContext context, FolderModelv2 folder) async {
    if (name == null || name!.trim().isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Folder name is required'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final body = <String, dynamic>{
        'name': name!.trim(),
        // Only include icon if a new one was picked; omit to keep existing
        if (selectedIconBase64 != null && selectedIconBase64!.isNotEmpty)
          'icon': selectedIconBase64,
      };

      final response = await _apiService.getPostApiResponse(
        '${FolderEndpoints.updateFolder}${folder.id}',
        body,
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('Folder ${folder.id} updated');
        clearFields();
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchFolders(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error updating folder: $e'), context);
      _logger.e('editFolder error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── DELETE /api/folders/{id} ──────────────────────────────────────────────
  Future<void> deleteFolder(BuildContext context, FolderModelv2 folder) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService
          .getDeleteApiResponse('${FolderEndpoints.deleteFolder}${folder.id}');

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('Folder ${folder.id} deleted');
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchFolders(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error deleting folder: $e'), context);
      _logger.e('deleteFolder error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Image picker → compress → base64 ─────────────────────────────────────
  Future<void> pickIcon() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      Uint8List? compressedBytes;

      if (kIsWeb) {
        // Web: read bytes, then compress in-memory
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
        // Mobile/desktop: compress from file path
        compressedBytes = await FlutterImageCompress.compressWithFile(
          pickedFile.path,
          quality: 80,
          minWidth: 256,
          minHeight: 256,
          format: CompressFormat.jpeg,
        );

        final tempDir =
        await Directory.systemTemp.createTemp('folder_icon_');
        if (compressedBytes != null) {
          final file = File(
              '${tempDir.path}/icon_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(compressedBytes);
          selectedIconFile = file;
          selectedIconBytes = compressedBytes;
        } else {
          // Fallback: copy the original into our own temp dir rather than
          // holding a File on the picker's own path, which may be the
          // user's real device file and must never be deleted.
          final ext = pickedFile.path.split('.').last;
          final copy = await File(pickedFile.path).copy(
              '${tempDir.path}/icon_${DateTime.now().millisecondsSinceEpoch}.$ext');
          selectedIconFile = copy;
          selectedIconBytes = await copy.readAsBytes();
          _logger.w('Compression failed — using copied original');
        }
      }

      // Encode to base64
      if (selectedIconBytes != null) {
        final base64 = base64Encode(selectedIconBytes!);

        selectedIconBase64 = "data:image/jpeg;base64,$base64";

        _logger.i("FINAL ICON FORMAT → ${selectedIconBase64!.substring(0, 50)}");
      }

      notifyListeners();
    } catch (e) {
      _logger.e('pickIcon error: $e');
    }
  }
  Timer? _debounceTimer;
  BuildContext? _lastContext;
  // ── Search / filter ───────────────────────────────────────────────────────
  void searchFolders(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterLists();
    notifyListeners();
    _debounceSearch();
  }

  void _debounceSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final ctx = _lastContext;
      if (ctx == null) return;
      // Guard: don't fire if widget using this context is disposed
      try {
        if (ctx is Element && !ctx.mounted) return;
      } catch (_) {
        return;
      }
      fetchFolders(ctx, refresh: true);
    });
  }

  void _filterLists() {
    if (_searchQuery.isEmpty) {
      filteredFolders = List.from(folders);
    } else {
      filteredFolders = folders.where((f) {
        final n = f.name?.toLowerCase() ?? '';
        return n.contains(_searchQuery);
      }).toList();
    }
  }

  // ── Field helpers ─────────────────────────────────────────────────────────
  void setFields({String? name, String? iconBase64}) {
    this.name = name;
    selectedIconBase64 = iconBase64;
    notifyListeners();
  }

  void clearFields() {
    name = null;
    selectedIconBase64 = null;
    selectedIconBytes = null;
    _debounceTimer?.cancel(); // ← cancel any pending search on clear
    _searchQuery = '';
    try {
      selectedIconFile?.deleteSync();
    } catch (_) {}
    selectedIconFile = null;
    _filterLists();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel(); // ← always cancel on VM dispose
    super.dispose();
  }
  void clearIcon() {
    selectedIconBase64 = null;
    selectedIconBytes = null;
    notifyListeners();
  }
}