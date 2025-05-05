import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Check if dotenv is loaded to avoid "NotInitializedError"
  static bool get isInitialized => dotenv.isInitialized && dotenv.env.isNotEmpty;
  
  // Debug method to print all environment variables (safe for logging)
  static void logEnvStatus() {
    debugPrint('=== Environment Status ===');
    debugPrint('dotenv initialized: ${dotenv.isInitialized}');
    debugPrint('dotenv variables count: ${dotenv.env.length}');
    
    // Log key variables with sensitive values masked
    debugPrint('OPENAI_MODEL: ${openAiModel}');
    debugPrint('OPENAI_API_KEY: ${openAiApiKey.isNotEmpty ? "[CONFIGURED]" : "[MISSING]"}');
    debugPrint('=== End Environment Status ===');
  }
  
  // OpenAI Configuration
  static String get openAiApiKey => _getEnv('OPENAI_API_KEY', '');
  static String get openAiModel => _getEnv('OPENAI_MODEL', 'gpt-4o');
  
  // Firebase Configuration
  static String get firebaseFunctionsUrl => _getEnv('FIREBASE_FUNCTIONS_URL', 
      'https://us-central1-default-project.cloudfunctions.net');
  static String get firebaseFunctionsRegion => _getEnv('FIREBASE_FUNCTIONS_REGION', 'us-central1');
  
  // Feature Flags
  static bool get debugMode => _getBoolEnv('DEBUG_MODE', false);
  
  // Helper methods
  static String _getEnv(String key, String defaultValue) {
    if (!isInitialized) return defaultValue;
    return dotenv.env[key] ?? defaultValue;
  }
  
  static bool _getBoolEnv(String key, bool defaultValue) {
    if (!isInitialized) return defaultValue;
    final value = dotenv.env[key]?.toLowerCase();
    if (value == null) return defaultValue;
    return value == 'true' || value == '1' || value == 'yes';
  }
} 