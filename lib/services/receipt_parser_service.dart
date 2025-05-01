import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // No longer needed for API key
import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/models/person.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Data model representing a receipt with items and subtotal
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
  
  /// Convert raw API response items to ReceiptItem objects
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

/// Service for parsing receipts using Firebase Cloud Functions
class ReceiptParserService {
  
  /// Parses a receipt image using the Firebase Cloud Function
  /// 
  /// Uploads the image to Firebase Storage and then calls the parse_receipt
  /// Cloud Function to process it with OpenAI's API.
  static Future<ReceiptData> parseReceipt(File imageFile) async {
    // Get instance of Cloud Functions & Storage
    FirebaseFunctions functions = FirebaseFunctions.instance;
    FirebaseStorage storage = FirebaseStorage.instance;
    // You can specify a region if your function is not in us-central1
    // functions = FirebaseFunctions.instanceFor(region: 'your-region');

    // --- Upload to Firebase Storage ---
    String? imageUri; // Use gs:// URI
    try {
      // Create a unique filename using timestamp
      String fileName = 'receipts/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      Reference storageRef = storage.ref().child(fileName);

      debugPrint('Uploading receipt to Storage: $fileName');
      UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Await the upload completion
      TaskSnapshot snapshot = await uploadTask;

      // Get the gs:// URI
      // IMPORTANT: Ensure your Cloud Function's service account has permission
      // to read from this bucket (e.g., Storage Object Viewer role).
      imageUri = 'gs://${snapshot.ref.bucket}/${snapshot.ref.fullPath}';
      debugPrint('Receipt upload complete. URI: $imageUri');

    } on FirebaseException catch (e) {
      debugPrint('Storage upload error: ${e.code} - ${e.message}');
      throw Exception('Failed to upload receipt image: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected storage upload error: $e');
      throw Exception('Failed to upload receipt image: $e');
    }
    // --- End Upload ---


    // Ensure we got a URI before proceeding
    if (imageUri == null) {
       throw Exception('Failed to get image URI from Firebase Storage.');
    }

    try {
      // Prepare the callable function reference
      HttpsCallable callable = functions.httpsCallable('parse_receipt');

      // Call the function with the image URI
      debugPrint('Calling parse_receipt function with URI');
      final HttpsCallableResult result = await callable.call<Map<String, dynamic>>(
        {
          'imageUri': imageUri,
        },
      );

      try {
        // Access the response data
        final Map<String, dynamic>? receiptMap = result.data is Map<String, dynamic> ? result.data as Map<String, dynamic> : null;

        if (receiptMap == null) {
          debugPrint("Error: Invalid response structure from Cloud Function");
          throw Exception('Invalid response from receipt parser');
        }

        // Check if the response has a nested 'data' field
        final Map<String, dynamic> finalReceiptMap = receiptMap.containsKey('data') 
            ? receiptMap['data'] as Map<String, dynamic>
            : receiptMap; // Use the map directly if no 'data' wrapper

        // Parse the map
        return ReceiptData.fromJson(finalReceiptMap);
      } catch (e) {
        debugPrint("Error parsing receipt data: $e");
        throw Exception('Failed to parse receipt data: $e');
      }

    } on FirebaseFunctionsException catch (e) {
      // Handle Firebase Cloud Functions specific exceptions
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      throw Exception('Receipt parsing failed: ${e.message}');
    } catch (e) {
      // Catch any other exceptions
      debugPrint('Receipt processing error: $e');
      throw Exception('Receipt processing failed: $e');
    } finally {
       // Optional: Delete the image from Storage after processing?
       // Decide if you want to keep the images in Storage or clean them up.
       // If cleaning up:
       // if (imageUri != null) {
       //   try {
       //     debugPrint('Deleting image from storage: $imageUri');
       //     // Extract bucket and path from gs:// URI
       //     final uriParts = imageUri.replaceFirst('gs://', '').split('/');
       //     final bucketName = uriParts.first; // Note: Default bucket often doesn't need explicit naming here
       //     final objectPath = uriParts.sublist(1).join('/');
       //     await storage.ref().child(objectPath).delete();
       //     debugPrint('Successfully deleted image from storage.');
       //   } catch (e) {
       //     debugPrint('Failed to delete image from storage: $e');
       //     // Log error but don't fail the whole operation just for cleanup failure
       //   }
       // }
    }
  }
} 