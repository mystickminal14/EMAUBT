import 'package:ema_app/screens/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SessionManager {
  static const String _emailKey = 'email';
  static const String _userNameKey = 'user_name';
  static const String _userRoleKey = 'user_role';
  static const String _userImageKey = 'user_image';
  static const String _userIdKey = 'user_id';
  static const String _sessionTokenKey = 'session_token';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _loginTimestampKey = 'login_timestamp';
  
  // Session expiry duration (24 hours)
  static const int sessionDurationMs = 24 * 60 * 60 * 1000;
  
  // Save complete login session
  static Future<void> saveLoginSession({
    required String email,
    required Map<String, dynamic> userData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_emailKey, email);
    await prefs.setString(_userNameKey, userData['name'] ?? '');
    await prefs.setString(_userRoleKey, userData['role'] ?? '');
    await prefs.setString(_userImageKey, userData['image'] ?? '');
    await prefs.setString(_userIdKey, userData['user_id']?.toString() ?? '');
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setInt(_loginTimestampKey, DateTime.now().millisecondsSinceEpoch);
    
    // Save session token if provided by backend
    if (userData['session_token'] != null) {
      await prefs.setString(_sessionTokenKey, userData['session_token']);
    }
  }
  
  // Check if user is logged in and session is valid
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    final loginTimestamp = prefs.getInt(_loginTimestampKey);
    
    if (!isLoggedIn || loginTimestamp == null) {
      return false;
    }
    
    // Check if session has expired
    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionDuration = now - loginTimestamp;
    
    if (sessionDuration > sessionDurationMs) {
      await clearSession();
      return false;
    }
    
    return true;
  }
  
  // Get current user data
  static Future<Map<String, String?>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(_emailKey),
      'name': prefs.getString(_userNameKey),
      'role': prefs.getString(_userRoleKey),
      'image': prefs.getString(_userImageKey),
      'user_id': prefs.getString(_userIdKey),
      'session_token': prefs.getString(_sessionTokenKey),
    };
  }
  
  // Get specific user property
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }
  
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }
  
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }
  
  static Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }
  
  static Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionTokenKey);
  }
  
  // Clear all session data
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  // Logout with backend call and navigation
  static Future<void> logout(BuildContext context, {String? redirectRoute}) async {
    try {
      // Call backend logout endpoint
      await _callBackendLogout();
    } catch (e) {
      // Continue with logout even if backend call fails
      print('Backend logout failed: $e');
    }
    
    // Clear local session
    await clearSession();
    
    // Navigate to login or specified route
    if (redirectRoute != null) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        redirectRoute,
        (Route<dynamic> route) => false,
      );
    } else {
      // Import your LoginPage and use it here
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }
  
  // Call backend logout endpoint
  static Future<void> _callBackendLogout() async {
    try {
      final sessionToken = await getSessionToken();
      final userEmail = await getUserEmail();
      
      final Uri url = Uri.parse("https://theemaeducation.com/logout.php");
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
        },
        body: json.encode({
          'action': 'logout',
          'email': userEmail,
          'session_token': sessionToken,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('Backend logout successful');
      }
    } catch (e) {
      throw Exception('Backend logout failed: $e');
    }
  }
  
  // Update session timestamp (call this on app resume or important actions)
  static Future<void> updateSessionTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_isLoggedInKey) ?? false) {
      await prefs.setInt(_loginTimestampKey, DateTime.now().millisecondsSinceEpoch);
    }
  }
  
  // Check if session will expire soon (within 1 hour)
  static Future<bool> willSessionExpireSoon() async {
    final prefs = await SharedPreferences.getInstance();
    final loginTimestamp = prefs.getInt(_loginTimestampKey);
    
    if (loginTimestamp == null) return true;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionDuration = now - loginTimestamp;
    final remainingTime = sessionDurationMs - sessionDuration;
    
    return remainingTime < (60 * 60 * 1000); // Less than 1 hour remaining
  }
  
  // Extend session (useful for "Remember Me" functionality)
  static Future<void> extendSession() async {
    await updateSessionTimestamp();
  }
}