import 'dart:io';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ema_app/model/notice_model.dart';
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
      final noticeData = NoticeModel.fromJson(response);
      if (noticeData != null) {
        notices = noticeData as List<NoticeModel>;
        _filterNotices();
        _logger.i('Fetched ${notices.length} notices');
      } else {
        notices = [];
        _filterNotices();
        _showErrorMessage(context,
            'Failed to fetch notices: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      notices = [];
      _filterNotices();
      _showErrorMessage(context, 'Error fetching notices: $e');
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
      _showErrorMessage(context, 'Title is required');
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();
      final fields = {
        'title': title!,
        if (textContent != null && textContent!.isNotEmpty)
          'text_content': textContent!,
      };
      final response = await _apiService.postMultipartResponse(
        '${BaseUrl.baseUrl}notices.php',
        fields,
        files: selectedFiles.isNotEmpty ? selectedFiles : null,
        fieldName: 'files[]',
      );
      if (response['success'] == true) {
        _showSuccessMessage(context, 'Notice added successfully');
        clearFields();
        await fetchNotices(context);
      } else {
        _showErrorMessage(context,
            'Failed to add notice: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorMessage(context, 'Error adding notice: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  Future<void> editNotice(BuildContext context, NoticeModel notice) async {
    if (title == null || title!.isEmpty) {
      _showErrorMessage(context, 'Title is required');
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();
      final fields = {
        '_method': 'PUT',
        'id': notice.id!,
        'title': title!,
        if (textContent != null && textContent!.isNotEmpty)
          'text_content': textContent!,
      };
      final response = await _apiService.postFileMultipart(
        '${BaseUrl.baseUrl}notices.php',
        fields,
        files: selectedFiles.isNotEmpty ? selectedFiles : null,
        fieldName: 'files[]',
      );
      if (response['success'] == true) {
        _showSuccessMessage(context, 'Notice updated successfully');
        clearFields();
        await fetchNotices(context);
      } else {
        _showErrorMessage(context,
            'Failed to update notice: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorMessage(context, 'Error updating notice: $e');
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
          '${BaseUrl.baseUrl}notices.php?id=${Uri.encodeQueryComponent(notice.id!)}');
      if (response['success'] == true) {
        _showSuccessMessage(context, 'Notice deleted successfully');
        await fetchNotices(context);
      } else {
        _showErrorMessage(context,
            'Failed to delete notice: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorMessage(context, 'Error deleting notice: $e');
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