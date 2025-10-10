import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:ema_app/constants/base_url.dart';

class UserFolderViewModel with ChangeNotifier {
  List<Map<String, dynamic>> files = [];
  List<Map<String, dynamic>> quizSets = [];

  Future<void> fetchFiles(String folderId, bool isAdmin, String userIdentifier) async {
    try {
      final url =
          '${BaseUrl.baseUrl}folder_details_page.php?action=get_files&folder_id=$folderId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          List<Map<String, dynamic>> allFiles =
          List<Map<String, dynamic>>.from(data['data']).map((file) {
            file['id'] = int.parse(file['id'].toString());
            return file;
          }).toList();

          for (var file in allFiles) {
            var accessResult = await checkAccess(file['id'], 'file', isAdmin, userIdentifier);
            file['can_access'] = accessResult['can_access'];
            file['has_permission'] = accessResult['has_permission'];
            file['is_active'] = accessResult['is_active'];
            file['access_times'] = accessResult['access_times'];
            file['times_accessed'] = accessResult['times_accessed'];
            if (kDebugMode) {
              print(
                  'File: ${file['name']}, can_access: ${file['can_access']}, has_permission: ${file['has_permission']}, is_active: ${file['is_active']}');
            }
          }

          files = allFiles;
          notifyListeners();
        } else {
          throw Exception('Failed to fetch files: ${data['message']}');
        }
      } else {
        throw Exception('Server error while fetching files');
      }
    } catch (e) {
      throw Exception('Error fetching files: $e');
    }
  }

  Future<void> fetchQuizSets(String folderId, bool isAdmin, String userIdentifier) async {
    try {
      final url =
          '${BaseUrl.baseUrl}folder_details_page.php?action=get_quiz_sets&folder_id=$folderId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          List<Map<String, dynamic>> allQuizSets =
          List<Map<String, dynamic>>.from(data['data']).map((quizSet) {
            quizSet['id'] = int.parse(quizSet['id'].toString());
            return quizSet;
          }).toList();

          allQuizSets.sort((a, b) => a['id'].compareTo(b['id']));

          // Parallelize access checks to improve performance
          final accessFutures = allQuizSets.map((quizSet) async {
            final accessResult = await checkAccess(quizSet['id'], 'quiz_set', isAdmin, userIdentifier);
            quizSet['can_access'] = accessResult['can_access'];
            quizSet['has_permission'] = accessResult['has_permission'];
            quizSet['is_active'] = accessResult['is_active'];
            quizSet['access_times'] = accessResult['access_times'];
            quizSet['times_accessed'] = accessResult['times_accessed'];
            if (kDebugMode) {
              print(
                  'QuizSet: ${quizSet['name']}, can_access: ${quizSet['can_access']}, has_permission: ${quizSet['has_permission']}, is_active: ${quizSet['is_active']}');
            }
          }).toList();

          await Future.wait(accessFutures);

          quizSets = allQuizSets;
          notifyListeners();
        } else {
          throw Exception('Failed to fetch quiz sets: ${data['message']}');
        }
      } else {
        throw Exception('Server error while fetching quiz sets');
      }
    } catch (e) {
      throw Exception('Error fetching quiz sets: $e');
    }
  }
  Future<String?> fetchFilePath(int fileId) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${BaseUrl.baseUrl}folder_details_page.php?action=get_file_by_id&file_id=$fileId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success" && data['data'] != null) {
          return data['data']['file_path'];
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error fetching file path: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> checkAccess(int itemId, String itemType, bool isAdmin, String userIdentifier) async {
    if (isAdmin) {
      return {
        'can_access': true,
        'has_permission': true,
        'is_active': 1,
        'access_times': -1,
        'times_accessed': 0,
      };
    }

    try {
      final response = await http.post(
        Uri.parse('${BaseUrl.baseUrl}check_access.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'identifier': userIdentifier.isEmpty ? 'guest' : userIdentifier,
          'is_admin': 'false',
          'item_id': itemId.toString(),
          'item_type': itemType,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) {
          print(
              'CheckAccess Response for Item ID: $itemId, Type: $itemType - $data');
        }
        if (data['success'] == true) {
          return {
            'can_access': data['can_access'] == true,
            'has_permission': data['has_permission'] == true,
            'is_active': data['is_active'] ?? 0,
            'access_times': data['access_times'] ?? -1,
            'times_accessed': data['times_accessed'] ?? 0,
          };
        }
      }
      return {
        'can_access': false,
        'has_permission': false,
        'is_active': 0,
        'access_times': -1,
        'times_accessed': 0,
      };
    } catch (e) {
      if (kDebugMode)
        print(
            'Error checking access for Item ID: $itemId, Type: $itemType - $e');
      return {
        'can_access': false,
        'has_permission': false,
        'is_active': 0,
        'access_times': -1,
        'times_accessed': 0,
      };
    }
  }

  Future<bool> incrementAccessCount(int itemId, String itemType, bool isAdmin, String userIdentifier) async {
    if (userIdentifier.isEmpty || isAdmin) return true;

    try {
      final response = await http.post(
        Uri.parse('${BaseUrl.baseUrl}increment_access.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'identifier': userIdentifier,
          'is_admin': 'false',
          'item_id': itemId.toString(),
          'item_type': itemType,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) {
          print(
              'Increment Access Response for Item ID: $itemId, Type: $itemType - $data');
        }
        return data['success'] == true;
      }
    } catch (e) {
      if (kDebugMode) print('Error incrementing access count: $e');
      return false;
    }
    return false;
  }
}