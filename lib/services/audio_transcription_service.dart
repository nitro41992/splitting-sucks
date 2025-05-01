import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import '../env/firebase_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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

/// A service that handles audio transcription and assignment of people to items
/// using Firebase Cloud Functions.
class AudioTranscriptionService {
  // Firebase Functions instance
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  // Firebase Storage instance for uploading audio
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  AudioTranscriptionService();

  /// Transcribes audio using Firebase Cloud Functions.
  /// 
  /// Uploads the audio to Firebase Storage and then calls the transcribe_audio
  /// Cloud Function to process it with OpenAI's Whisper API.
  Future<String> getTranscription(Uint8List audioBytes) async {
    try {
      // 1. Upload the audio file to Firebase Storage first
      final String fileName = 'audio_${const Uuid().v4()}.wav';
      final String storagePath = 'audio_transcriptions/$fileName';
      
      final Reference storageRef = _storage.ref(storagePath);
      await storageRef.putData(audioBytes);
      
      // 2. Get the Cloud Storage URI (gs://)
      final String bucket = _storage.bucket;
      final String audioUri = 'gs://$bucket/$storagePath';
      
      // 3. Call the Firebase Cloud Function for transcription
      debugPrint('Calling transcribe_audio with URI: $audioUri');
      final callable = _functions.httpsCallable('transcribe_audio');
      
      // The Firebase SDK automatically adds the outer 'data' wrapper
      // So we just need to provide the audioUri directly as the argument
      final result = await callable.call(
        {'audioUri': audioUri}
      );
      
      // 4. Parse the response
      final responseData = result.data;
      if (responseData == null || responseData['text'] == null) {
        throw Exception('Invalid response format from Cloud Function');
      }
      
      return responseData['text'] as String;
    } catch (e) {
      // Log the error and rethrow
      debugPrint('Error in audio transcription: $e');
      rethrow;
    }
  }

  /// Assigns people to receipt items based on voice transcription using Firebase Cloud Functions.
  ///
  /// Calls the assign_people_to_items Cloud Function to process the transcription
  /// and receipt data with OpenAI's API.
  Future<AssignmentResult> assignPeopleToItems(String transcription, Map<String, dynamic> receipt) async {
    try {
      // Call the Firebase Cloud Function
      debugPrint('Calling assign_people_to_items with transcription and receipt');
      final callable = _functions.httpsCallable('assign_people_to_items');
      
      // No need for extra data wrapper, SDK handles it
      final result = await callable.call({
        'transcription': transcription,
        'receipt': receipt,
      });
      
      // Parse the response
      final responseData = result.data;
      
      if (responseData == null) {
        throw Exception('Invalid response format from Cloud Function');
      }
      
      return AssignmentResult.fromJson(responseData);
    } catch (e) {
      // Log the error and rethrow
      debugPrint('Error assigning items: $e');
      rethrow;
    }
  }
} 