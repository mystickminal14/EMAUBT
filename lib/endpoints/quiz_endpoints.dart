import 'package:ema_app/constants/base_url.dart';

class QuizSetEndpoints {
  static const String quizSetList   = '${BaseUrl.baseUrl}/quiz-sets';
  static const String createQuizSet = '${BaseUrl.baseUrl}/quiz-sets';
  static const String quizSetDetail = '${BaseUrl.baseUrl}/quiz-sets/'; // append {id}
  static const String updateQuizSet = '${BaseUrl.baseUrl}/quiz-sets/'; // append {id}
  static const String deleteQuizSet = '${BaseUrl.baseUrl}/quiz-sets/'; // append {id}
}