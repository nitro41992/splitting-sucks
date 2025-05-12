import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity_service.dart';

class OfflineStorageService {
  static const String _pendingReceiptsKey = 'pendingReceipts';
  final SharedPreferences _prefs;
  final ConnectivityService _connectivityService;
  
  OfflineStorageService({
    required SharedPreferences prefs,
    required ConnectivityService connectivityService,
  }) : _prefs = prefs, 
       _connectivityService = connectivityService;
  
  // Save receipt data for sync later
  Future<bool> saveReceiptOffline(String receiptId, Map<String, dynamic> data) async {
    // Get existing pending receipts
    final List<Map<String, dynamic>> pendingReceipts = getPendingReceipts();
    
    // Add or update this receipt
    bool found = false;
    for (var i = 0; i < pendingReceipts.length; i++) {
      if (pendingReceipts[i]['id'] == receiptId) {
        pendingReceipts[i] = {
          'id': receiptId,
          'data': data,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        found = true;
        break;
      }
    }
    
    if (!found) {
      pendingReceipts.add({
        'id': receiptId,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
    
    // Save back to prefs
    return await _prefs.setString(
      _pendingReceiptsKey, 
      jsonEncode(pendingReceipts),
    );
  }
  
  // Get all pending receipts
  List<Map<String, dynamic>> getPendingReceipts() {
    final String? pendingReceiptsJson = _prefs.getString(_pendingReceiptsKey);
    if (pendingReceiptsJson == null || pendingReceiptsJson.isEmpty) {
      return [];
    }
    
    try {
      List<dynamic> decoded = jsonDecode(pendingReceiptsJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      // Handle JSON decode errors by returning empty list
      return [];
    }
  }
  
  // Remove a receipt from pending
  Future<bool> removePendingReceipt(String receiptId) async {
    final List<Map<String, dynamic>> pendingReceipts = getPendingReceipts();
    pendingReceipts.removeWhere((receipt) => receipt['id'] == receiptId);
    
    return await _prefs.setString(
      _pendingReceiptsKey, 
      jsonEncode(pendingReceipts),
    );
  }
  
  // Clear all pending receipts
  Future<bool> clearPendingReceipts() async {
    return await _prefs.remove(_pendingReceiptsKey);
  }
  
  // Check if we should save offline
  bool shouldSaveOffline() {
    return !_connectivityService.currentStatus;
  }
  
  // Get receipt data by ID
  Map<String, dynamic>? getPendingReceiptById(String receiptId) {
    final pendingReceipts = getPendingReceipts();
    final receipt = pendingReceipts.firstWhere(
      (r) => r['id'] == receiptId,
      orElse: () => <String, dynamic>{},
    );
    
    if (receipt.isEmpty) {
      return null;
    }
    
    return receipt['data'] as Map<String, dynamic>;
  }
  
  // Count of pending receipts
  int get pendingReceiptCount => getPendingReceipts().length;
} 