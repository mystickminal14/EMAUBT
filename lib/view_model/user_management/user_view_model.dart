import 'dart:async';
import 'dart:io';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/endpoints/user_endpoints.dart';
import 'package:ema_app/model/user_model.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ManageUserViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();

  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading = false;
  bool isActionLoading = false;

  List<UserModel> users = [];
  List<UserModel> filteredUsers = [];
  String _searchQuery = '';

  // Pagination
  int currentPage = 1;
  int totalPages = 1;
  int totalUsers = 0;
  int perPage = 20;
  bool isFetchingMore = false;

  // Form fields
  File? selectedImage;
  String? name;
  String? email;
  String? phone;
  String? password;
  String? roleFilter; // 'user' | 'admin' | null

  // ── Helpers ────────────────────────────────────────────────────────────────
  List<UserModel> _parseUsers(Map<String, dynamic> response) {
    try {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final rawList = data['users'];
        if (rawList is List) {
          return rawList
              .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (e) {
      _logger.e('Error parsing users: $e');
    }
    return [];
  }

  // ── GET /users  ────────────────────────────────────────────────────────────
  Future<void> fetchUsers(
      BuildContext context, {
        bool refresh = false,
      }) async {
    if (refresh) {
      currentPage = 1;
      users.clear();
    }

    try {
      isLoading = true;
      notifyListeners();

      final uri = Uri.parse(UserEndpoints.userList).replace(
        queryParameters: {
          'page': currentPage.toString(),
          'per_page': perPage.toString(),
          if (_searchQuery.isNotEmpty) 'search': _searchQuery,
          if (roleFilter != null) 'role': roleFilter!,
          'sort_by': 'created_at',
          'sort_order': 'DESC',
        },
      );

      final response = await _apiService.getApiResponse(uri.toString());

      if (response['success'] == true) {
        final fetched = _parseUsers(response);
        if (refresh) {
          users = fetched;
        } else {
          users.addAll(fetched);
        }

        final data = response['data'] as Map<String, dynamic>? ?? {};
        totalUsers = (data['total'] as num?)?.toInt() ?? users.length;
        totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
        currentPage = (data['page'] as num?)?.toInt() ?? currentPage;

        _filterLists();
        _logger.i('Fetched ${fetched.length} users (total: $totalUsers)');
      } else {
        if (refresh) {
          users = [];
          _filterLists();
        }
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      if (refresh) {
        users = [];
        _filterLists();
      }
      Utils.showApiResponse(Utils.errorResponse('Error fetching users: $e'), context);
      _logger.e('Error fetching users: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Infinite scroll ────────────────────────────────────────────────────────
  Future<void> fetchNextPage(BuildContext context) async {
    if (isFetchingMore || currentPage >= totalPages) return;
    isFetchingMore = true;
    currentPage++;
    notifyListeners();
    try {
      await fetchUsers(context);
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  // ── GET /users/me  ─────────────────────────────────────────────────────────
  Future<UserModel?> fetchCurrentUser(BuildContext context) async {
    try {
      final response =
      await _apiService.getApiResponse(UserEndpoints.fetchUser);
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final userMap = data['user'] as Map<String, dynamic>?;
        if (userMap != null) return UserModel.fromJson(userMap);
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error fetching current user: $e'), context);
      _logger.e('Error fetching current user: $e');
    }
    return null;
  }

  // ── GET /users/{id}  ───────────────────────────────────────────────────────
  Future<UserModel?> fetchUserById(BuildContext context, dynamic userId) async {
    try {
      final response = await _apiService
          .getApiResponse('${UserEndpoints.userDetail}$userId');
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final userMap = data['user'] as Map<String, dynamic>?;
        if (userMap != null) return UserModel.fromJson(userMap);
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error fetching user: $e'), context);
      _logger.e('Error fetching user $userId: $e');
    }
    return null;
  }

  // ── POST /register.php  ────────────────────────────────────────────────────
  Future<void> addUser(BuildContext context) async {
    if (name == null || name!.isEmpty ||
        email == null || email!.isEmpty ||
        phone == null || phone!.isEmpty ||
        password == null || password!.isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Full Name, Email, Phone, and Password are required'),
          context);
      return;
    }

    if (users.any((u) => u.email?.toLowerCase() == email!.toLowerCase())) {
      Utils.showApiResponse(Utils.errorResponse('Email already exists'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.postMultipartResponse(
        UserEndpoints.registerUser,
        <String, dynamic>{
          'full_name': name!,
          'email': email!,
          'phone': phone!,
          'password': password!,
        },
        selectedImage,
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('User added successfully');
        clearFields();
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchUsers(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error adding user: $e'), context);
      _logger.e('Error adding user: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── PUT /users/{id}  ───────────────────────────────────────────────────────
  Future<void> editUser(BuildContext context, UserModel user) async {
    if (name == null || name!.isEmpty ||
        phone == null || phone!.isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse('Full Name and Phone are required'), context);
      return;
    }

    try {
      isActionLoading = true;
      notifyListeners();

      final body = <String, dynamic>{
        'full_name': name!,
        'phone': phone!,
        if (password != null && password!.isNotEmpty) 'password': password!,
      };

      final Map<String, dynamic> response;
      if (selectedImage != null) {
        response = await _apiService.postMultipartResponse(
          '${UserEndpoints.updateUser}${user.id}',
          <String, dynamic>{'_method': 'PUT', ...body},
          selectedImage,
        );
      } else {
        response = await _apiService.getPutResponse(
          '${UserEndpoints.updateUser}${user.id}',
          body,
        );
      }

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('User ${user.id} updated successfully');
        clearFields();
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchUsers(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error updating user: $e'), context);
      _logger.e('Error updating user: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── DELETE /users/{id}  ───────────────────────────────────────────────────
  Future<void> deleteUser(BuildContext context, UserModel user) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService
          .getDeleteApiResponse('${UserEndpoints.deleteUser}${user.id}');

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('User ${user.id} deleted successfully');
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchUsers(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error deleting user: $e'), context);
      _logger.e('Error deleting user: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Search / filter ────────────────────────────────────────────────────────
  void searchUsers(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterLists();
    notifyListeners();
  }

  void _filterLists() {
    if (_searchQuery.isEmpty) {
      filteredUsers = List.from(users);
    } else {
      filteredUsers = users.where((u) {
        final n = u.fullName?.toLowerCase() ?? '';
        final e = u.email?.toLowerCase() ?? '';
        return n.contains(_searchQuery) || e.contains(_searchQuery);
      }).toList();
    }
  }

  // ── Image picker ───────────────────────────────────────────────────────────
  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final compressedBytes = await FlutterImageCompress.compressWithFile(
        pickedFile.path,
        quality: 85,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes != null) {
        final tempDir = await Directory.systemTemp.createTemp();
        final file = File(
            '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(compressedBytes);
        selectedImage = file;
      } else {
        selectedImage = File(pickedFile.path);
      }
      notifyListeners();
    } catch (e) {
      _logger.e('Error picking image: $e');
    }
  }

  // ── Field helpers ──────────────────────────────────────────────────────────
  void setFields({
    String? name,
    String? email,
    String? phone,
    String? password,
    File? image,
  }) {
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
    selectedImage?.deleteSync();
    selectedImage = null;
    _searchQuery = '';
    _filterLists();
    notifyListeners();
  }
}