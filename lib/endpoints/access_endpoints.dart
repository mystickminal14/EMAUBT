import 'package:ema_app/constants/base_url.dart';

class AccessEndpoints {
  static const String batchCheck  = '${BaseUrl.baseUrl}/access/batch-check';
  static const String grant       = '${BaseUrl.baseUrl}/access/grant';
  static const String permissions = '${BaseUrl.baseUrl}/access/permissions';
  static const String allUsers    = '${BaseUrl.baseUrl}/access/all-users';
  static const String loginUsers  = '${BaseUrl.baseUrl}/access/login-users';
}