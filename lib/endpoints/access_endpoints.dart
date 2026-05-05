import 'package:ema_app/constants/base_url.dart';

class AccessEndpoints {
  static const String batchCheck  = '${BaseUrl.baseUrl}/access/batch-check';
  static const String grant       = '${BaseUrl.baseUrl}/access/grant';
  static const String bulkOperations = '${BaseUrl.baseUrl}/admin/bulk-operations';
  static String fileAssignType(int fileId) =>
      '${BaseUrl.baseUrl}/admin/files/$fileId/access-type';
  static String quizSetAssignType(int quizSetId) =>
      '${BaseUrl.baseUrl}/admin/quiz-sets/$quizSetId/access-type';
  static String userGrantedFiles(int uid) => '${BaseUrl.baseUrl}/admin/users/$uid/files/granted';
  static String userNotGrantedFiles(int uid) => '${BaseUrl.baseUrl}/admin/users/$uid/files/not-granted';
  static String userGrantedQuizSets(int uid) => '${BaseUrl.baseUrl}/admin/users/$uid/quiz-sets/granted';
  static String userNotGrantedQuizSets(int uid) => '${BaseUrl.baseUrl}/admin/users/$uid/quiz-sets/not-granted';
}