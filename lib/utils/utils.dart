import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';

import '../data/standard_response.dart';
import '../resource/colors.dart';


class Utils {

  static void noInternet(String message) {
    Flushbar(
      message: message,
      backgroundColor: Colors.red,
      title: 'Error',
      messageColor: Colors.black,
      duration: const Duration(seconds: 3),
      icon: const Icon(
        Icons.error,
        size: 28.0,
        color: Colors.white,
      ),
      leftBarIndicatorColor: Colors.redAccent,
      animationDuration: const Duration(milliseconds: 2000),
      isDismissible: true,
      flushbarPosition: FlushbarPosition.BOTTOM,
      flushbarStyle: FlushbarStyle.FLOATING,
      forwardAnimationCurve: Curves.easeInOut,
    );
  }
  static void flushBarErrorMessage(String message, BuildContext context) {
    Flushbar(
      message: message,
      backgroundColor: Colors.red,
      title: 'Error',
      messageColor: Colors.black,
      duration: const Duration(seconds: 4),
      icon: const Icon(
        Icons.error,
        size: 28.0,
        color: Colors.white,
      ),
      leftBarIndicatorColor: Colors.redAccent,
      animationDuration: const Duration(milliseconds: 2000),
      isDismissible: true,
      flushbarPosition: FlushbarPosition.BOTTOM,
      flushbarStyle: FlushbarStyle.FLOATING,
      forwardAnimationCurve: Curves.easeInOut,
    ).show(context);
  }
  static void flushBarSuccessMessage(String message, BuildContext context) {
    Flushbar(
      message: message,
      backgroundColor: AppColors.primary,
      title: 'Success',
      messageColor: Colors.white,
      duration: const Duration(seconds: 2),
      icon: const Icon(
        Icons.check,
        size: 28.0,
        color: Colors.white,
      ),
      leftBarIndicatorColor:AppColors.primary,
      animationDuration: const Duration(milliseconds: 500),
      isDismissible: true,
      flushbarPosition: FlushbarPosition.BOTTOM,
      flushbarStyle: FlushbarStyle.FLOATING,
      forwardAnimationCurve: Curves.easeInOut,
    ).show(context);
  }

  static void fieldFocusChange(String message, BuildContext context, FocusNode current, FocusNode nextFocus){
    current.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  /// Shows a snackbar based on the standardized API response format
  /// Automatically detects success/error from the response
  static void showApiResponse(Map<String, dynamic> response, BuildContext context) {
    if (!context.mounted) return;

    final success = response['success'] == true;
    final message = response['message']?.toString() ?? (success ? 'Operation successful' : 'Operation failed');

    if (success) {
      flushBarSuccessMessage(message, context);
    } else {
      flushBarErrorMessage(message, context);
    }
  }

  /// Shows a SnackBar based on the standardized API response format
  /// Alternative to Flushbar for simple snackbar usage
  static void showSnackBarResponse(Map<String, dynamic> response, BuildContext context) {
    if (!context.mounted) return;

    final success = response['success'] == true;
    final message = response['message']?.toString() ?? (success ? 'Operation successful' : 'Operation failed');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Creates a StandardResponse for success
  static Map<String, dynamic> successResponse(String message, {dynamic data}) {
    return StandardResponse.success(message, data: data).toJson();
  }

  /// Creates a StandardResponse for error
  static Map<String, dynamic> errorResponse(String message) {
    return StandardResponse.error(message).toJson();
  }

}
