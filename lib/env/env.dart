import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Check if dotenv is loaded to avoid "NotInitializedError"
  static bool get _isDotEnvLoaded => dotenv.isInitialized && dotenv.env.isNotEmpty;
  
  static String get openAiApiKey => _isDotEnvLoaded ? dotenv.env['OPENAI_API_KEY'] ?? '' : '';
  static String get openAiModel => _isDotEnvLoaded ? dotenv.env['OPENAI_MODEL'] ?? 'gpt-4o' : 'gpt-4o';
  
  // Flag to determine if we should use mock receipt history data
  // Default to true if dotenv is not initialized to ensure the app can run without .env
  static bool get useMockReceiptHistory {
    if (!_isDotEnvLoaded) return true;
    return (dotenv.env['USE_MOCK_RECEIPT_HISTORY']?.toLowerCase() == 'true') ?? true;
  }
} 