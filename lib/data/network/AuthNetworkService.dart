import 'dart:convert';
import 'dart:io';
import 'package:ema_app/model/user_model.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'package:ema_app/data/standard_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:logger/logger.dart';
import '../../utils/utils.dart';
import '../api_exception.dart';

class AuthNetworkApiService {
  Future<Map<String, String>> _getHeaders() async {
    return {
      HttpHeaders.acceptHeader: "application/json",
      HttpHeaders.contentTypeHeader: "application/json",
    };
  }


  Future<Map<String, dynamic>> login(String url, Map<String, dynamic> body) async {
    var logger = Logger();

    try {
      final headers = await _getHeaders();

      if (kDebugMode) {
        logger.i("🚀 Sending login request...");
        logger.i("📤 Request Headers: $headers");
        logger.i("📦 Request Body: $body");
      }

      final response = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        logger.i("📥 Response Status: ${response.statusCode}");
        logger.i("📥 Response Body: ${response.body}");
        logger.i("🍪 Response Headers: ${response.headers}");
      }

      final responseBody = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : {};

      final normalizedResponse =
      normalizeApiResponse(responseBody, response.statusCode);

      logger.i("ews ${responseBody}");
      // =========================
      // 🔐 SESSION EXTRACTION LOGIC
      // =========================
      String? session;
      final setCookie = response.headers['set-cookie'];

      if (kDebugMode) {
        logger.i("🍪 Set-Cookie raw header: $setCookie");
      }

      if (setCookie != null && setCookie.isNotEmpty) {
        final cookies = setCookie.split(',');

        for (var cookie in cookies) {
          if (cookie.contains('EMA_SESSION')) {
            session = cookie.split(';')[0].split('=')[1];

            if (kDebugMode) {
              logger.i("✅ EMA_SESSION FOUND in cookie: $session");
            }
            break;
          }
        }
      } else {
        if (kDebugMode) {
          logger.w("⚠️ No Set-Cookie header received from server");
        }
      }

      // =========================
      // 💾 SAVE SESSION TRACE
      // =========================
      if (normalizedResponse['success'] == true) {
        if (session != null && session.isNotEmpty) {
          if (kDebugMode) {
            logger.i("💾 Saving session to SharedPreferences...");
          }

          UserModel user = UserModel(
            phone: responseBody['data']['phone'],
            role: responseBody['data']['role'],
            email: responseBody['data']['email'],
            image: responseBody['data']['image'],
            fullName: responseBody['data']['full_name'],
            csrf: responseBody['data']['csrf_token'],
          );

          final saved = await UserViewModel().saveUser(user, session: session);

          if (kDebugMode) {
            logger.i(saved
                ? "✅ User + session saved successfully"
                : "❌ Failed to save user/session");
          }
        } else {
          if (kDebugMode) {
            logger.e("❌ Login success but session is NULL");
          }
        }
      }

      return normalizedResponse;
    } on SocketException {
      return {'success': false, 'message': 'No Internet Connection'};
    }
  }
//for register
  Future<Map<String, dynamic>> postMultipartResponse(
      String url, Map<String, dynamic> fields, File? file) async {
    Map<String, dynamic> responseJson;
    var logger = Logger();
    try {
      if (kDebugMode) {
        logger.d('Multipart Request Fields: $fields');
      }
      final headers = await _getHeaders();
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..fields.addAll(
          fields.map((key, value) => MapEntry(key, value.toString())),
        );

      if (file != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_image',
          file.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      if (kDebugMode) {
        logger.d('Multipart Request Fields: ${request.fields}');
        logger.d('Multipart Request Files: ${request.files.map((f) => f.filename)}');
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        logger.i('Response Status: ${response.statusCode}');
        logger.d('Response Body: ${response.body}');
      }

      responseJson = returnResponse(response);
    } on SocketException {
      Utils.noInternet('No internet connection');
      responseJson = {'success': false, 'message': 'No Internet Connection'};
    }
    return responseJson;
  }

  Map<String, dynamic> returnResponse(http.Response response, {BuildContext? context}) {
    var logger = Logger();

    try {
      if (response.body.isEmpty) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          return {'success': true, 'message': 'Operation successful', 'data': {}};
        }
        return {'success': false, 'message': 'Empty response from server'};
      }

      final responseBody = jsonDecode(response.body);

      if (kDebugMode) {
        logger.i("Decoded JSON: $responseBody");
      }

      // Normalize response to standard format
      return normalizeApiResponse(responseBody, response.statusCode);
    } catch (e) {
      if (kDebugMode) {
        logger.e("Non-JSON response: ${response.body}");
      }

      // Handle known duplicate email error
      if (response.body.contains("Duplicate entry")) {
        return {
          "success": false,
          "message": "Email already exists",
        };
      }

      return {
        "success": false,
        "message": "Unexpected server error",
      };
    }
  }

}
