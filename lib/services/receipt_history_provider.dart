import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../env/env.dart';
import '../models/receipt_history.dart';
import '../models/split_manager.dart';
import 'receipt_history_service.dart';
import 'mock_receipt_history_service.dart';

/// A provider class that decides whether to use the real or mock receipt history service
/// This follows the strategy pattern to provide a consistent interface regardless of implementation
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
  
  // Get the appropriate service implementation based on the environment
  dynamic get _service {
    if (Env.useMockReceiptHistory) {
      return MockReceiptHistoryService(auth: _auth);
    } else {
      return ReceiptHistoryService(firestore: _firestore, auth: _auth);
    }
  }
  
  // Save a receipt
  Future<ReceiptHistory> saveReceipt({
    required SplitManager splitManager,
    required String imageUri,
    required String restaurantName,
    required String status,
    String? transcription,
  }) async {
    return _service.saveReceipt(
      splitManager: splitManager,
      imageUri: imageUri,
      restaurantName: restaurantName,
      status: status,
      transcription: transcription,
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
  }) async {
    return _service.saveDraftReceipt(
      splitManager: splitManager,
      imageUri: imageUri,
      restaurantName: restaurantName,
      transcription: transcription,
    );
  }
  
  // Check if mock data is being used
  bool get isMockData => Env.useMockReceiptHistory;
} 