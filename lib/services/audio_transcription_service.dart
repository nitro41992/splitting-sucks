import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// Model classes for structured validation
class Order {
  final String person;
  final String item;
  final double price;
  final int quantity;

  Order({
    required this.person,
    required this.item,
    required this.price,
    required this.quantity,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      person: json['person'] as String,
      item: json['item'] as String,
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : json['price'] as double,
      quantity: json['quantity'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'person': person,
        'item': item,
        'price': price,
        'quantity': quantity,
      };
}

class SharedItem {
  final String item;
  final double price;
  final int quantity;
  final List<String> people;

  SharedItem({
    required this.item,
    required this.price,
    required this.quantity,
    required this.people,
  });

  factory SharedItem.fromJson(Map<String, dynamic> json) {
    return SharedItem(
      item: json['item'] as String,
      price: (json['price'] is int)
          ? (json['price'] as int).toDouble()
          : json['price'] as double,
      quantity: json['quantity'] as int,
      people: (json['people'] as List).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'item': item,
        'price': price,
        'quantity': quantity,
        'people': people,
      };
}

class Person {
  final String name;

  Person({required this.name});

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(name: json['name'] as String);
  }

  Map<String, dynamic> toJson() => {'name': name};
}

class AssignmentResult {
  final List<dynamic> orders;
  final List<dynamic> sharedItems;
  final List<dynamic> people;
  final List<dynamic>? unassignedItems;

  AssignmentResult({
    required this.orders,
    required this.sharedItems,
    required this.people,
    this.unassignedItems,
  });

  factory AssignmentResult.fromJson(Map<String, dynamic> json) {
    return AssignmentResult(
      orders: json['orders'] as List,
      sharedItems: json['shared_items'] as List,
      people: json['people'] as List,
      unassignedItems: json['unassigned_items'] as List?,
    );
  }

  Map<String, dynamic> toJson() => {
        'orders': orders,
        'shared_items': sharedItems,
        'people': people,
        if (unassignedItems != null) 'unassigned_items': unassignedItems,
      };

  // Helper methods to convert raw data to typed objects
  List<Order> getOrders() {
    return orders
        .map((item) => Order.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<SharedItem> getSharedItems() {
    return sharedItems
        .map((item) => SharedItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<Person> getPeople() {
    return people
        .map((item) => Person.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class AudioTranscriptionService {
  final String _apiKey;
  final String _baseUrl = 'https://api.openai.com/v1';
  
  AudioTranscriptionService() : _apiKey = dotenv.env['OPEN_AI_API_KEY'] ?? '';

  Future<String> getTranscription(Uint8List audioBytes) async {
    try {
      final url = Uri.parse('$_baseUrl/audio/transcriptions');
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            audioBytes,
            filename: 'audio.wav',
          ),
        )
        ..fields['model'] = 'whisper-1';

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        throw Exception('Failed to transcribe audio: ${response.statusCode}');
      }

      final json = jsonDecode(responseBody);
      return json['text'] as String;
    } catch (e) {
      print('Error transcribing audio: $e');
      rethrow;
    }
  }

  Future<AssignmentResult> assignPeopleToItems(String transcription, Map<String, dynamic> receipt) async {
    try {
      // Use the /v1/responses endpoint
      final url = Uri.parse('$_baseUrl/responses');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        // Adapt the body structure for the /v1/responses endpoint
        body: jsonEncode({
          'model': dotenv.env['OPEN_AI_MODEL'] ?? 'gpt-4o', // Or specify a model compatible with /v1/responses like 'gpt-4.1' if needed
          'input': [
            {
              'role': 'system',
              // Content structure for /v1/responses
              'content': [
                {'type': 'input_text', 'text': '''You are a helpful assistant that assigns items from a receipt to people based on voice instructions.
                 Analyze the voice transcription and receipt items to determine who ordered what.
                 Each item in the receipt items list has a numeric 'id'. Use these IDs to refer to items when possible, especially if the transcription mentions numbers.
                 Return a JSON object WITHIN YOUR TEXT RESPONSE with the following structure:
                 {
                   "orders": [
                     {"person": "name", "item": "item_name", "price": price, "quantity": quantity}
                   ],
                   "shared_items": [
                     {"item": "item_name", "price": price, "quantity": quantity, "people": ["name1", "name2"]}
                   ],
                   "people": [
                     {"name": "name1"},
                     {"name": "name2"}
                   ],
                   "unassigned_items": [
                     {"item": "item_name", "price": price, "quantity": quantity}
                   ]
                 }

                 Pay close attention to:
                 1. Include ALL people mentioned in the transcription
                 2. Make sure all items are assigned to someone, marked as shared, or added to the unassigned_items array. Its important to include all items.
                 3. Ensure quantities and prices match the receipt, providing a positive integer for quantity.
                 4. If not every instance of an item is mentioned in the transcription, make sure to add the item to the unassigned_items array
                 5. If numeric references to items are provided, use the provided numeric IDs to reference items when the transcription includes numbers that seem to correspond to items.'''
                }
              ]
            },
            {
              'role': 'user',
              // Content structure for /v1/responses
              'content': [
                {'type': 'input_text', 'text': '''Voice transcription: $transcription
                Receipt items: ${jsonEncode(receipt)}'''}
              ]
            },
          ],
          // Instruct the model to output JSON directly within the text if possible (similar intent to response_format)
          // Note: The /v1/responses endpoint might have a different mechanism for this,
          // but the curl example doesn't show it. We rely on the system prompt.
          // 'response_format': { 'type': 'json_object' }, // This might not be valid for /v1/responses
        }),
      );

      if (response.statusCode != 200) {
        // Log detailed error information from the API response
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? response.body;
        print('OpenAI API error (${response.statusCode}) using /v1/responses: $errorMessage');
        throw Exception('Failed to get completion from /v1/responses: ${response.statusCode}');
      }

      final json = jsonDecode(response.body);

      // Parse the output structure of /v1/responses
      if (json['output'] == null || (json['output'] as List).isEmpty) {
          print('Error assigning items: /v1/responses output missing "output" field.');
          throw Exception('Invalid response format from OpenAI /v1/responses: Missing "output" field.');
      }

      // Find the first message output
      final messageOutput = (json['output'] as List).firstWhere(
          (item) => item['type'] == 'message' && item['role'] == 'assistant',
          orElse: () => null);

      if (messageOutput == null || messageOutput['content'] == null || (messageOutput['content'] as List).isEmpty) {
          print('Error assigning items: /v1/responses output missing assistant message content.');
          throw Exception('Invalid response format from OpenAI /v1/responses: Missing assistant message content.');
      }

      // Find the text content within the message
      final textContent = (messageOutput['content'] as List).firstWhere(
          (item) => item['type'] == 'output_text',
          orElse: () => null);

      if (textContent == null || textContent['text'] == null) {
        print('Error assigning items: /v1/responses output missing "output_text" field in message content.');
        throw Exception('No text content received from OpenAI /v1/responses');
      }

      final contentString = textContent['text'] as String;

      try {
        // Parse the JSON string contained within the text response
        final Map<String, dynamic> parsedJson = jsonDecode(contentString);
        return AssignmentResult.fromJson(parsedJson);
      } catch (e) {
         print('Failed to parse OpenAI response content (from /v1/responses) as JSON: $contentString\\nError: $e');
         throw Exception('Failed to parse OpenAI response content as JSON: $e');
      }
    } catch (e) {
      // Print the error regardless of its type before rethrowing
      print('Error assigning items using /v1/responses: $e');
      rethrow;
    }
  }
} 