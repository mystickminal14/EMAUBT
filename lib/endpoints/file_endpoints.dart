import 'package:ema_app/constants/base_url.dart';

class FileEndpoints {
  static const String uploadFile   = '${BaseUrl.baseUrl}/files/upload';
  static const String fileDetail   = '${BaseUrl.baseUrl}/files/';     // append {id}
  static const String deleteFile   = '${BaseUrl.baseUrl}/files/';     // append {id}
  static const String downloadFile = '${BaseUrl.baseUrl}/files/';     // append {id}/download
}