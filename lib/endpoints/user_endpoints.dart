import '../constants/base_url.dart';
class UserEndpoints{
  static var fetchUser = '${BaseUrl.baseUrl}users/me';
  static var userDetail = '${BaseUrl.baseUrl}users/';
  static var userList = '${BaseUrl.baseUrl}users/view';
}
