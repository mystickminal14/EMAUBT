import 'dart:async';
import 'dart:io';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/model/user_data_model.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:image_picker/image_picker.dart';

class UserManagementViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();
  bool isLoading = true;
  bool isActionLoading = false;
  List<Users> users = [];
  List<Users> filteredUsers = [];
  String _searchQuery = '';
  File? selectedImage;
  String? name;
  String? email;
  String? phone;
  String? password;

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> fetchUsers(BuildContext context) async {
    try {
      isLoading = true;
      notifyListeners();
      final response = await _apiService.getApiResponse('${BaseUrl.baseUrl}register.php');
      final userData = UserModelData.fromJson(response);
      if (userData.success == true && userData.users != null) {
        users = userData.users!;
        _filterLists();
        _logger.i('Fetched ${users.length} users');
      } else {
        users = [];
        _filterLists();
        _showErrorMessage(context, 'Failed to fetch users: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      users = [];
      _filterLists();
      _showErrorMessage(context, 'Error fetching users: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      selectedImage = File(pickedFile.path);
      notifyListeners();
    }
  }

  Future<void> addUser(BuildContext context) async {
    if (name == null || name!.isEmpty || email == null || email!.isEmpty || phone == null || phone!.isEmpty || password == null || password!.isEmpty) {
      _showErrorMessage(context, 'Full Name, Email, Phone, and Password are required');
      return;
    }

    if (users.any((user) => user.email?.toLowerCase() == email!.toLowerCase())) {
      _showErrorMessage(context, 'Email already exists');
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();
      final fields = {
        'full_name': name!,
        'email': email!,
        'phone': phone!,
        'password': password!,
      };
      final response = await _apiService.postMultipartResponse(
        '${BaseUrl.baseUrl}register.php',
        fields,
        selectedImage,
      );
      if (response['success'] == true) {
        _showSuccessMessage(context, 'User added successfully');
        clearFields();
        await fetchUsers(context);
      } else {
        _showErrorMessage(context, 'Failed to add user: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorMessage(context, 'Error adding user: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  Future<void> editUser(BuildContext context, Users user) async {
    if (name == null || name!.isEmpty || email == null || email!.isEmpty || phone == null || phone!.isEmpty) {
      _showErrorMessage(context, 'Full Name, Email, and Phone are required');
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();
      final fields = {
        '_method': 'PUT',
        'id': user.id ?? '',
        'full_name': name!,
        'email': email!,
        'phone': phone!,
        if (password != null && password!.isNotEmpty) 'password': password!,
      };
      final response = await _apiService.postMultipartResponse(
        '${BaseUrl.baseUrl}register.php',
        fields,
        selectedImage,
      );
      if (response['success'] == true) {
        _showSuccessMessage(context, 'User updated successfully');
        clearFields();
        await fetchUsers(context);
      } else {
        _showErrorMessage(context, 'Failed to update user: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorMessage(context, 'Error updating user: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser(BuildContext context, Users user) async {
    try {
      isActionLoading = true;
      notifyListeners();
      final response = await _apiService.getDeleteApiResponse('${BaseUrl.baseUrl}register.php?id=${user.id}');
      if (response['success'] == true) {
        _showSuccessMessage(context, 'User deleted successfully');
        await fetchUsers(context);
      } else {
        _showErrorMessage(context, 'Failed to delete user: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorMessage(context, 'Error deleting user: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  void searchUsers(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterLists();
    notifyListeners();
  }

  void _filterLists() {
    if (_searchQuery.isEmpty) {
      filteredUsers = List.from(users);
    } else {
      filteredUsers = users.where((user) {
        final name = user.fullName?.toLowerCase() ?? '';
        final email = user.email?.toLowerCase() ?? '';
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    }
  }

  void setFields({String? name, String? email, String? phone, String? password, File? image}) {
    this.name = name;
    this.email = email;
    this.phone = phone;
    this.password = password;
    selectedImage = image;
    notifyListeners();
  }

  void clearFields() {
    name = null;
    email = null;
    phone = null;
    password = null;
    selectedImage = null;
    _searchQuery = '';
    filteredUsers = List.from(users);
    notifyListeners();
  }
}