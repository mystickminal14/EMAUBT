import 'dart:io';

abstract class BaseApiServices {
  Future<dynamic> getApiResponse(String url);
  Future<dynamic> getPostApiResponse(String url, dynamic body);
  Future<Map<String, dynamic>> postFormData(String url, Map<String, String> fields);
  Future<dynamic> postMultipartResponse(String url, Map<String, dynamic> fields, File? file);
  Future<dynamic> getPutResponse(String url, dynamic data);
  Future<dynamic> getDeleteApiResponse(String url);
}
