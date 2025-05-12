import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../test_helpers/connectivity_mock.dart';
import '../../lib/services/connectivity_service.dart';

// This service will be implemented to handle offline storage
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
    
    List<dynamic> decoded = jsonDecode(pendingReceiptsJson);
    return decoded.cast<Map<String, dynamic>>();
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
  
  // Check if we need to save offline
  bool shouldSaveOffline() {
    return !_connectivityService.currentStatus;
  }
}

class MockSharedPreferences extends Mock implements SharedPreferences {
  final Map<String, dynamic> data = {};
  
  @override
  String? getString(String key) {
    return data[key] as String?;
  }
  
  @override
  Future<bool> setString(String key, String value) async {
    data[key] = value;
    return true;
  }
  
  @override
  Future<bool> remove(String key) async {
    data.remove(key);
    return true;
  }
}

void main() {
  late MockSharedPreferences mockPrefs;
  late MockConnectivity mockConnectivity;
  late ConnectivityService connectivityService;
  late OfflineStorageService offlineStorageService;
  
  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockConnectivity = MockConnectivity();
    connectivityService = ConnectivityService(connectivity: mockConnectivity);
    offlineStorageService = OfflineStorageService(
      prefs: mockPrefs,
      connectivityService: connectivityService,
    );
  });
  
  tearDown(() {
    mockConnectivity.dispose();
  });
  
  group('OfflineStorageService', () {
    test('should save receipt data offline', () async {
      // Arrange
      final receiptId = 'receipt123';
      final receiptData = {'name': 'Test Restaurant', 'total': 50.0};
      
      // Act
      final result = await offlineStorageService.saveReceiptOffline(receiptId, receiptData);
      
      // Assert
      expect(result, true);
      final pendingReceipts = offlineStorageService.getPendingReceipts();
      expect(pendingReceipts.length, 1);
      expect(pendingReceipts[0]['id'], receiptId);
      expect(pendingReceipts[0]['data']['name'], 'Test Restaurant');
      expect(pendingReceipts[0]['data']['total'], 50.0);
    });
    
    test('should update existing receipt data', () async {
      // Arrange
      final receiptId = 'receipt123';
      final initialData = {'name': 'Test Restaurant', 'total': 50.0};
      final updatedData = {'name': 'Updated Restaurant', 'total': 75.0};
      
      // Act
      await offlineStorageService.saveReceiptOffline(receiptId, initialData);
      await offlineStorageService.saveReceiptOffline(receiptId, updatedData);
      
      // Assert
      final pendingReceipts = offlineStorageService.getPendingReceipts();
      expect(pendingReceipts.length, 1);
      expect(pendingReceipts[0]['id'], receiptId);
      expect(pendingReceipts[0]['data']['name'], 'Updated Restaurant');
      expect(pendingReceipts[0]['data']['total'], 75.0);
    });
    
    test('should remove pending receipt', () async {
      // Arrange
      final receiptId = 'receipt123';
      final receiptData = {'name': 'Test Restaurant', 'total': 50.0};
      await offlineStorageService.saveReceiptOffline(receiptId, receiptData);
      
      // Act
      final result = await offlineStorageService.removePendingReceipt(receiptId);
      
      // Assert
      expect(result, true);
      final pendingReceipts = offlineStorageService.getPendingReceipts();
      expect(pendingReceipts.length, 0);
    });
    
    test('should clear all pending receipts', () async {
      // Arrange
      await offlineStorageService.saveReceiptOffline('receipt1', {'name': 'Restaurant 1'});
      await offlineStorageService.saveReceiptOffline('receipt2', {'name': 'Restaurant 2'});
      
      // Act
      final result = await offlineStorageService.clearPendingReceipts();
      
      // Assert
      expect(result, true);
      final pendingReceipts = offlineStorageService.getPendingReceipts();
      expect(pendingReceipts.length, 0);
    });
    
    test('shouldSaveOffline returns true when offline', () async {
      // Arrange
      mockConnectivity.setConnectivityResult(ConnectivityResult.none);
      await Future.delayed(Duration.zero); // Let connectivity service update
      
      // Act & Assert
      expect(offlineStorageService.shouldSaveOffline(), true);
    });
    
    test('shouldSaveOffline returns false when online', () async {
      // Arrange
      mockConnectivity.setConnectivityResult(ConnectivityResult.wifi);
      await Future.delayed(Duration.zero); // Let connectivity service update
      
      // Act & Assert
      expect(offlineStorageService.shouldSaveOffline(), false);
    });
  });
} 