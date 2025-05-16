import 'package:flutter/material.dart';
import '../theme/neumorphic_theme.dart';

/// A helper class to show standardized toast notifications throughout the app
class ToastHelper {
  /// Shows a notification at the top of the screen using overlay
  /// 
  /// Parameters:
  /// - [context]: The BuildContext
  /// - [message]: The message to display
  /// - [isError]: Whether this is an error message (red)
  /// - [isSuccess]: Whether this is a success message (green)
  /// - If neither isError nor isSuccess is true, shows an info toast (gold)
  static void showToast(BuildContext context, String message, {bool isError = false, bool isSuccess = false}) {
    final overlay = Overlay.of(context);
    final mediaQuery = MediaQuery.of(context);
    
    // Get appropriate color from theme - always use success or warning (never puce)
    Color backgroundColor;
    if (isSuccess) {
      backgroundColor = NeumorphicTheme.success; // Green
    } else {
      backgroundColor = NeumorphicTheme.warning; // Gold/orange for both warnings and errors
    }
    
    // Use appropriate icon based on type, but consistent colors
    IconData iconData = isSuccess 
        ? Icons.check_circle_outline 
        : (isError ? Icons.error_outline : Icons.info_outline);
    
    // Position just below the app bar
    final topPosition = mediaQuery.padding.top + 70;
    
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: topPosition,
        left: 20,
        right: 20,
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(8),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(
                  iconData,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  /// Fallback method that uses SnackBar when overlay context isn't available
  /// Should be used sparingly in cases where access to Overlay isn't possible
  static void showSnackBar(BuildContext context, String message, {bool isError = false, bool isSuccess = false}) {
    // Use only success or warning colors (never puce)
    Color backgroundColor = isSuccess ? NeumorphicTheme.success : NeumorphicTheme.warning;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
} 