import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/model/user_data_model.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Add this import

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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorMessage(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
      _logger.e('Error fetching users: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        // Compress the image
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          pickedFile.path,
          quality: 85, // 85% quality
          minWidth: 1024,
          minHeight: 1024,
          format: CompressFormat.jpeg,
        );
        if (compressedBytes != null) {
          // Create a temporary file for the compressed bytes
          final tempDir = await Directory.systemTemp.createTemp();
          final compressedFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await compressedFile.writeAsBytes(compressedBytes);
          selectedImage = compressedFile;
          _logger.i('Image picked and compressed: ${compressedFile.path} (original: ${pickedFile.path})');
        } else {
          // Fallback to original if compression fails
          selectedImage = File(pickedFile.path);
          _logger.w('Compression failed, using original image');
        }
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error picking/compressing image: $e');
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
      _logger.i('Adding user: $name, $email, $phone');
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
        _logger.i('User added successfully');
        clearFields();
        await Future.delayed(const Duration(milliseconds: 100)); // Delay to avoid disposal race
        await fetchUsers(context);
      } else {
        _showErrorMessage(context, 'Failed to add user: ${response['message'] ?? 'Unknown error'}');
        _logger.w('Failed to add user: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorMessage(context, 'Error adding user: $e');
      _logger.e('Error adding user: $e');
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
      _logger.i('Editing user: ${user.id}, $name, $email, $phone');
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
        _logger.i('User updated successfully');
        clearFields();
        await Future.delayed(const Duration(milliseconds: 100)); // Delay to avoid disposal race
        await fetchUsers(context);
      } else {
        _showErrorMessage(context, 'Failed to update user: ${response['message'] ?? 'Unknown error'}');
        _logger.w('Failed to update user: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorMessage(context, 'Error updating user: $e');
      _logger.e('Error updating user: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser(BuildContext context, Users user) async {
    try {
      isActionLoading = true;
      notifyListeners();
      _logger.i('Deleting user: ${user.id}, ${user.fullName}');
      final response = await _apiService.getDeleteApiResponse('${BaseUrl.baseUrl}register.php?id=${user.id}');
      if (response['success'] == true) {
        _showSuccessMessage(context, 'User deleted successfully');
        _logger.i('User deleted successfully');
        await Future.delayed(const Duration(milliseconds: 100)); // Delay to avoid disposal race
        await fetchUsers(context);
      } else {
        _showErrorMessage(context, 'Failed to delete user: ${response['message'] ?? 'Unknown error'}');
        _logger.w('Failed to delete user: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showErrorMessage(context, 'Error deleting user: $e');
      _logger.e('Error deleting user: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  void searchUsers(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterLists();
    notifyListeners();
    _logger.i('Searching users with query: $_searchQuery');
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
    _logger.i('Filtered users: ${filteredUsers.length}');
  }

  void setFields({String? name, String? email, String? phone, String? password, File? image}) {
    this.name = name;
    this.email = email;
    this.phone = phone;
    this.password = password;
    selectedImage = image;
    notifyListeners();
    _logger.i('Fields updated: name=$name, email=$email, phone=$phone, image=${image?.path}');
  }

  void clearFields() {
    name = null;
    email = null;
    phone = null;
    password = null;
    selectedImage?.deleteSync(); // Clean up compressed temp file
    selectedImage = null;
    _searchQuery = '';
    _filterLists();
    notifyListeners();
    _logger.i('Fields cleared');
  }
}