import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // No longer needed for API key
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
    // Get instance of Cloud Functions & Storage
    FirebaseFunctions functions = FirebaseFunctions.instance;
    FirebaseStorage storage = FirebaseStorage.instance;
    // You can specify a region if your function is not in us-central1
    // functions = FirebaseFunctions.instanceFor(region: 'your-region');

    // --- Upload to Firebase Storage ---
    String? imageUri; // Use gs:// URI
    try {
      // Create a unique filename (e.g., using timestamp or UUID)
      String fileName = 'receipts/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      Reference storageRef = storage.ref().child(fileName);

      print('Uploading to Storage: $fileName');
      UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'), // Set content type (adjust if needed)
      );

      // Await the upload completion
      TaskSnapshot snapshot = await uploadTask;

      // Get the gs:// URI
      // IMPORTANT: Ensure your Cloud Function's service account has permission
      // to read from this bucket (e.g., Storage Object Viewer role).
      imageUri = 'gs://${snapshot.ref.bucket}/${snapshot.ref.fullPath}';
      print('Upload complete. Image URI: $imageUri');

    } on FirebaseException catch (e) {
      print('Storage Upload Error: ${e.code} - ${e.message}');
      throw Exception('Failed to upload image to Firebase Storage: ${e.message}');
    } catch (e) {
      print('Storage Upload Error: $e');
      throw Exception('An unexpected error occurred during image upload: $e');
    }
    // --- End Upload ---


    // Ensure we got a URI before proceeding
    if (imageUri == null) {
       throw Exception('Failed to get image URI from Firebase Storage.');
    }

    try {
      // Prepare the callable function reference
      HttpsCallable callable = functions.httpsCallable('parse_receipt');

      // Call the function with the image URI instead of base64
      print('Calling Cloud Function with URI: $imageUri');
      // Expect a Map back, since the Python function returns a JSON object
      final HttpsCallableResult result = await callable.call<Map<String, dynamic>>(
        {
          // Send the gs:// URI (SDK implicitly wraps this in 'data' for request)
          'imageUri': imageUri,
        },
      );

      // The Cloud Function response structure is {"data": { ...receipt data... }}
      // result.data will be the outer Map<String, dynamic>.
      try {
        // Access the nested 'data' map which contains the actual receipt fields
        // Modified to handle both formats: data.data or data directly 
        final Map<String, dynamic>? receiptMap = result.data is Map<String, dynamic> ? result.data as Map<String, dynamic> : null;

        if (receiptMap == null) {
          print("Error: Cloud function response was not a valid map.");
          print("Raw function response data: ${result.data}");
          throw Exception('Invalid response structure from Cloud Function.');
        }

        // Check if the response has a nested 'data' field
        final Map<String, dynamic> finalReceiptMap = receiptMap.containsKey('data') 
            ? receiptMap['data'] as Map<String, dynamic>
            : receiptMap; // Use the map directly if no 'data' wrapper

        print('Successfully received structured data from Cloud Function.');
        // Parse the map using your existing factory
        return ReceiptData.fromJson(finalReceiptMap);
      } catch (e) {
        // Handle cases where casting fails or other parsing errors occur
        print("Error parsing structured response from Cloud Function: $e");
        print("Raw function response data: ${result.data}");
        throw Exception('Failed to parse Cloud Function response map: $e');
      }

    } on FirebaseFunctionsException catch (e) {
      // Handle Firebase Cloud Functions specific exceptions
      print('Cloud Function Error Code: ${e.code}');
      print('Cloud Function Error Message: ${e.message}');
      print('Cloud Function Error Details: ${e.details}');
      // Clean up the uploaded file if the function call fails? Maybe not, user might retry.
      throw Exception('Error calling Cloud Function (${e.code}): ${e.message}');
    } catch (e) {
      // Catch any other exceptions during the process
      print('Error processing receipt: $e');
      // Clean up uploaded file on general errors?
      throw Exception('Error processing receipt: $e');
    } finally {
       // Optional: Delete the image from Storage after processing?
       // Decide if you want to keep the images in Storage or clean them up.
       // If cleaning up:
       // if (imageUri != null) {
       //   try {
       //     print('Deleting image from storage: $imageUri');
       //     // Extract bucket and path from gs:// URI
       //     final uriParts = imageUri.replaceFirst('gs://', '').split('/');
       //     final bucketName = uriParts.first; // Note: Default bucket often doesn't need explicit naming here
       //     final objectPath = uriParts.sublist(1).join('/');
       //     await storage.ref().child(objectPath).delete();
       //     print('Successfully deleted image from storage.');
       //   } catch (e) {
       //     print('Failed to delete image from storage: $e');
       //     // Log error but don't fail the whole operation just for cleanup failure
       //   }
       // }
    }
  }
} 