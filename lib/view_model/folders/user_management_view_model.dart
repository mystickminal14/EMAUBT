import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/model/user_data_model.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ema_app/utils/image_compress_util.dart';

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
      if (response['success'] == true) {
        // Handle both old format (UserModelData) and new standard format
        if (response['data'] != null) {
          final userData = UserModelData.fromJson(response);
          if (userData.users != null) {
            users = userData.users!;
          }
        } else if (response['users'] != null) {
          // Old format fallback
          final userData = UserModelData.fromJson(response);
          if (userData.users != null) {
            users = userData.users!;
          }
        }
        _filterLists();
        _logger.i('Fetched ${users.length} users');
      } else {
        users = [];
        _filterLists();
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      users = [];
      _filterLists();
      Utils.showApiResponse(Utils.errorResponse('Error fetching users: $e'), context);
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
        final compressedBytes = await ImageCompressUtil.compressFile(
          pickedFile.path,
          quality: 85, // 85% quality
          minWidth: 1024,
          minHeight: 1024,
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
    if (name == null || name!.trim().isEmpty) {
      Utils.showApiResponse(
        Utils.errorResponse('Full Name is required'),
        context,
      );
      return;
    }

    if (email == null || email!.trim().isEmpty) {
      Utils.showApiResponse(
        Utils.errorResponse('Email is required'),
        context,
      );
      return;
    }

    if (phone == null || phone!.trim().isEmpty) {
      Utils.showApiResponse(
        Utils.errorResponse('Phone is required'),
        context,
      );
      return;
    }

    if (password == null || password!.isEmpty) {
      Utils.showApiResponse(
        Utils.errorResponse('Password is required'),
        context,
      );
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final fields = {
        'full_name': name!.trim(),
        'email': email!.trim(),
        'phone': phone!.trim(),
        'password': password!,
      };

      final response = await _apiService.postMultipartResponse(
        '${BaseUrl.baseUrl}register.php',
        fields,
        selectedImage,
      );

      // ✅ SHOW BACKEND VALIDATION MESSAGE
      if (response['success'] == true) {
        Utils.showApiResponse(response, context);

        clearFields();

        await Future.delayed(
          const Duration(milliseconds: 100),
        );

        await fetchUsers(context);
      } else {
        String errorMessage = '';

        // backend sends errors
        if (response['errors'] != null) {
          if (response['errors'] is String) {
            errorMessage = response['errors'];
          } else if (response['errors'] is List) {
            errorMessage =
                (response['errors'] as List).join('\n');
          } else if (response['errors'] is Map) {
            final errors = response['errors'] as Map;

            errorMessage = errors.values
                .map((e) {
              if (e is List) {
                return e.join('\n');
              }
              return e.toString();
            })
                .join('\n');
          }
        }

        errorMessage = errorMessage.isNotEmpty
            ? errorMessage
            : (response['message'] ?? 'Something went wrong');

        Utils.showApiResponse(
          Utils.errorResponse(errorMessage),
          context,
        );
      }
    } catch (e) {
      Utils.showApiResponse(
        Utils.errorResponse('Error adding user: $e'),
        context,
      );
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }
  Future<void> editUser(BuildContext context, Users user) async {
    if (name == null || name!.isEmpty || email == null || email!.isEmpty || phone == null || phone!.isEmpty) {
      Utils.showApiResponse(Utils.errorResponse('Full Name, Email, and Phone are required'), context);
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
      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('User updated successfully');
        clearFields();
        await Future.delayed(const Duration(milliseconds: 100)); // Delay to avoid disposal race
        await fetchUsers(context);
      } else {
        _logger.w('Failed to update user: ${response['message']}');
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error updating user: $e'), context);
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
      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('User deleted successfully');
        await Future.delayed(const Duration(milliseconds: 100)); // Delay to avoid disposal race
        await fetchUsers(context);
      } else {
        _logger.w('Failed to delete user: ${response['message']}');
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error deleting user: $e'), context);
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