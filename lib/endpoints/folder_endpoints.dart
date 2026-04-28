import 'package:ema_app/constants/base_url.dart';

class FolderEndpoints {

  static const String folderList   = '${BaseUrl.baseUrl}/folders';
  static const String createFolder = '${BaseUrl.baseUrl}/folders';
  static const String folderDetail = '${BaseUrl.baseUrl}/folders/';   // append {id}
  static const String updateFolder = '${BaseUrl.baseUrl}/folders/';   // append {id}
  static const String deleteFolder = '${BaseUrl.baseUrl}/folders/';   // append {id}
}