/// Standard API response model for all API calls in the app
/// All responses from backend are normalized to this format
class StandardResponse<T> {
  final bool success;
  final String message;
  final T? data;

  StandardResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory StandardResponse.success(String message, {T? data}) {
    return StandardResponse(
      success: true,
      message: message,
      data: data,
    );
  }

  factory StandardResponse.error(String message, {T? data}) {
    return StandardResponse(
      success: false,
      message: message,
      data: data,
    );
  }

  factory StandardResponse.fromJson(Map<String, dynamic> json) {
    return StandardResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'],
    );

  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (data != null) 'data': data,
    };
  }

  @override
  String toString() {
    return 'StandardResponse(success: $success, message: $message, data: $data)';
  }
}

/// Helper function to normalize any API response to StandardResponse format
/// This ensures consistent response handling across the app
Map<String, dynamic> normalizeApiResponse(dynamic response, int statusCode) {
  // If response is already in standard format, return as is
  if (response is Map && response.containsKey('success')) {
    return Map<String, dynamic>.from(response);
  }

  // Handle 'status' field as alternative to 'success' (some endpoints use 'status': 'success'/'error')
  if (response is Map && response.containsKey('status')) {
    final statusValue = response['status'];
    final isSuccess = statusValue == true || statusValue == 'success';

    return {
      'success': isSuccess,
      'message': response['message']?.toString() ?? (isSuccess ? 'Operation successful' : 'Operation failed'),
      if (response.containsKey('data')) 'data': response['data'],
    };
  }

  // If response is a list, wrap it in standard format
  if (response is List) {
    return {
      'success': statusCode >= 200 && statusCode < 300,
      'message': statusCode >= 200 && statusCode < 300
          ? 'Data retrieved successfully'
          : 'Failed to retrieve data',
      'data': response,
    };
  }

  // For success status codes (200, 201), try to create success response
  if (statusCode == 200 || statusCode == 201) {
    if (response is Map) {
      return {
        'success': true,
        'message': response['message'] ?? 'Operation successful',
        'data': response.containsKey('data') ? response['data'] : response,
      };
    }
    return {
      'success': true,
      'message': 'Operation successful',
      'data': response,
    };
  }

  // For error status codes, create error response
  String errorMessage = 'Something went wrong';
  if (response is Map) {
    errorMessage = response['message']?.toString() ??
                 response['error']?.toString() ??
                 response['err']?.toString() ??
                 'Operation failed';
  }

  return {
    'success': false,
    'message': errorMessage,
  };
}
