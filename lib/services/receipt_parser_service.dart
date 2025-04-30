import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/models/person.dart';

class ReceiptData {
  final List<dynamic> items;
  // final double tax;
  // final double tip;
  // final List<dynamic> people;
  final double subtotal;
  // final double total;

  ReceiptData({
    required this.items, 
    // required this.tax, 
    // required this.tip, 
    // required this.people, 
    required this.subtotal, 
    // required this.total
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    return ReceiptData(
      items: json['items'] as List,
      // tax: (json['tax'] is int) ? (json['tax'] as int).toDouble() : json['tax'] as double,
      // tip: (json['tip'] is int) ? (json['tip'] as int).toDouble() : json['tip'] as double,
      // people: json['people'] as List,
      subtotal: (json['subtotal'] is int) ? (json['subtotal'] as int).toDouble() : json['subtotal'] as double,
      // total: (json['total'] is int) ? (json['total'] as int).toDouble() : json['total'] as double,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items,
    // 'tax': tax,
    // 'tip': tip,
    // 'people': people,
    'subtotal': subtotal,
    // 'total': total,
  };
  
  // Convert raw API response items to ReceiptItem objects
  List<ReceiptItem> getReceiptItems() {
    return items.map((item) {
      final double price = (item['price'] is int) 
          ? (item['price'] as int).toDouble() 
          : item['price'] as double;
          
      final double quantity = (item['quantity'] is int) 
          ? (item['quantity'] as int).toDouble() 
          : item['quantity'] as double;
          
      return ReceiptItem(
        name: item['item'] as String,
        price: price,
        quantity: quantity.round(),
      );
    }).toList();
  }
  
  // // Convert raw API response people to Person objects
  // List<Person> getPeople() {
  //   return people.map((person) {
  //     return Person(
  //       name: person['name'] as String,
  //     );
  //   }).toList();
  // }
}

class ReceiptParserService {
  static Future<ReceiptData> parseReceipt(File imageFile) async {
    final apiKey = dotenv.env['OPEN_AI_API_KEY'];
    // Use a model compatible with /v1/responses, potentially gpt-4.1 or a vision-capable one if specified
    final model = dotenv.env['OPEN_AI_MODEL'] ?? 'gpt-4o'; 
    
    if (apiKey == null) {
      throw Exception('OpenAI API key not found in environment variables');
    }

    // Convert image to base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      // Use the /v1/responses endpoint
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/responses'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        // Adapt the body structure for the /v1/responses endpoint
        body: jsonEncode({
          'model': model,
          // 'max_tokens': 1000, // Parameter might differ or not be supported in /v1/responses
          'input': [
            {
              'role': 'user',
              // Content structure for /v1/responses with text and image
              'content': [
                {
                  'type': 'input_text',
                  'text': '''Parse the image and generate a receipt. Return a JSON object WITHIN YOUR TEXT RESPONSE with the following structure:
                  {
                    "items": [
                      {
                        "item": "string",
                        "quantity": number,
                        "price": number
                      }
                    ],
                    "subtotal": number
                  }

                  Instructions:
                  - First, accurately transcribe every item and its listed price exactly as shown on the receipt, before performing any calculations or transformations. Do not assume or infer numbers — copy the listed amount first. Only after verifying transcription, adjust for quantities.
                  - Sometimes, items may have add-ons or modifiers in the receipt. 
                  - Use your intuition to roll up the add-ons into the parent item and sum the prices.
                  - If an item or line has its own price listed to the far right of it, it must be treated as a separate line item in the JSON, even if it appears visually indented, grouped, or described as part of a larger item. Do not assume bundling unless there is no separate price.
                  - MAKE SURE the price is the individual price for the item and the quantity is accurate based on the receipt. (ex. If the receipt says Quantity of 2 and price is \$10, then the price of the item to provide is \$5, not \$10)
                  - MAKE SURE all items, quantities, and prices are present and accurate in the json'''
                },
                {
                  'type': 'input_image', // Use input_image type
                  'image_url': 'data:image/jpeg;base64,$base64Image'
                }
              ]
            }
          ],
          // Rely on the system prompt for JSON output, as 'response_format' might differ for /v1/responses
          // 'response_format': { 'type': 'json_object' },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Parse the output structure of /v1/responses
        if (data['output'] == null || (data['output'] as List).isEmpty) {
            print('Error parsing receipt: /v1/responses output missing "output" field.');
            throw Exception('Invalid response format from OpenAI /v1/responses: Missing "output" field.');
        }

        // Find the first message output
        final messageOutput = (data['output'] as List).firstWhere(
            (item) => item['type'] == 'message' && item['role'] == 'assistant',
            orElse: () => null);

        if (messageOutput == null || messageOutput['content'] == null || (messageOutput['content'] as List).isEmpty) {
            print('Error parsing receipt: /v1/responses output missing assistant message content.');
            throw Exception('Invalid response format from OpenAI /v1/responses: Missing assistant message content.');
        }

        // Find the text content within the message
        final textContent = (messageOutput['content'] as List).firstWhere(
            (item) => item['type'] == 'output_text',
            orElse: () => null);
            
        if (textContent == null || textContent['text'] == null) {
          print('Error parsing receipt: /v1/responses output missing "output_text" field in message content.');
          throw Exception('No text content received from OpenAI /v1/responses');
        }

        final contentString = textContent['text'] as String;
        
        try {
          // Parse the JSON string contained within the text response
          final Map<String, dynamic> parsedJson = jsonDecode(contentString);
          return ReceiptData.fromJson(parsedJson);
        } catch (e) {
          // Log the content that failed to parse and the error
          print('Failed to parse OpenAI response content (from /v1/responses) as JSON: $contentString\\nError: $e');
          throw Exception('Failed to parse OpenAI response content as JSON: $e');
        }
      } else {
        // Log detailed error information from the API response
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? response.body;
        print('OpenAI API error (${response.statusCode}) using /v1/responses: $errorMessage');
        throw Exception('OpenAI API error (${response.statusCode}) using /v1/responses: $errorMessage');
      }
    } catch (e) {
      // Print the error regardless of its type before rethrowing
      print('Error communicating with OpenAI API (using /v1/responses): $e');
      rethrow;
    }
  }
} 