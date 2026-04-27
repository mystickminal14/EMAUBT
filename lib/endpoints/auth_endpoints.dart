import '../constants/base_url.dart';
class AuthEndpoints{
  static var login = '${BaseUrl.baseUrl}/auth/login';
  static var register = '${BaseUrl.baseUrl}/auth/register';
  static var logout = '${BaseUrl.baseUrl}/auth/logout';
  static var changePassword = '${BaseUrl.baseUrl}/auth/change-password';
  static var resetPassword = '${BaseUrl.baseUrl}/auth/reset-password';
  static var forgetPassword = '${BaseUrl.baseUrl}/auth/forget-password';
}
""