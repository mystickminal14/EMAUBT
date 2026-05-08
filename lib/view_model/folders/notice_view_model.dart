import 'dart:async';

import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/notice_endpoitn.dart';
import 'package:ema_app/model/notice_model.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared read-only view model used by the USER notice screen
// ─────────────────────────────────────────────────────────────────────────────
class NoticeViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _api = NetworkApiService();

  bool isLoading = false;
  bool isFetchingMore = false;

  List<NoticeModel> notices = [];
  List<NoticeModel> filteredNotices = [];
  String _searchQuery = '';

  int currentPage  = 1;
  int totalPages   = 1;
  int totalNotices = 0;
  static const int perPage = 10;

  bool get hasMorePages => currentPage < totalPages;

  Timer? _debounceTimer;
  BuildContext? _lastContext;

  // ── URL builder ────────────────────────────────────────────────────────────
  String _buildUrl(int page) {
    final uri = Uri.parse(NoticeEndpoints.noticeList).replace(
      queryParameters: {
        'page':       page.toString(),
        'per_page':   perPage.toString(),
        'sort_by':    'created_at',
        'sort_order': 'DESC',
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
      },
    );
    return uri.toString();
  }

  // ── Response parsers ───────────────────────────────────────────────────────
  List<NoticeModel> _parseNotices(Map<String, dynamic> response) {
    try {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final rawList = data['notices'] ?? data['data'];
        if (rawList is List) {
          return rawList
              .map((e) => NoticeModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ))
              .toList();
        }
      }
      if (data is List) {
        return data
            .map((e) => NoticeModel.fromJson(
          Map<String, dynamic>.from(e as Map),
        ))
            .toList();
      }
    } catch (e) {
      _logger.e('Error parsing notices: $e');
    }
    return [];
  }

  void _parsePagination(Map<String, dynamic> response) {
    try {
      final data       = response['data'] as Map<String, dynamic>? ?? {};
      final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

      // Support both Laravel-style (total/last_page) and custom (total_count/total_pages)
      totalNotices = (pagination['total_count'] as num?)?.toInt()
          ?? (pagination['total']      as num?)?.toInt()
          ?? totalNotices;
      currentPage  = (pagination['current_page'] as num?)?.toInt()
          ?? currentPage;
      totalPages   = (pagination['total_pages']  as num?)?.toInt()
          ?? (pagination['last_page']  as num?)?.toInt()
          ?? totalPages;

      _logger.i(
        '📄 Pagination → page $currentPage / $totalPages | total: $totalNotices',
      );
    } catch (e) {
      _logger.e('Pagination parse error: $e');
    }
  }

  // ── Fetch (first page / refresh) ───────────────────────────────────────────
  Future<void> fetchNotices(
      BuildContext context, {
        bool refresh = false,
      }) async {
    _lastContext = context;

    if (refresh) {
      currentPage  = 1;
      totalPages   = 1;
      totalNotices = 0;
      notices.clear();
      filteredNotices.clear();
    }

    isLoading = true;
    notifyListeners();

    final url = _buildUrl(currentPage);
    _logger.i('🔍 fetchNotices → refresh=$refresh | url=$url');

    try {
      final response = await _api.getApiResponse(url);
      _logger.i('✅ fetchNotices response: $response');

      if (response['success'] == true) {
        _parsePagination(response);
        notices = _parseNotices(response);
        _logger.i('📋 Loaded ${notices.length} notices');
        _applyFilter();
      } else {
        _logger.w('⚠️ fetchNotices non-success: $response');
        if (refresh) {
          notices = [];
          _applyFilter();
        }
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      _logger.e('❌ fetchNotices error: $e');
      if (refresh) {
        notices = [];
        _applyFilter();
      }
      Utils.showApiResponse(
        Utils.errorResponse('Error fetching notices: $e'),
        context,
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Fetch next page (pagination) ───────────────────────────────────────────
  Future<void> fetchNextPage(BuildContext context) async {
    if (isFetchingMore || isLoading || !hasMorePages) return;

    isFetchingMore = true;
    notifyListeners();

    final nextPage = currentPage + 1;
    final url      = _buildUrl(nextPage);
    _logger.i('➡️ fetchNextPage → page $nextPage | url=$url');

    try {
      final response = await _api.getApiResponse(url);
      _logger.i('✅ fetchNextPage response: $response');

      if (response['success'] == true) {
        _parsePagination(response);
        final fetched = _parseNotices(response);
        notices.addAll(fetched);
        _logger.i(
          '📋 Appended ${fetched.length} | total list: ${notices.length}',
        );
        _applyFilter();
      } else {
        _logger.w('⚠️ fetchNextPage non-success: $response');
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      _logger.e('❌ fetchNextPage error: $e');
      Utils.showApiResponse(
        Utils.errorResponse('Error loading more: $e'),
        context,
      );
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────
  void searchNotices(String query) {
    _searchQuery = query.trim().toLowerCase();
    _logger.d('🔎 searchNotices → query="$_searchQuery"');
    _applyFilter();
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final ctx = _lastContext;
      if (ctx == null) return;
      try {
        if (ctx is Element && !ctx.mounted) return;
      } catch (_) {
        return;
      }
      _logger.i('⏱️ Debounce fired → fetching with search="$_searchQuery"');
      fetchNotices(ctx, refresh: true);
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      filteredNotices = List.from(notices);
    } else {
      filteredNotices = notices.where((n) {
        final t = n.title?.toLowerCase()   ?? '';
        final c = n.content?.toLowerCase() ?? '';
        return t.contains(_searchQuery) || c.contains(_searchQuery);
      }).toList();
    }
    _logger.d('🗂️ filteredNotices count: ${filteredNotices.length}');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin view model — extends base with create / update / delete
// ─────────────────────────────────────────────────────────────────────────────
class AdminNoticeViewModel extends NoticeViewModel {
  bool isActionLoading = false;

  String? formTitle;
  String? formContent;
  List<PlatformFile> selectedFiles = [];

  // Existing attachments shown during edit mode
  List<NoticeAttachment> existingAttachments = [];

  // IDs of attachments the user removed during edit
  final Set<String> _removedAttachmentIds = {};

  // ── Form helpers ───────────────────────────────────────────────────────────

  /// Call this when opening the form in EDIT mode.
  void setFormFromNotice(NoticeModel notice) {
    formTitle              = notice.title   ?? '';
    formContent            = notice.content ?? '';
    selectedFiles          = [];
    existingAttachments    = List.from(notice.attachments ?? []);
    _removedAttachmentIds.clear();
    _logger.i(
      '📝 setFormFromNotice → id=${notice.id} | title="${notice.title}" '
          '| existingAttachments=${existingAttachments.length}',
    );
    notifyListeners();
  }

  /// Call this when opening the form in CREATE mode.
  void clearForm() {
    formTitle           = null;
    formContent         = null;
    selectedFiles       = [];
    existingAttachments = [];
    _removedAttachmentIds.clear();
    _logger.i('🧹 clearForm → form reset');
    notifyListeners();
  }

  /// Remove an existing server attachment; marks it for deletion on submit.
  void removeExistingAttachment(NoticeAttachment attachment) {
    existingAttachments.removeWhere((a) => a.id == attachment.id);
    if (attachment.id != null) {
      _removedAttachmentIds.add(attachment.id!);
      _logger.i(
        '🗑️ removeExistingAttachment → id=${attachment.id} '
            '| removed set size: ${_removedAttachmentIds.length}',
      );
    }
    notifyListeners();
  }

  // ── File picker ────────────────────────────────────────────────────────────
  Future<void> pickFiles() async {
    _logger.i('📂 pickFiles → opening file picker');
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result == null) {
        _logger.i('📂 pickFiles → cancelled (no file selected)');
        return;
      }
      selectedFiles.addAll(result.files);
      _logger.i(
        '📂 pickFiles → picked ${result.files.length} file(s) '
            '| total now: ${selectedFiles.length}',
      );
      for (final f in result.files) {
        _logger.d('   • ${f.name} | ${f.size}B | ext=${f.extension}');
      }
      notifyListeners();
    } catch (e) {
      _logger.e('❌ pickFiles error: $e');
    }
  }

  void removeFile(int index) {
    if (index >= 0 && index < selectedFiles.length) {
      _logger.i(
        '🗑️ removeFile → removing index $index: ${selectedFiles[index].name}',
      );
      selectedFiles.removeAt(index);
      _logger.i('📎 Remaining files: ${selectedFiles.length}');
      notifyListeners();
    }
  }

  // ── Create ─────────────────────────────────────────────────────────────────
  Future<bool> createNotice(BuildContext context) async {
    if (!_validateForm(context)) return false;

    isActionLoading = true;
    notifyListeners();

    final fields = <String, dynamic>{
      'title':   formTitle!.trim(),
      'content': formContent!.trim(),
    };

    _logger.i('📤 createNotice → URL: ${NoticeEndpoints.createNotice}');
    _logger.i('📦 Fields: $fields');
    _logger.i('📎 Attachments count: ${selectedFiles.length}');
    for (int i = 0; i < selectedFiles.length; i++) {
      final f = selectedFiles[i];
      _logger.d('   [$i] name=${f.name} | size=${f.size}B | ext=${f.extension}');
    }

    try {
      final response = await _api.postMultipartNoticeFiles(
        NoticeEndpoints.createNotice,
        fields,
        files:     selectedFiles.isEmpty ? null : selectedFiles,
        fieldName: 'attachment[]',
      );

      _logger.i('✅ createNotice response: $response');
      Utils.showApiResponse(response, context);

      if (response['success'] == true) {
        clearForm();
        await fetchNotices(context, refresh: true);
        return true;
      } else {
        _logger.w('⚠️ createNotice non-success: $response');
      }
    } catch (e) {
      _logger.e('❌ createNotice error: $e');
      Utils.showApiResponse(
        Utils.errorResponse('Error creating notice: $e'),
        context,
      );
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
    return false;
  }

  // ── Update ─────────────────────────────────────────────────────────────────
  Future<bool> updateNotice(BuildContext context, NoticeModel notice) async {
    if (!_validateForm(context)) return false;

    isActionLoading = true;
    notifyListeners();

    final url = NoticeEndpoints.updateNotice(notice.id!);

    // Build fields — include removed attachment IDs so backend deletes them
    final fields = <String, dynamic>{
      'title':   formTitle!.trim(),
      'content': formContent!.trim(),
      // Send each removed ID as a separate field key expected by most Laravel APIs.
      // If your backend uses a JSON array instead, replace with:
      // 'remove_attachment_ids': _removedAttachmentIds.join(',')
      if (_removedAttachmentIds.isNotEmpty)
        'remove_attachment_ids[]': _removedAttachmentIds.toList().join(','),
    };

    _logger.i('📤 updateNotice → URL: $url');
    _logger.i('📦 Fields: $fields');
    _logger.i('📎 New attachments count: ${selectedFiles.length}');
    _logger.i(
      '🗑️ Attachments to remove: ${_removedAttachmentIds.toList()}',
    );
    for (int i = 0; i < selectedFiles.length; i++) {
      final f = selectedFiles[i];
      _logger.d('   [$i] name=${f.name} | size=${f.size}B | ext=${f.extension}');
    }

    try {
      final response = await _api.postMultipartNoticeFiles(
        url,
        fields,
        files:     selectedFiles.isEmpty ? null : selectedFiles,
        fieldName: 'attachments[]',
      );

      _logger.i('✅ updateNotice response: $response');
      Utils.showApiResponse(response, context);

      if (response['success'] == true) {
        clearForm();
        await fetchNotices(context, refresh: true);
        return true;
      } else {
        _logger.w('⚠️ updateNotice non-success: $response');
      }
    } catch (e) {
      _logger.e('❌ updateNotice error: $e');
      Utils.showApiResponse(
        Utils.errorResponse('Error updating notice: $e'),
        context,
      );
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
    return false;
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> deleteNotice(BuildContext context, NoticeModel notice) async {
    isActionLoading = true;
    notifyListeners();

    final url = NoticeEndpoints.deleteNotice(notice.id!);
    _logger.i(
      '🗑️ deleteNotice → URL: $url | id=${notice.id} | title="${notice.title}"',
    );

    try {
      final response = await _api.getDeleteApiResponse(url);
      _logger.i('✅ deleteNotice response: $response');
      Utils.showApiResponse(response, context);

      if (response['success'] == true) {
        _logger.i('✅ Notice ${notice.id} deleted successfully');
        await fetchNotices(context, refresh: true);
      } else {
        _logger.w('⚠️ deleteNotice non-success: $response');
      }
    } catch (e) {
      _logger.e('❌ deleteNotice error: $e');
      Utils.showApiResponse(
        Utils.errorResponse('Error deleting notice: $e'),
        context,
      );
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validateForm(BuildContext context) {
    _logger.d(
      '🔎 validateForm → title="$formTitle" '
          '| content length=${formContent?.length ?? 0}',
    );
    if (formTitle == null || formTitle!.trim().isEmpty) {
      _logger.w('⚠️ Validation failed: title is empty');
      Utils.showApiResponse(
        Utils.errorResponse('Title is required'),
        context,
      );
      return false;
    }
    if (formContent == null || formContent!.trim().isEmpty) {
      _logger.w('⚠️ Validation failed: content is empty');
      Utils.showApiResponse(
        Utils.errorResponse('Content is required'),
        context,
      );
      return false;
    }
    _logger.i('✅ Validation passed');
    return true;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}