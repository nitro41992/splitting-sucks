import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class AssignmentResult {
  final Map<String, dynamic> assignments;
  final List<dynamic> shared_items;
  final List<dynamic>? unassigned_items;

  AssignmentResult({
    required this.assignments,
    required this.shared_items,
    this.unassigned_items,
  });

  factory AssignmentResult.fromJson(Map<String, dynamic> json) {
    final assignmentsMap = json['assignments'];
    final sharedItemsList = json['shared_items'];
    final unassignedItemsList = json['unassigned_items'];

    return AssignmentResult(
      assignments: assignmentsMap is Map ? Map<String, dynamic>.from(assignmentsMap) : {},
      shared_items: sharedItemsList is List ? List<dynamic>.from(sharedItemsList) : [],
      unassigned_items: unassignedItemsList is List ? List<dynamic>.from(unassignedItemsList) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'assignments': assignments,
        'shared_items': shared_items,
        if (unassigned_items != null) 'unassigned_items': unassigned_items,
      };

  List<SharedItem> getSharedItems() {
    return shared_items
        .map((item) => SharedItem.fromJson(item as Map<String, dynamic>))
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
  // Firebase Firestore instance for database operations
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
      
      // Parse the response - convert to proper Map<String, dynamic> first
      final responseData = _convertToStringKeyedMap(result.data);
      
      if (responseData == null) {
        throw Exception('Invalid response format from Cloud Function');
      }
      
      debugPrint('Parsed response: ${responseData.toString()}');
      
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

  Future<void> saveAssignmentsToService(String receiptId, Map<String, dynamic> assignments) async {
    debugPrint('STARTING SAVE ASSIGNMENTS: ${assignments.keys.join(", ")}');
    
    // Debug logging for assignments structure
    if (assignments.containsKey('assignments')) {
      final assignmentsMap = assignments['assignments'] as Map<String, dynamic>;
      debugPrint('Assignments map has ${assignmentsMap.length} people');
      assignmentsMap.forEach((person, items) {
        final itemsList = items as List<dynamic>;
        debugPrint('  Person $person has ${itemsList.length} assigned items');
      });
    } else {
      debugPrint('WARNING: No "assignments" key found in assignments map!');
    }
    
    // Debug logging for shared items
    if (assignments.containsKey('shared_items')) {
      final sharedItems = assignments['shared_items'] as List<dynamic>;
      debugPrint('Shared items list has ${sharedItems.length} items');
      for (final sharedItem in sharedItems) {
        final itemMap = sharedItem as Map<String, dynamic>;
        final itemName = itemMap['name'] as String;
        List<String> peopleList = [];
        if (itemMap.containsKey('people') && itemMap['people'] is List<dynamic>) {
          final people = itemMap['people'] as List<dynamic>;
          peopleList = people.map((p) => p.toString()).toList();
        }
        debugPrint('  Shared item $itemName is shared among ${peopleList.length} people: ${peopleList.join(", ")}');
      }
    } else {
      debugPrint('WARNING: No "shared_items" key found in assignments map!');
    }
    
    // Debug logging for unassigned items
    if (assignments.containsKey('unassigned_items')) {
      final unassignedItems = assignments['unassigned_items'] as List<dynamic>;
      debugPrint('Unassigned items list has ${unassignedItems.length} items');
      for (final item in unassignedItems) {
        final itemMap = item as Map<String, dynamic>;
        final itemName = itemMap['name'] as String;
        final price = itemMap['price'] as num;
        debugPrint('  Unassigned item: $itemName, Price: \$${price.toStringAsFixed(2)}');
      }
    } else {
      debugPrint('WARNING: No "unassigned_items" key found in assignments map!');
    }
    
    try {
      // The key here MUST match receiptService.saveAssignPeopleToItemsResults
      debugPrint('SAVING TO FIRESTORE: ${assignments.keys.join(", ")}');
      await _firestore.collection('receipts').doc(receiptId).update({
        'assign_people_to_items': assignments,
      });
      
      // Additional check to ensure data was written as expected
      final savedDoc = await _firestore.collection('receipts').doc(receiptId).get();
      final savedData = savedDoc.data();
      if (savedData != null && savedData.containsKey('assign_people_to_items')) {
        final savedAssignments = savedData['assign_people_to_items'] as Map<String, dynamic>;
        
        // Check assignments
        if (savedAssignments.containsKey('assignments')) {
          final assignmentsMap = savedAssignments['assignments'] as Map<String, dynamic>;
          debugPrint('Firestore assignments map has ${assignmentsMap.length} people');
          assignmentsMap.forEach((person, items) {
            final itemsList = items as List<dynamic>;
            debugPrint('  Person $person items type: ${items.runtimeType}');
            debugPrint('  Person $person has ${itemsList.length} assigned items');
          });
        }
        
        // Check shared items
        if (savedAssignments.containsKey('shared_items')) {
          final sharedItems = savedAssignments['shared_items'] as List<dynamic>;
          debugPrint('Firestore shared_items has ${sharedItems.length} items');
        }
        
        // Check unassigned items
        if (savedAssignments.containsKey('unassigned_items')) {
          final unassignedItems = savedAssignments['unassigned_items'] as List<dynamic>;
          debugPrint('Firestore unassigned_items has ${unassignedItems.length} items');
        }
        
        debugPrint('ASSIGNMENTS SAVED SUCCESSFULLY TO FIRESTORE');
      } else {
        debugPrint('WARNING: Could not verify saved data in Firestore!');
      }
    } catch (e) {
      debugPrint('Error saving assignments to Firestore: $e');
      rethrow;
    }
  }
} 