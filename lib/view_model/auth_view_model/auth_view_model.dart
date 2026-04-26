import 'dart:async';
import 'dart:io';
import 'package:ema_app/data/network/AuthNetworkService.dart';
import 'package:ema_app/endpoints/auth_endpoints.dart';
import 'package:ema_app/screens/admin/admin_dashboard_page.dart';
import 'package:ema_app/screens/auth/login_page.dart';
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
          throw TimeoutException(
              "The connection has timed out, please try again.");
        },
      );

      if (kDebugMode) {
        logger.i("Login response: $response");
      }

      if (response['success'] == true) {
        // Extract user data from the response
        final userData = response['data'] ?? response;
        final user = UserModel.fromJson(userData);
        if (kDebugMode) {
          logger.i("User logged in: $user.");
        }

        final saved = await _userViewModel.saveUser(user);
        if (kDebugMode && saved) {
          logger.i("User saved successfully in SharedPreferences.");
        }

        setUser(ApiResponse.completed(user));
        Utils.showApiResponse(response, context);

        // Navigate based on role
        if (user.role == 'admin') {
          if (kDebugMode) {
            logger.i("Navigating to AdminDashboardPage");
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AdminDashboardPage(
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
              builder: (_) =>
                  UserHomePage(
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
        Utils.showApiResponse(response, context);
      }
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        logger.e("Login timeout: $e");
      }
      setUser(ApiResponse.error("Request timed out"));
      Utils.flushBarErrorMessage(
          "Request timed out. Please check your internet connection.", context);
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

  Future<void> register(Map<String, dynamic> body, File image,
      BuildContext context) async {
    FocusScope.of(context).unfocus();
    setLoading(true);

    try {
      final response = await _authService.postMultipartResponse(
        AuthEndpoints.register,
        body,
        image,
      );

      logger.d('Server response: $response');

      if (response['success'] == true) {
        logger.i('Registration successful for ${body['email']}');
        Utils.showApiResponse(response, context);

        await Future.delayed(const Duration(seconds: 2));

        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      } else {
        logger.w('Registration failed: ${response['message']}');
        Utils.showApiResponse(response, context);
      }
    } on TimeoutException catch (e) {
      logger.e("Register timeout: $e");
      Utils.showApiResponse(Utils.errorResponse("Request timed out. Please check your internet connection."), context);
    } on SocketException {
      logger.e("No internet connection during registration");
      Utils.showApiResponse(Utils.errorResponse("No internet connection"), context);
    } catch (e, st) {
      logger.e('Registration error', error: e, stackTrace: st);
      Utils.showApiResponse(Utils.errorResponse("Error: ${e.toString()}"), context);
    } finally {
      setLoading(false);
    }
  }
}