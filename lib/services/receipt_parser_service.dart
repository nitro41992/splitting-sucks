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
    final model = dotenv.env['OPEN_AI_MODEL'] ?? 'gpt-4o';
    
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
                  'text': '''Parse the image and generate a receipt. Return a JSON object with the following structure:
                  {
                    "items": [
                      {
                        "item": "string",
                        "quantity": number,
                        "price": number
                      }
                    ],
                    "subtotal": number,
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
          final Map<String, dynamic> parsedJson = jsonDecode(content);
          // Use model class to validate and parse the JSON structure
          return ReceiptData.fromJson(parsedJson);
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