import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for Firestore CRUD operations related to receipts
/// 
/// Handles emulator connections based on environment variables.
/// All operations are scoped to the current authenticated user.
class FirestoreService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  
  /// Private constructor used by factory constructor
  FirestoreService._({
    required FirebaseFirestore db,
    required FirebaseStorage storage,
    required FirebaseAuth auth,
  }) : _db = db,
       _storage = storage,
       _auth = auth;
  
  /// Factory constructor that configures Firestore with emulator if needed
  factory FirestoreService() {
    // Get environment variables
    final useEmulator = dotenv.env['USE_FIRESTORE_EMULATOR'] == 'true';
    
    // Get instances
    final db = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;
    final auth = FirebaseAuth.instance;
    
    // Connect to emulators if enabled
    if (useEmulator) {
      debugPrint('🔧 Connecting to Firestore emulator on localhost:8081');
      db.useFirestoreEmulator('localhost', 8081);
      storage.useStorageEmulator('localhost', 9199);
      // Note: If you also need Auth emulator, uncomment:
      // auth.useAuthEmulator('localhost', 9099);
    }
    
    return FirestoreService._(
      db: db,
      storage: storage,
      auth: auth,
    );
  }
  
  /// Gets the current user ID, or throws an error if not logged in
  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }
  
  /// Reference to the user's receipts collection
  CollectionReference get _receiptsCollection {
    return _db.collection('users').doc(_userId).collection('receipts');
  }
  
  /// Get a specific receipt by ID
  Future<DocumentSnapshot> getReceipt(String receiptId) async {
    return await _receiptsCollection.doc(receiptId).get();
  }
  
  /// Get all receipts for the current user, with optional filtering
  /// If [status] is provided, only returns receipts with that status
  Future<QuerySnapshot> getReceipts({String? status}) async {
    Query query = _receiptsCollection.orderBy('metadata.updated_at', descending: true);
    
    if (status != null) {
      query = query.where('metadata.status', isEqualTo: status);
    }
    
    return await query.get();
  }
  
  /// Create a new receipt or update an existing one
  /// If [receiptId] is null, a new receipt will be created
  /// Returns the ID of the created/updated receipt
  Future<String> saveReceipt({
    String? receiptId,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Ensure metadata exists
      if (!data.containsKey('metadata')) {
        data['metadata'] = {};
      }
      
      // Add/update timestamps
      data['metadata']['updated_at'] = FieldValue.serverTimestamp();
      
      // If new receipt, add created_at timestamp
      if (receiptId == null) {
        data['metadata']['created_at'] = FieldValue.serverTimestamp();
      }
      
      // If receiptId is null, add a new document, otherwise update existing
      final docRef = receiptId == null
          ? await _receiptsCollection.add(data)
          : _receiptsCollection.doc(receiptId);
      
      // If updating existing, update the document
      if (receiptId != null) {
        await docRef.set(data, SetOptions(merge: true));
      }
      
      // Return the document ID
      return receiptId ?? docRef.id;
    } catch (e) {
      debugPrint('Error saving receipt: $e');
      rethrow;
    }
  }
  
  /// Save receipt as draft
  Future<String> saveDraft({
    String? receiptId,
    required Map<String, dynamic> data,
  }) async {
    // Ensure metadata exists
    if (!data.containsKey('metadata')) {
      data['metadata'] = {};
    }
    
    // Set status to draft
    data['metadata']['status'] = 'draft';
    
    // Save the receipt
    return await saveReceipt(
      receiptId: receiptId,
      data: data,
    );
  }
  
  /// Mark a receipt as completed
  /// This updates the status and ensures required fields are present
  Future<String> completeReceipt({
    required String receiptId,
    required Map<String, dynamic> data,
    required String restaurantName,
    double? tip,
    double? tax,
  }) async {
    // Ensure metadata exists
    if (!data.containsKey('metadata')) {
      data['metadata'] = {};
    }
    
    // Set status to completed
    data['metadata']['status'] = 'completed';
    
    // Set restaurant name
    data['metadata']['restaurant_name'] = restaurantName;
    
    // Set default tip if not provided (20%)
    if (tip != null) {
      data['metadata']['tip'] = tip;
    } else if (!data['metadata'].containsKey('tip')) {
      data['metadata']['tip'] = 20.0; // Default 20%
    }
    
    // Set default tax if not provided (8.875%)
    if (tax != null) {
      data['metadata']['tax'] = tax;
    } else if (!data['metadata'].containsKey('tax')) {
      data['metadata']['tax'] = 8.875; // Default 8.875%
    }
    
    // Save the receipt
    return await saveReceipt(
      receiptId: receiptId,
      data: data,
    );
  }
  
  /// Delete a receipt by ID
  Future<void> deleteReceipt(String receiptId) async {
    try {
      await _receiptsCollection.doc(receiptId).delete();
    } catch (e) {
      debugPrint('Error deleting receipt: $e');
      rethrow;
    }
  }
  
  /// Upload a receipt image to Firebase Storage and return the URI
  /// Returns a gs:// URI like 'gs://bucket-name/path/to/image.jpg'
  Future<String> uploadReceiptImage(File imageFile) async {
    try {
      // Create a unique filename using timestamp
      String fileName = 'receipts/${_userId}/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      Reference storageRef = _storage.ref().child(fileName);

      debugPrint('Uploading receipt to Storage: $fileName');
      UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Await the upload completion
      TaskSnapshot snapshot = await uploadTask;

      // Get the gs:// URI
      final imageUri = 'gs://${snapshot.ref.bucket}/${snapshot.ref.fullPath}';
      debugPrint('Receipt upload complete. URI: $imageUri');
      
      return imageUri;
    } catch (e) {
      debugPrint('Error uploading receipt image: $e');
      rethrow;
    }
  }
  
  /// Generate a thumbnail for a receipt image and return the URI
  /// This should be called after uploading the original image
  Future<String?> generateThumbnail(String originalImageUri) async {
    try {
      // Extract the path from the original image URI
      final uriParts = originalImageUri.replaceFirst('gs://', '').split('/');
      final bucketName = uriParts.first;
      final objectPath = uriParts.sublist(1).join('/');
      
      // Generate a thumbnail path based on original path
      final originalPath = objectPath;
      final thumbnailPath = originalPath.replaceFirst('receipts/', 'thumbnails/');
      
      // Create a reference to the thumbnail location
      final thumbnailRef = _storage.ref(thumbnailPath);
      
      // Generate the thumbnail URL
      final thumbnailUri = 'gs://${thumbnailRef.bucket}/${thumbnailRef.fullPath}';
      
      // Create a Cloud Function call to generate the thumbnail
      // For now we'll return the original URI as this would need a separate Cloud Function
      // TODO: Implement proper thumbnail generation via Cloud Function
      
      debugPrint('Thumbnail generated at: $thumbnailUri');
      return originalImageUri; // Temporary until Cloud Function is implemented
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }
  
  /// Delete a receipt image from Firebase Storage
  Future<void> deleteReceiptImage(String imageUri) async {
    try {
      // Extract bucket and path from gs:// URI
      final uriParts = imageUri.replaceFirst('gs://', '').split('/');
      final bucketName = uriParts.first;
      final objectPath = uriParts.sublist(1).join('/');
      
      // Delete the image
      await _storage.ref(objectPath).delete();
      debugPrint('Successfully deleted image from storage: $imageUri');
    } catch (e) {
      debugPrint('Error deleting receipt image: $e');
      rethrow;
    }
  }
} 