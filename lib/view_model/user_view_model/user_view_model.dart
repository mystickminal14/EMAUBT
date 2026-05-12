import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../../../model/user_model.dart';

class UserViewModel with ChangeNotifier {
  final Logger logger = Logger();

  Future<bool> saveUser(UserModel user, {String? session}) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.setString('session', session ?? '');

      if (kDebugMode) {
        logger.i("💾 SESSION SAVED: $session");
        logger.i("📧 Email: ${user.email}");
        logger.i("📧 CSRF: ${user.csrf}");

        logger.i("👤 Name: ${user.fullName}");
        logger.i("id : ${user.id.toString()}");
      }
      await prefs.setString('id', user.id.toString() ?? '');
      await prefs.setString('email', user.email ?? '');
      await prefs.setString('csrf', user.csrf ?? '');
      await prefs.setString('user_name', user.fullName ?? '');
      await prefs.setString('user_role', user.role ?? '');
      await prefs.setString('user_image', user.image ?? '');
      await prefs.setBool('is_logged_in', true);
      await prefs.setInt(
          'login_timestamp', DateTime.now().millisecondsSinceEpoch);

      return true;
    } catch (e) {
      logger.e("❌ Error saving user/session: $e");
      return false;
    }
  }

  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('is_logged_in')) return null;

    return UserModel(
      // session: prefs.getString('session'),
      id: int.tryParse(prefs.getString('id') ?? '') ?? 0,
      email: prefs.getString('email'),
      fullName: prefs.getString('user_name'),
      role: prefs.getString('user_role'),
      image: prefs.getString('user_image'),
      success: prefs.getBool('is_logged_in'),
    );
  }

  Future<bool> removeUser() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.clear();
  }
  Future<bool> isAuthenticated() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    return sp.getString('session') != null;
  }
  Future<String?> getRole() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    return sp.getString('role');
  }
}
