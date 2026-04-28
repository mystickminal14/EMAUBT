import 'package:ema_app/constants/base_url.dart';

class UserEndpoints {
  static var userList      = '${BaseUrl.baseUrl}/users';
  static var fetchUser     = '${BaseUrl.baseUrl}/users/me';
  static var userDetail    = '${BaseUrl.baseUrl}/users/';
  static var registerUser  = '${BaseUrl.baseUrl}/auth/register';
  static var updateUser    = '${BaseUrl.baseUrl}/users/';
  static var deleteUser    = '${BaseUrl.baseUrl}/users/';
}