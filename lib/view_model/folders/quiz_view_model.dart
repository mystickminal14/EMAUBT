import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/model/quiz_set_model.dart';
import 'package:ema_app/utils/utils.dart';

class QuizSetsViewModel extends ChangeNotifier {
  final NetworkApiService _apiService = NetworkApiService();
  final Logger _logger = Logger();

  List<QuizSetData> quizSets = [];
  bool isLoading = false;

  void _showSuccessMessage(BuildContext context, String message) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.green,
      icon: const Icon(Icons.check_circle, color: Colors.white),
    ).show(context);
  }

  Future<void> fetchQuizSets(String folderId) async {
    isLoading = true;
    notifyListeners();
    quizSets.clear();
    try {
      final url =
          "${BaseUrl.baseUrl}folder_details_page.php?action=get_quiz_sets&folder_id=$folderId";
      final response =
      await _apiService.getApiResponse(url).timeout(const Duration(seconds: 15));

      if (response is Map<String, dynamic> && response['status'] == 'success') {
        final quizSetModel = QuizSetModel.fromJson(response);
        quizSets = quizSetModel.data;
        _logger.i("Fetched ${quizSets.length} quiz sets for folder $folderId");
      } else {
        quizSets = [];
        _logger.w("No quiz sets found or invalid response for folder $folderId");
      }
    } on TimeoutException {
      Utils.noInternet("Request timed out. Please try again later.");
    } catch (e, stack) {
      _logger.e('Error fetching quiz sets', error: e, stackTrace: stack);
      Utils.noInternet('Something went wrong.');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addQuizSet(
      BuildContext context,
      String folderId,
      String name, {
        File? iconFile,
        Uint8List? iconBytes,
        String? iconName,
      }) async {
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempQuizSet = QuizSetData(
      id: tempId,
      folderId: int.tryParse(folderId),
      name: name,
      iconPath: iconFile?.path ?? (iconBytes != null ? 'temp_icon' : null),
    );

    quizSets.add(tempQuizSet);
    notifyListeners();

    try {
      final response = await _apiService
          .postFileMultipart(
        "${BaseUrl.baseUrl}folder_details_page.php",
        {
          'action': 'add_quiz_set',
          'folder_id': folderId,
          'name': name,
        },
        iconFile: iconFile,
        iconBytes: iconBytes,
        iconName: iconName,
      )
          .timeout(const Duration(seconds: 15));

      if (response['status'] == 'success') {
        _showSuccessMessage(context, response['message'] ?? 'Quiz set added successfully');
        await fetchQuizSets(folderId);
      } else {
        throw Exception(response['message'] ?? 'Failed to add quiz set');
      }
    } catch (e, stack) {
      quizSets.removeWhere((q) => q.id == tempId);
      notifyListeners();
      _logger.e('Error adding quiz set', error: e, stackTrace: stack);
      Utils.noInternet(e.toString());
    }
  }

  Future<void> editQuizSet(
      BuildContext context,
      String folderId,
      int id,
      String name, {
        File? iconFile,
        Uint8List? iconBytes,
        String? iconName,
      }) async {
    final index = quizSets.indexWhere((q) => q.id == id);
    QuizSetData? oldQuizSet;
    if (index != -1) {
      oldQuizSet = quizSets[index];
      quizSets[index] = QuizSetData(
        id: id,
        folderId: int.tryParse(folderId),
        name: name,
        iconPath: iconFile?.path ?? (iconBytes != null ? 'temp_icon' : oldQuizSet.iconPath),
      );
      notifyListeners();
    }

    try {
      final response = await _apiService
          .postFileMultipart(
        "${BaseUrl.baseUrl}folder_details_page.php",
        {
          'action': 'edit_quiz_set',
          'id': id.toString(),
          'name': name,
        },
        iconFile: iconFile,
        iconBytes: iconBytes,
        iconName: iconName,
      )
          .timeout(const Duration(seconds: 15));

      if (response['status'] == 'success') {
        _showSuccessMessage(context, response['message'] ?? 'Quiz set updated successfully');
        await fetchQuizSets(folderId);
      } else {
        throw Exception(response['message'] ?? 'Failed to edit quiz set');
      }
    } catch (e, stack) {
      if (oldQuizSet != null && index != -1) {
        quizSets[index] = oldQuizSet;
        notifyListeners();
      }
      _logger.e('Error editing quiz set', error: e, stackTrace: stack);
      Utils.noInternet(e.toString());
    }
  }

  Future<void> deleteQuizSet(BuildContext context, String folderId, int id) async {
    final index = quizSets.indexWhere((q) => q.id == id);
    QuizSetData? removedQuizSet;
    if (index != -1) {
      removedQuizSet = quizSets[index];
      quizSets.removeAt(index);
      notifyListeners();
    }

    try {
      final response = await _apiService
          .postFormData(
        "${BaseUrl.baseUrl}folder_details_page.php",
        {'action': 'delete_quiz_set', 'id': id.toString()},
      )
          .timeout(const Duration(seconds: 15));

      if (response['status'] == 'success') {
        _showSuccessMessage(context, response['message'] ?? 'Quiz set deleted successfully');
        await fetchQuizSets(folderId);
      } else {
        throw Exception(response['message'] ?? 'Failed to delete quiz set');
      }
    } catch (e, stack) {
      if (removedQuizSet != null && index != -1) {
        quizSets.insert(index, removedQuizSet);
        notifyListeners();
      }
      _logger.e('Error deleting quiz set', error: e, stackTrace: stack);
      Utils.noInternet(e.toString());
    }
  }
}