import 'package:ema_app/utils/utils.dart';

/// Standard API response model for all API calls in the app.
/// All responses from the backend are normalised to this format.
class StandardResponse<T> {
  final bool success;
  final String message;
  final T? data;

  StandardResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory StandardResponse.success(String message, {T? data}) =>
      StandardResponse(success: true, message: message, data: data);

  factory StandardResponse.error(String message, {T? data}) =>
      StandardResponse(success: false, message: message, data: data);

  factory StandardResponse.fromJson(Map<String, dynamic> json) =>
      StandardResponse(
        success: json['success'] == true,
        message: json['message']?.toString() ?? '',
        data: json['data'],
      );

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    if (data != null) 'data': data,
  };

  @override
  String toString() =>
      'StandardResponse(success: $success, message: $message, data: $data)';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Error message extractor
// ─────────────────────────────────────────────────────────────────────────────

/// Pulls the most meaningful error string out of any response body shape:
///   { "message": "..." }
///   { "error": "..." }
///   { "errors": { "email": ["taken"] } }   ← Laravel-style validation
///   { "errors": ["something wrong"] }
String _extractError(dynamic body, {String fallback = 'Something went wrong'}) {
  if (body is! Map) return fallback;

  final errors = body['errors'];

  // Plain string errors are most specific — check first
  // e.g. { "errors": "The email field is required." }
  if (errors is String && errors.isNotEmpty) return errors;

  // Prefer explicit error/err over generic message
  for (final key in ['error', 'err']) {
    final v = body[key];
    if (v is String && v.isNotEmpty) return v;
  }

  // Fall back to message only if no specific error found
  final msg = body['message'];
  if (msg is String && msg.isNotEmpty) return msg;

  // Laravel map: { "errors": { "email": ["already taken"] } }
  if (errors is Map && errors.isNotEmpty) {
    final firstValue = errors.values.first;
    if (firstValue is List && firstValue.isNotEmpty) {
      return firstValue.first.toString();
    }
    if (firstValue is String) return firstValue;
  }

  // Flat list: { "errors": ["msg1", "msg2"] }
  if (errors is List && errors.isNotEmpty) {
    return errors.first.toString();
  }

  return fallback;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main normaliser  (called by NetworkApiService._returnResponse)
// ─────────────────────────────────────────────────────────────────────────────

/// Converts any raw API response into a flat [Map<String, dynamic>] with the
/// keys `success`, `message`, and optionally `data`.
///
/// For 4xx / 5xx status codes the function:
///   1. Extracts a human-readable message.
///   2. Calls [Utils.noInternet] so the existing toast/snackbar fires.
///   3. Returns `{ success: false, message: "..." }` — never throws —
///      so ViewModels can keep using `response['success'] == true`.
Map<String, dynamic> normalizeApiResponse(dynamic body, int statusCode) {
  // ── 2xx — success path ───────────────────────────────────────────────────
  if (statusCode >= 200 && statusCode < 300) {
    // Already in standard format
    if (body is Map && body.containsKey('success')) {
      return Map<String, dynamic>.from(body);
    }

    // { status: 'success' } variant
    if (body is Map && body.containsKey('status')) {
      final isOk = body['status'] == true || body['status'] == 'success';
      return {
        'success': isOk,
        'message': body['message']?.toString() ??
            (isOk ? 'Operation successful' : 'Operation failed'),
        if (body.containsKey('data')) 'data': body['data'],
      };
    }

    // Raw list response
    if (body is List) {
      return {
        'success': true,
        'message': 'Data retrieved successfully',
        'data': body,
      };
    }

    // Plain map without success key
    if (body is Map) {
      return {
        'success': true,
        'message': body['message']?.toString() ?? 'Operation successful',
        'data': body.containsKey('data') ? body['data'] : body,
      };
    }

    return {'success': true, 'message': 'Operation successful', 'data': body};
  }

  // ── 4xx / 5xx — error path ───────────────────────────────────────────────
  final message = _extractError(body, fallback: _defaultMessage(statusCode));

  // Show the toast / snackbar just like the old returnResponse did
  Utils.noInternet(message);

  return {'success': false, 'message': message};
}

String _defaultMessage(int code) {
  switch (code) {
    case 400: return 'Bad request';
    case 401: return 'Unauthorised — please log in again';
    case 403: return 'Forbidden — you do not have permission';
    case 404: return 'Resource not found';
    case 409: return 'Conflict — resource already exists';
    case 422: return 'Validation failed';
    case 429: return 'Too many requests — please slow down';
    case 500: return 'Internal server error';
    case 502: return 'Bad gateway';
    case 503: return 'Service unavailable';
    default:  return 'Request failed (HTTP $code)';
  }
}