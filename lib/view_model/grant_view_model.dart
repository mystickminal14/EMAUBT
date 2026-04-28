import 'package:ema_app/model/access/all_quiz_model.dart';
import 'package:ema_app/model/access/fetch_files.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/standard_response.dart';


class GrantAccessFilesViewModel extends ChangeNotifier {
  bool _isLoading = false;
  List<FilesData> files = [];
  List<QuizData> quizSets = [];
  List<Map<String, dynamic>> accessPermissions = [];
  final TextEditingController accessTimesController = TextEditingController();
  final Map<int, bool> _selectedFiles = {};
  final Map<int, bool> _selectedQuizSets = {};

  bool get isLoading => _isLoading;
  Map<int, bool> get selectedFiles => _selectedFiles;
  Map<int, bool> get selectedQuizSets => _selectedQuizSets;

  Future<void> initializeData(String email) async {
    if (email.isEmpty) {
      throw Exception('No email provided for entity');
    }
    await Future.wait([
      fetchFiles(),
      fetchQuizSets(),
      fetchAccessPermissions(email),
    ]);
  }

  Future<void> fetchFiles() async {
    _setLoading(true);
    try {
      final response = await http.get(
        Uri.parse('${BaseUrl.baseUrl}folder_details_page.php?action=get_all_files'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('Files response status: ${response.statusCode}');
      debugPrint('Files response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        final responseData = jsonDecode(response.body);
        final normalizedResponse = normalizeApiResponse(responseData, response.statusCode);

        if (normalizedResponse['success'] == true) {
          final data = fetchallFilesModel.fromJson(responseData);
          files = data.data ?? [];
          for (var file in files) {
            _selectedFiles[file.id!] = false;
          }
          notifyListeners();
        } else {
          throw Exception('Error fetching files: ${normalizedResponse['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching files: $e');
      throw Exception('Failed to fetch files: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchQuizSets() async {
    _setLoading(true);
    try {
      final response = await http.get(
        Uri.parse('${BaseUrl.baseUrl}folder_details_page.php?action=get_all_quiz_sets'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('Quiz sets response status: ${response.statusCode}');
      debugPrint('Quiz sets response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        final responseData = jsonDecode(response.body);
        final normalizedResponse = normalizeApiResponse(responseData, response.statusCode);

        if (normalizedResponse['success'] == true) {
          final data = AllQuizModel.fromJson(responseData);
          List<QuizData> allQuizSets = data.data ?? [];
          allQuizSets.sort((a, b) => a.id!.compareTo(b.id!));

          quizSets = allQuizSets;
          for (var quizSet in quizSets) {
            _selectedQuizSets[quizSet.id!] = false;
          }
          notifyListeners();
        } else {
          throw Exception('Error fetching quiz sets: ${normalizedResponse['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching quiz sets: $e');
      throw Exception('Failed to fetch quiz sets: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchAccessPermissions(String email) async {
    if (email.isEmpty) {
      throw Exception('No email provided for entity');
    }

    _setLoading(true);
    try {
      final uri = Uri.parse('${BaseUrl.baseUrl}grant_file_access.php').replace(
        queryParameters: {
          'action': 'get_access_permissions',
          'identifier': email,
        },
      );

      debugPrint('Fetching permissions from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('Permissions response status: ${response.statusCode}');
      debugPrint('Permissions response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        final responseData = jsonDecode(response.body);
        final normalizedResponse = normalizeApiResponse(responseData, response.statusCode);

        if (normalizedResponse['success'] == true) {
          accessPermissions = List<Map<String, dynamic>>.from(normalizedResponse['data'] ?? []);
          notifyListeners();
        } else {
          throw Exception('Error fetching access permissions: ${normalizedResponse['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching access permissions: $e');
      throw Exception('Failed to fetch access permissions: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> grantFileAccess(String identifier, bool isAdmin) async {
    if (_isLoading) return false;

    _setLoading(true);
    final accessTimes = int.tryParse(accessTimesController.text) ?? 0;

    if (accessTimes <= 0) {
      throw Exception('Please enter a valid number of access times');
    }

    List<Map<String, dynamic>> selectedItems = [];
    for (var file in files) {
      if (_selectedFiles[file.id!] == true) {
        selectedItems.add({'item_id': file.id, 'item_type': 'file'});
      }
    }
    for (var quizSet in quizSets) {
      if (_selectedQuizSets[quizSet.id!] == true) {
        if (quizSet.folderId == 1 && quizSets.isNotEmpty && quizSet.id == quizSets[0].id) {
          continue;
        }
        selectedItems.add({'item_id': quizSet.id, 'item_type': 'quiz_set'});
      }
    }

    if (selectedItems.isEmpty) {
      throw Exception('Please select at least one file or quiz set');
    }

    try {
      final response = await http.post(
        Uri.parse("${BaseUrl.baseUrl}grant_file_access.php"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'identifier': identifier,
          'is_admin': isAdmin.toString(),
          'items': jsonEncode(selectedItems),
          'access_times': accessTimes.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Grant access response status: ${response.statusCode}');
      debugPrint('Grant access response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await fetchAccessPermissions(identifier);
          return true;
        } else {
          throw Exception('Error: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error granting access: $e');
      throw Exception('Error granting access: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAccessPermission(int itemId, String itemType, String identifier) async {
    if (_isLoading) return false;

    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse("${BaseUrl.baseUrl}grant_file_access.php"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'action': 'delete_access_permission',
          'identifier': identifier,
          'item_id': itemId.toString(),
          'item_type': itemType,
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('Delete response status: ${response.statusCode}');
      debugPrint('Delete response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await fetchAccessPermissions(identifier);
          return true;
        } else {
          throw Exception('Error: ${data['message']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting access permission: $e');
      throw Exception('Failed to delete access permission: $e');
    } finally {
      _setLoading(false);
    }
  }

  bool isFirstQuizSetInFirstFolder(QuizData quizSet) {
    return quizSet.folderId == 1 && quizSets.isNotEmpty && quizSet.id == quizSets[0].id;
  }

  void toggleFileSelection(int fileId, bool value) {
    _selectedFiles[fileId] = value;
    notifyListeners();
  }

  void toggleQuizSetSelection(int quizSetId, bool value) {
    _selectedQuizSets[quizSetId] = value;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    accessTimesController.dispose();
    super.dispose();
  }
}