import 'package:flutter/material.dart';

/// A dedicated class that holds all design constants for the app
/// This is the single source of truth for all colors and styling
class NeumorphicTheme {
  // Core Colors
  static const Color pageBackground = Color(0xFFF5F5F7);
  static const Color cardBackground = Colors.white;
  static const Color slateBlue = Color(0xFF5D737E);
  static const Color mutedCoral = Color(0xFFFFB59E);
  static const Color darkGrey = Color(0xFF1D1D1F);
  static const Color mediumGrey = Color(0xFF8A8A8E);
  static const Color lightGrey = Color(0xFFE0E0E0); 
  static const Color mutedRed = Color(0xFFE57373);
  static const Color trackBackground = Color(0xFFE9ECEF);
  
  // Secondary Palette
  static const Color puce = Color(0xFFC6878F);
  static const Color rosyBrown = Color(0xFFB79D94);
  static const Color battleshipGray = Color(0xFF969696);
  static const Color dimGray = Color(0xFF67697C);
  static const Color prussianBlue = Color(0xFF253D5B);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = mutedRed;
  static const Color warning = Color(0xFFFFA726);
  
  // Functional Color Assignments
  static const Color primary = slateBlue;
  static const Color secondary = puce;
  static const Color tertiary = rosyBrown;
  static const Color accent = slateBlue;
  
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF8F8F8);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFFE8EAF0);
  
  static const Color text = darkGrey;
  static const Color textLight = dimGray;
  static const Color textMuted = mediumGrey;
  
  static const Color buttonPrimary = slateBlue;
  static const Color buttonSecondary = puce;
  static const Color buttonTertiary = rosyBrown;
  static const Color disabled = battleshipGray;
  
  static const Color divider = battleshipGray;
  static const Color cardBorder = rosyBrown;
  
  // Text Styles
  static TextStyle primaryText({
    double size = 16.0,
    FontWeight weight = FontWeight.normal,
    Color? color,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? darkGrey,
    );
  }
  
  static TextStyle secondaryText({
    double size = 14.0,
    FontWeight weight = FontWeight.normal,
    Color? color,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? mediumGrey,
    );
  }
  
  static TextStyle onAccentText({
    double size = 14.0,
    FontWeight weight = FontWeight.normal,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: Colors.white,
    );
  }
  
  // Spacing Values
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Border Radius Values
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double pillRadius = 20.0;
  static const double inputRadius = 10.0;
  
  // Shadow Values - For direct use in CSS-style descriptions
  static const String raisedShadow = '4px 4px 8px rgba(0,0,0,0.06), -3px -3px 6px rgba(255,255,255,0.7)';
  static const String insetShadow = 'inset 2px 2px 4px rgba(0,0,0,0.06), inset -2px -2px 4px rgba(255,255,255,0.7)';
  
  // Avatar Sizes
  static const double largeAvatarSize = 44.0;
  static const double mediumAvatarSize = 36.0;
  static const double smallAvatarSize = 28.0;
  
  // Typography
  static const double titleLarge = 18.0;
  static const double titleMedium = 16.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
  static const double buttonTextSize = 15.0;
  
  // Bottom Bar
  static const double bottomBarHeight = 72.0;
  static const double bottomBarButtonSize = 48.0;
}

/// Helper class for applying predefined styles to text
class NeumorphicText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  
  const NeumorphicText(
    this.text, {
    Key? key,
    required this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  }) : super(key: key);
  
  // Factory constructors for common text styles
  
  factory NeumorphicText.title(
    String text, {
    Key? key,
    FontWeight weight = FontWeight.w600,
    TextAlign textAlign = TextAlign.start,
    int? maxLines,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return NeumorphicText(
      text,
      key: key,
      style: NeumorphicTheme.primaryText(
        size: NeumorphicTheme.titleLarge,
        weight: weight,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
  
  factory NeumorphicText.subtitle(
    String text, {
    Key? key,
    FontWeight weight = FontWeight.w500,
    TextAlign textAlign = TextAlign.start,
    int? maxLines,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return NeumorphicText(
      text,
      key: key,
      style: NeumorphicTheme.primaryText(
        size: NeumorphicTheme.titleMedium,
        weight: weight,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
  
  factory NeumorphicText.body(
    String text, {
    Key? key,
    FontWeight weight = FontWeight.normal,
    TextAlign textAlign = TextAlign.start,
    int? maxLines,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return NeumorphicText(
      text,
      key: key,
      style: NeumorphicTheme.primaryText(
        size: NeumorphicTheme.bodyMedium,
        weight: weight,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
  
  factory NeumorphicText.caption(
    String text, {
    Key? key,
    FontWeight weight = FontWeight.normal,
    TextAlign textAlign = TextAlign.start,
    int? maxLines,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return NeumorphicText(
      text,
      key: key,
      style: NeumorphicTheme.secondaryText(
        size: NeumorphicTheme.bodySmall,
        weight: weight,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
} 