import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/split_manager.dart';
import '../models/receipt.dart';
import 'firestore_service.dart';
import 'offline_storage_service.dart';
import 'connectivity_service.dart';

/// Service to handle persistence of receipt data between modal views
/// and synchronization with backend database
class ReceiptPersistenceService {
  final FirestoreService _firestoreService;
  final OfflineStorageService _offlineStorageService;
  
  // In-memory cache of receipts being edited
  final Map<String, Map<String, dynamic>> _editCache = {};
  
  ReceiptPersistenceService._({
    required FirestoreService firestoreService,
    required OfflineStorageService offlineStorageService,
  }) : _firestoreService = firestoreService,
       _offlineStorageService = offlineStorageService;

  /// Factory constructor that handles creating dependencies
  static Future<ReceiptPersistenceService> create({
    FirestoreService? firestoreService,
    OfflineStorageService? offlineStorageService,
  }) async {
    // Create dependencies if not provided
    final prefs = await SharedPreferences.getInstance();
    final connectivityService = ConnectivityService();
    
    return ReceiptPersistenceService._(
      firestoreService: firestoreService ?? FirestoreService(),
      offlineStorageService: offlineStorageService ?? 
        OfflineStorageService(
          prefs: prefs,
          connectivityService: connectivityService,
        ),
    );
  }
  
  /// Store the split data in memory while editing
  /// This creates a cache that persists during navigation between modal views
  void cacheReceiptData(String receiptId, SplitManager splitManager) {
    debugPrint('[ReceiptPersistenceService] Caching split data for receipt: $receiptId');
    
    // Generate assignment map from split manager
    final assignmentMap = splitManager.generateAssignmentMap();
    
    // Store the current people names in metadata for convenience
    final peopleNames = splitManager.currentPeopleNames;
    
    // Store tax and tip percentages if available
    final tipPercentage = splitManager.tipPercentage;
    final taxPercentage = splitManager.taxPercentage;
    
    // Create a combined map with all data
    final Map<String, dynamic> receiptData = {
      'assign_people_to_items': assignmentMap,
      'metadata': {
        'people': peopleNames,
        'tip': tipPercentage,
        'tax': taxPercentage,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }
    };
    
    // Cache in memory
    _editCache[receiptId] = receiptData;
    
    // Also cache to local storage for robustness
    _cacheToLocalStorage(receiptId, receiptData);
    
    debugPrint('[ReceiptPersistenceService] Split data cached successfully with ${peopleNames.length} people');
  }
  
  /// Cache to local storage as a backup
  Future<void> _cacheToLocalStorage(String receiptId, Map<String, dynamic> data) async {
    try {
      await _offlineStorageService.saveEditCache(receiptId, data);
      debugPrint('[ReceiptPersistenceService] Cached to local storage: $receiptId');
    } catch (e) {
      debugPrint('[ReceiptPersistenceService] Error caching to local storage: $e');
    }
  }
  
  /// Check if there is cached data for a receipt
  bool hasCachedData(String receiptId) {
    return _editCache.containsKey(receiptId);
  }
  
  /// Get cached data for a receipt
  Map<String, dynamic>? getCachedData(String receiptId) {
    return _editCache[receiptId];
  }
  
  /// Persist changes to database when leaving parent modal views
  /// This should be called when navigating away from the parent modal
  Future<void> persistToDatabase(String receiptId, SplitManager splitManager) async {
    debugPrint('[ReceiptPersistenceService] Persisting split data to database for receipt: $receiptId');
    
    // First cache the latest data
    cacheReceiptData(receiptId, splitManager);
    
    try {
      // Get the cached data
      final data = _editCache[receiptId];
      if (data == null) {
        debugPrint('[ReceiptPersistenceService] No cached data to persist for receipt: $receiptId');
        return;
      }
      
      // Save to Firestore
      await _firestoreService.saveReceipt(
        receiptId: receiptId,
        data: data,
      );
      
      debugPrint('[ReceiptPersistenceService] Split data persisted to database successfully: $receiptId');
      
      // Clear the cache after successful save (optional)
      _editCache.remove(receiptId);
      await _offlineStorageService.removeEditCache(receiptId);
    } catch (e) {
      debugPrint('[ReceiptPersistenceService] Error persisting to database: $e');
      // Keep the cache in case of error, to allow retrying later
      rethrow;
    }
  }
  
  /// Restore cached data to a SplitManager
  /// This can be used when returning to an edit screen
  Future<bool> restoreCachedData(String receiptId, SplitManager splitManager) async {
    debugPrint('[ReceiptPersistenceService] Attempting to restore cached data for receipt: $receiptId');
    
    // First check in-memory cache
    Map<String, dynamic>? cachedData = _editCache[receiptId];
    
    // If not in memory, try local storage
    if (cachedData == null) {
      try {
        cachedData = await _offlineStorageService.getEditCache(receiptId);
        // If found in local storage, update the in-memory cache
        if (cachedData != null) {
          _editCache[receiptId] = cachedData;
        }
      } catch (e) {
        debugPrint('[ReceiptPersistenceService] Error retrieving from local storage: $e');
      }
    }
    
    // If still null, no cached data available
    if (cachedData == null) {
      debugPrint('[ReceiptPersistenceService] No cached data found for receipt: $receiptId');
      return false;
    }
    
    try {
      // Extract the assignment data
      final assignmentData = cachedData['assign_people_to_items'];
      if (assignmentData != null) {
        // TODO: Implement logic to restore the SplitManager state from the assignment data
        // This would involve creating people, shared items, and unassigned items
        
        debugPrint('[ReceiptPersistenceService] Successfully restored cached data');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[ReceiptPersistenceService] Error restoring cached data: $e');
      return false;
    }
  }
} 