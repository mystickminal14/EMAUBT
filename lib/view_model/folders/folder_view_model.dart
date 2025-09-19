import 'dart:async';
import 'dart:io';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/model/folder_model.dart';
import 'package:ema_app/utils/utils.dart';

class FolderViewModel extends ChangeNotifier {
  final NetworkApiService _apiService = NetworkApiService();
  final Logger _logger = Logger();

  List<FolderModel> folders = [];
  bool isLoading = false;

  void _showSuccessMessage(BuildContext context, String message) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.green,
      icon: const Icon(Icons.check_circle, color: Colors.white),
    ).show(context);
  }

  /// Fetch all folders from backend
  Future<void> fetchFolders() async {
    isLoading = true;
    notifyListeners();
    folders.clear();
    try {
      final response = await _apiService
          .getApiResponse("${BaseUrl.baseUrl}folders.php")
          .timeout(const Duration(seconds: 15));

      if (response is List) {
        folders = response.map((json) => FolderModel.fromJson(json)).toList();
      } else if (response is Map && response['data'] != null) {
        folders = (response['data'] as List)
            .map((json) => FolderModel.fromJson(json))
            .toList();
      }
      _logger.i('Fetched ${folders.length} folders');
    } on TimeoutException {
      Utils.noInternet("Request timed out. Please try again later.");
    } catch (e, stack) {
      _logger.e('⛔ Error fetching folders', error: e, stackTrace: stack);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Add folder with optimistic UI update
  Future<void> addFolder(BuildContext context, String name, File? iconFile) async {
    try {
      final tempFolder = FolderModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        iconUrl: iconFile?.path,
      );
      folders.add(tempFolder);
      notifyListeners();

      Map<String, dynamic> fields = {'action': 'add', 'name': name};
      final response = await _apiService
          .postMultipartResponse("${BaseUrl.baseUrl}folders.php", fields, iconFile)
          .timeout(const Duration(seconds: 15));

      if (response['success'] != null) {
        _showSuccessMessage(context, response['success']);
        await fetchFolders();
      } else if (response['error'] != null) {
        Utils.noInternet(response['error']);
        folders.remove(tempFolder); // rollback UI
        notifyListeners();
      }
    } on TimeoutException {
      Utils.noInternet("Request timed out. Please try again later.");
      folders.removeWhere((f) => f.name == name); // rollback UI
      notifyListeners();
    } catch (e) {
      _logger.e('⛔ Error adding folder', error: e);
      Utils.noInternet('Something went wrong. Please try again.');
    }
  }

  Future<void> editFolder(BuildContext context, String id, String name, File? iconFile) async {
    try {
      final index = folders.indexWhere((f) => f.id == id);
      if (index != -1) {
        final oldFolder = folders[index];
        folders[index] = FolderModel(
          id: id,
          name: name,
          iconUrl: iconFile?.path ?? oldFolder.iconUrl,
        );
        notifyListeners();
      }

      Map<String, dynamic> fields = {'action': 'edit', 'id': id, 'name': name};
      final response = await _apiService
          .postMultipartResponse("${BaseUrl.baseUrl}folders.php", fields, iconFile)
          .timeout(const Duration(seconds: 15));

      if (response['success'] != null) {
        _showSuccessMessage(context, response['success']);
        await fetchFolders();
      } else if (response['error'] != null) {
        Utils.noInternet(response['error']);
      }
    } on TimeoutException {
      Utils.noInternet("Request timed out. Please try again later.");
    } catch (e) {
      _logger.e('⛔ Error editing folder', error: e);
      Utils.noInternet('Something went wrong. Please try again.');
    }
  }

  Future<void> deleteFolder(BuildContext context, String id) async {
    try {
      final index = folders.indexWhere((f) => f.id == id);
      FolderModel? removedFolder;
      if (index != -1) {
        removedFolder = folders.removeAt(index);
        notifyListeners();
      }

      Map<String, String> fields = {'action': 'delete', 'id': id};
      final response = await _apiService
          .postFormData("${BaseUrl.baseUrl}folders.php", fields)
          .timeout(const Duration(seconds: 15));

      if (response['success'] != null) {
        _showSuccessMessage(context, response['success']);
        await fetchFolders();
      } else if (response['error'] != null) {
        Utils.noInternet(response['error']);
        if (removedFolder != null) folders.insert(index, removedFolder); // rollback
        notifyListeners();
      }
    } on TimeoutException {
      Utils.noInternet("Request timed out. Please try again later.");
      // rollback deletion if needed
      if (!folders.any((f) => f.id == id)) {
        folders.insert(0, FolderModel(id: id, name: "Unknown", iconUrl: null));
        notifyListeners();
      }
    } catch (e) {
      _logger.e('⛔ Error deleting folder', error: e);
      Utils.noInternet('Something went wrong. Please try again.');
    }
  }
}
