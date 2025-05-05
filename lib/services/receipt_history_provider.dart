import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/receipt_history.dart';
import '../models/split_manager.dart';
import 'receipt_history_service.dart';
import 'file_helper.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// A provider class for receipt history operations
/// This class provides a clean interface for receipt history operations
class ReceiptHistoryProvider {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  // Private constructor
  ReceiptHistoryProvider._({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : 
    _firestore = firestore ?? FirebaseFirestore.instance,
    _auth = auth ?? FirebaseAuth.instance;
  
  // Singleton instance
  static ReceiptHistoryProvider? _instance;
  
  // Factory constructor to get instance
  factory ReceiptHistoryProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    _instance ??= ReceiptHistoryProvider._(
      firestore: firestore,
      auth: auth,
    );
    return _instance!;
  }
  
  // Always use the real Firestore service
  ReceiptHistoryService get _service {
    return ReceiptHistoryService(firestore: _firestore, auth: _auth);
  }
  
  // Save a receipt
  Future<ReceiptHistory> saveReceipt({
    required SplitManager splitManager,
    required String imageUri,
    required String restaurantName,
    required String status,
    String? transcription,
    String? existingReceiptId,
  }) async {
    return _service.saveReceipt(
      splitManager: splitManager,
      imageUri: imageUri,
      restaurantName: restaurantName,
      status: status,
      transcription: transcription,
      existingReceiptId: existingReceiptId,
    );
  }
  
  // Update an existing receipt
  Future<void> updateReceipt(ReceiptHistory receipt) async {
    return _service.updateReceipt(receipt);
  }
  
  // Delete a receipt
  Future<void> deleteReceipt(String receiptId) async {
    return _service.deleteReceipt(receiptId);
  }
  
  // Get all receipts for the current user
  Future<List<ReceiptHistory>> getAllReceipts() async {
    return _service.getAllReceipts();
  }
  
  // Get receipts filtered by status
  Future<List<ReceiptHistory>> getReceiptsByStatus(String status) async {
    return _service.getReceiptsByStatus(status);
  }
  
  // Get a specific receipt by ID
  Future<ReceiptHistory?> getReceiptById(String receiptId) async {
    return _service.getReceiptById(receiptId);
  }
  
  // Search receipts by restaurant name
  Future<List<ReceiptHistory>> searchByRestaurantName(String query) async {
    return _service.searchByRestaurantName(query);
  }
  
  // Save draft receipt (auto-save functionality)
  Future<ReceiptHistory> saveDraftReceipt({
    required SplitManager splitManager,
    required String imageUri,
    String restaurantName = 'Draft Receipt',
    String? transcription,
    Map<String, dynamic>? receiptData,
    Map<String, dynamic>? splitManagerState,
    String? existingReceiptId,
  }) async {
    return _service.saveDraftReceipt(
      splitManager: splitManager,
      imageUri: imageUri,
      restaurantName: restaurantName,
      transcription: transcription,
      receiptData: receiptData,
      splitManagerState: splitManagerState,
      existingReceiptId: existingReceiptId,
    );
  }
  
  // Convert a gs:// URI to an HTTPS download URL
  Future<String> getDownloadURL(String? imageUri) async {
    if (imageUri == null || imageUri.isEmpty) {
      debugPrint('Empty or null imageUri provided');
      return '';
    }
    
    try {
      // If it's a gs:// URI, convert it to an HTTPS download URL
      if (imageUri.startsWith('gs://')) {
        final downloadUrl = await FileHelper.getDownloadURLFromGsURI(imageUri);
        return downloadUrl;
      } else if (imageUri.startsWith('http')) {
        // If it's already an HTTPS URL, return it as is
        return imageUri;
      } else {
        debugPrint('Unrecognized image URI format: $imageUri');
        return '';
      }
    } catch (e) {
      debugPrint('Error getting download URL: $e');
      return '';
    }
  }
  
  // This app always uses real data now
  bool get isMockData => false;
} 