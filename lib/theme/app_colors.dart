import 'package:flutter/material.dart';

/// @deprecated Use NeumorphicTheme instead
/// This class is being phased out in favor of NeumorphicTheme, which is the central
/// source of design constants for the app. Avoid using AppColors in new code.
class AppColors {
  // Primary Palette
  static const Color slateBlue = Color(0xFF5D737E);
  static const Color deepSlateBlue = Color(0xFF506C97);
  static const Color puce = Color(0xFFC6878F);
  static const Color mutedCoral = Color(0xFFFFB59E);
  static const Color rosyBrown = Color(0xFFB79D94);
  static const Color battleshipGray = Color(0xFF969696);
  static const Color dimGray = Color(0xFF67697C);
  static const Color prussianBlue = Color(0xFF253D5B);
  
  // Neutrals
  static const Color darkGrey = Color(0xFF1D1D1F);
  static const Color mediumGrey = Color(0xFF8A8A8E);
  static const Color lightGrey = Color(0xFFE0E0E0);
  static const Color pageBackground = Color(0xFFF5F5F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFFE8EAF0);
  static const Color trackBackground = Color(0xFFE9ECEF);
  
  // Status/Alert Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE57373);
  static const Color mutedRed = Color(0xFFE57373);
  static const Color warning = Color(0xFFFFA726);
  
  // Theme Color Assignments
  static const Color primary = slateBlue;
  static const Color secondary = puce;
  static const Color tertiary = rosyBrown;
  static const Color accent = slateBlue;
  
  // Background Colors
  static const Color background = surfaceLight;
  static const Color surface = surfaceLight;
  static const Color surfaceVariant = Color(0xFFF8F8F8);
  static const Color cardBackground = surfaceLight;
  
  // Text Colors
  static const Color text = darkGrey;
  static const Color textLight = dimGray;
  static const Color textMuted = mediumGrey;
  
  // Interactive Elements
  static const Color buttonPrimary = slateBlue;
  static const Color buttonSecondary = puce;
  static const Color buttonTertiary = rosyBrown;
  static const Color disabled = battleshipGray;
  
  // Decorative Elements
  static const Color divider = battleshipGray;
  static const Color cardBorder = rosyBrown;
} 