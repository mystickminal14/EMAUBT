import 'package:ema_app/constants/base_url.dart';

class QuizSetEndpoints {
  static const String quizSetList   = '${BaseUrl.baseUrl}/quiz-sets';
  static const String createQuizSet = '${BaseUrl.baseUrl}/quiz-sets';
  static const String quizSetDetail = '${BaseUrl.baseUrl}/quiz-sets/'; // append {id}
  static const String updateQuizSet = '${BaseUrl.baseUrl}/quiz-sets/'; // append {id}
  static const String deleteQuizSet = '${BaseUrl.baseUrl}/quiz-sets/'; // append {id}
  static const String baseUrl = '${BaseUrl.baseUrl}/quiz-sets';

  static String questionsList(int quizSetId) =>
      '$baseUrl/$quizSetId/questions';

  static String addQuestions(int quizSetId) =>
      '$baseUrl/$quizSetId/questions';

  static String updateQuestions(int quizSetId, int questionId) =>
      '$baseUrl/$quizSetId/questions/$questionId';

  static String deleteQuestions(int quizSetId, int questionId) =>
      '$baseUrl/$quizSetId/questions/$questionId';


}