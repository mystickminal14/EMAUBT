import 'package:ema_app/constants/base_url.dart';

class QuizSetEndpoints {
  static const String quizSetList   = '${BaseUrl.baseUrl}/quiz-sets';
  static const String createQuizSet = '${BaseUrl.baseUrl}/quiz-sets';
  static const String quizSetDetail = '${BaseUrl.baseUrl}/quiz-sets/'; // append {id}
  static const String updateQuizSet = '${BaseUrl.baseUrl}/quiz-sets/'; // append {id}
  static const String deleteQuizSet = '${BaseUrl.baseUrl}/quiz-sets/'; // append {id}
  static String questionsList (id) =>  '${BaseUrl.baseUrl}/quiz-sets/${id}/questions';
  static String addQuestions (id) =>  '${BaseUrl.baseUrl}/quiz-sets/${id}/questions';
  static String updateQuestions (quizSetId, questionId) =>  '${BaseUrl.baseUrl}/quiz-sets/$quizSetId/questions/$questionId';
  static String deleteQuestions (quizSetId, questionId) =>  '${BaseUrl.baseUrl}/questions/$quizSetId/questions/$questionId';


}