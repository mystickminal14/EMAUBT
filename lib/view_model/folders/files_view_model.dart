import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ema_app/model/files_model.dart';
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:logger/logger.dart';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/utils/utils.dart';

class FilesViewModel extends ChangeNotifier {
  final NetworkApiService _apiService = NetworkApiService();
  final Logger _logger = Logger();

  List<FileData> files = []; // Updated to use FileData consistently
  bool isLoading = false;

  void _showSuccessMessage(BuildContext context, String message) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.green,
      icon: const Icon(Icons.check_circle, color: Colors.white),
    ).show(context);
  }

  /// Fetch files for a folder
  Future<void> fetchFiles(String folderId) async {
    isLoading = true;
    notifyListeners();
    try {
      final url =
          "${BaseUrl.baseUrl}folder_details_page.php?action=get_files&folder_id=$folderId";
      final response = await _apiService
          .getApiResponse(url)
          .timeout(const Duration(seconds: 15));

      if (response is Map<String, dynamic> && response['status'] == 'success' && response['data'] != null) {
        final filesModel = FilesModel.fromJson(response);
        files = filesModel.data;
      } else {
        files = [];
      }

      _logger.i("Fetched ${files.length} files for folder $folderId");
    } on TimeoutException {
      Utils.noInternet("Request timed out. Please try again later.");
    } catch (e, stackTrace) {
      _logger.e('Error fetching files', error: e, stackTrace: stackTrace);
      Utils.noInternet('Something went wrong.');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Add file with optimistic UI
  Future<void> addFile(
      BuildContext context,
      String folderId,
      String name, {
        String? filePath,
        Uint8List? fileBytes,
        String? fileNameForMime,
        File? iconFile,
        Uint8List? iconBytes,
        String? iconName,
      }) async {
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempFile = FileData(
      id: tempId,
      folderId: folderId,
      name: name,
      filePath: filePath ?? 'temp',
      iconPath: iconFile?.path ?? (iconBytes != null ? 'temp_icon' : null),
    );

    files.add(tempFile);
    notifyListeners();

    try {
      Map<String, dynamic> fields = {
        'action': 'add_file',
        'folder_id': folderId,
        'name': name,
      };

      final response = await _apiService
          .postFileMultipart(
        "${BaseUrl.baseUrl}folder_details_page.php",
        fields,
        mainFilePath: filePath,
        mainFileBytes: fileBytes,
        mainFileName: fileNameForMime,
        iconFile: iconFile,
        iconBytes: iconBytes,
        iconName: iconName,
      )
          .timeout(const Duration(seconds: 15));

      if (response['status'] == 'success') {
        _showSuccessMessage(context, response['message'] ?? 'File added successfully');
        await fetchFiles(folderId); // Refresh to get real IDs and data
      } else {
        throw Exception(response['message'] ?? 'Failed to add file');
      }
    } catch (e, stackTrace) {
      // Rollback optimistic update
      files.removeWhere((f) => f.id == tempId);
      notifyListeners();
      _logger.e('Error adding file', error: e, stackTrace: stackTrace);
      Utils.noInternet(e.toString().replaceFirst('Exception: ', '')); // Clean error message
    }
  }

  /// Edit file
  Future<void> editFile(
      BuildContext context,
      String folderId,
      dynamic id,
      String name, {
        File? iconFile,
        Uint8List? iconBytes,
        String? iconName,
      }) async {
    final index = files.indexWhere((f) => f.id == id);
    FileData? oldFile;
    if (index != -1) {
      oldFile = files[index];
      files[index] = FileData(
        id: id,
        folderId: folderId,
        name: name,
        filePath: oldFile.filePath,
        iconPath: iconFile?.path ?? (iconBytes != null ? 'temp_icon' : oldFile.iconPath),
      );
      notifyListeners();
    }

    try {
      Map<String, dynamic> fields = {
        'action': 'edit_file',
        'id': id.toString(),
        'name': name,
      };

      final response = await _apiService
          .postFileMultipart(
        "${BaseUrl.baseUrl}folder_details_page.php",
        fields,
        iconFile: iconFile,
        iconBytes: iconBytes,
        iconName: iconName,
      )
          .timeout(const Duration(seconds: 15));

      if (response['status'] == 'success') {
        _showSuccessMessage(context, response['message'] ?? 'File updated successfully');
        await fetchFiles(folderId); // Refresh to sync changes
      } else {
        throw Exception(response['message'] ?? 'Failed to edit file');
      }
    } catch (e, stackTrace) {
      // Rollback optimistic update
      if (oldFile != null && index != -1) {
        files[index] = oldFile;
        notifyListeners();
      }
      _logger.e('Error editing file', error: e, stackTrace: stackTrace);
      Utils.noInternet(e.toString().replaceFirst('Exception: ', '')); // Clean error message
    }
  }

  /// Delete file
  Future<void> deleteFile(
      BuildContext context,
      String folderId,
      dynamic id,
      ) async {
    final index = files.indexWhere((f) => f.id == id);
    FileData? removedFile;
    if (index != -1) {
      removedFile = files.removeAt(index);
      notifyListeners();
    }

    try {
      Map<String, String> fields = {
        'action': 'delete_file',
        'id': id.toString(),
      };
      final response = await _apiService
          .postFormData("${BaseUrl.baseUrl}folder_details_page.php", fields)
          .timeout(const Duration(seconds: 15));

      if (response['status'] == 'success') {
        _showSuccessMessage(context, response['message'] ?? 'File deleted successfully');
        await fetchFiles(folderId); // Refresh to sync deletions
      } else {
        throw Exception(response['message'] ?? 'Failed to delete file');
      }
    } catch (e, stackTrace) {
      // Rollback optimistic update
      if (removedFile != null && index != -1) {
        files.insert(index, removedFile);
        notifyListeners();
      }
      _logger.e('Error deleting file', error: e, stackTrace: stackTrace);
      Utils.noInternet(e.toString().replaceFirst('Exception: ', '')); // Clean error message
    }
  }
}