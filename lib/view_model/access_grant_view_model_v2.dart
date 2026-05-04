import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/access_endpoints.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:ema_app/view_model/folders/user_management_view_model.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

// ── Lightweight result models ──────────────────────────────────────────────

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

// ── ViewModel ──────────────────────────────────────────────────────────────

class AccessControlViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();

  // ── Loading states ─────────────────────────────────────────────────────
  bool isLoading = false;       // list fetches
  bool isActionLoading = false; // mutations (grant / revoke / batch-check)

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


  // ══════════════════════════════════════════════════════════════════════════
  // POST /api/access/batch-check
  // body: { "items": [ {"item_id": 1, "item_type": "file"}, … ] }
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
        batchSummary =
        rawSummary != null ? BatchCheckSummary.fromJson(rawSummary) : null;

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
  // action: 'grant' | 'revoke'
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> grantAccess(
      BuildContext context, {
        required int userId,
        required int itemId,
        required String itemType,
        required int accessTimes,
        required String action, // 'grant' | 'revoke'
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
        _logger.i(
            'Access ${action}ed — user $userId, item $itemId ($itemType)');
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

  // ══════════════════════════════════════════════════════════════════════════
  // GET /api/access/permissions
  // Both filters are optional.
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> fetchPermissions(
      BuildContext context, {
        int? userId,
        String? itemType, // 'file' | 'quiz_set'
      }) async {
    try {
      isLoading = true;
      notifyListeners();

      final uri = Uri.parse(AccessEndpoints.permissions).replace(
        queryParameters: {
          if (userId != null) 'user_id': userId.toString(),
          if (itemType != null) 'item_type': itemType,
        },
      );

      final response = await _apiService.getApiResponse(uri.toString());

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};

        final rawList = data['permissions'] as List? ?? [];
        permissions = rawList
            .map((e) =>
            UserPermission.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        totalPermissions = (data['total'] as num?)?.toInt() ?? permissions.length;
        _logger.i('Fetched ${permissions.length} permissions (total $totalPermissions)');
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching permissions: $e'), context);
      _logger.e('fetchPermissions error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POST /api/access/all-users  — grant or revoke public access
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> setPublicAccess(
      BuildContext context, {
        required int itemId,
        required String itemType,
        required bool grant,
      }) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.getPostApiResponse(
        AccessEndpoints.allUsers,
        {
          'item_id': itemId,
          'item_type': itemType,
          'grant': grant,
        },
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i(
            'Public access ${grant ? 'granted' : 'revoked'} — item $itemId ($itemType)');
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchPublicAccessItems(context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error setting public access: $e'), context);
      _logger.e('setPublicAccess error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GET /api/access/all-users  — list items with public access
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> fetchPublicAccessItems(
      BuildContext context, {
        String? itemType,
      }) async {
    try {
      isLoading = true;
      notifyListeners();

      final uri = Uri.parse(AccessEndpoints.allUsers).replace(
        queryParameters: {
          if (itemType != null) 'item_type': itemType,
        },
      );

      final response = await _apiService.getApiResponse(uri.toString());

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};

        final rawList = data['items'] as List? ?? [];
        publicAccessItems = rawList
            .map((e) => AccessItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        totalPublicItems = (data['total'] as num?)?.toInt() ?? publicAccessItems.length;
        _logger.i('Fetched ${publicAccessItems.length} public-access items');
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching public access items: $e'), context);
      _logger.e('fetchPublicAccessItems error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // POST /api/access/login-users  — grant or revoke logged-in access
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> setLoginAccess(
      BuildContext context, {
        required int itemId,
        required String itemType,
        required bool grant,
      }) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.getPostApiResponse(
        AccessEndpoints.loginUsers,
        {
          'item_id': itemId,
          'item_type': itemType,
          'grant': grant,
        },
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i(
            'Login access ${grant ? 'granted' : 'revoked'} — item $itemId ($itemType)');
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchLoginAccessItems(context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error setting login access: $e'), context);
      _logger.e('setLoginAccess error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GET /api/access/login-users  — list items with logged-in access
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> fetchLoginAccessItems(
      BuildContext context, {
        String? itemType,
      }) async {
    try {
      isLoading = true;
      notifyListeners();

      final uri = Uri.parse(AccessEndpoints.loginUsers).replace(
        queryParameters: {
          if (itemType != null) 'item_type': itemType,
        },
      );

      final response = await _apiService.getApiResponse(uri.toString());

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};

        final rawList = data['items'] as List? ?? [];
        loginAccessItems = rawList
            .map((e) => AccessItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        totalLoginItems = (data['total'] as num?)?.toInt() ?? loginAccessItems.length;
        _logger.i('Fetched ${loginAccessItems.length} login-access items');
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching login access items: $e'), context);
      _logger.e('fetchLoginAccessItems error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────
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
}