
import 'package:ema_app/constants/base_url.dart';

class NoticeEndpoints {
  static const String _base = '${BaseUrl.baseUrl}/notices';

  static const String noticeList   = _base;
  static const String createNotice = _base;

  /// GET  /api/notices/{id}
  static String noticeDetail(String id) => '$_base/$id';

  /// POST /api/notices/{id}   (update)
  static String updateNotice(String id) => '$_base/$id';

  /// DELETE /api/notices/{id}
  static String deleteNotice(String id) => '$_base/$id';
}