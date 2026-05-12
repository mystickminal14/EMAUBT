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
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    iconPath: json['icon_path'] as String? ?? '',
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
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    iconPath: json['icon_path'] as String?,
    questionCount: json['question_count'] as int? ?? 0,
    accessType: json['access_type'] as String? ?? '',
    status: json['status'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    folderName: json['folder_name'] as String? ?? '',
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
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    filePath: json['file_path'] as String? ?? '',
    iconPath: json['icon_path'] as String?,
    accessType: json['access_type'] as String? ?? '',
    status: json['status'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
    folderName: json['folder_name'] as String? ?? '',
    folderIconPath: json['folder_icon_path'] as String? ?? '',
  );
}

// ─── ViewModel ─────────────────────────────────────────────────────────────────

class PublicFolderViewModel extends ChangeNotifier {
  static const int _perPage = 20;
  static const String _tag = '[PublicFolderVM]';

  // ── Folders ──────────────────────────────────────────────────────────────────
  List<PublicFolder> _folders = [];
  List<PublicFolder> get folders => _folders;

  bool _isFoldersLoading = false;
  bool get isFoldersLoading => _isFoldersLoading;

  bool _isFoldersLoadingMore = false;
  bool get isFoldersLoadingMore => _isFoldersLoadingMore;

  bool _folderFilesHasNextPage = false;
  int _foldersCurrentPage = 1;
  int _foldersTotalPages = 1;
  int _foldersTotalItems = 0;
  int get foldersTotalItems => _foldersTotalItems;
  bool get hasFoldersNextPage => _foldersCurrentPage < _foldersTotalPages;
  bool get hasFolderFilesNextPage => _folderFilesHasNextPage;

  String? _foldersError;
  String? get foldersError => _foldersError;

  // ── Folder Files ──────────────────────────────────────────────────────────────
  List<PublicFile> _folderFiles = [];
  List<PublicFile> get folderFiles => _folderFiles;

  PublicFolder? _currentFolder;
  PublicFolder? get currentFolder => _currentFolder;

  bool _isFolderFilesLoading = false;
  bool get isFolderFilesLoading => _isFolderFilesLoading;

  bool _isFolderFilesLoadingMore = false;
  bool get isFolderFilesLoadingMore => _isFolderFilesLoadingMore;

  int _folderFilesCurrentPage = 1;
  int _folderFilesTotalPages = 1;
  int _folderFilesTotalItems = 0;
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
  int _publicFilesTotalPages = 1;
  int _publicFilesTotalItems = 0;
  int get publicFilesTotalItems => _publicFilesTotalItems;
  bool get hasPublicFilesNextPage =>
      _publicFilesCurrentPage < _publicFilesTotalPages;

  String? _publicFilesError;
  String? get publicFilesError => _publicFilesError;

  // ── Folder Quiz Sets ──────────────────────────────────────────────────────────
  List<PublicQuizSet> _folderQuizSets = [];
  List<PublicQuizSet> get folderQuizSets => _folderQuizSets;

  bool _isFolderQuizSetsLoading = false;
  bool get isFolderQuizSetsLoading => _isFolderQuizSetsLoading;

  bool _isFolderQuizSetsLoadingMore = false;
  bool get isFolderQuizSetsLoadingMore => _isFolderQuizSetsLoadingMore;

  int _folderQuizSetsCurrentPage = 1;
  int _folderQuizSetsTotalPages = 1;
  int _folderQuizSetsTotalItems = 0;
  bool _folderQuizSetsHasNextPage = false;

  int get folderQuizSetsTotalItems => _folderQuizSetsTotalItems;
  bool get hasFolderQuizSetsNextPage => _folderQuizSetsHasNextPage;

  String? _folderQuizSetsError;
  String? get folderQuizSetsError => _folderQuizSetsError;

  // ══════════════════════════════════════════════════════════════════════════════
  // PAGINATION PARSERS
  // ══════════════════════════════════════════════════════════════════════════════

  void _parseFoldersPagination(Map<String, dynamic> pagination) {
    _foldersCurrentPage =
        (pagination['current_page'] as num?)?.toInt() ?? _foldersCurrentPage;
    _foldersTotalPages =
        (pagination['last_page'] as num?)?.toInt() ?? _foldersTotalPages;
    _foldersTotalItems =
        (pagination['total'] as num?)?.toInt() ?? _foldersTotalItems;
    debugPrint(
        '$_tag _parseFoldersPagination → page=$_foldersCurrentPage / last=$_foldersTotalPages / total=$_foldersTotalItems');
  }

  void _parseFolderFilesPagination(Map<String, dynamic> pagination) {
    _folderFilesCurrentPage =
        (pagination['page'] as num?)?.toInt() ?? _folderFilesCurrentPage;
    _folderFilesTotalPages =
        (pagination['total_pages'] as num?)?.toInt() ?? _folderFilesTotalPages;
    _folderFilesTotalItems =
        (pagination['total_items'] as num?)?.toInt() ?? _folderFilesTotalItems;
    _folderFilesHasNextPage = pagination['has_next_page'] as bool? ?? false;
    debugPrint(
        '$_tag _parseFolderFilesPagination → page=$_folderFilesCurrentPage / total_pages=$_folderFilesTotalPages / has_next=$_folderFilesHasNextPage');
  }

  void _parseFolderQuizSetsPagination(Map<String, dynamic> pagination) {
    _folderQuizSetsCurrentPage =
        (pagination['page'] as num?)?.toInt() ?? _folderQuizSetsCurrentPage;
    _folderQuizSetsTotalPages =
        (pagination['total_pages'] as num?)?.toInt() ??
            _folderQuizSetsTotalPages;
    _folderQuizSetsTotalItems =
        (pagination['total_items'] as num?)?.toInt() ??
            _folderQuizSetsTotalItems;
    _folderQuizSetsHasNextPage =
        pagination['has_next_page'] as bool? ?? false;
    debugPrint(
        '$_tag _parseFolderQuizSetsPagination → page=$_folderQuizSetsCurrentPage / total_pages=$_folderQuizSetsTotalPages / has_next=$_folderQuizSetsHasNextPage');
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // FOLDERS
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> fetchFolders({bool refresh = false}) async {
    debugPrint('$_tag fetchFolders() called — refresh=$refresh');

    if (refresh) {
      _folders = [];
      _foldersCurrentPage = 1;
      _foldersTotalPages = 1;
      _foldersTotalItems = 0;
      _foldersError = null;
      debugPrint('$_tag fetchFolders — state reset for refresh');
    }

    // ── Guard ────────────────────────────────────────────────────────────────
    if (_isFoldersLoading || _isFoldersLoadingMore) {
      debugPrint(
          '$_tag fetchFolders — SKIPPED (isFoldersLoading=$_isFoldersLoading, isFoldersLoadingMore=$_isFoldersLoadingMore)');
      return;
    }

    _isFoldersLoading = true;
    notifyListeners();

    final url =
        '${BaseUrl.baseUrl}/public/folders?page=$_foldersCurrentPage&per_page=$_perPage';
    debugPrint('$_tag fetchFolders — GET $url');

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint(
          '$_tag fetchFolders — response ${response.statusCode}, body length=${response.body.length}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('$_tag fetchFolders — top-level keys: ${json.keys.toList()}');

        final data = json['data'] as Map<String, dynamic>? ?? {};
        debugPrint('$_tag fetchFolders — data keys: ${data.keys.toList()}');

        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
        _parseFoldersPagination(pagination);

        final rawList = data['folders'] as List? ?? [];
        debugPrint('$_tag fetchFolders — raw folder count: ${rawList.length}');

        _folders = rawList
            .map((e) => PublicFolder.fromJson(e as Map<String, dynamic>))
            .toList();
        _foldersError = null;
        debugPrint(
            '$_tag fetchFolders — parsed ${_folders.length} folders ✓');
      } else {
        _foldersError = 'Server error: ${response.statusCode}';
        debugPrint(
            '$_tag fetchFolders — ERROR ${response.statusCode}: ${response.body}');
      }
    } catch (e, st) {
      _foldersError = 'Failed to load folders: $e';
      debugPrint('$_tag fetchFolders — EXCEPTION: $e\n$st');
    } finally {
      _isFoldersLoading = false;
      notifyListeners();
      debugPrint('$_tag fetchFolders — done, folders.length=${_folders.length}');
    }
  }

  Future<void> fetchFoldersNextPage() async {
    debugPrint(
        '$_tag fetchFoldersNextPage() — hasFoldersNextPage=$hasFoldersNextPage');

    if (_isFoldersLoading || _isFoldersLoadingMore || !hasFoldersNextPage) {
      debugPrint(
          '$_tag fetchFoldersNextPage — SKIPPED (loading=$_isFoldersLoading, loadingMore=$_isFoldersLoadingMore, hasNext=$hasFoldersNextPage)');
      return;
    }

    _isFoldersLoadingMore = true;
    notifyListeners();

    final nextPage = _foldersCurrentPage + 1;
    final url =
        '${BaseUrl.baseUrl}/public/folders?page=$nextPage&per_page=$_perPage';
    debugPrint('$_tag fetchFoldersNextPage — GET $url');

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint(
          '$_tag fetchFoldersNextPage — response ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>? ?? {};
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        _parseFoldersPagination(pagination);
        final newItems = (data['folders'] as List? ?? [])
            .map((e) => PublicFolder.fromJson(e as Map<String, dynamic>))
            .toList();
        _folders.addAll(newItems);
        debugPrint(
            '$_tag fetchFoldersNextPage — appended ${newItems.length}, total=${_folders.length}');
      }
    } catch (e, st) {
      debugPrint('$_tag fetchFoldersNextPage — EXCEPTION: $e\n$st');
    } finally {
      _isFoldersLoadingMore = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // FOLDER FILES
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> fetchFolderFiles(int folderId, {bool refresh = false}) async {
    debugPrint(
        '$_tag fetchFolderFiles(folderId=$folderId) called — refresh=$refresh');

    if (refresh) {
      _folderFiles = [];
      _currentFolder = null;
      _folderFilesCurrentPage = 1;
      _folderFilesTotalPages = 1;
      _folderFilesTotalItems = 0;
      _folderFilesError = null;
      debugPrint('$_tag fetchFolderFiles — state reset for refresh');
    }

    if (_isFolderFilesLoading || _isFolderFilesLoadingMore) {
      debugPrint(
          '$_tag fetchFolderFiles — SKIPPED (isFolderFilesLoading=$_isFolderFilesLoading, isFolderFilesLoadingMore=$_isFolderFilesLoadingMore)');
      return;
    }

    _isFolderFilesLoading = true;
    notifyListeners();

    final url =
        '${BaseUrl.baseUrl}/public/folder/$folderId/files?page=$_folderFilesCurrentPage&per_page=$_perPage';
    debugPrint('$_tag fetchFolderFiles — GET $url');

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint(
          '$_tag fetchFolderFiles — response ${response.statusCode}, body length=${response.body.length}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
            '$_tag fetchFolderFiles — top-level keys: ${json.keys.toList()}');

        final data = json['data'] as Map<String, dynamic>? ?? {};
        debugPrint(
            '$_tag fetchFolderFiles — data keys: ${data.keys.toList()}');

        if (data['folder'] != null) {
          _currentFolder =
              PublicFolder.fromJson(data['folder'] as Map<String, dynamic>);
          debugPrint(
              '$_tag fetchFolderFiles — currentFolder="${_currentFolder?.name}"');
        }

        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
        _parseFolderFilesPagination(pagination);

        final rawList = data['files'] as List? ?? [];
        debugPrint(
            '$_tag fetchFolderFiles — raw file count: ${rawList.length}');

        final list = rawList
            .map((e) => PublicFile.fromJson(e as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _folderFiles = list;
        } else {
          _folderFiles.addAll(list);
        }
        _folderFilesError = null;

        // Log access_type breakdown so filtering issues are visible
        final accessGroups = <String, int>{};
        for (final f in _folderFiles) {
          accessGroups[f.accessType] =
              (accessGroups[f.accessType] ?? 0) + 1;
        }
        debugPrint(
            '$_tag fetchFolderFiles — parsed ${_folderFiles.length} files, access_type breakdown: $accessGroups');
      } else {
        _folderFilesError = 'Server error: ${response.statusCode}';
        debugPrint(
            '$_tag fetchFolderFiles — ERROR ${response.statusCode}: ${response.body}');
      }
    } catch (e, st) {
      _folderFilesError = 'Failed to load files: $e';
      debugPrint('$_tag fetchFolderFiles — EXCEPTION: $e\n$st');
    } finally {
      _isFolderFilesLoading = false;
      notifyListeners();
      debugPrint(
          '$_tag fetchFolderFiles — done, folderFiles.length=${_folderFiles.length}');
    }
  }

  Future<void> fetchFolderFilesNextPage(int folderId) async {
    debugPrint(
        '$_tag fetchFolderFilesNextPage(folderId=$folderId) — hasFolderFilesNextPage=$hasFolderFilesNextPage');

    if (_isFolderFilesLoading ||
        _isFolderFilesLoadingMore ||
        !hasFolderFilesNextPage) {
      debugPrint(
          '$_tag fetchFolderFilesNextPage — SKIPPED (loading=$_isFolderFilesLoading, loadingMore=$_isFolderFilesLoadingMore, hasNext=$hasFolderFilesNextPage)');
      return;
    }

    _isFolderFilesLoadingMore = true;
    notifyListeners();

    final nextPage = _folderFilesCurrentPage + 1;
    final url =
        '${BaseUrl.baseUrl}/public/folder/$folderId/files?page=$nextPage&per_page=$_perPage';
    debugPrint('$_tag fetchFolderFilesNextPage — GET $url');

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint(
          '$_tag fetchFolderFilesNextPage — response ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>? ?? {};
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        _parseFolderFilesPagination(pagination);
        final newItems = (data['files'] as List? ?? [])
            .map((e) => PublicFile.fromJson(e as Map<String, dynamic>))
            .toList();
        _folderFiles.addAll(newItems);
        debugPrint(
            '$_tag fetchFolderFilesNextPage — appended ${newItems.length}, total=${_folderFiles.length}');
      }
    } catch (e, st) {
      debugPrint('$_tag fetchFolderFilesNextPage — EXCEPTION: $e\n$st');
    } finally {
      _isFolderFilesLoadingMore = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // FOLDER QUIZ SETS
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> fetchFolderQuizSets(int folderId, {bool refresh = false}) async {
    debugPrint(
        '$_tag fetchFolderQuizSets(folderId=$folderId) called — refresh=$refresh');

    if (refresh) {
      _folderQuizSets = [];
      _currentFolder = null;
      _folderQuizSetsCurrentPage = 1;
      _folderQuizSetsTotalPages = 1;
      _folderQuizSetsTotalItems = 0;
      _folderQuizSetsHasNextPage = false;
      _folderQuizSetsError = null;
      debugPrint('$_tag fetchFolderQuizSets — state reset for refresh');
    }

    if (_isFolderQuizSetsLoading || _isFolderQuizSetsLoadingMore) {
      debugPrint(
          '$_tag fetchFolderQuizSets — SKIPPED (isFolderQuizSetsLoading=$_isFolderQuizSetsLoading, isFolderQuizSetsLoadingMore=$_isFolderQuizSetsLoadingMore)');
      return;
    }

    _isFolderQuizSetsLoading = true;
    notifyListeners();

    final url =
        '${BaseUrl.baseUrl}/public/folder/$folderId/quiz-sets?page=$_folderQuizSetsCurrentPage&per_page=$_perPage';
    debugPrint('$_tag fetchFolderQuizSets — GET $url');

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint(
          '$_tag fetchFolderQuizSets — response ${response.statusCode}, body length=${response.body.length}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
            '$_tag fetchFolderQuizSets — top-level keys: ${json.keys.toList()}');

        final data = json['data'] as Map<String, dynamic>? ?? {};
        debugPrint(
            '$_tag fetchFolderQuizSets — data keys: ${data.keys.toList()}');

        if (data['folder'] != null) {
          _currentFolder =
              PublicFolder.fromJson(data['folder'] as Map<String, dynamic>);
          debugPrint(
              '$_tag fetchFolderQuizSets — currentFolder="${_currentFolder?.name}"');
        }

        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
        _parseFolderQuizSetsPagination(pagination);

        final rawList = data['quiz_sets'] as List? ?? [];
        debugPrint(
            '$_tag fetchFolderQuizSets — raw quiz_sets count: ${rawList.length}');

        final list = rawList
            .map((e) => PublicQuizSet.fromJson(e as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _folderQuizSets = list;
        } else {
          _folderQuizSets.addAll(list);
        }
        _folderQuizSetsError = null;

        // Log access_type breakdown
        final accessGroups = <String, int>{};
        for (final q in _folderQuizSets) {
          accessGroups[q.accessType] =
              (accessGroups[q.accessType] ?? 0) + 1;
        }
        debugPrint(
            '$_tag fetchFolderQuizSets — parsed ${_folderQuizSets.length} quiz sets, access_type breakdown: $accessGroups');
      } else {
        _folderQuizSetsError = 'Server error: ${response.statusCode}';
        debugPrint(
            '$_tag fetchFolderQuizSets — ERROR ${response.statusCode}: ${response.body}');
      }
    } catch (e, st) {
      _folderQuizSetsError = 'Failed to load quiz sets: $e';
      debugPrint('$_tag fetchFolderQuizSets — EXCEPTION: $e\n$st');
    } finally {
      _isFolderQuizSetsLoading = false;
      notifyListeners();
      debugPrint(
          '$_tag fetchFolderQuizSets — done, folderQuizSets.length=${_folderQuizSets.length}');
    }
  }

  Future<void> fetchFolderQuizSetsNextPage(int folderId) async {
    debugPrint(
        '$_tag fetchFolderQuizSetsNextPage(folderId=$folderId) — hasFolderQuizSetsNextPage=$hasFolderQuizSetsNextPage');

    if (_isFolderQuizSetsLoading ||
        _isFolderQuizSetsLoadingMore ||
        !hasFolderQuizSetsNextPage) {
      debugPrint(
          '$_tag fetchFolderQuizSetsNextPage — SKIPPED (loading=$_isFolderQuizSetsLoading, loadingMore=$_isFolderQuizSetsLoadingMore, hasNext=$hasFolderQuizSetsNextPage)');
      return;
    }

    _isFolderQuizSetsLoadingMore = true;
    notifyListeners();

    final nextPage = _folderQuizSetsCurrentPage + 1;
    final url =
        '${BaseUrl.baseUrl}/public/folder/$folderId/quiz-sets?page=$nextPage&per_page=$_perPage';
    debugPrint('$_tag fetchFolderQuizSetsNextPage — GET $url');

    try {
      final response = await http.get(Uri.parse(url));
      debugPrint(
          '$_tag fetchFolderQuizSetsNextPage — response ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>? ?? {};
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        _parseFolderQuizSetsPagination(pagination);
        final newItems = (data['quiz_sets'] as List? ?? [])
            .map((e) => PublicQuizSet.fromJson(e as Map<String, dynamic>))
            .toList();
        _folderQuizSets.addAll(newItems);
        debugPrint(
            '$_tag fetchFolderQuizSetsNextPage — appended ${newItems.length}, total=${_folderQuizSets.length}');
      }
    } catch (e, st) {
      debugPrint(
          '$_tag fetchFolderQuizSetsNextPage — EXCEPTION: $e\n$st');
    } finally {
      _isFolderQuizSetsLoadingMore = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> refreshAll() async {
    debugPrint('$_tag refreshAll()');
    await Future.wait([fetchFolders(refresh: true)]);
  }

  void clearFolderFiles() {
    debugPrint('$_tag clearFolderFiles()');
    _folderFiles = [];
    _currentFolder = null;
    _folderFilesCurrentPage = 1;
    _folderFilesTotalPages = 1;
    _folderFilesTotalItems = 0;
    _folderFilesError = null;
    notifyListeners();
  }

  void clearFolderQuizSets() {
    debugPrint('$_tag clearFolderQuizSets()');
    _folderQuizSets = [];
    _currentFolder = null;
    _folderQuizSetsCurrentPage = 1;
    _folderQuizSetsTotalPages = 1;
    _folderQuizSetsTotalItems = 0;
    _folderQuizSetsHasNextPage = false;
    _folderQuizSetsError = null;
    notifyListeners();
  }
}