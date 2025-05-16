import 'package:flutter/material.dart';
import 'neumorphic_theme.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        primary: NeumorphicTheme.primary,
        secondary: NeumorphicTheme.secondary,
        tertiary: NeumorphicTheme.tertiary,
        surface: NeumorphicTheme.surface,
        background: NeumorphicTheme.surface,
        error: NeumorphicTheme.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: NeumorphicTheme.text,
        onBackground: NeumorphicTheme.text,
        onError: Colors.white,
        brightness: Brightness.light,
      ),
      
      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: NeumorphicTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),
      
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NeumorphicTheme.buttonPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: NeumorphicTheme.disabled.withOpacity(0.12),
          disabledForegroundColor: NeumorphicTheme.disabled,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NeumorphicTheme.buttonSecondary,
          disabledForegroundColor: NeumorphicTheme.disabled,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NeumorphicTheme.buttonTertiary,
          side: BorderSide(color: NeumorphicTheme.buttonTertiary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Input Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NeumorphicTheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: NeumorphicTheme.textMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: NeumorphicTheme.primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: NeumorphicTheme.textMuted.withOpacity(0.5)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: NeumorphicTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: NeumorphicTheme.error, width: 2),
        ),
        errorStyle: TextStyle(color: NeumorphicTheme.error),
        labelStyle: TextStyle(color: NeumorphicTheme.textLight),
        hintStyle: TextStyle(color: NeumorphicTheme.textMuted),
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        color: NeumorphicTheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: NeumorphicTheme.cardBorder.withOpacity(0.1)),
        ),
      ),
      
      // Text Theme
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: NeumorphicTheme.text, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: NeumorphicTheme.text, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: NeumorphicTheme.text, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: NeumorphicTheme.textLight),
        bodyLarge: TextStyle(color: NeumorphicTheme.text),
        bodyMedium: TextStyle(color: NeumorphicTheme.textLight),
        bodySmall: TextStyle(color: NeumorphicTheme.textMuted),
      ),
      
      // Divider Theme
      dividerTheme: DividerThemeData(
        color: NeumorphicTheme.divider.withOpacity(0.2),
        thickness: 1,
        space: 24,
      ),
      
      // Icon Theme
      iconTheme: IconThemeData(
        color: NeumorphicTheme.primary,
        size: 24,
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: NeumorphicTheme.accent,
        foregroundColor: Colors.white,
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: NeumorphicTheme.primary,
        ),
      ),
    );
  }
} 