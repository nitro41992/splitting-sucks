import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'receipt_splitter_ui.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define custom color scheme with specified colors
    final lightColorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: const Color(0xFF082D0F),      // Green
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF9DC5BB), // Teal
      onPrimaryContainer: const Color(0xFF082D0F),
      secondary: const Color(0xFF9DC5BB),    // Teal
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF9DC5BB).withOpacity(0.7),
      onSecondaryContainer: const Color(0xFF082D0F),
      tertiary: const Color(0xFF082D0F).withOpacity(0.8),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFDEE5E5),
      onTertiaryContainer: const Color(0xFF082D0F),
      error: Colors.redAccent,
      onError: Colors.white,
      errorContainer: Colors.redAccent.withOpacity(0.2),
      onErrorContainer: Colors.redAccent.shade700,
      background: const Color(0xFFDEE5E5),   // Light Gray
      onBackground: const Color(0xFF082D0F),
      surface: Colors.white,
      onSurface: const Color(0xFF082D0F),
      surfaceVariant: const Color(0xFFDEE5E5),
      onSurfaceVariant: const Color(0xFF082D0F).withOpacity(0.7),
      outline: const Color(0xFF9DC5BB),
      shadow: Colors.black.withOpacity(0.1),
      inverseSurface: const Color(0xFF082D0F),
      onInverseSurface: Colors.white,
      inversePrimary: const Color(0xFF9DC5BB),
      surfaceTint: Colors.transparent, // Important to avoid color tinting
    );

    return MaterialApp(
      title: 'Receipt Splitter',
      theme: ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: lightColorScheme.background, // Match the background color
          foregroundColor: lightColorScheme.onBackground,
          elevation: 0, // No shadow for a cleaner look
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: lightColorScheme.primary,
            foregroundColor: lightColorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: lightColorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const ReceiptSplitterUI(),
    );
  }
}
