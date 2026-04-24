import 'dart:convert';
import 'dart:io';
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

  Future<dynamic> login(String url, Map<String, dynamic> body) async {
    var logger = Logger();
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        logger.i("Login Response: ${response.body}");
      }

      // Fix: call returnResponse instead of using responseJson variable
      return returnResponse(response);

    } on SocketException {
      throw FetchDataException("No Internet Connection");
    }
  }
//for register
  Future<dynamic> postMultipartResponse(
      String url, Map<String, dynamic> fields, File? file) async {
    dynamic responseJson;
    var logger = Logger();
    try {
      final headers = await _getHeaders();
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..fields.addAll(
          fields.map((key, value) => MapEntry(key, value.toString())),
        );

      if (file != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
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
      throw FetchDataException("No Internet Connection");
    }
    return responseJson;
  }

  dynamic returnResponse(http.Response response, {BuildContext? context}) {
    var logger = Logger();

    try {
      final responseBody = jsonDecode(response.body);

      if (kDebugMode) {
        logger.i("Decoded JSON: $responseBody");
      }

      String errorMessage = "Something went wrong";

      if (responseBody is Map && responseBody.containsKey('err')) {
        errorMessage = responseBody['err'];
      } else if (responseBody is Map && responseBody.containsKey('message')) {
        errorMessage = responseBody['message'];
      }

      switch (response.statusCode) {
        case 200:
        case 201:
          return responseBody;
        case 400:
          throw BadRequestException(errorMessage);
        case 401:
          throw BadRequestException(errorMessage);
        case 402:
          throw UnAuthorizeException(errorMessage);
        case 403:
          throw FetchDataException(errorMessage);
        case 404:
          throw FetchDataException("Not Found: $errorMessage");
        case 500:
          throw FetchDataException("Internal Server Error: $errorMessage");
        default:
          if (context != null) {
            Utils.noInternet(errorMessage);
          }
          throw FetchDataException(
              'Error communicating with server. Status code: ${response.statusCode}');
      }
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
