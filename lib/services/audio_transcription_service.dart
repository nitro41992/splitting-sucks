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
      final url = Uri.parse('$_baseUrl/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': dotenv.env['OPEN_AI_MODEL'] ?? 'gpt-4o',
          'response_format': { 'type': 'json_object' },
          'messages': [
            {
              'role': 'system',
              'content': '''You are a helpful assistant that assigns items from a receipt to people based on voice instructions.
              Analyze the voice transcription and receipt items to determine who ordered what.
              Return a JSON object with the following structure:
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
              3. Ensure quantities and prices match the receipt
              4. If not every instance of an item is mentioned in the transcription, make sure to add the item to the unassigned_items array''',
            },
            {
              'role': 'user',
              'content': '''Voice transcription: $transcription
              Receipt items: ${jsonEncode(receipt)}''',
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get completion: ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      final content = json['choices'][0]['message']['content'];
      if (content == null) {
        throw Exception('No response from OpenAI');
      }

      final Map<String, dynamic> parsedJson = jsonDecode(content);
      return AssignmentResult.fromJson(parsedJson);
    } catch (e) {
      print('Error assigning items: $e');
      rethrow;
    }
  }
} 