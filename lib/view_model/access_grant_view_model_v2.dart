import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/access_endpoints.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

// ── Lightweight result models ──────────────────────────────────────────────

class BulkOperationResult {
  final int operationId;
  final String operationType;
  final String targetType;
  final int totalItems;

  const BulkOperationResult({
    required this.operationId,
    required this.operationType,
    required this.targetType,
    required this.totalItems,
  });

  factory BulkOperationResult.fromJson(Map<String, dynamic> json) =>
      BulkOperationResult(
        operationId: (json['operation_id'] as num).toInt(),
        operationType: json['operation_type'] as String,
        targetType: json['target_type'] as String,
        totalItems: (json['total_items'] as num).toInt(),
      );
}

class AccessCheckResult {
  final int itemId;
  final String itemType;
  final bool hasAccess;
  final String accessType;

  const AccessCheckResult({
    required this.itemId,
    required this.itemType,
    required this.hasAccess,
    required this.accessType,
  });

  factory AccessCheckResult.fromJson(Map<String, dynamic> json) =>
      AccessCheckResult(
        itemId: (json['item_id'] as num).toInt(),
        itemType: json['item_type'] as String,
        hasAccess: json['has_access'] as bool,
        accessType: json['access_type'] as String,
      );
}

class BatchCheckSummary {
  final int total;
  final int accessible;
  final int inaccessible;

  const BatchCheckSummary({
    required this.total,
    required this.accessible,
    required this.inaccessible,
  });

  factory BatchCheckSummary.fromJson(Map<String, dynamic> json) =>
      BatchCheckSummary(
        total: (json['total'] as num).toInt(),
        accessible: (json['accessible'] as num).toInt(),
        inaccessible: (json['inaccessible'] as num).toInt(),
      );
}

class UserPermission {
  final int id;
  final int userId;
  final int itemId;
  final String itemType;
  final int accessTimes;
  final String grantedAt;

  const UserPermission({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.itemType,
    required this.accessTimes,
    required this.grantedAt,
  });

  factory UserPermission.fromJson(Map<String, dynamic> json) => UserPermission(
    id: (json['id'] as num).toInt(),
    userId: (json['user_id'] as num).toInt(),
    itemId: (json['item_id'] as num).toInt(),
    itemType: json['item_type'] as String,
    accessTimes: (json['access_times'] as num).toInt(),
    grantedAt: json['granted_at'] as String,
  );
}

class AccessItem {
  final int id;
  final String itemType;
  final String name;

  const AccessItem({
    required this.id,
    required this.itemType,
    required this.name,
  });

  factory AccessItem.fromJson(Map<String, dynamic> json) => AccessItem(
    id: (json['id'] as num).toInt(),
    itemType: json['item_type'] as String,
    name: json['name'] as String,
  );
}

// ── Folder content models ──────────────────────────────────────────────────

class FolderFileModel {
  final int id;
  final String? name;
  final String? assignType;

  const FolderFileModel({
    required this.id,
    this.name,
    this.assignType,
  });

  factory FolderFileModel.fromJson(Map<String, dynamic> json) =>
      FolderFileModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String?,
        assignType: json['assign_type'] as String?,
      );

  FolderFileModel copyWith({String? assignType}) => FolderFileModel(
    id: id,
    name: name,
    assignType: assignType ?? this.assignType,
  );
}

class FolderQuizSetModel {
  final int id;
  final String? name;
  final String? assignType;

  const FolderQuizSetModel({
    required this.id,
    this.name,
    this.assignType,
  });

  factory FolderQuizSetModel.fromJson(Map<String, dynamic> json) =>
      FolderQuizSetModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String?,
        assignType: json['assign_type'] as String?,
      );

  FolderQuizSetModel copyWith({String? assignType}) => FolderQuizSetModel(
    id: id,
    name: name,
    assignType: assignType ?? this.assignType,
  );
}

// ── User-grant inspection models ───────────────────────────────────────────

/// Pagination metadata returned by every paginated endpoint.
class PaginationMeta {
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  const PaginationMeta({
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) => PaginationMeta(
    page: (json['page'] as num).toInt(),
    perPage: (json['per_page'] as num).toInt(),
    totalItems: (json['total_items'] as num).toInt(),
    totalPages: (json['total_pages'] as num).toInt(),
    hasNextPage: json['has_next_page'] as bool,
    hasPrevPage: json['has_prev_page'] as bool,
  );
}

/// A file entry from the granted / not-granted file endpoints.
class UserGrantedFile {
  final int id;
  final String name;
  final String filePath;
  final String? iconPath;
  final String accessType;
  final String status;
  final String createdAt;
  final String folderName;
  final String? folderIconPath;

  const UserGrantedFile({
    required this.id,
    required this.name,
    required this.filePath,
    this.iconPath,
    required this.accessType,
    required this.status,
    required this.createdAt,
    required this.folderName,
    this.folderIconPath,
  });

  factory UserGrantedFile.fromJson(Map<String, dynamic> json) =>
      UserGrantedFile(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        filePath: json['file_path'] as String,
        iconPath: json['icon_path'] as String?,
        accessType: json['access_type'] as String,
        status: json['status'] as String,
        createdAt: json['created_at'] as String,
        folderName: json['folder_name'] as String,
        folderIconPath: json['folder_icon_path'] as String?,
      );
}

/// A quiz-set entry from the granted / not-granted quiz-set endpoints.
class UserGrantedQuizSet {
  final int id;
  final int folderId;
  final String name;
  final String? description;
  final String? iconPath;
  final String accessType;
  final String status;
  final int questionCount;
  final int totalQuestions;
  final int durationMinutes;
  final int passingScore;
  final bool isPublished;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final String folderName;
  final String? folderIconPath;

  const UserGrantedQuizSet({
    required this.id,
    required this.folderId,
    required this.name,
    this.description,
    this.iconPath,
    required this.accessType,
    required this.status,
    required this.questionCount,
    required this.totalQuestions,
    required this.durationMinutes,
    required this.passingScore,
    required this.isPublished,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.folderName,
    this.folderIconPath,
  });

  factory UserGrantedQuizSet.fromJson(Map<String, dynamic> json) =>
      UserGrantedQuizSet(
        id: (json['id'] as num).toInt(),
        folderId: (json['folder_id'] as num).toInt(),
        name: json['name'] as String,
        description: json['description'] as String?,
        iconPath: json['icon_path'] as String?,
        accessType: json['access_type'] as String,
        status: json['status'] as String,
        questionCount: (json['question_count'] as num).toInt(),
        totalQuestions: (json['total_questions'] as num).toInt(),
        durationMinutes: (json['duration_minutes'] as num).toInt(),
        passingScore: (json['passing_score'] as num).toInt(),
        isPublished: json['is_published'] as bool,
        createdBy: (json['created_by'] as num).toInt(),
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
        folderName: json['folder_name'] as String,
        folderIconPath: json['folder_icon_path'] as String?,
      );
}

// ── ViewModel ──────────────────────────────────────────────────────────────

class AccessControlViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();

  BulkOperationResult? lastBulkOperation;

  // ── Loading states ─────────────────────────────────────────────────────
  bool isLoading = false;
  bool isActionLoading = false;
  bool isFolderContentLoading = false;

  // ── Batch-check ────────────────────────────────────────────────────────
  List<AccessCheckResult> batchResults = [];
  BatchCheckSummary? batchSummary;

  // ── Permissions list ───────────────────────────────────────────────────
  List<UserPermission> permissions = [];
  int totalPermissions = 0;

  // ── Public-access items ────────────────────────────────────────────────
  List<AccessItem> publicAccessItems = [];
  int totalPublicItems = 0;

  // ── Logged-in-access items ─────────────────────────────────────────────
  List<AccessItem> loginAccessItems = [];
  int totalLoginItems = 0;

  // ── Folder content ─────────────────────────────────────────────────────
  List<FolderFileModel> folderFiles = [];
  List<FolderQuizSetModel> folderQuizSets = [];
  int? _currentFolderId;

  // ══════════════════════════════════════════════════════════════════════════
  // USER-GRANT INSPECTION — Granted Files
  // GET /api/admin/users/{userId}/files/granted?page=N&per_page=20
  //
  // Response shape:
  // { "success": true, "data": { "files": [...], "pagination": {...}, "total": N } }
  //
  // Add to AccessEndpoints:
  //   static String userGrantedFiles(int uid) =>
  //       '/api/admin/users/$uid/files/granted';
  // ══════════════════════════════════════════════════════════════════════════
  List<UserGrantedFile> grantedFiles = [];
  PaginationMeta? grantedFilesPagination;
  bool isGrantedFilesLoading = false;
  bool isGrantedFilesLoadingMore = false;
  int _grantedFilesPage = 1;

  Future<void> fetchGrantedFiles(int userId, {bool refresh = false}) async {
    if (refresh) {
      _grantedFilesPage = 1;
      grantedFiles = [];
      grantedFilesPagination = null;
    }

    // Guard: already on last page
    if (!refresh &&
        grantedFilesPagination != null &&
        !grantedFilesPagination!.hasNextPage) return;

    try {
      if (_grantedFilesPage == 1) {
        isGrantedFilesLoading = true;
      } else {
        isGrantedFilesLoadingMore = true;
      }
      notifyListeners();

      final response = await _apiService.getApiResponse(
        '${AccessEndpoints.userGrantedFiles(userId)}?page=$_grantedFilesPage&per_page=20',
      );

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final rawFiles = data['files'] as List? ?? [];
        final newItems = rawFiles
            .map((e) =>
            UserGrantedFile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        grantedFiles = [...grantedFiles, ...newItems];

        final rawPagination = data['pagination'] as Map<String, dynamic>?;
        if (rawPagination != null) {
          grantedFilesPagination = PaginationMeta.fromJson(rawPagination);
          _grantedFilesPage = grantedFilesPagination!.page + 1;
        }

        _logger.i(
          'Granted files page ${_grantedFilesPage - 1} loaded — '
              '${newItems.length} items, total ${grantedFiles.length}',
        );
      } else {
        _logger.w('fetchGrantedFiles: unexpected response — $response');
      }
    } catch (e) {
      _logger.e('fetchGrantedFiles error: $e');
    } finally {
      isGrantedFilesLoading = false;
      isGrantedFilesLoadingMore = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER-GRANT INSPECTION — Not-Granted Files
  // GET /api/admin/users/{userId}/files/not-granted?page=N&per_page=20
  //
  // Add to AccessEndpoints:
  //   static String userNotGrantedFiles(int uid) =>
  //       '/api/admin/users/$uid/files/not-granted';
  // ══════════════════════════════════════════════════════════════════════════
  List<UserGrantedFile> notGrantedFiles = [];
  PaginationMeta? notGrantedFilesPagination;
  bool isNotGrantedFilesLoading = false;
  bool isNotGrantedFilesLoadingMore = false;
  int _notGrantedFilesPage = 1;

  Future<void> fetchNotGrantedFiles(int userId, {bool refresh = false}) async {
    if (refresh) {
      _notGrantedFilesPage = 1;
      notGrantedFiles = [];
      notGrantedFilesPagination = null;
    }

    if (!refresh &&
        notGrantedFilesPagination != null &&
        !notGrantedFilesPagination!.hasNextPage) return;

    try {
      if (_notGrantedFilesPage == 1) {
        isNotGrantedFilesLoading = true;
      } else {
        isNotGrantedFilesLoadingMore = true;
      }
      notifyListeners();

      final response = await _apiService.getApiResponse(
        '${AccessEndpoints.userNotGrantedFiles(userId)}?page=$_notGrantedFilesPage&per_page=20',
      );

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final rawFiles = data['files'] as List? ?? [];
        final newItems = rawFiles
            .map((e) =>
            UserGrantedFile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        notGrantedFiles = [...notGrantedFiles, ...newItems];

        final rawPagination = data['pagination'] as Map<String, dynamic>?;
        if (rawPagination != null) {
          notGrantedFilesPagination = PaginationMeta.fromJson(rawPagination);
          _notGrantedFilesPage = notGrantedFilesPagination!.page + 1;
        }

        _logger.i(
          'Not-granted files page ${_notGrantedFilesPage - 1} loaded — '
              '${newItems.length} items, total ${notGrantedFiles.length}',
        );
      } else {
        _logger.w('fetchNotGrantedFiles: unexpected response — $response');
      }
    } catch (e) {
      _logger.e('fetchNotGrantedFiles error: $e');
    } finally {
      isNotGrantedFilesLoading = false;
      isNotGrantedFilesLoadingMore = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER-GRANT INSPECTION — Granted Quiz Sets
  // GET /api/admin/users/{userId}/quiz-sets/granted?page=N&per_page=20
  //
  // Add to AccessEndpoints:
  //   static String userGrantedQuizSets(int uid) =>
  //       '/api/admin/users/$uid/quiz-sets/granted';
  // ══════════════════════════════════════════════════════════════════════════
  List<UserGrantedQuizSet> grantedQuizSets = [];
  PaginationMeta? grantedQuizSetsPagination;
  bool isGrantedQuizSetsLoading = false;
  bool isGrantedQuizSetsLoadingMore = false;
  int _grantedQuizSetsPage = 1;

  Future<void> fetchGrantedQuizSets(int userId, {bool refresh = false}) async {
    if (refresh) {
      _grantedQuizSetsPage = 1;
      grantedQuizSets = [];
      grantedQuizSetsPagination = null;
    }

    if (!refresh &&
        grantedQuizSetsPagination != null &&
        !grantedQuizSetsPagination!.hasNextPage) return;

    try {
      if (_grantedQuizSetsPage == 1) {
        isGrantedQuizSetsLoading = true;
      } else {
        isGrantedQuizSetsLoadingMore = true;
      }
      notifyListeners();

      final response = await _apiService.getApiResponse(
        '${AccessEndpoints.userGrantedQuizSets(userId)}?page=$_grantedQuizSetsPage&per_page=20',
      );

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final rawSets = data['quiz_sets'] as List? ?? [];
        final newItems = rawSets
            .map((e) =>
            UserGrantedQuizSet.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        grantedQuizSets = [...grantedQuizSets, ...newItems];

        final rawPagination = data['pagination'] as Map<String, dynamic>?;
        if (rawPagination != null) {
          grantedQuizSetsPagination = PaginationMeta.fromJson(rawPagination);
          _grantedQuizSetsPage = grantedQuizSetsPagination!.page + 1;
        }

        _logger.i(
          'Granted quiz sets page ${_grantedQuizSetsPage - 1} loaded — '
              '${newItems.length} items, total ${grantedQuizSets.length}',
        );
      } else {
        _logger.w('fetchGrantedQuizSets: unexpected response — $response');
      }
    } catch (e) {
      _logger.e('fetchGrantedQuizSets error: $e');
    } finally {
      isGrantedQuizSetsLoading = false;
      isGrantedQuizSetsLoadingMore = false;
      notifyListeners();
    }
  }

  List<UserGrantedQuizSet> notGrantedQuizSets = [];
  PaginationMeta? notGrantedQuizSetsPagination;
  bool isNotGrantedQuizSetsLoading = false;
  bool isNotGrantedQuizSetsLoadingMore = false;
  int _notGrantedQuizSetsPage = 1;

  Future<void> fetchNotGrantedQuizSets(int userId,
      {bool refresh = false}) async {
    if (refresh) {
      _notGrantedQuizSetsPage = 1;
      notGrantedQuizSets = [];
      notGrantedQuizSetsPagination = null;
    }

    if (!refresh &&
        notGrantedQuizSetsPagination != null &&
        !notGrantedQuizSetsPagination!.hasNextPage) return;

    try {
      if (_notGrantedQuizSetsPage == 1) {
        isNotGrantedQuizSetsLoading = true;
      } else {
        isNotGrantedQuizSetsLoadingMore = true;
      }
      notifyListeners();

      final response = await _apiService.getApiResponse(
        '${AccessEndpoints.userNotGrantedQuizSets(userId)}?page=$_notGrantedQuizSetsPage&per_page=20',
      );

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final rawSets = data['quiz_sets'] as List? ?? [];
        final newItems = rawSets
            .map((e) =>
            UserGrantedQuizSet.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        notGrantedQuizSets = [...notGrantedQuizSets, ...newItems];

        final rawPagination = data['pagination'] as Map<String, dynamic>?;
        if (rawPagination != null) {
          notGrantedQuizSetsPagination = PaginationMeta.fromJson(rawPagination);
          _notGrantedQuizSetsPage = notGrantedQuizSetsPagination!.page + 1;
        }

        _logger.i(
          'Not-granted quiz sets page ${_notGrantedQuizSetsPage - 1} loaded — '
              '${newItems.length} items, total ${notGrantedQuizSets.length}',
        );
      } else {
        _logger.w('fetchNotGrantedQuizSets: unexpected response — $response');
      }
    } catch (e) {
      _logger.e('fetchNotGrantedQuizSets error: $e');
    } finally {
      isNotGrantedQuizSetsLoading = false;
      isNotGrantedQuizSetsLoadingMore = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Convenience: load all 4 grant-inspection lists for a user at once.
  // Call this when first opening the user-detail / access-inspection screen.
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> fetchAllUserGrantData(int userId, {bool refresh = false}) async {
    await Future.wait([
      fetchGrantedFiles(userId, refresh: refresh),
      fetchNotGrantedFiles(userId, refresh: refresh),
      fetchGrantedQuizSets(userId, refresh: refresh),
      fetchNotGrantedQuizSets(userId, refresh: refresh),
    ]);
  }


  // ══════════════════════════════════════════════════════════════════════════
  // PATCH /api/admin/files/{fileId}/assign-type
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> updateFileAssignType(
      BuildContext context,
      int fileId,
      String type,
      ) async {
    final prevList = List<FolderFileModel>.from(folderFiles);
    folderFiles = folderFiles
        .map((f) => f.id == fileId ? f.copyWith(assignType: type) : f)
        .toList();
    notifyListeners();

    try {
      final response = await _apiService.getPostApiResponse(
        AccessEndpoints.fileAssignType(fileId),
        {'access_type': type},
      );

      if (response['success'] == true) {
        _logger.i('File $fileId assign_type → $type');
      } else {
        folderFiles = prevList;
        notifyListeners();
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      folderFiles = prevList;
      notifyListeners();
      Utils.showApiResponse(
          Utils.errorResponse('Failed to update file access type: $e'),
          context);
      _logger.e('updateFileAssignType error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATCH /api/admin/quiz-sets/{quizSetId}/assign-type
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> updateQuizSetAssignType(
      BuildContext context,
      int quizSetId,
      String type,
      ) async {
    final prevList = List<FolderQuizSetModel>.from(folderQuizSets);
    folderQuizSets = folderQuizSets
        .map((q) => q.id == quizSetId ? q.copyWith(assignType: type) : q)
        .toList();
    notifyListeners();

    try {
      final response = await _apiService.getPostApiResponse(
        AccessEndpoints.quizSetAssignType(quizSetId),
        {'access_type': type},
      );

      if (response['success'] == true) {
        _logger.i('Quiz set $quizSetId assign_type → $type');
      } else {
        folderQuizSets = prevList;
        notifyListeners();
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      folderQuizSets = prevList;
      notifyListeners();
      Utils.showApiResponse(
          Utils.errorResponse('Failed to update quiz set access type: $e'),
          context);
      _logger.e('updateQuizSetAssignType error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POST /api/admin/bulk-operations
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> createBulkOperation(
      BuildContext context, {
        required String operationType,
        required String targetType,
        required List<int> targetIds,
        int? userId,
        int? accessTimes,
      }) async {
    if (targetIds.isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Target IDs list cannot be empty'), context);
      return;
    }

    const accessOps = {'bulk_grant_access', 'bulk_revoke_access'};
    if (accessOps.contains(operationType) && userId == null) {
      Utils.showApiResponse(
          Utils.errorResponse('user_id is required for access operations'),
          context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final body = <String, dynamic>{
        'operation_type': operationType,
        'target_type': targetType,
        'target_ids': targetIds,
        if (accessOps.contains(operationType)) ...{
          'user_id': userId,
          if (accessTimes != null) 'access_times': accessTimes,
        },
      };

      final response = await _apiService.getPostApiResponse(
        AccessEndpoints.bulkOperations,
        body,
      );

      Utils.showApiResponse(response, context);

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        lastBulkOperation = BulkOperationResult.fromJson(data);
        _logger.i(
          'Bulk op created — id ${lastBulkOperation?.operationId}, '
              '$operationType on ${targetIds.length} $targetType',
        );
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error creating bulk operation: $e'), context);
      _logger.e('createBulkOperation error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POST /api/access/batch-check
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> batchCheck(
      BuildContext context, {
        required List<Map<String, dynamic>> items,
      }) async {
    if (items.isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Items list cannot be empty'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.getPostApiResponse(
        AccessEndpoints.batchCheck,
        {'items': items},
      );

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};

        final rawResults = data['results'] as List? ?? [];
        batchResults = rawResults
            .map((e) =>
            AccessCheckResult.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        final rawSummary = data['summary'] as Map<String, dynamic>?;
        batchSummary = rawSummary != null
            ? BatchCheckSummary.fromJson(rawSummary)
            : null;

        _logger.i(
            'Batch check done — ${batchSummary?.accessible}/${batchSummary?.total} accessible');
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error during batch check: $e'), context);
      _logger.e('batchCheck error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POST /api/access/grant
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> grantAccess(
      BuildContext context, {
        required int userId,
        required int itemId,
        required String itemType,
        required int accessTimes,
        required String action,
      }) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.getPostApiResponse(
        AccessEndpoints.grant,
        {
          'user_id': userId,
          'item_id': itemId,
          'item_type': itemType,
          'access_times': accessTimes,
          'action': action,
        },
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger
            .i('Access ${action}ed — user $userId, item $itemId ($itemType)');
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error granting access: $e'), context);
      _logger.e('grantAccess error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Clear helpers ──────────────────────────────────────────────────────

  void clearFolderContent() {
    folderFiles = [];
    folderQuizSets = [];
    _currentFolderId = null;
    notifyListeners();
  }

  void clearBatchResults() {
    batchResults = [];
    batchSummary = null;
    notifyListeners();
  }

  void clearPermissions() {
    permissions = [];
    totalPermissions = 0;
    notifyListeners();
  }

  void clearBulkOperation() {
    lastBulkOperation = null;
    notifyListeners();
  }

  /// Resets all four paginated grant-inspection lists.
  /// Call this when navigating away from the user-detail screen.
  void clearUserGrantData() {
    grantedFiles = [];
    grantedFilesPagination = null;
    _grantedFilesPage = 1;

    notGrantedFiles = [];
    notGrantedFilesPagination = null;
    _notGrantedFilesPage = 1;

    grantedQuizSets = [];
    grantedQuizSetsPagination = null;
    _grantedQuizSetsPage = 1;

    notGrantedQuizSets = [];
    notGrantedQuizSetsPagination = null;
    _notGrantedQuizSetsPage = 1;

    notifyListeners();
  }
}