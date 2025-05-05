import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/receipt_history.dart';
import '../models/split_manager.dart';
import 'package:flutter/foundation.dart';

class ReceiptHistoryService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  // Private constructor
  ReceiptHistoryService._({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : 
    _firestore = firestore ?? FirebaseFirestore.instance,
    _auth = auth ?? FirebaseAuth.instance;
  
  // Singleton instance
  static ReceiptHistoryService? _instance;
  
  // Factory constructor to get instance
  factory ReceiptHistoryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    _instance ??= ReceiptHistoryService._(
      firestore: firestore,
      auth: auth,
    );
    return _instance!;
  }
  
  // Get the current user ID or throw an error if no user is logged in
  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }
  
  // Reference to the user's receipts collection
  CollectionReference<Map<String, dynamic>> get _receiptsCollection {
    return _firestore.collection('users/$_userId/receipts');
  }
  
  // Save a receipt to Firestore
  Future<ReceiptHistory> saveReceipt({
    required SplitManager splitManager,
    required String imageUri,
    required String restaurantName,
    required String status,
    String? transcription,
    String? existingReceiptId,
  }) async {
    // Create a ReceiptHistory object from the current state
    final receipt = ReceiptHistory.fromAppState(
      splitManager: splitManager,
      userId: _userId,
      imageUri: imageUri,
      restaurantName: restaurantName,
      status: status,
      transcription: transcription,
      id: existingReceiptId, // Pass the existing ID if provided
    );
    
    // Save to Firestore - update if existingReceiptId is provided
    if (existingReceiptId != null) {
      await _receiptsCollection.doc(existingReceiptId).update(receipt.toFirestore());
    } else {
      await _receiptsCollection.doc(receipt.id).set(receipt.toFirestore());
    }
    
    return receipt;
  }
  
  // Update an existing receipt
  Future<void> updateReceipt(ReceiptHistory receipt) async {
    await _receiptsCollection.doc(receipt.id).update({
      'updated_at': Timestamp.now(),
      'restaurant_name': receipt.restaurantName,
      'status': receipt.status,
      'total_amount': receipt.totalAmount,
      'receipt_data': receipt.receiptData,
      'transcription': receipt.transcription,
      'people': receipt.people,
      'person_totals': receipt.personTotals,
      'split_manager_state': receipt.splitManagerState,
    });
  }
  
  // Delete a receipt
  Future<void> deleteReceipt(String receiptId) async {
    await _receiptsCollection.doc(receiptId).delete();
  }
  
  // Get all receipts for the current user
  Future<List<ReceiptHistory>> getAllReceipts() async {
    final snapshot = await _receiptsCollection.get();
    return snapshot.docs.map((doc) => ReceiptHistory.fromFirestore(doc)).toList();
  }
  
  // Get receipts filtered by status
  Future<List<ReceiptHistory>> getReceiptsByStatus(String status) async {
    final snapshot = await _receiptsCollection
        .where('status', isEqualTo: status)
        .orderBy('updated_at', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => ReceiptHistory.fromFirestore(doc)).toList();
  }
  
  // Get a specific receipt by ID
  Future<ReceiptHistory?> getReceiptById(String receiptId) async {
    final doc = await _receiptsCollection.doc(receiptId).get();
    if (!doc.exists) {
      return null;
    }
    return ReceiptHistory.fromFirestore(doc);
  }
  
  // Search receipts by restaurant name
  Future<List<ReceiptHistory>> searchByRestaurantName(String query) async {
    // This is a simple implementation that doesn't use proper full-text search
    // For a production app, consider using Algolia or a similar search service
    final snapshot = await _receiptsCollection
        .orderBy('restaurant_name')
        .startAt([query])
        .endAt([query + '\uf8ff'])
        .get();
    
    return snapshot.docs.map((doc) => ReceiptHistory.fromFirestore(doc)).toList();
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
    // Use a custom implementation for drafts if receipt data is provided
    if (receiptData != null) {
      // Create a ReceiptHistory object from the current state
      final String documentId = existingReceiptId ?? 
          FirebaseFirestore.instance.collection('users/$_userId/receipts').doc().id;
      
      final receipt = ReceiptHistory(
        id: documentId,
        imageUri: imageUri,
        createdAt: existingReceiptId != null ? 
            (await _receiptsCollection.doc(existingReceiptId).get())['created_at'] ?? Timestamp.now() :
            Timestamp.now(),
        updatedAt: Timestamp.now(),
        userId: _userId,
        restaurantName: restaurantName,
        status: 'draft',
        totalAmount: receiptData['subtotal'] ?? 0.0,
        receiptData: receiptData,
        transcription: transcription,
        people: [],
        personTotals: [],
        splitManagerState: splitManagerState ?? splitManager.getSplitManagerState() ?? {},
      );
      
      // Save to Firestore - either update existing or create new
      if (existingReceiptId != null) {
        debugPrint('Updating existing receipt: $existingReceiptId');
        await _receiptsCollection.doc(existingReceiptId).update(receipt.toFirestore());
      } else {
        debugPrint('Creating new receipt');
        await _receiptsCollection.doc(receipt.id).set(receipt.toFirestore());
      }
      
      return receipt;
    } else {
      // Use the standard implementation if no receipt data provided
      if (existingReceiptId != null) {
        // For updating existing receipt without receipt data
        final existingReceipt = await getReceiptById(existingReceiptId);
        if (existingReceipt != null) {
          final updatedReceipt = existingReceipt.copyWith(
            imageUri: imageUri,
            updatedAt: Timestamp.now(),
            restaurantName: restaurantName,
            status: 'draft',
            transcription: transcription,
            splitManagerState: splitManager.getSplitManagerState() ?? {},
          );
          
          await updateReceipt(updatedReceipt);
          return updatedReceipt;
        }
      }
      
      return saveReceipt(
        splitManager: splitManager,
        imageUri: imageUri,
        restaurantName: restaurantName,
        status: 'draft',
        transcription: transcription,
      );
    }
  }
} 