import 'package:shared_preferences/shared_preferences.dart';

Future<Map<String, String>> getAuthHeaders() async {
  final sp = await SharedPreferences.getInstance();
  final session = sp.getString('session');
  final csrf = sp.getString('csrf');

  final headers = <String, String>{};

  if (session != null && session.isNotEmpty) {
    headers['Cookie'] = 'EMA_SESSION=$session';
  }

  if (csrf != null && csrf.isNotEmpty) {
    headers['X-CSRF-Token'] = csrf;
  }

  return headers;
}