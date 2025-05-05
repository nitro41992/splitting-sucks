import 'package:cloud_firestore/cloud_firestore.dart';
import 'receipt_item.dart';
import 'split_manager.dart';
import 'person.dart';

class ReceiptHistory {
  final String id;
  final String imageUri;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String userId;
  final String restaurantName;
  final String status; // 'completed' or 'draft'
  final double totalAmount;
  final Map<String, dynamic> receiptData;
  final String? transcription;
  final List<String> people;
  final List<Map<String, dynamic>> personTotals;
  final Map<String, dynamic> splitManagerState;

  ReceiptHistory({
    required this.id,
    required this.imageUri,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.restaurantName,
    required this.status,
    required this.totalAmount,
    required this.receiptData,
    this.transcription,
    required this.people,
    required this.personTotals,
    required this.splitManagerState,
  });

  // Convert Firestore document to ReceiptHistory object
  factory ReceiptHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ReceiptHistory(
      id: doc.id,
      imageUri: data['image_uri'] ?? '',
      createdAt: data['created_at'] as Timestamp,
      updatedAt: data['updated_at'] as Timestamp,
      userId: data['userId'] ?? '',
      restaurantName: data['restaurant_name'] ?? '',
      status: data['status'] ?? 'draft',
      totalAmount: (data['total_amount'] ?? 0.0).toDouble(),
      receiptData: data['receipt_data'] ?? {},
      transcription: data['transcription'],
      people: List<String>.from(data['people'] ?? []),
      personTotals: List<Map<String, dynamic>>.from(data['person_totals'] ?? []),
      splitManagerState: data['split_manager_state'] ?? {},
    );
  }

  // Convert ReceiptHistory object to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'image_uri': imageUri,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'userId': userId,
      'restaurant_name': restaurantName,
      'status': status,
      'total_amount': totalAmount,
      'receipt_data': receiptData,
      'transcription': transcription,
      'people': people,
      'person_totals': personTotals,
      'split_manager_state': splitManagerState,
    };
  }

  // Create a ReceiptHistory from the current app state
  static ReceiptHistory fromAppState({
    required SplitManager splitManager,
    required String userId,
    required String imageUri,
    required String restaurantName,
    required String status,
    String? transcription,
    String? id,
  }) {
    // Convert receipt items to maps for storage
    final receiptItems = splitManager.unassignedItems.map((item) => _receiptItemToMap(item)).toList();
    
    // Create receipt data structure
    final receiptData = {
      'items': receiptItems,
      'subtotal': splitManager.unassignedItemsTotal,
    };

    // Create person totals list
    final personTotals = splitManager.people.map((person) => {
      'name': person.name,
      'total': person.totalAmount,
    }).toList();

    // Create the split manager state
    final splitManagerState = _createSplitManagerState(splitManager);

    // Get list of people names
    final people = splitManager.people.map((person) => person.name).toList();

    return ReceiptHistory(
      id: id ?? FirebaseFirestore.instance.collection('users/$userId/receipts').doc().id,
      imageUri: imageUri,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      userId: userId,
      restaurantName: restaurantName,
      status: status,
      totalAmount: splitManager.totalAmount,
      receiptData: receiptData,
      transcription: transcription,
      people: people,
      personTotals: personTotals.cast<Map<String, dynamic>>(),
      splitManagerState: splitManagerState,
    );
  }

  // Restore app state from this history record
  SplitManager toSplitManager() {
    // Extract receipt items from split manager state
    final people = _extractPeopleFromState();
    final sharedItems = _extractSharedItemsFromState();
    final unassignedItems = _extractUnassignedItemsFromState();
    
    return SplitManager(
      people: people,
      sharedItems: sharedItems,
      unassignedItems: unassignedItems,
    );
  }

  // Helper methods
  List<Person> _extractPeopleFromState() {
    final peopleData = (splitManagerState['people'] ?? []) as List;
    return peopleData.map((personData) {
      final assignedItemsData = (personData['assignedItems'] ?? []) as List;
      final assignedItems = assignedItemsData.map((item) => _mapToReceiptItem(item)).toList();
      
      return Person(
        name: personData['name'] ?? '',
        assignedItems: assignedItems,
        // Note: shared items are handled separately
      );
    }).toList();
  }

  List<ReceiptItem> _extractSharedItemsFromState() {
    final sharedItemsData = (splitManagerState['sharedItems'] ?? []) as List;
    return sharedItemsData.map((item) => _mapToReceiptItem(item)).toList();
  }

  List<ReceiptItem> _extractUnassignedItemsFromState() {
    final unassignedItemsData = (splitManagerState['unassignedItems'] ?? []) as List;
    return unassignedItemsData.map((item) => _mapToReceiptItem(item)).toList();
  }

  // Helper to convert Map to ReceiptItem
  static ReceiptItem _mapToReceiptItem(Map<String, dynamic> map) {
    return ReceiptItem(
      name: map['item'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 1,
      itemId: 'item_${map['id']}_${map['item']}',
    );
  }

  // Helper to convert ReceiptItem to Map
  static Map<String, dynamic> _receiptItemToMap(ReceiptItem item) {
    return {
      'id': int.tryParse(item.itemId.split('_')[1]) ?? 0,
      'item': item.name,
      'quantity': item.quantity,
      'price': item.price,
    };
  }

  // Create split manager state map from SplitManager
  static Map<String, dynamic> _createSplitManagerState(SplitManager splitManager) {
    // Convert people data
    final peopleData = splitManager.people.map((person) {
      return {
        'id': person.name,
        'name': person.name,
        'assignedItems': person.assignedItems.map((item) => _receiptItemToMap(item)).toList(),
      };
    }).toList();

    // Convert shared items
    final sharedItemsData = splitManager.sharedItems.map((item) {
      // Find which people have this shared item
      final sharedBy = splitManager.people
          .where((person) => person.sharedItems.contains(item))
          .map((person) => person.name)
          .toList();

      return {
        ...ReceiptHistory._receiptItemToMap(item),
        'shared_by': sharedBy,
      };
    }).toList();

    // Convert unassigned items
    final unassignedItemsData = splitManager.unassignedItems
        .map((item) => _receiptItemToMap(item))
        .toList();

    // Create the state object
    return {
      'people': peopleData,
      'sharedItems': sharedItemsData,
      'unassignedItems': unassignedItemsData,
      'tipAmount': 0.0, // This should be updated with actual tip data when available
      'taxAmount': 0.0, // This should be updated with actual tax data when available
      'subtotal': splitManager.unassignedItemsTotal,
      'total': splitManager.totalAmount,
    };
  }

  // Create a copy of this receipt with updated properties
  ReceiptHistory copyWith({
    String? id,
    String? imageUri,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? userId,
    String? restaurantName,
    String? status,
    double? totalAmount,
    Map<String, dynamic>? receiptData,
    String? transcription,
    List<String>? people,
    List<Map<String, dynamic>>? personTotals,
    Map<String, dynamic>? splitManagerState,
  }) {
    return ReceiptHistory(
      id: id ?? this.id,
      imageUri: imageUri ?? this.imageUri,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? Timestamp.now(), // Always update the timestamp
      userId: userId ?? this.userId,
      restaurantName: restaurantName ?? this.restaurantName,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      receiptData: receiptData ?? this.receiptData,
      transcription: transcription ?? this.transcription,
      people: people ?? this.people,
      personTotals: personTotals ?? this.personTotals,
      splitManagerState: splitManagerState ?? this.splitManagerState,
    );
  }
} 