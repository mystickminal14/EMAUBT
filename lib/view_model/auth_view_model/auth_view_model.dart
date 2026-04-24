import 'dart:async';
import 'package:ema_app/data/network/AuthNetworkService.dart';
import 'package:ema_app/endpoints/auth_endpoints.dart';
import 'package:ema_app/screens/admin/admin_dashboard_page.dart';
import 'package:ema_app/screens/users/user_home_page.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import '../../model/user_model.dart';
import '../../data/api_response.dart';
import '../../utils/utils.dart';

class AuthViewModel with ChangeNotifier {
  final Logger logger = Logger();
  final AuthNetworkApiService _authService = AuthNetworkApiService();
  final UserViewModel _userViewModel = UserViewModel();

  ApiResponse<UserModel> userData = ApiResponse.loading();
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setUser(ApiResponse<UserModel> response) {
    userData = response;
    notifyListeners();
  }


  Future<void> login(Map<String, dynamic> body, BuildContext context) async {
    FocusScope.of(context).unfocus();
    setLoading(true);

    final url = AuthEndpoints.login;
    if (kDebugMode) {
      logger.i("Attempting login with email: ${body['email']}");
    }

    try {
      final response = await _authService.login(url, body).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("The connection has timed out, please try again.");
        },
      );

      if (kDebugMode) {
        logger.i("Login response: $response");
      }

      if (response['success'] == true) {
        final user = UserModel.fromJson(response);
        if (kDebugMode) {
          logger.i("User logged in: $user.");
        }

        final saved = await _userViewModel.saveUser(user);
        if (kDebugMode && saved) {
          logger.i("User saved successfully in SharedPreferences.");
        }

        setUser(ApiResponse.completed(user));
        Utils.flushBarSuccessMessage("Welcome ${user.fullName}", context);

        // Navigate based on role
        if (user.role == 'admin') {
          if (kDebugMode) {
            logger.i("Navigating to AdminDashboardPage");
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardPage(
                fullName: user.fullName ?? '',
                profileImage: user.image ?? '',
                isAdmin: true,
                userEmail: user.email ?? '',
              ),
            ),
          );
        } else {
          if (kDebugMode) {
            logger.i("Navigating to UserHomePage");
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UserHomePage(
                fullName: user.fullName ?? '',
                profileImage: user.image ?? '',
                isAdmin: false,
                userEmail: user.email ?? '',
                userIdentifier: '',
                folderId: null,
                folderName: '',
              ),
            ),
          );
        }
      } else {
        if (kDebugMode) {
          logger.w("Login failed: ${response['message']}");
        }
        setUser(ApiResponse.error("Login failed"));
        Utils.flushBarErrorMessage(response['message'] ?? "Login failed", context);
      }
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        logger.e("Login timeout: $e");
      }
      setUser(ApiResponse.error("Request timed out"));
      Utils.flushBarErrorMessage("Request timed out. Please check your internet connection.", context);
    } catch (e) {
      if (kDebugMode) {
        logger.e("Login error: $e");
      }
      setUser(ApiResponse.error(e.toString()));
      Utils.flushBarErrorMessage("Error: $e", context);
    } finally {
      setLoading(false);
    }
  }

}
