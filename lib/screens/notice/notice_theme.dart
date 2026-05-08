import 'package:flutter/material.dart';

class NoticeTheme {
  NoticeTheme._();

  static const Color accent   = Color(0xFF4F6AF5);
  static const Color surface  = Color(0xFFF7F8FC);
  static const Color cardBg   = Colors.white;
  static const Color textMain = Color(0xFF1A1E2C);
  static const Color textSub  = Color(0xFF7A8099);
  static const Color divider  = Color(0xFFEEF0F6);
  static const Color chip     = Color(0xFFEEF1FD);
  static const Color danger   = Color(0xFFE53935);

  static const TextStyle screenTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: textMain,
    letterSpacing: -0.5,
  );

  static const TextStyle screenSubtitle = TextStyle(
    fontSize: 13,
    color: textSub,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: textMain,
  );

  static const TextStyle cardBody = TextStyle(
    fontSize: 13,
    color: textSub,
    height: 1.5,
  );

  static const TextStyle dateLabel = TextStyle(
    fontSize: 11,
    color: textSub,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle fabLabel = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
    fontSize: 14,
  );

  static const TextStyle emptyTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: textMain,
  );

  static const TextStyle emptySubtitle = TextStyle(
    fontSize: 13,
    color: textSub,
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}