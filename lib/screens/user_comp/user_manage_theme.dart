import 'package:flutter/material.dart';

/// All colors, text styles, and decorations used across
/// the User Management feature.  Import this file anywhere
/// you need a color or style — never hard-code them inline.
class UMTheme {
  UMTheme._();

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color primary    = Color(0xFF1A1A2E);
  static const Color accent     = Color(0xFF4F8EF7);
  static const Color surface    = Color(0xFFF5F7FF);
  static const Color card       = Colors.white;
  static const Color border     = Color(0xFFE3E8F0);
  static const Color textMain   = Color(0xFF1A1A2E);
  static const Color textSub    = Color(0xFF6B7A99);

  // Role badge colours
  static const Color adminBadgeBg   = Color(0xFFFFEDD5);
  static const Color adminBadgeText = Color(0xFFB45309);
  static const Color userBadgeBg    = Color(0xFFDCFCE7);
  static const Color userBadgeText  = Color(0xFF166534);

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
    fontSize: 15,
    color: textMain,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 12.5,
    color: textSub,
  );

  static const TextStyle cardPhone = TextStyle(
    fontSize: 12,
    color: textSub,
  );

  static const TextStyle roleBadge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
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

  static const TextStyle chipLabel = TextStyle(fontSize: 13);

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

  static BoxDecoration avatarDecoration({String? imageUrl}) => BoxDecoration(
    shape: BoxShape.circle,
    color: accent.withOpacity(0.12),
    border: Border.all(color: accent.withOpacity(0.3), width: 2),
    image: imageUrl != null && imageUrl.isNotEmpty
        ? DecorationImage(
        image: NetworkImage(imageUrl), fit: BoxFit.cover)
        : null,
  );

  static BoxDecoration roleBadgeDecoration({required bool isAdmin}) =>
      BoxDecoration(
        color: isAdmin ? adminBadgeBg : userBadgeBg,
        borderRadius: BorderRadius.circular(6),
      );

  static BoxDecoration sheetDecoration = const BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  );

  static BoxDecoration sheetIconDecoration = BoxDecoration(
    color: accent.withOpacity(0.1),
    borderRadius: BorderRadius.circular(10),
  );

  static BoxDecoration cameraBadgeDecoration = const BoxDecoration(
    color: accent,
    shape: BoxShape.circle,
  );
}