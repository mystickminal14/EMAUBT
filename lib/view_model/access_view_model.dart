import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/api_exception.dart';
import 'package:ema_app/data/network/BaseApiService.dart';
import 'package:ema_app/model/access/all_permission.dart';
import 'package:ema_app/model/access/all_quiz_model.dart';
import 'package:ema_app/model/access/alladminModel.dart';
import 'package:ema_app/model/access/fetch_files.dart';
import 'package:ema_app/model/access/get_all_activation.dart';
import 'package:ema_app/model/user_data_model.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class GiveAccessViewModel extends ChangeNotifier {
  final BaseApiServices _apiService;
  final Logger _logger = Logger();

  final TextEditingController searchController = TextEditingController();
  bool _isLoading = false;
  List<Users> _users = [];
  List<Admins> _admins = [];
  List<Users> _filteredUsers = [];
  List<Admins> _filteredAdmins = [];
  List<FilesData> _files = [];
  List<QuizData> _quizSets = [];
  List<PermssionData> _grantedItems = [];
  List<ActivateData> _activatedItems = [];
  final List<int> _selectedItems = [];

  bool get isLoading => _isLoading;
  List<Users> get filteredUsers => _filteredUsers;
  List<Admins> get filteredAdmins => _filteredAdmins;
  List<FilesData> get files => _files;
  List<QuizData> get quizSets => _quizSets;
  List<PermssionData> get grantedItems => _grantedItems;
  List<ActivateData> get activatedItems => _activatedItems;
  List<int> get selectedItems => _selectedItems;

  GiveAccessViewModel(this._apiService) {
    fetchData();
    searchController.addListener(searchUsersAndAdmins);
  }

  Future<void> fetchData() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        fetchUsersAndAdmins(),
        fetchFiles(),
        fetchQuizSets(),
        fetchGrantedItems(),
        fetchActivatedItems(),
      ]);
    } catch (e) {
      _logger.e('Error fetching data: $e');
      throw FetchDataException('Error fetching data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUsersAndAdmins() async {
    try {
      final usersResponse = await _apiService.getApiResponse('${BaseUrl.baseUrl}register.php');
      final adminsResponse = await _apiService.getApiResponse('${BaseUrl.baseUrl}get_admins.php');

      final userModel = UserModelData.fromJson(usersResponse);
      final adminModel = AllAdminModel.fromJson(adminsResponse);

      if (userModel.success == true && userModel.users != null) {
        _users = userModel.users!;
        _filteredUsers = _users;
      } else {
        throw FetchDataException(userModel.success == false ? userModel.toJson()['message'] ?? 'Error fetching users' : 'No users found');
      }

      if (adminModel.success == true && adminModel.admins != null) {
        _admins = adminModel.admins!;
        _filteredAdmins = _admins;
      } else {
        throw FetchDataException(adminModel.success == false ? adminModel.toJson()['message'] ?? 'Error fetching admins' : 'No admins found');
      }
      notifyListeners();
    } catch (e) {
      _logger.e('Error fetching users/admins: $e');
      throw FetchDataException('Error fetching users/admins: $e');
    }
  }

  Future<void> fetchFiles() async {
    try {
      final response = await _apiService.getApiResponse(
        '${BaseUrl.baseUrl}folder_details_page.php?action=get_all_files',
      );
      final quizModel = fetchallFilesModel.fromJson(response);
      if (quizModel.status == "success" && quizModel.data != null) {
        _files = quizModel.data!.map((file) {
          return FilesData(
            id: file.id,
            folderId: file.folderId,
            name: file.name,
            iconPath: file.iconPath,
            // isActivated: file.isActivated ?? false,
          );
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error fetching files: $e');
    }
  }

  Future<void> fetchQuizSets() async {
    try {
      final response = await _apiService.getApiResponse(
        '${BaseUrl.baseUrl}folder_details_page.php?action=get_all_quiz_sets',
      );
      final quizModel = AllQuizModel.fromJson(response);
      if (quizModel.status == "success" && quizModel.data != null) {
        _quizSets = quizModel.data!.map((quizSet) {
          return QuizData(
            id: quizSet.id,
            folderId: quizSet.folderId,
            name: quizSet.name,
            iconPath: quizSet.iconPath,
            // isActivated: quizSet.isActivated ?? false,
          );
        }).toList()
          ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error fetching quiz sets: $e');
    }
  }

  Future<void> fetchGrantedItems() async {
    try {
      final response = await _apiService.getApiResponse(
        '${BaseUrl.baseUrl}grant_file_access.php?action=get_all_permissions',
      );
      final permissionModel = GetAllPermissionModel.fromJson(response);
      if (permissionModel.status == "success" && permissionModel.data != null) {
        _grantedItems = permissionModel.data!;
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error fetching granted items: $e');
    }
  }

  Future<void> fetchActivatedItems() async {
    try {
      final response = await _apiService.getApiResponse(
        '${BaseUrl.baseUrl}grant_file_access.php?action=get_all_activations',
      );
      final activationModel = GetAllActivation.fromJson(response);
      if (activationModel.status == "success" && activationModel.data != null) {
        _activatedItems = activationModel.data!;
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error fetching activated items: $e');
    }
  }

  Future<void> toggleFileActivation(int fileId, bool currentStatus) async {
    try {
      final response = await _apiService.getPostApiResponse(
        '${BaseUrl.baseUrl}grant_file_access.php',
        {
          'action': 'update_activation',
          'item_type': 'file',
          'item_id': fileId,
          'is_activated': !currentStatus,
        },
      );
      if (response['success'] == true) {
        _files = _files.map((file) {
          if (file.id == fileId) {
            return FilesData(
              id: file.id,
              folderId: file.folderId,
              name: file.name,
              iconPath: file.iconPath,
              // isActivated: !currentStatus,
            );
          }
          return file;
        }).toList();
        await fetchActivatedItems();
        notifyListeners();
      } else {
        throw FetchDataException(response['message'] ?? 'Failed to toggle file activation');
      }
    } catch (e) {
      _logger.e('Error toggling file activation: $e');
      throw FetchDataException('Error toggling file activation: $e');
    }
  }

  Future<void> toggleQuizSetActivation(int quizSetId, bool currentStatus) async {
    try {
      final response = await _apiService.getPostApiResponse(
        '${BaseUrl.baseUrl}grant_file_access.php',
        {
          'action': 'update_activation',
          'item_type': 'quiz_set',
          'item_id': quizSetId,
          'is_activated': !currentStatus,
        },
      );
      if (response['success'] == true) {
        _quizSets = _quizSets.map((quizSet) {
          if (quizSet.id == quizSetId) {
            return QuizData(
              id: quizSet.id,
              folderId: quizSet.folderId,
              name: quizSet.name,
              iconPath: quizSet.iconPath,
              // isActivated: !currentStatus,
            );
          }
          return quizSet;
        }).toList();
        await fetchActivatedItems();
        notifyListeners();
      } else {
        throw FetchDataException(response['message'] ?? 'Failed to toggle quiz set activation');
      }
    } catch (e) {
      _logger.e('Error toggling quiz set activation: $e');
      throw FetchDataException('Error toggling quiz set activation: $e');
    }
  }

  Future<void> deleteActivatedItem(int itemId, String itemType) async {
    try {
      final response = await _apiService.getPostApiResponse(
        '${BaseUrl.baseUrl}grant_file_access.php',
        {
          'action': 'delete_activation',
          'item_type': itemType,
          'item_id': itemId,
        },
      );
      if (response['success'] == true) {
        _activatedItems.removeWhere((item) => item.itemId == itemId && item.itemType == itemType);
        if (itemType == 'file') {
          _files = _files.map((file) {
            if (file.id == itemId) {
              return FilesData(
                id: file.id,
                folderId: file.folderId,
                name: file.name,
                iconPath: file.iconPath,
                isActivated: false,
              );
            }
            return file;
          }).toList();
        } else {
          _quizSets = _quizSets.map((quizSet) {
            if (quizSet.id == itemId) {
              return QuizData(
                id: quizSet.id,
                folderId: quizSet.folderId,
                name: quizSet.name,
                iconPath: quizSet.iconPath,
                isActivated: false,
              );
            }
            return quizSet;
          }).toList();
        }
        notifyListeners();
      } else {
        throw FetchDataException(response['message'] ?? 'Failed to delete item');
      }
    } catch (e) {
      _logger.e('Error deleting item: $e');
      throw FetchDataException('Error deleting item: $e');
    }
  }

  Future<void> deleteSelectedItems() async {
    if (_selectedItems.isEmpty) {
      throw FetchDataException('No items selected for deletion');
    }
    try {
      final itemsToDelete = _activatedItems
          .where((item) => _selectedItems.contains(item.itemId))
          .map((item) => {
        'item_id': item.itemId,
        'item_type': item.itemType,
      })
          .toList();

      if (itemsToDelete.isEmpty) {
        throw FetchDataException('No valid items to delete');
      }

      final response = await _apiService.getPostApiResponse(
        '${BaseUrl.baseUrl}grant_file_access.php',
        {
          'action': 'batch_delete',
          'items': itemsToDelete,
        },
      );

      if (response['success'] == true) {
        _activatedItems.removeWhere((item) => _selectedItems.contains(item.itemId));
        for (var item in itemsToDelete) {
          if (item['item_type'] == 'file') {
            _files = _files.map((file) {
              if (file.id == item['item_id']) {
                return FilesData(
                  id: file.id,
                  folderId: file.folderId,
                  name: file.name,
                  iconPath: file.iconPath,
                  isActivated: false,
                );
              }
              return file;
            }).toList();
          } else {
            _quizSets = _quizSets.map((quizSet) {
              if (quizSet.id == item['item_id']) {
                return QuizData(
                  id: quizSet.id,
                  folderId: quizSet.folderId,
                  name: quizSet.name,
                  iconPath: quizSet.iconPath,
                  isActivated: false,
                );
              }
              return quizSet;
            }).toList();
          }
        }
        _selectedItems.clear();
        notifyListeners();
      } else {
        throw FetchDataException(response['message'] ?? 'Failed to delete items');
      }
    } catch (e) {
      _logger.e('Error during batch deletion: $e');
      throw FetchDataException('Error during batch deletion: $e');
    }
  }

  Future<void> activateAll() async {
    try {
      final itemsToActivate = [
        ..._files.map((file) => {'item_id': file.id, 'item_type': 'file'}),
        ..._quizSets
            .where((quizSet) =>
        !(quizSet.folderId == 1 && _quizSets.isNotEmpty && quizSet.id == _quizSets.first.id))
            .map((quizSet) => {'item_id': quizSet.id, 'item_type': 'quiz_set'}),
      ];

      final response = await _apiService.getPostApiResponse(
        '${BaseUrl.baseUrl}grant_file_access.php',
        {
          'action': 'batch_activate',
          'items': itemsToActivate,
          'is_activated': true,
        },
      );

      if (response['success'] == true) {
        _files = _files.map((file) {
          return FilesData(
            id: file.id,
            folderId: file.folderId,
            name: file.name,
            iconPath: file.iconPath,
            // isActivated: true,
          );
        }).toList();
        _quizSets = _quizSets.map((quizSet) {
          final isFreeQuiz = quizSet.folderId == 1 && _quizSets.isNotEmpty && quizSet.id == _quizSets.first.id;
          return QuizData(
            id: quizSet.id,
            folderId: quizSet.folderId,
            name: quizSet.name,
            iconPath: quizSet.iconPath,
            // isActivated: isFreeQuiz ? quizSet.isActivated : true,
          );
        }).toList();
        await fetchActivatedItems();
        notifyListeners();
      } else {
        throw FetchDataException(response['message'] ?? 'Failed to activate items');
      }
    } catch (e) {
      _logger.e('Error activating all items: $e');
      throw FetchDataException('Error activating all items: $e');
    }
  }

  void searchUsersAndAdmins() {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredUsers = _users;
      _filteredAdmins = _admins;
    } else {
      _filteredUsers = _users.where((user) {
        final name = (user.fullName ?? '').toLowerCase();
        final email = (user.email ?? '').toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
      _filteredAdmins = _admins.where((admin) {
        final name = (admin.fullName ?? '').toLowerCase();
        final email = (admin.email ?? '').toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    searchController.clear();
    _filteredUsers = _users;
    _filteredAdmins = _admins;
    notifyListeners();
  }

  void toggleItemSelection(int itemId) {
    if (_selectedItems.contains(itemId)) {
      _selectedItems.remove(itemId);
    } else {
      _selectedItems.add(itemId);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    searchController.removeListener(searchUsersAndAdmins);
    searchController.dispose();
    super.dispose();
  }
}

// Extend Data class to include isActivated for files and quiz sets
extension DataExtension on ActivateData {
  bool get isActivated => this.isActivated ?? false;
  set isActivated(bool? value) => this.isActivated = value;
}