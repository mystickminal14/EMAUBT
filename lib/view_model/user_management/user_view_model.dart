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
  bool isFetchingMore = false;

  List<UserModel> users = [];
  List<UserModel> filteredUsers = [];
  String _searchQuery = '';

  // ── Pagination ─────────────────────────────────────────────────────────────
  int currentPage = 1;
  int totalPages = 1;   // mapped from API's "last_page"
  int totalUsers = 0;
  static const int perPage = 8;

  /// True while there are still pages left to load
  bool get hasMorePages => currentPage < totalPages;

  // ── Filter ─────────────────────────────────────────────────────────────────
  String? roleFilter; // 'user' | 'admin' | null
  Timer? _debounce;

  // ── Set role filter and fetch ──────────────────────────────────────────────
  void setRoleFilter(BuildContext context, String? role) {
    roleFilter = role;
    fetchUsers(context, refresh: true);
  }
  // ── Form fields ────────────────────────────────────────────────────────────
  File? selectedImage;
  String? name;
  String? email;
  String? phone;
  String? password;

  // ── Parse users list from response ────────────────────────────────────────
  List<UserModel> _parseUsers(Map<String, dynamic> response) {
    try {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final rawList = data['users'];
        if (rawList is List) {
          return rawList
              .map((e) => UserModel.fromJson(
              Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (e) {
      _logger.e('Error parsing users: $e');
    }
    return [];
  }

  // ── Parse pagination from response ────────────────────────────────────────
  // API shape:
  // { "data": { "pagination": { "total": 46, "current_page": 1,
  //                              "per_page": 8, "last_page": 6 } } }
  void _parsePagination(Map<String, dynamic> response) {
    try {
      final data       = response['data'] as Map<String, dynamic>? ?? {};
      final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

      totalUsers  = (pagination['total']        as num?)?.toInt() ?? totalUsers;
      currentPage = (pagination['current_page'] as num?)?.toInt() ?? currentPage;
      totalPages  = (pagination['last_page']    as num?)?.toInt() ?? totalPages;

      _logger.i('Pagination → page $currentPage / $totalPages, total $totalUsers');
    } catch (e) {
      _logger.e('Error parsing pagination: $e');
    }
  }

  // ── Build URL ─────────────────────────────────────────────────────────────
  String _buildUrl(int page) {
    final uri = Uri.parse(UserEndpoints.userList).replace(
      queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
        'sort_by': 'created_at',
        'sort_order': 'DESC',
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
        if (roleFilter != null) 'role': roleFilter!,
      },
    );
    return uri.toString();
  }

  // ── Initial / refresh fetch ───────────────────────────────────────────────
  Future<void> fetchUsers(BuildContext context, {bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      totalPages  = 1;
      totalUsers  = 0;
      users.clear();
      filteredUsers.clear();
    }

    isLoading = true;
    notifyListeners();

    try {
      final url = _buildUrl(currentPage);
      _logger.i('fetchUsers → $url');
      final response = await _apiService.getApiResponse(url);

      if (response['success'] == true) {
        _parsePagination(response);
        users = _parseUsers(response);   // replace on refresh / first load
        _filterLists();
        _logger.i('Loaded ${users.length} users (page $currentPage / $totalPages)');
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
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching users: $e'), context);
      _logger.e('fetchUsers error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Load next page (triggered by scroll) ──────────────────────────────────
  Future<void> fetchNextPage(BuildContext context) async {
    // Guards: never fire duplicate or unnecessary requests
    if (isFetchingMore || isLoading || !hasMorePages) return;

    isFetchingMore = true;
    notifyListeners();

    try {
      final nextPage = currentPage + 1;
      final url = _buildUrl(nextPage);
      _logger.i('fetchNextPage → page $nextPage → $url');

      final response = await _apiService.getApiResponse(url);

      if (response['success'] == true) {
        _parsePagination(response);          // updates currentPage & totalPages
        final fetched = _parseUsers(response);
        users.addAll(fetched);               // ← APPEND, never replace
        _filterLists();
        _logger.i('Appended ${fetched.length} — list total: ${users.length}');
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error loading more users: $e'), context);
      _logger.e('fetchNextPage error: $e');
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  // ── GET /users/me ─────────────────────────────────────────────────────────
  Future<UserModel?> fetchCurrentUser(BuildContext context) async {
    try {
      final response =
      await _apiService.getApiResponse(UserEndpoints.fetchUser);
      if (response['success'] == true) {
        final data    = response['data'] as Map<String, dynamic>? ?? {};
        final userMap = data['user'] as Map<String, dynamic>?;
        if (userMap != null) return UserModel.fromJson(userMap);
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching current user: $e'), context);
      _logger.e('fetchCurrentUser error: $e');
    }
    return null;
  }

  // ── GET /users/{id} ───────────────────────────────────────────────────────
  Future<UserModel?> fetchUserById(
      BuildContext context, dynamic userId) async {
    try {
      final response = await _apiService
          .getApiResponse('${UserEndpoints.userDetail}$userId');
      if (response['success'] == true) {
        final data    = response['data'] as Map<String, dynamic>? ?? {};
        final userMap = data['user'] as Map<String, dynamic>?;
        if (userMap != null) return UserModel.fromJson(userMap);
      } else {
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error fetching user: $e'), context);
      _logger.e('fetchUserById $userId error: $e');
    }
    return null;
  }

  // ── POST /register ────────────────────────────────────────────────────────
  Future<void> addUser(BuildContext context) async {
    if (name == null || name!.isEmpty ||
        email == null || email!.isEmpty ||
        phone == null || phone!.isEmpty ||
        password == null || password!.isEmpty) {
      Utils.showApiResponse(
          Utils.errorResponse(
              'Full Name, Email, Phone, and Password are required'),
          context);
      return;
    }

    if (users.any(
            (u) => u.email?.toLowerCase() == email!.toLowerCase())) {
      Utils.showApiResponse(
          Utils.errorResponse('Email already exists'), context);
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
      Utils.showApiResponse(
          Utils.errorResponse('Error adding user: $e'), context);
      _logger.e('addUser error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── PUT /users/{id} ───────────────────────────────────────────────────────
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
_logger.d(user);
      final body = <String, dynamic>{
        'full_name': name!,
        'phone': phone!,
        'email':email!,
        if (password != null && password!.isNotEmpty) 'password': password!,
      };

      final Map<String, dynamic> response;

        response = await _apiService.getPutResponse(
          '${UserEndpoints.updateUser}${user.id}',
          body,
        );


      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('User ${user.id} updated');
        clearFields();
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchUsers(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error updating user: $e'), context);
      _logger.e('editUser error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── DELETE /users/{id} ────────────────────────────────────────────────────
  Future<void> deleteUser(BuildContext context, UserModel user) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService
          .getDeleteApiResponse('${UserEndpoints.deleteUser}${user.id}');

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('User ${user.id} deleted');
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchUsers(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error deleting user: $e'), context);
      _logger.e('deleteUser error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeAdmin(BuildContext context, UserModel user) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService
          .getPostApiResponse('${UserEndpoints.removeAdmin}',{"user_id":"${user.id}"});

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('remove ${user.id} admin');
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchUsers(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error removing admin: $e'), context);
      _logger.e('Remove Admin error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  Future<void> makeAdmin(BuildContext context, UserModel user) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.getPostApiResponse(
        UserEndpoints.makeAdmin,
        {
          "user_id": user.id
        },
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('Make Admin to  ${user.id} ');
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchUsers(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error Make Admin: $e'), context);
      _logger.e('Make Admin error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }
  Future<void> changeUserPassword(BuildContext context, dynamic body) async {
    try {
      isActionLoading = true;
      notifyListeners();

      final response = await _apiService.getPostApiResponse(
        UserEndpoints.changeuserPassword,
        body
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        _logger.i('Change user password of ${body['user_id']} ');
        await Future.delayed(const Duration(milliseconds: 100));
        await fetchUsers(context, refresh: true);
      }
    } catch (e) {
      Utils.showApiResponse(
          Utils.errorResponse('Error change user password: $e'), context);
      _logger.e('change user password error: $e');
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  // ── Search / filter ───────────────────────────────────────────────────────
  void searchUsers(BuildContext context, String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      _searchQuery = query.trim(); // ✅ don't lowercase for API

      currentPage = 1;
      totalPages = 1;
      totalUsers = 0;
      users.clear();
      filteredUsers.clear();

      await fetchUsers(context, refresh: true); // ✅ API CALL
    });
  }
  void _filterLists() {
    filteredUsers = List.from(users);
  }

  // ── Image picker ──────────────────────────────────────────────────────────
  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile =
      await picker.pickImage(source: ImageSource.gallery);
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
        _logger.i('Image compressed: ${file.path}');
      } else {
        selectedImage = File(pickedFile.path);
        _logger.w('Compression failed, using original');
      }
      notifyListeners();
    } catch (e) {
      _logger.e('pickImage error: $e');
    }
  }

  // ── Field helpers ─────────────────────────────────────────────────────────
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