import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ema_app/data/api_exception.dart';
import 'package:ema_app/data/network/BaseApiService.dart';
import 'package:ema_app/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:logger/logger.dart';

class NetworkApiService extends BaseApiServices {
  final Logger _logger = Logger();

  Map<String, String> _getHeaders() {
    return {
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
  }

  @override
  Future getApiResponse(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: _getHeaders()).timeout(const Duration(seconds: 15));
      _logger.i('GET $url: ${response.statusCode}');
      return _returnResponse(response);
    } on SocketException {
      Utils.noInternet('No internet connection');
      throw FetchDataException("No internet Connection");
    }
  }

  @override
  Future getPostApiResponse(String url, dynamic body) async {
    try {
      final response = await http.post(Uri.parse(url), headers: _getHeaders(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      _logger.i('POST $url: ${response.statusCode}');
      return _returnResponse(response);
    } on SocketException {
      Utils.noInternet('No internet connection');
      throw FetchDataException("No internet Connection");
    }
  }

  @override
  Future<Map<String, dynamic>> postFormData(String url, Map<String, String> fields) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields.addAll(fields);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _logger.i('Form-data POST $url: ${response.statusCode}');

      if (response.body.isEmpty) return {};

      dynamic responseBody;
      try {
        responseBody = jsonDecode(response.body);
      } on FormatException catch (e, stack) {
        _logger.e('⛔ Invalid JSON response from server: ${response.body}', error: e, stackTrace: stack);
        throw FormatException('Invalid JSON response from server');
      }

      if (response.statusCode == 200 || response.statusCode == 201) return responseBody;
      throw FetchDataException('Error communicating with server. Status code: ${response.statusCode}');
    } on SocketException {
      Utils.noInternet('No internet connection');
      throw FetchDataException("No internet Connection");
    }
  }

  @override
  Future postMultipartResponse(String url, Map<String, dynamic> fields, File? file) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(_getHeaders());
      request.fields.addAll(fields.map((key, value) => MapEntry(key, value.toString())));

      if (file != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'icon',
          file.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _logger.i('Multipart POST $url: ${response.statusCode}');
      return _returnResponse(response);
    } on SocketException {
      Utils.noInternet('No internet connection');
      throw FetchDataException("No internet Connection");
    }
  }

  Future<Map<String, dynamic>> postFileMultipart(
      String url,
      Map<String, dynamic> fields, {
        String? mainFilePath,
        Uint8List? mainFileBytes,
        String? mainFileName,
        File? iconFile,
        Uint8List? iconBytes,
        String? iconName,
      }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(_getHeaders());
      request.fields.addAll(fields.map((key, value) => MapEntry(key, value.toString())));

      if (mainFilePath != null || mainFileBytes != null) {
        String extension = mainFileName?.split('.').last.toLowerCase() ??
            (mainFilePath?.split('.').last.toLowerCase() ?? 'bin');
        String mimeType = _getMimeType(extension);
        if (mainFileBytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'file',
            mainFileBytes,
            filename: mainFileName ?? 'file',
            contentType: MediaType.parse(mimeType),
          ));
        } else if (mainFilePath != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'file',
            mainFilePath,
            filename: mainFileName ?? mainFilePath.split('/').last,
            contentType: MediaType.parse(mimeType),
          ));
        }
      }

      if (iconBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'icon',
          iconBytes,
          filename: iconName ?? 'icon.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      } else if (iconFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'icon',
          iconFile.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _logger.i('Files Multipart POST $url: ${response.statusCode}');
      return _returnResponse(response);
    } on SocketException {
      Utils.noInternet('No internet connection');
      throw FetchDataException("No internet Connection");
    }
  }

  Future<Map<String, dynamic>> postMultipartNoticeFiles(
      String url,
      Map<String, dynamic> fields, {
        List<PlatformFile>? files,
        required String fieldName,
      }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(_getHeaders());
      request.fields.addAll(fields.map((key, value) => MapEntry(key, value.toString())));

      if (files != null && files.isNotEmpty) {
        for (var file in files) {
          if (file.bytes != null) {
            request.files.add(http.MultipartFile.fromBytes(
              fieldName,
              file.bytes!,
              filename: file.name,
              contentType: MediaType.parse(_getMimeType(file.extension ?? 'bin')),
            ));
          } else if (file.path != null) {
            request.files.add(await http.MultipartFile.fromPath(
              fieldName,
              file.path!,
              filename: file.name,
              contentType: MediaType.parse(_getMimeType(file.extension ?? 'bin')),
            ));
          }
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _logger.i('Notice Multipart POST $url: ${response.statusCode}');
      return _returnResponse(response);
    } on SocketException {
      Utils.noInternet('No internet connection');
      throw FetchDataException("No internet Connection");
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'm4a':
        return 'audio/mp4';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'flv':
        return 'video/x-flv';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'rtf':
        return 'application/rtf';
      case 'odt':
        return 'application/vnd.oasis.opendocument.text';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'html':
        return 'text/html';
      default:
        return 'application/octet-stream';
    }
  }

  dynamic _returnResponse(http.Response response) {
    if (response.body.isEmpty) {
      _logger.w('Empty response from server for ${response.request?.url}');
      return {};
    }

    dynamic responseBody;
    try {
      responseBody = jsonDecode(response.body);
    } on FormatException catch (e, stack) {
      _logger.e('⛔ Invalid JSON response from server: ${response.body}', error: e, stackTrace: stack);
      throw FormatException('Invalid JSON response from server');
    }

    switch (response.statusCode) {
      case 200:
      case 201:
        return responseBody;
      case 400:
        throw BadRequestException(responseBody['message'] ?? 'Bad Request');
      case 401:
        throw UnAuthorizeException(responseBody['message'] ?? 'Unauthorized');
      case 404:
        throw NoDataException(responseBody['message'] ?? 'Not Found');
      case 500:
        throw FetchDataException(responseBody['message'] ?? 'Internal Server Error');
      default:
        throw FetchDataException('Error communicating with server. Status code: ${response.statusCode}');
    }
  }

  @override
  Future getPutResponse(String url, dynamic data) async {
    try {
      final response = await http.put(Uri.parse(url), headers: _getHeaders(), body: jsonEncode(data))
          .timeout(const Duration(seconds: 15));
      _logger.i('PUT $url: ${response.statusCode}');
      return _returnResponse(response);
    } on SocketException {
      Utils.noInternet('No internet connection');
      throw FetchDataException("No internet Connection");
    }
  }

  @override
  Future getDeleteApiResponse(String url) async {
    try {
      final response = await http.delete(Uri.parse(url), headers: _getHeaders());
      _logger.i('DELETE $url: ${response.statusCode}');
      return _returnResponse(response);
    } on SocketException {
      Utils.noInternet('No internet connection');
      throw FetchDataException("No internet Connection");
    }
  }
}