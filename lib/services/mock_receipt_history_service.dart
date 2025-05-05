import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/receipt_history.dart';
import '../models/split_manager.dart';
import 'mock_data_service.dart';
import 'package:flutter/foundation.dart';

/// A mock implementation of the receipt history service that uses in-memory data
/// This service is DEPRECATED and should not be used in production
/// It's kept for reference and future testing utilities
class MockReceiptHistoryService {
  final FirebaseAuth _auth;
  List<ReceiptHistory> _mockReceipts = [];
  bool _initialized = false;
  
  // Private constructor
  MockReceiptHistoryService._({
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;
  
  // Singleton instance
  static MockReceiptHistoryService? _instance;
  
  // Factory constructor to get instance
  factory MockReceiptHistoryService({
    FirebaseAuth? auth,
  }) {
    _instance ??= MockReceiptHistoryService._(
      auth: auth,
    );
    
    // Log that we're using mock service - helps with debugging
    debugPrint("⚠️ WARNING: MockReceiptHistoryService is deprecated. Please use real Firestore data.");
    
    return _instance!;
  }
  
  // Get the current user ID or use a fallback for testing
  String get _userId {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("Warning: No authenticated user found, using fallback 'mock_user_id'");
        return 'mock_user_id';
      }
      return user.uid;
    } catch (e) {
      debugPrint("Error getting current user: $e - using fallback 'mock_user_id'");
      return 'mock_user_id';
    }
  }
  
  // Initialize mock data
  Future<void> _initializeIfNeeded() async {
    if (_initialized) return;
    
    debugPrint("Initializing MockReceiptHistoryService...");
    
    try {
      // Create mock receipts through the MockDataService
      _mockReceipts = MockDataService.createMockReceiptHistories(
        userId: _userId,
        count: 5, // Create 5 mock receipts
      );
      
      debugPrint("MockReceiptHistoryService initialized with ${_mockReceipts.length} mock receipts");
    } catch (e) {
      debugPrint("Error initializing mock receipt history: $e");
      _mockReceipts = [];
    }
    
    _initialized = true;
  }
  
  // Save a receipt
  Future<ReceiptHistory> saveReceipt({
    required SplitManager splitManager,
    required String imageUri,
    required String restaurantName,
    required String status,
    String? transcription,
  }) async {
    await _initializeIfNeeded();
    
    final receipt = MockDataService.createMockReceiptHistory(
      userId: _userId,
      restaurantName: restaurantName,
      status: status,
      createdAt: DateTime.now(),
      imageUri: imageUri,
    );
    
    _mockReceipts.add(receipt);
    
    return receipt;
  }
  
  // Update an existing receipt
  Future<void> updateReceipt(ReceiptHistory receipt) async {
    await _initializeIfNeeded();
    
    final index = _mockReceipts.indexWhere((r) => r.id == receipt.id);
    if (index >= 0) {
      _mockReceipts[index] = receipt;
    }
  }
  
  // Delete a receipt
  Future<void> deleteReceipt(String receiptId) async {
    await _initializeIfNeeded();
    
    _mockReceipts.removeWhere((receipt) => receipt.id == receiptId);
  }
  
  // Get all receipts for the current user
  Future<List<ReceiptHistory>> getAllReceipts() async {
    await _initializeIfNeeded();
    
    // Return a copy of the list instead of an unmodifiable list
    return List<ReceiptHistory>.from(_mockReceipts);
  }
  
  // Get receipts filtered by status
  Future<List<ReceiptHistory>> getReceiptsByStatus(String status) async {
    await _initializeIfNeeded();
    
    return _mockReceipts
        .where((receipt) => receipt.status == status)
        .toList();
  }
  
  // Get a specific receipt by ID
  Future<ReceiptHistory?> getReceiptById(String receiptId) async {
    await _initializeIfNeeded();
    
    return _mockReceipts
        .firstWhere((receipt) => receipt.id == receiptId, orElse: () => null as ReceiptHistory)
        as ReceiptHistory?;
  }
  
  // Search receipts by restaurant name
  Future<List<ReceiptHistory>> searchByRestaurantName(String query) async {
    await _initializeIfNeeded();
    
    final lowerQuery = query.toLowerCase();
    return _mockReceipts
        .where((receipt) => receipt.restaurantName.toLowerCase().contains(lowerQuery))
        .toList();
  }
  
  // Save draft receipt (auto-save functionality)
  Future<ReceiptHistory> saveDraftReceipt({
    required SplitManager splitManager,
    required String imageUri,
    String restaurantName = 'Draft Receipt',
    String? transcription,
  }) async {
    return saveReceipt(
      splitManager: splitManager,
      imageUri: imageUri,
      restaurantName: restaurantName,
      status: 'draft',
      transcription: transcription,
    );
  }
} 