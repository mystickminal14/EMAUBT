import 'dart:async';
import 'dart:convert';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ema_app/utils/utils.dart';

class FreeAccessViewModel extends ChangeNotifier {
  final NetworkApiService _apiService = NetworkApiService();
  final Logger _logger = Logger();

  List<Map<String, dynamic>> files = [];
  List<Map<String, dynamic>> quizSets = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchGrantedAccessItems(String folderId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService
          .getApiResponse(
        "${BaseUrl.baseUrl}give_access_to_login_users.php?action=get_granted_access_items&folder_id=$folderId",
      )
          .timeout(const Duration(seconds: 15));

      if (response is Map && response['status'] == 'success') {
        final items = List<Map<String, dynamic>>.from(response['data'])
            .map((item) => {
          ...item,
          'id': int.parse(item['id'].toString()),
          'item_type': item['item_type'],
        })
            .toList();

        files = items.where((i) => i['item_type'] == 'file').toList();
        quizSets = items.where((i) => i['item_type'] == 'quiz_set').toList();

        _logger.i("Fetched ${files.length} files and ${quizSets.length} quiz sets");
      } else {
        errorMessage = "Failed: ${response['message'] ?? 'Unknown error'}";
      }
    } on TimeoutException {
      errorMessage = "Request timed out. Please try again later.";
      Utils.noInternet(errorMessage!);
    } catch (e, stack) {
      errorMessage = "Error fetching items: $e";
      _logger.e("⛔ Error fetching granted items", error: e, stackTrace: stack);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
