import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ema_app/constants/base_url.dart';

// ─── Models ────────────────────────────────────────────────────────────────────

class PublicFolder {
  final int id;
  final String name;
  final String iconPath;
  final int fileCount;
  final String createdAt;

  const PublicFolder({
    required this.id,
    required this.name,
    required this.iconPath,
    required this.fileCount,
    required this.createdAt,
  });

  factory PublicFolder.fromJson(Map<String, dynamic> json) => PublicFolder(
    id:        json['id'] as int,
    name:      json['name'] as String? ?? '',
    iconPath:  json['icon_path'] as String? ?? '',
    fileCount: json['file_count'] as int? ?? 0,
    createdAt: json['created_at'] as String? ?? '',
  );
}
class PublicQuizSet {
  final int id;
  final String title;
  final String? description;
  final String? iconPath;
  final int questionCount;
  final String accessType;
  final String status;
  final String createdAt;
  final String folderName;
  final String folderIconPath;

  const PublicQuizSet({
    required this.id,
    required this.title,
    this.description,
    this.iconPath,
    required this.questionCount,
    required this.accessType,
    required this.status,
    required this.createdAt,
    required this.folderName,
    required this.folderIconPath,
  });

  factory PublicQuizSet.fromJson(Map<String, dynamic> json) => PublicQuizSet(
    id:             json['id'] as int,
    title:          json['title'] as String? ?? '',
    description:    json['description'] as String?,
    iconPath:       json['icon_path'] as String?,
    questionCount:  json['question_count'] as int? ?? 0,
    accessType:     json['access_type'] as String? ?? '',
    status:         json['status'] as String? ?? '',
    createdAt:      json['created_at'] as String? ?? '',
    folderName:     json['folder_name'] as String? ?? '',
    folderIconPath: json['folder_icon_path'] as String? ?? '',
  );
}

class PublicFile {
  final int id;
  final String name;
  final String filePath;
  final String? iconPath;
  final String accessType;
  final String status;
  final String createdAt;
  final String folderName;
  final String folderIconPath;

  const PublicFile({
    required this.id,
    required this.name,
    required this.filePath,
    this.iconPath,
    required this.accessType,
    required this.status,
    required this.createdAt,
    required this.folderName,
    required this.folderIconPath,
  });

  factory PublicFile.fromJson(Map<String, dynamic> json) => PublicFile(
    id:             json['id'] as int,
    name:           json['name'] as String? ?? '',
    filePath:       json['file_path'] as String? ?? '',
    iconPath:       json['icon_path'] as String?,
    accessType:     json['access_type'] as String? ?? '',
    status:         json['status'] as String? ?? '',
    createdAt:      json['created_at'] as String? ?? '',
    folderName:     json['folder_name'] as String? ?? '',
    folderIconPath: json['folder_icon_path'] as String? ?? '',
  );
}

// ─── ViewModel ─────────────────────────────────────────────────────────────────

class PublicFolderViewModel extends ChangeNotifier {
  static const int _perPage = 20;

  // ── Folders ─────────────────────────────────────────────────────────────────
  List<PublicFolder> _folders = [];
  List<PublicFolder> get folders => _folders;

  bool _isFoldersLoading = false;
  bool get isFoldersLoading => _isFoldersLoading;

  bool _isFoldersLoadingMore = false;
  bool get isFoldersLoadingMore => _isFoldersLoadingMore;
  bool _folderFilesHasNextPage = false;
  int _foldersCurrentPage = 1;
  int _foldersTotalPages  = 1;
  int _foldersTotalItems  = 0;
  int get foldersTotalItems => _foldersTotalItems;
  bool get hasFoldersNextPage => _foldersCurrentPage < _foldersTotalPages;
  bool get hasFolderFilesNextPage => _folderFilesHasNextPage;
  String? _foldersError;
  String? get foldersError => _foldersError;

  // ── Folder Files ─────────────────────────────────────────────────────────────
  List<PublicFile> _folderFiles = [];
  List<PublicFile> get folderFiles => _folderFiles;

  PublicFolder? _currentFolder;
  PublicFolder? get currentFolder => _currentFolder;

  bool _isFolderFilesLoading = false;
  bool get isFolderFilesLoading => _isFolderFilesLoading;

  bool _isFolderFilesLoadingMore = false;
  bool get isFolderFilesLoadingMore => _isFolderFilesLoadingMore;

  int _folderFilesCurrentPage = 1;
  int _folderFilesTotalPages  = 1;
  int _folderFilesTotalItems  = 0;
  int get folderFilesTotalItems => _folderFilesTotalItems;

  String? _folderFilesError;
  String? get folderFilesError => _folderFilesError;

  // ── All Public Files ──────────────────────────────────────────────────────────
  List<PublicFile> _publicFiles = [];
  List<PublicFile> get publicFiles => _publicFiles;

  bool _isPublicFilesLoading = false;
  bool get isPublicFilesLoading => _isPublicFilesLoading;

  bool _isPublicFilesLoadingMore = false;
  bool get isPublicFilesLoadingMore => _isPublicFilesLoadingMore;

  int _publicFilesCurrentPage = 1;
  int _publicFilesTotalPages  = 1;
  int _publicFilesTotalItems  = 0;
  int get publicFilesTotalItems => _publicFilesTotalItems;
  bool get hasPublicFilesNextPage => _publicFilesCurrentPage < _publicFilesTotalPages;

  String? _publicFilesError;
  String? get publicFilesError => _publicFilesError;

  // ── Folder Quiz Sets ──────────────────────────────────────────────────────────
  List<PublicQuizSet> _folderQuizSets = [];
  List<PublicQuizSet> get folderQuizSets => _folderQuizSets;

  bool _isFolderQuizSetsLoading = false;
  bool get isFolderQuizSetsLoading => _isFolderQuizSetsLoading;

  bool _isFolderQuizSetsLoadingMore = false;
  bool get isFolderQuizSetsLoadingMore => _isFolderQuizSetsLoadingMore;

  int  _folderQuizSetsCurrentPage = 1;
  int  _folderQuizSetsTotalPages  = 1;
  int  _folderQuizSetsTotalItems  = 0;
  bool _folderQuizSetsHasNextPage = false;

  int  get folderQuizSetsTotalItems  => _folderQuizSetsTotalItems;
  bool get hasFolderQuizSetsNextPage => _folderQuizSetsHasNextPage;

  String? _folderQuizSetsError;
  String? get folderQuizSetsError => _folderQuizSetsError;
  // ══════════════════════════════════════════════════════════════════════════════
  // PAGINATION PARSERS
  // ══════════════════════════════════════════════════════════════════════════════

  /// Folders list uses Laravel-style keys: current_page / last_page / total.
  void _parseFoldersPagination(Map<String, dynamic> pagination) {
    _foldersCurrentPage = (pagination['current_page'] as num?)?.toInt() ?? _foldersCurrentPage;
    _foldersTotalPages  = (pagination['last_page']    as num?)?.toInt() ?? _foldersTotalPages;
    _foldersTotalItems  = (pagination['total']        as num?)?.toInt() ?? _foldersTotalItems;
  }

  /// Folder-files & public-files use: page / total_pages / total_items.
  void _parseFolderFilesPagination(Map<String, dynamic> pagination) {
    _folderFilesCurrentPage  = (pagination['page']          as num?)?.toInt() ?? _folderFilesCurrentPage;
    _folderFilesTotalPages   = (pagination['total_pages']   as num?)?.toInt() ?? _folderFilesTotalPages;
    _folderFilesTotalItems   = (pagination['total_items']   as num?)?.toInt() ?? _folderFilesTotalItems;
    _folderFilesHasNextPage  =  pagination['has_next_page'] as bool? ?? false;  // ← read directly
  }
  void _parseFolderQuizSetsPagination(Map<String, dynamic> pagination) {
    _folderQuizSetsCurrentPage = (pagination['page']          as num?)?.toInt() ?? _folderQuizSetsCurrentPage;
    _folderQuizSetsTotalPages  = (pagination['total_pages']   as num?)?.toInt() ?? _folderQuizSetsTotalPages;
    _folderQuizSetsTotalItems  = (pagination['total_items']   as num?)?.toInt() ?? _folderQuizSetsTotalItems;
    _folderQuizSetsHasNextPage =  pagination['has_next_page'] as bool? ?? false;
  }
  // ══════════════════════════════════════════════════════════════════════════════
  // FOLDERS
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> fetchFolders({bool refresh = false}) async {
    if (refresh) {
      _folders            = [];
      _foldersCurrentPage = 1;
      _foldersTotalPages  = 1;
      _foldersTotalItems  = 0;
      _foldersError       = null;
    }

    if (_isFoldersLoading || _isFoldersLoadingMore) return;

    _isFoldersLoading = true;
    notifyListeners();

    try {
      final uri = Uri.parse(
        '${BaseUrl.baseUrl}/api/public/folders?page=$_foldersCurrentPage&per_page=$_perPage',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json       = jsonDecode(response.body) as Map<String, dynamic>;
        final data       = json['data'] as Map<String, dynamic>;
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        _parseFoldersPagination(pagination);
        _folders      = (data['folders'] as List)
            .map((e) => PublicFolder.fromJson(e as Map<String, dynamic>))
            .toList();
        _foldersError = null;
      } else {
        _foldersError = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _foldersError = 'Failed to load folders: $e';
    } finally {
      _isFoldersLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFoldersNextPage() async {
    if (_isFoldersLoading || _isFoldersLoadingMore || !hasFoldersNextPage) return;

    _isFoldersLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _foldersCurrentPage + 1;
      final uri = Uri.parse(
        '${BaseUrl.baseUrl}/api/public/folders?page=$nextPage&per_page=$_perPage',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json       = jsonDecode(response.body) as Map<String, dynamic>;
        final data       = json['data'] as Map<String, dynamic>;
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        _parseFoldersPagination(pagination);
        _folders.addAll(
          (data['folders'] as List)
              .map((e) => PublicFolder.fromJson(e as Map<String, dynamic>)),
        );
      }
    } catch (_) {
      // silently fail — user can scroll up to retry
    } finally {
      _isFoldersLoadingMore = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // FOLDER FILES
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> fetchFolderFiles(int folderId, {bool refresh = false}) async {
    if (refresh) {
      _folderFiles            = [];
      _currentFolder          = null;
      _folderFilesCurrentPage = 1;
      _folderFilesTotalPages  = 1;
      _folderFilesTotalItems  = 0;
      _folderFilesError       = null;
    }

    if (_isFolderFilesLoading || _isFolderFilesLoadingMore) return;

    _isFolderFilesLoading = true;
    notifyListeners();

    try {
      final uri = Uri.parse(
        '${BaseUrl.baseUrl}/api/public/folder/$folderId/files'
            '?page=$_folderFilesCurrentPage&per_page=$_perPage',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json       = jsonDecode(response.body) as Map<String, dynamic>;
        final data       = json['data'] as Map<String, dynamic>;
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        if (data['folder'] != null) {
          _currentFolder =
              PublicFolder.fromJson(data['folder'] as Map<String, dynamic>);
        }

        _parseFolderFilesPagination(pagination);
        final list = (data['files'] as List)
            .map((e) => PublicFile.fromJson(e as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _folderFiles = list;
        } else {
          _folderFiles.addAll(list);
        }
        _folderFilesError = null;
      } else {
        _folderFilesError = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _folderFilesError = 'Failed to load files: $e';
    } finally {
      _isFolderFilesLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFolderFilesNextPage(int folderId) async {
    if (_isFolderFilesLoading || _isFolderFilesLoadingMore || !hasFolderFilesNextPage) return;

    _isFolderFilesLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _folderFilesCurrentPage + 1;
      final uri = Uri.parse(
        '${BaseUrl.baseUrl}/api/public/folder/$folderId/files'
            '?page=$nextPage&per_page=$_perPage',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json       = jsonDecode(response.body) as Map<String, dynamic>;
        final data       = json['data'] as Map<String, dynamic>;
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        _parseFolderFilesPagination(pagination);
        _folderFiles.addAll(
          (data['files'] as List)
              .map((e) => PublicFile.fromJson(e as Map<String, dynamic>)),
        );
      }
    } catch (_) {
      // silently fail
    } finally {
      _isFolderFilesLoadingMore = false;
      notifyListeners();
    }
  }
  // ══════════════════════════════════════════════════════════════════════════════
// FOLDER QUIZ SETS
// ══════════════════════════════════════════════════════════════════════════════

  Future<void> fetchFolderQuizSets(int folderId, {bool refresh = false}) async {
    if (refresh) {
      _folderQuizSets            = [];
      _currentFolder             = null;
      _folderQuizSetsCurrentPage = 1;
      _folderQuizSetsTotalPages  = 1;
      _folderQuizSetsTotalItems  = 0;
      _folderQuizSetsHasNextPage = false;
      _folderQuizSetsError       = null;
    }

    if (_isFolderQuizSetsLoading || _isFolderQuizSetsLoadingMore) return;

    _isFolderQuizSetsLoading = true;
    notifyListeners();

    try {
      final uri = Uri.parse(
        '${BaseUrl.baseUrl}/api/public/folder/$folderId/quiz-sets'
            '?page=$_folderQuizSetsCurrentPage&per_page=$_perPage',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json       = jsonDecode(response.body) as Map<String, dynamic>;
        final data       = json['data'] as Map<String, dynamic>;
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        if (data['folder'] != null) {
          _currentFolder =
              PublicFolder.fromJson(data['folder'] as Map<String, dynamic>);
        }

        _parseFolderQuizSetsPagination(pagination);
        final list = (data['quiz_sets'] as List)
            .map((e) => PublicQuizSet.fromJson(e as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _folderQuizSets = list;
        } else {
          _folderQuizSets.addAll(list);
        }
        _folderQuizSetsError = null;
      } else {
        _folderQuizSetsError = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _folderQuizSetsError = 'Failed to load quiz sets: $e';
    } finally {
      _isFolderQuizSetsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFolderQuizSetsNextPage(int folderId) async {
    if (_isFolderQuizSetsLoading ||
        _isFolderQuizSetsLoadingMore ||
        !hasFolderQuizSetsNextPage) return;

    _isFolderQuizSetsLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _folderQuizSetsCurrentPage + 1;
      final uri = Uri.parse(
        '${BaseUrl.baseUrl}/api/public/folder/$folderId/quiz-sets'
            '?page=$nextPage&per_page=$_perPage',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json       = jsonDecode(response.body) as Map<String, dynamic>;
        final data       = json['data'] as Map<String, dynamic>;
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        _parseFolderQuizSetsPagination(pagination);
        _folderQuizSets.addAll(
          (data['quiz_sets'] as List)
              .map((e) => PublicQuizSet.fromJson(e as Map<String, dynamic>)),
        );
      }
    } catch (_) {
      // silently fail
    } finally {
      _isFolderQuizSetsLoadingMore = false;
      notifyListeners();
    }
  }
  Future<void> refreshAll() async {
    await Future.wait([
      fetchFolders(refresh: true),
    ]);
  }

  void clearFolderFiles() {
    _folderFiles            = [];
    _currentFolder          = null;
    _folderFilesCurrentPage = 1;
    _folderFilesTotalPages  = 1;
    _folderFilesTotalItems  = 0;
    _folderFilesError       = null;
    notifyListeners();
  }
  void clearFolderQuizSets() {
    _folderQuizSets            = [];
    _currentFolder             = null;
    _folderQuizSetsCurrentPage = 1;
    _folderQuizSetsTotalPages  = 1;
    _folderQuizSetsTotalItems  = 0;
    _folderQuizSetsHasNextPage = false;
    _folderQuizSetsError       = null;
    notifyListeners();
  }
}