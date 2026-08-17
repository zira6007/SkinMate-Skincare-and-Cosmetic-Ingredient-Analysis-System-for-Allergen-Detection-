import 'package:flutter/material.dart';

class AppColors {

  AppColors._();

  // ═══════════════════════════════════════════════════════
  // PRIMARY BRAND COLOURS
  // ═══════════════════════════════════════════════════════

  static const Color primary = Color(0xFFB07B6B);
  static const Color primaryDark = Color(0xFF3D2420);
  static const Color primaryMuted = Color(0xFF9A7070);
  static const Color primaryLight = Color(0xFFD4A090);


  // ═══════════════════════════════════════════════════════
  // SECONDARY — DUSTY PINK
  // ═══════════════════════════════════════════════════════

  static const Color secondary = Color(0xFFE8A0A0);
  static const Color secondaryLight = Color(0xFFF5D5D5);
  static const Color secondaryCard = Color(0xFFE8D5CC);
  static const Color cardBackground = Color(0xFFEDE0D8);
  static const Color selectedHighlight = Color(0xFFEDD5CC);


  // ═══════════════════════════════════════════════════════
  // BACKGROUND COLOURS
  // ═══════════════════════════════════════════════════════

  static const Color background = Color(0xFFF9F3EC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF3D2420);


  // ═══════════════════════════════════════════════════════
  // TEXT COLOURS
  // ═══════════════════════════════════════════════════════

  static const Color textPrimary = Color(0xFF4A2C2A);
  static const Color textSecondary = Color(0xFF9A7070);
  static const Color textLabel = Color(0xFF7A5555);
  static const Color textOnDark = Color(0xFFEDD5CC);
  static const Color textHint = Color(0xFFBBA0A0);
  static const Color textWhite = Color(0xFFFFFFFF);


  // ═══════════════════════════════════════════════════════
  // RISK / SAFETY COLOURS
  // Used in scan results, ingredient badges, risk scores
  // ═══════════════════════════════════════════════════════

  static const Color safeColor = Color(0xFF27AE60);
  static const Color safeBg = Color(0xFFD4EDDA);
  static const Color safeText = Color(0xFF155724);
  static const Color cautionColor = Color(0xFFF59F00);
  static const Color cautionBg = Color(0xFFFFF3CD);
  static const Color cautionText = Color(0xFF664D03);
  static const Color allergenColor = Color(0xFFE74C3C);
  static const Color allergenBg = Color(0xFFFFEDED);
  static const Color allergenText = Color(0xFF721C24);


  // ═══════════════════════════════════════════════════════
  // BORDER & DIVIDER COLOURS
  // ═══════════════════════════════════════════════════════

  static const Color border = Color(0xFFE0D0C8);
  static const Color borderFocused = Color(0xFFB07B6B);
  static const Color borderError = Color(0xFFE74C3C);
  static const Color divider = Color(0xFFEDE0D8);

static const Color lightPink = Color(0xFFF5D5D5);


  static Color riskColor(String flag) {
    switch (flag.toUpperCase()) {
      case 'SAFE':
        return safeColor;
      case 'CAUTION':
        return cautionColor;
      case 'ALLERGEN':
        return allergenColor;
      default:
        return textSecondary;
    }
  }

  static Color riskBgColor(String flag) {
    switch (flag.toUpperCase()) {
      case 'SAFE':
        return safeBg;
      case 'CAUTION':
        return cautionBg;
      case 'ALLERGEN':
        return allergenBg;
      default:
        return background;
    }
  }

  static Color riskTextColor(String flag) {
    switch (flag.toUpperCase()) {
      case 'SAFE':
        return safeText;
      case 'CAUTION':
        return cautionText;
      case 'ALLERGEN':
        return allergenText;
      default:
        return textSecondary;
    }
  }

  static Color riskScoreColor(int score) {
    if (score >= 4) return allergenColor;
    if (score == 3) return cautionColor;
    return safeColor;
  }
}