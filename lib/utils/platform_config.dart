import 'dart:io';
import 'package:flutter/material.dart';

/// A utility class for platform-specific configurations
class PlatformConfig {
  /// Returns platform-specific horizontal padding for cards
  static EdgeInsetsGeometry getCardPadding() {
    if (Platform.isIOS) {
      // iOS needs explicit padding
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0);
    } else {
      // Android also needs padding, just a bit different
      return const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0);
    }
  }
  
  /// Returns platform-specific horizontal padding for list items
  static EdgeInsetsGeometry getListItemPadding() {
    if (Platform.isIOS) {
      // iOS needs explicit padding
      return const EdgeInsets.symmetric(horizontal: 8.0);
    } else {
      // Android also needs padding
      return const EdgeInsets.symmetric(horizontal: 8.0);
    }
  }
  
  /// Returns platform-specific horizontal margin for cards
  static EdgeInsetsGeometry getCardMargin() {
    if (Platform.isIOS) {
      // iOS needs explicit margins
      return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0);
    } else {
      // Update Android margins to include horizontal padding
      return const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0);
    }
  }
} 