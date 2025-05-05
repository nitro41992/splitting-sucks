import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get openAiApiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static String get openAiModel => dotenv.env['OPENAI_MODEL'] ?? 'gpt-4o';
  
  // Flag to determine if we should use mock receipt history data
  static bool get useMockReceiptHistory => 
      (dotenv.env['USE_MOCK_RECEIPT_HISTORY']?.toLowerCase() == 'true') ?? false;
} 