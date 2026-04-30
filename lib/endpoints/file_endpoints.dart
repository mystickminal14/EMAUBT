import 'package:ema_app/constants/base_url.dart';

class FileEndpoints {
  FileEndpoints._();

  static const String uploadFile   = '${BaseUrl.baseUrl}/files/upload';
  static const String fileDetail   = '${BaseUrl.baseUrl}/files/';       // append {id}
  static const String deleteFile   = '${BaseUrl.baseUrl}/files/';       // append {id}
  static const String downloadFile = '${BaseUrl.baseUrl}/files/';       // append {id}/download
  static const String editFIle = '${BaseUrl.baseUrl}/files/';       // append {id}/download

  /// GET /api/folder/{folderId}/files?page=1&per_page=15&search=...
  static String folderFiles(int folderId) =>
      '${BaseUrl.baseUrl}/folders/$folderId/files';
}