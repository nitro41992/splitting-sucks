import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import '../env/firebase_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/foundation.dart' show Platform;

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

// --- Model Classes for Assignment Result (Matching Pydantic) ---

class ItemDetail {
  final String name;
  final int quantity;
  final double price;

  ItemDetail({required this.name, required this.quantity, required this.price});

  factory ItemDetail.fromJson(Map<String, dynamic> json) {
    return ItemDetail(
      name: json['name'] as String? ?? 'Unknown Item', // Handle potential null
      quantity: json['quantity'] as int? ?? 1,      // Handle potential null
      price: (json['price'] as num?)?.toDouble() ?? 0.0, // Handle potential null
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
      };
}

class PersonItemAssignment {
  final String personName;
  final List<ItemDetail> items;

  PersonItemAssignment({required this.personName, required this.items});

  factory PersonItemAssignment.fromJson(Map<String, dynamic> json) {
    var itemsList = <ItemDetail>[];
    if (json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((itemJson) => ItemDetail.fromJson(itemJson as Map<String, dynamic>))
          .toList();
    }
    return PersonItemAssignment(
      personName: json['person_name'] as String? ?? 'Unknown Person', // Handle potential null
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'person_name': personName,
        'items': items.map((item) => item.toJson()).toList(),
      };
}

class SharedItemDetail { // Keeping this definition for completeness
  final String name;
  final int quantity;
  final double price;
  final List<String> people;

  SharedItemDetail({
    required this.name,
    required this.quantity,
    required this.price,
    required this.people,
  });

  factory SharedItemDetail.fromJson(Map<String, dynamic> json) {
    return SharedItemDetail(
      name: json['name'] as String? ?? 'Unknown Item',
      quantity: json['quantity'] as int? ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      people: (json['people'] as List?)?.whereType<String>().toList() ?? [],
    );
  }

   Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
        'people': people,
      };
}

// --- Updated AssignmentResult Class --- 
class AssignmentResult {
  // Correctly typed field matching Pydantic
  final List<PersonItemAssignment> assignments; 
  // Use specific types for better safety
  final List<SharedItemDetail> sharedItems; 
  final List<ItemDetail> unassignedItems;

  AssignmentResult({
    required this.assignments,
    required this.sharedItems, // Renamed param
    required this.unassignedItems, // Renamed param
  });

  factory AssignmentResult.fromJson(Map<String, dynamic> json) {
    var assignmentsList = <PersonItemAssignment>[];
    if (json['assignments'] is List) {
      assignmentsList = (json['assignments'] as List)
          .map((assignJson) => PersonItemAssignment.fromJson(assignJson as Map<String, dynamic>))
          .toList();
    }

    var sharedItemsList = <SharedItemDetail>[];
    if (json['shared_items'] is List) {
        sharedItemsList = (json['shared_items'] as List)
            .map((itemJson) => SharedItemDetail.fromJson(itemJson as Map<String, dynamic>))
            .toList();
    }
    
    var unassignedItemsList = <ItemDetail>[];
     if (json['unassigned_items'] is List) {
        unassignedItemsList = (json['unassigned_items'] as List)
            .map((itemJson) => ItemDetail.fromJson(itemJson as Map<String, dynamic>))
            .toList();
    }

    return AssignmentResult(
      assignments: assignmentsList, // Assign the parsed list
      sharedItems: sharedItemsList,
      unassignedItems: unassignedItemsList,
    );
  }

  Map<String, dynamic> toJson() => {
        // Correctly serialize the list
        'assignments': assignments.map((a) => a.toJson()).toList(), 
        'shared_items': sharedItems.map((s) => s.toJson()).toList(),
        'unassigned_items': unassignedItems.map((u) => u.toJson()).toList(),
      };

  // Optional: Keep getSharedItems if needed elsewhere, but ensure it returns List<SharedItemDetail>
  List<SharedItemDetail> getSharedItems() {
    return sharedItems; // Already the correct type
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
      
      debugPrint('Uploading audio to storage: $storagePath');
      final Reference storageRef = _storage.ref(storagePath);
      
      // Use a proper standard MIME type for WAV files
      // This is more widely recognized across platforms
      final metadata = SettableMetadata(
        contentType: 'audio/x-wav',
        customMetadata: {
          'uploadedFrom': Platform.isIOS ? 'iOS' : Platform.isAndroid ? 'Android' : 'other'
        }
      );
      
      debugPrint('Uploading with content type: ${metadata.contentType}');
      await storageRef.putData(audioBytes, metadata);
      debugPrint('Upload successful');
      
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
      debugPrint('Received response from transcribe_audio function');
      final responseData = _convertToStringKeyedMap(result.data);
      if (responseData == null) {
        throw Exception('No response data received from Cloud Function');
      }
      
      if (responseData['text'] == null) {
        // Check if there's an error message in the response
        if (responseData['error'] != null) {
          throw Exception('Transcription error: ${responseData['error']}');
        }
        throw Exception('Invalid response format from Cloud Function - missing text field');
      }
      
      debugPrint('Transcription successful');
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
  Future<AssignmentResult> assignPeopleToItems(String transcription, Map<String, dynamic> request) async {
    try {
      // Call the Firebase Cloud Function
      debugPrint('Calling assign_people_to_items with transcription and receipt');
      final callable = _functions.httpsCallable('assign_people_to_items');
      
      // Extract the inner data object from the request
      // The Cloud Function expects direct access to 'transcription' and 'receipt_items' 
      final innerData = request['data'];
      
      // Ensure the transcription parameter is used (in case it was edited)
      // This overrides any transcription that might have been in the request object
      final modifiedData = Map<String, dynamic>.from(innerData);
      modifiedData['transcription'] = transcription;
      
      debugPrint('Request data: ${modifiedData.toString()}');
      
      final result = await callable.call(modifiedData);
      
      debugPrint('Raw result: ${result.data.toString()}');
      
      final responseData = _convertToStringKeyedMap(result.data);
      if (responseData == null) {
        throw Exception('Invalid response format from Cloud Function');
      }
      debugPrint('Parsed response: ${responseData.toString()}');
      
      // This now uses the corrected AssignmentResult.fromJson
      return AssignmentResult.fromJson(responseData);
    } catch (e) {
      // Log the error and rethrow
      debugPrint('Error assigning items: $e');
      rethrow;
    }
  }
  
  // Helper method to convert dynamic Map to Map<String, dynamic>
  Map<String, dynamic> _convertToStringKeyedMap(dynamic data) {
    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        if (key != null) {
          final stringKey = key.toString();
          if (value is Map) {
            result[stringKey] = _convertToStringKeyedMap(value);
          } else if (value is List) {
            result[stringKey] = _convertList(value);
          } else {
            result[stringKey] = value;
          }
        }
      });
      return result;
    }
    throw Exception('Data is not a Map: ${data.runtimeType}');
  }
  
  // Helper method to convert dynamic List
  List<dynamic> _convertList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return _convertToStringKeyedMap(item);
      } else if (item is List) {
        return _convertList(item);
      } else {
        return item;
      }
    }).toList();
  }
} 