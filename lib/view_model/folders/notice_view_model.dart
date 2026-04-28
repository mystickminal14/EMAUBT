import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/model/notice_model.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ema_app/constants/base_url.dart';
import 'package:file_picker/file_picker.dart';

class NoticeManagementViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();
  bool isLoading = true;
  bool isActionLoading = false;
  List<NoticeModel> notices = [];
  List<NoticeModel> filteredNotices = [];
  String _searchQuery = '';
  String? title;
  String? textContent;
  List<PlatformFile> selectedFiles = [];

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> fetchNotices(BuildContext context) async {
    try {
      isLoading = true;
      notifyListeners();

      final response =
      await _apiService.getApiResponse('${BaseUrl.baseUrl}notices.php');

      if (response != null) {
        final List<dynamic> data = response as List<dynamic>;
        notices = data.map((json) => NoticeModel.fromJson(json)).toList();
        _filterNotices();
        _logger.i('Fetched ${notices.length} notices');
      } else {
        notices = [];
        _filterNotices();
        Utils.showApiResponse(Utils.errorResponse('Failed to fetch notices'), context);
      }
    } catch (e) {
      notices = [];
      _filterNotices();
      Utils.showApiResponse(Utils.errorResponse('Error fetching notices: $e'), context);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickFiles() async {
    FilePickerResult? result =
    await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      selectedFiles = result.files;
      notifyListeners();
    }
  }

  Future<void> addNotice(BuildContext context) async {
    if (title == null || title!.isEmpty) {
      Utils.showApiResponse(Utils.errorResponse('Title is required'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final fields = {
        'action': 'create',
        'title': title!,
        if (textContent != null && textContent!.isNotEmpty)
          'text_content': textContent!,
      };

      final response = await _apiService.postMultipartNoticeFiles(
        '${BaseUrl.baseUrl}notices.php',
        fields,
        files: selectedFiles.isNotEmpty ? selectedFiles : null,
        fieldName: 'files[]',
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        clearFields();
        await fetchNotices(context);
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error adding notice: $e'), context);
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  Future<void> editNotice(BuildContext context, NoticeModel notice) async {
    if (title == null || title!.isEmpty) {
      Utils.showApiResponse(Utils.errorResponse('Title is required'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final fields = {
        'action': 'update',
        'id': notice.id!,
        'title': title!,
        if (textContent != null && textContent!.isNotEmpty)
          'text_content': textContent!,
      };

      final response = await _apiService.postMultipartNoticeFiles(
        '${BaseUrl.baseUrl}notices.php',
        fields,
        files: selectedFiles.isNotEmpty ? selectedFiles : null,
        fieldName: 'files[]',
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        clearFields();
        await fetchNotices(context);
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error updating notice: $e'), context);
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteNotice(BuildContext context, NoticeModel notice) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.getDeleteApiResponse(
        '${BaseUrl.baseUrl}notices.php?id=${Uri.encodeQueryComponent(notice.id!)}',
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        await fetchNotices(context);
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error deleting notice: $e'), context);
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  void searchNotices(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterNotices();
    notifyListeners();
  }

  void _filterNotices() {
    if (_searchQuery.isEmpty) {
      filteredNotices = List.from(notices);
    } else {
      filteredNotices = notices.where((notice) {
        final title = notice.title?.toLowerCase() ?? '';
        final textContent = notice.textContent?.toLowerCase() ?? '';
        return title.contains(_searchQuery) ||
            textContent.contains(_searchQuery);
      }).toList();
    }
  }

  void setFields(
      {String? title, String? textContent, List<PlatformFile>? files}) {
    this.title = title;
    this.textContent = textContent;
    selectedFiles = files ?? selectedFiles;
    notifyListeners();
  }

  void clearFields() {
    title = null;
    textContent = null;
    selectedFiles = [];
    _searchQuery = '';
    filteredNotices = List.from(notices);
    notifyListeners();
  }
}