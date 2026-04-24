import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../../../model/user_model.dart';

class UserViewModel with ChangeNotifier {
  final Logger logger = Logger();

  Future<bool> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString('session', user.session ?? '');
      await prefs.setString('email', user.email ?? '');
      await prefs.setString('user_name', user.fullName ?? '');
      await prefs.setString('user_role', user.role ?? '');
      await prefs.setString('user_image', user.image ?? '');
      await prefs.setBool('is_logged_in', true);
      await prefs.setInt('login_timestamp', DateTime.now().millisecondsSinceEpoch);
      logger.i("User saved in SharedPreferences: ${user.email}");
      return true;
    } catch (e) {
      logger.e("Error saving user: $e");
      return false;
    }
  }

  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('is_logged_in')) return null;

    return UserModel(
      session: prefs.getString('session'),
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
