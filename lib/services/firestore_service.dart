import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/receipt.dart';

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
    // Get instances
    final db = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;
    final auth = FirebaseAuth.instance;
    
    // Emulator connections are now handled in main()
    
    return FirestoreService._(
      db: db,
      storage: storage,
      auth: auth,
    );
  }
  
  /// Factory constructor for testing purposes
  @visibleForTesting
  factory FirestoreService.test({
    required FirebaseFirestore db,
    required FirebaseStorage storage,
    required FirebaseAuth auth,
  }) {
    return FirestoreService._(
      db: db,
      storage: storage,
      auth: auth,
    );
  }
  
  /// Gets the current user ID.
  String get _userId {
    final user = _auth.currentUser;
    final bool useEmulator = dotenv.env['USE_FIRESTORE_EMULATOR'] == 'true';

    if (user != null) {
      // If a user is logged in, always use their UID
      debugPrint('FirestoreService: Using actual user ID: ${user.uid}');
      return user.uid;
    } else {
      // No user is logged in
      if (useEmulator) {
        // In emulator mode, and no user is logged in.
        // Decide how to handle this. For now, throw to avoid accidental data access
        // to a hardcoded ID when no one is actually authenticated.
        // You could return a specific 'anonymous-emulator-user-id' if you have
        // data seeded for such a case and intend anonymous access.
        debugPrint('FirestoreService: No authenticated user in emulator mode. Throwing error.');
        throw Exception('User not logged in (emulator mode - no anonymous fallback configured)');
      } else {
        // In production, require authentication
        debugPrint('FirestoreService: User not logged in (production). Throwing error.');
        throw Exception('User not logged in');
      }
    }
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
  
  /// Get a stream of all receipts for the current user, ordered by updated_at.
  /// Useful for real-time updates in the UI.
  Stream<QuerySnapshot> getReceiptsStream() {
    Query query = _receiptsCollection.orderBy('metadata.updated_at', descending: true);
    return query.snapshots();
  }
  
  /// Get a paginated list of receipts for the current user.
  /// 
  /// [limit] specifies the number of receipts to retrieve per page.
  /// [startAfterDoc] is an optional [DocumentSnapshot] to start fetching after.
  Future<QuerySnapshot> getReceiptsPaginated({
    required int limit,
    DocumentSnapshot? startAfterDoc,
  }) async {
    Query query = _receiptsCollection.orderBy('metadata.updated_at', descending: true).limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
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
      
      // Create a separate mutable copy of the data to avoid modifying the original
      Map<String, dynamic> dataToSave = Map<String, dynamic>.from(data);
      if (!dataToSave.containsKey('metadata')) {
        dataToSave['metadata'] = {};
      } else {
        dataToSave['metadata'] = Map<String, dynamic>.from(dataToSave['metadata']);
      }
      
      // Add/update timestamps
      dataToSave['metadata']['updated_at'] = FieldValue.serverTimestamp();
      
      DocumentReference docRef;
      String definitiveReceiptId;

      if (receiptId == null) {
        // Truly new receipt, ID generated by Firestore
        dataToSave['metadata']['created_at'] = FieldValue.serverTimestamp();
        docRef = await _receiptsCollection.add(dataToSave);
        definitiveReceiptId = docRef.id;
        debugPrint('[FirestoreService.saveReceipt] Added new document with ID: $definitiveReceiptId');
      } else {
        // ReceiptId is provided (could be existing or new client-generated ID)
        docRef = _receiptsCollection.doc(receiptId);
        definitiveReceiptId = receiptId;

        // Check if the document exists to determine if it's a create or update
        final snapshot = await docRef.get();
        if (!snapshot.exists) {
          // Document doesn't exist, so this is its first save (create with specific ID)
          dataToSave['metadata']['created_at'] = FieldValue.serverTimestamp(); // Add created_at for new doc
          await docRef.set(dataToSave); // Create
          debugPrint('[FirestoreService.saveReceipt] Set new document with provided ID: $definitiveReceiptId');
        } else {
          // Document exists, so update (merge to preserve fields not in 'data' map, e.g. created_at)
          // Ensure 'created_at' is not accidentally overwritten if it was already in 'data' from a client model
          dataToSave['metadata'].remove('created_at'); // Prefer server-set created_at, don't overwrite
          await docRef.set(dataToSave, SetOptions(merge: true)); // Update/Merge
          debugPrint('[FirestoreService.saveReceipt] Merged (updated) document with ID: $definitiveReceiptId');
        }
      }
      
      return definitiveReceiptId;
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
  }) async {
    // Ensure metadata exists (already handled by Receipt.toMap, but safe check)
    if (!data.containsKey('metadata')) {
      data['metadata'] = {};
    }
    
    // Create a separate mutable copy of the data to avoid modifying the original
    Map<String, dynamic> dataToSave = Map<String, dynamic>.from(data);
    if (!dataToSave.containsKey('metadata')) {
      dataToSave['metadata'] = {};
    } else {
      dataToSave['metadata'] = Map<String, dynamic>.from(dataToSave['metadata']);
    }
    
    // Set status to completed
    dataToSave['metadata']['status'] = 'completed';
    
    // Ensure updated_at is set (Receipt.toMap handles this)
    dataToSave['metadata']['updated_at'] = FieldValue.serverTimestamp();
    
    // Update the document using the provided data map
    try {
      final docRef = _receiptsCollection.doc(receiptId);
      // Use set with merge option instead of update to ensure all fields are properly updated
      await docRef.set(dataToSave, SetOptions(merge: true));
      return docRef.id;
    } catch (e) {
      debugPrint('Error completing receipt: $e');
      rethrow;
    }
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
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('generate_thumbnail');
      
      debugPrint('Calling generate_thumbnail function with URI: $originalImageUri');
      final HttpsCallableResult result = await callable.call({
        'imageUri': originalImageUri
      });
      
      // Robust check for thumbnailUri in the result data
      if (result.data != null && 
          result.data is Map<String, dynamic> && 
          result.data['thumbnailUri'] != null &&
          result.data['thumbnailUri'] is String &&
          (result.data['thumbnailUri'] as String).isNotEmpty) {
            
        final thumbnailUri = result.data['thumbnailUri'] as String;
        // Further check if the returned URI is for the 'thumbnails/' path
        if (thumbnailUri.startsWith('gs://') && thumbnailUri.contains('/thumbnails/')) {
          debugPrint('Thumbnail generated successfully at: $thumbnailUri');
          return thumbnailUri;
        } else {
          debugPrint('Warning: Cloud function returned a thumbnailUri, but it does not appear to be a valid thumbnail path: $thumbnailUri. Original: $originalImageUri');
          // This could happen if the cloud function logic is flawed and returns the original URI
          return null; // Treat as failure if path is suspicious
        }
      } else {
        debugPrint('Thumbnail generation response was missing, null, empty, or had an unexpected format for thumbnailUri. Result data: ${result.data}');
        return null;
      }
    } on FirebaseFunctionsException catch (e) {
      // Handle specific FirebaseFunctionsExceptions
      debugPrint('FirebaseFunctionsException calling generate_thumbnail function: ${e.code} - ${e.message}');
      if (e.details != null) {
        debugPrint('FirebaseFunctionsException details: ${e.details}');
      }
      // Depending on the error code, you might want to handle it differently or just return null
      return null; // Explicitly return null on caught Firebase Functions errors
    } catch (e) {
      // Catch any other unexpected errors
      debugPrint('Generic error calling generate_thumbnail function: $e');
      return null; // Explicitly return null on other errors
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

  /// Delete an image from Firebase Storage using its GS URI
  Future<void> deleteImage(String gsUri) async {
    if (!gsUri.startsWith('gs://')) {
      debugPrint('Invalid GS URI provided for deletion: $gsUri');
      throw ArgumentError('Invalid GS URI format');
    }
    
    debugPrint('Attempting to delete image from Storage: $gsUri');
    try {
      Reference storageRef = _storage.refFromURL(gsUri);
      await storageRef.delete();
      debugPrint('Successfully deleted image from Storage: $gsUri');
    } on FirebaseException catch (e) {
      // Handle specific Firebase errors, e.g., object-not-found
      if (e.code == 'object-not-found') {
        debugPrint('Image not found in Storage (already deleted?): $gsUri');
        // Optionally ignore this error if it's acceptable that the file might not exist
      } else {
        debugPrint('Firebase error deleting image $gsUri: $e');
        rethrow; // Re-throw other Firebase errors
      }
    } catch (e) {
      debugPrint('Generic error deleting image $gsUri: $e');
      rethrow; // Re-throw other types of errors
    }
  }
} 