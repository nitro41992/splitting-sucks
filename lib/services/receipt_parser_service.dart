import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReceiptParserService {
  static Future<Map<String, dynamic>> parseReceipt(File imageFile) async {
    final apiKey = dotenv.env['OPEN_AI_API_KEY'];
    final model = dotenv.env['OPEN_AI_MODEL'] ?? 'gpt-4o-mini';
    
    if (apiKey == null) {
      throw Exception('OpenAI API key not found in environment variables');
    }

    // Convert image to base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'response_format': { 'type': 'json_object' },
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': '''Parse the image and generate a receipt. Return ONLY a valid JSON object with no additional text or explanation.

                  The JSON object must contain the following keys:
                  {
                    "items": [
                      {
                        "item": "string",
                        "quantity": number,
                        "price": number
                      }
                    ],
                    "tax": number,
                    "tip": number,
                    "people": [
                      {
                        "name": "string"
                      }
                    ],
                    "subtotal": number,
                    "total": number
                  }

                  Instructions:
                  - Sometimes, items may have add-ons or modifiers in the receipt. 
                  - Use your intuition to roll up the add-ons into the parent item and sum the prices.
                  - MAKE SURE the price is the individual price for the item and the quantity is accurate based on the receipt. (ex. If the receipt says Quantity of 2 and price is \$10, then the price of the item to provide is \$5, not \$10)
                  - MAKE SURE all items, quantities, and prices are present and accurate in the json
                  - Return ONLY the JSON object, no other text'''
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image'
                  }
                }
              ]
            }
          ],
          'max_tokens': 1000
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        try {
          return jsonDecode(content);
        } catch (e) {
          throw Exception('Failed to parse OpenAI response as JSON: $content\nError: $e');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('OpenAI API error (${response.statusCode}): ${errorBody['error']?['message'] ?? response.body}');
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Invalid response format from OpenAI API: $e');
      }
      throw Exception('Error communicating with OpenAI API: $e');
    }
  }
} 