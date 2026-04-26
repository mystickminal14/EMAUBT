import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/data/network/NetworkApiService.dart';
import 'package:ema_app/model/user_data_model.dart';
import 'package:ema_app/model/admin_model.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:ema_app/utils/utils.dart';

class AdminManagementViewModel extends ChangeNotifier {
  final Logger _logger = Logger();
  final NetworkApiService _apiService = NetworkApiService();

  bool isLoading = true;
  List<Users> users = [];
  List<Admins> admins = [];
  List<Users> filteredUsers = [];
  List<Admins> filteredAdmins = [];
  String _searchQuery = '';

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
      _logger.i('Fetching users...');
      final response =
          await _apiService.getApiResponse('${BaseUrl.baseUrl}register.php');
      final userData = UserModelData.fromJson(response);
      if (userData.success == true && userData.users != null) {
        users = userData.users!;
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

  Future<void> fetchAdmins(BuildContext context) async {
    try {
      isLoading = true;
      notifyListeners();
      _logger.i('Fetching admins...');
      final response = await _apiService
          .getApiResponse('${BaseUrl.baseUrl}give_admin_access.php');
      final adminData = AdminModel.fromJson(response);
      if (adminData.success == true && adminData.admins != null) {
        admins = adminData.admins!;
        _filterLists();
        _logger.i('Fetched ${admins.length} admins');
      } else {
        admins = [];
        _filterLists();
        Utils.showApiResponse(response, context);
      }
    } catch (e) {
      admins = [];
      _filterLists();
      Utils.showApiResponse(Utils.errorResponse('Error fetching admins: $e'), context);
      _logger.e('Error fetching admins: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> grantAdminAccess(BuildContext context, Users user) async {
    try {
      _logger.i('Granting admin access to ${user.fullName}...');

      final response = await _apiService.postFormData(
        '${BaseUrl.baseUrl}give_admin_access.php',
        {
          'user_id': user.id ?? '',
          'full_name': user.fullName ?? 'No Name',
          'email': user.email ?? 'No Email',
          'action': 'grant',
        },
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        await Future.wait([
          fetchUsers(context),
          fetchAdmins(context),
        ]);
      } else {
        _logger.w('Failed to grant admin access: ${response['message']}');
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error granting admin access: $e'), context);
      _logger.e('Error granting admin access: $e');
    }
  }

  Future<void> removeAdminAccess(BuildContext context, Admins admin) async {
    try {
      _logger.i('Removing admin access from ${admin.fullName}...');

      final response = await _apiService.postFormData(
        '${BaseUrl.baseUrl}give_admin_access.php',
        {
          'user_id': admin.userId ?? '',
          'action': 'remove',
        },
      );

      Utils.showApiResponse(response, context);
      if (response['success'] == true) {
        await Future.wait([
          fetchUsers(context),
          fetchAdmins(context),
        ]);
      } else {
        _logger.w('Failed to remove admin access: ${response['message']}');
      }
    } catch (e) {
      Utils.showApiResponse(Utils.errorResponse('Error removing admin access: $e'), context);
      _logger.e('Error removing admin access: $e');
    }
  }

  void searchUsersAndAdmins(String query) {
    _searchQuery = query.trim().toLowerCase();
    _filterLists();
    notifyListeners();
    _logger.i('Searching users/admins with query: $_searchQuery');
  }

  void _filterLists() {
    if (_searchQuery.isEmpty) {
      filteredUsers = List.from(users);
      filteredAdmins = List.from(admins);
    } else {
      filteredUsers = users.where((user) {
        final name = user.fullName?.toLowerCase() ?? '';
        final email = user.email?.toLowerCase() ?? '';
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();

      filteredAdmins = admins.where((admin) {
        final name = admin.fullName?.toLowerCase() ?? '';
        final email = admin.email?.toLowerCase() ?? '';
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    }
    _logger.i(
        'Filtered ${filteredUsers.length} users and ${filteredAdmins.length} admins');
  }
}
