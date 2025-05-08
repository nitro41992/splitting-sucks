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
  /// Either:
  /// 1. Uploads the image file to Firebase Storage if a File is provided, or
  /// 2. Uses the provided Storage URL (gs:// or https://) directly if a String is provided.
  /// 
  /// Then calls the parse_receipt Cloud Function to process it.
  static Future<ReceiptData> parseReceipt(dynamic imageSource) async {
    // Get instance of Cloud Functions & Storage
    FirebaseFunctions functions = FirebaseFunctions.instance;
    FirebaseStorage storage = FirebaseStorage.instance;
    
    String? imageGsUri; // Will hold the gs:// URI to process 
    
    // --- Handle Image Source --- 
    if (imageSource == null) {
      throw Exception('Image source cannot be null.');
    }

    if (imageSource is File) {
      // CASE 1: We received a File object - upload it to Firebase Storage
      try {
        String fileName = 'receipts/${DateTime.now().millisecondsSinceEpoch}_${imageSource.path.split('/').last}';
        Reference storageRef = storage.ref().child(fileName);

        debugPrint('[ReceiptParserService] Uploading receipt File to Storage: $fileName');
        UploadTask uploadTask = storageRef.putFile(
          imageSource,
          SettableMetadata(contentType: 'image/jpeg'), // Assuming JPEG, adjust if needed
        );
        TaskSnapshot snapshot = await uploadTask;
        imageGsUri = 'gs://${snapshot.ref.bucket}/${snapshot.ref.fullPath}';
        debugPrint('[ReceiptParserService] Receipt File upload complete. GS URI: $imageGsUri');
      } on FirebaseException catch (e) {
        debugPrint('[ReceiptParserService] Storage upload error for File: ${e.code} - ${e.message}');
        throw Exception('Failed to upload receipt image file: ${e.message}');
      } catch (e) {
        debugPrint('[ReceiptParserService] Unexpected storage upload error for File: $e');
        throw Exception('Failed to upload receipt image file: $e');
      }
    } else if (imageSource is String) {
      // CASE 2: We received a URL string
      debugPrint('[ReceiptParserService] Processing String imageSource: $imageSource');
      if (imageSource.startsWith('gs://')) {
        // It's already a gs:// URI, use as is
        imageGsUri = imageSource;
        debugPrint('[ReceiptParserService] Using provided GS URI directly: $imageGsUri');
      } else if (imageSource.startsWith('https://') || imageSource.startsWith('http://')) {
        // It's an HTTP/S URL, attempt to convert to gs:// URI
        try {
          debugPrint('[ReceiptParserService] Converting HTTP/S URL to GS URI: $imageSource');
          // FirebaseStorage.refFromURL can take an HTTP/S URL for a Firebase Storage object
          Reference storageRef = storage.refFromURL(imageSource);
          imageGsUri = 'gs://${storageRef.bucket}/${storageRef.fullPath}';
          debugPrint('[ReceiptParserService] Converted to GS URI: $imageGsUri');
        } catch (e) {
          debugPrint('[ReceiptParserService] Error converting HTTP/S URL to GS URI: $e. Image source: $imageSource');
          throw Exception('Invalid Firebase Storage HTTP/S URL or failed to convert: $e');
        }
      } else {
        debugPrint('[ReceiptParserService] Unrecognized String imageSource format: $imageSource');
        throw Exception('Invalid string image source. Must be a gs:// URI or a Firebase Storage HTTP/S URL.');
      }
    } else {
      // CASE 3: Unsupported image source type
      debugPrint('[ReceiptParserService] Invalid image source type: ${imageSource.runtimeType}');
      throw Exception('Invalid image source type. Must be a File or a String (gs:// or https:// URL).');
    }
    // --- End Handle Image Source ---

    // Ensure we got a GS URI before proceeding
    if (imageGsUri == null || imageGsUri.isEmpty) {
       throw Exception('Failed to determine image GS URI from the provided source.');
    }

    try {
      HttpsCallable callable = functions.httpsCallable('parse_receipt');
      debugPrint('[ReceiptParserService] Calling parse_receipt Cloud Function with GS URI: $imageGsUri');
      final HttpsCallableResult result = await callable.call<Map<String, dynamic>>(
        {
          'imageUri': imageGsUri, // Ensure the Cloud Function expects 'imageUri'
        },
      );

      final Map<String, dynamic>? receiptMap = result.data is Map<String, dynamic> ? result.data as Map<String, dynamic> : null;
      if (receiptMap == null) {
        debugPrint("[ReceiptParserService] Error: Invalid response structure from Cloud Function. Data is null or not a map.");
        throw Exception('Invalid response from receipt parser Cloud Function.');
      }

      final Map<String, dynamic> finalReceiptMap = receiptMap.containsKey('data') && receiptMap['data'] is Map<String, dynamic>
          ? receiptMap['data'] as Map<String, dynamic>
          : receiptMap;

      return ReceiptData.fromJson(finalReceiptMap);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[ReceiptParserService] Cloud Function error: ${e.code} - ${e.message} - ${e.details}');
      throw Exception('Receipt parsing Cloud Function failed: Code: ${e.code}, Message: ${e.message}');
    } catch (e) {
      debugPrint('[ReceiptParserService] General error during Cloud Function call or data parsing: $e');
      throw Exception('Receipt processing failed: $e');
    }
    // No finally block for deleting image, as this service might be called with pre-existing URIs.
    // Deletion logic should be handled by the caller if needed (e.g., after a File upload and successful parse).
  }
} 