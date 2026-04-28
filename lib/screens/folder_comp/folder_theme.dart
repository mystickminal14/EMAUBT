import 'package:flutter/material.dart';

/// All colors, text styles, and decorations for the Folder Management feature.
/// Mirrors [UMTheme] palette for visual consistency across the app.
class FolderTheme {
  FolderTheme._();

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color primary  = Color(0xFF1A1A2E);
  static const Color accent   = Color(0xFF4F8EF7);
  static const Color surface  = Color(0xFFF5F7FF);
  static const Color card     = Colors.white;
  static const Color border   = Color(0xFFE3E8F0);
  static const Color textMain = Color(0xFF1A1A2E);
  static const Color textSub  = Color(0xFF6B7A99);

  // Folder icon container colours
  static const Color iconBg       = Color(0xFFEEF4FF);
  static const Color iconBgAccent = Color(0xFFDBEAFF);

  // ── Text Styles ───────────────────────────────────────────────────────────
  static const TextStyle screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: textMain,
    letterSpacing: -0.5,
  );

  static const TextStyle screenSubtitle = TextStyle(
    fontSize: 13,
    color: textSub,
  );

  static const TextStyle cardTitle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: textMain,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 12,
    color: textSub,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize: 13,
    color: textSub,
  );

  static const TextStyle fieldInput = TextStyle(
    fontSize: 14,
    color: textMain,
  );

  static const TextStyle sheetTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: textMain,
  );

  static const TextStyle submitButton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
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

  static const TextStyle fabLabel = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  // ── Decorations ───────────────────────────────────────────────────────────
  static BoxDecoration cardDecoration = BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
        color: primary.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  static BoxDecoration searchDecoration = BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
        color: primary.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration fieldDecoration({bool enabled = true}) => BoxDecoration(
    color: enabled ? surface : border.withOpacity(0.5),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: border),
  );

  static BoxDecoration iconContainerDecoration = BoxDecoration(
    color: iconBg,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: iconBgAccent, width: 1.5),
  );

  static BoxDecoration sheetDecoration = const BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  );

  static BoxDecoration sheetIconDecoration = BoxDecoration(
    color: accent.withOpacity(0.1),
    borderRadius: BorderRadius.circular(10),
  );

  static BoxDecoration selectedIconDecoration = BoxDecoration(
    color: accent.withOpacity(0.15),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: accent, width: 2),
  );

  static BoxDecoration unselectedIconDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: border),
  );
}