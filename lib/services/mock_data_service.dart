import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receipt_item.dart';
import '../models/person.dart';
import '../models/split_manager.dart';
import '../models/receipt_history.dart';

class MockDataService {
  static final List<ReceiptItem> mockItems = [
    ReceiptItem(name: "Burger", price: 12.99, quantity: 1),
    ReceiptItem(name: "Fries", price: 4.99, quantity: 2),
    ReceiptItem(name: "Soda", price: 2.99, quantity: 3),
    ReceiptItem(name: "Salad", price: 8.99, quantity: 1),
    ReceiptItem(name: "Pizza", price: 15.99, quantity: 1),
    ReceiptItem(name: "Ice Cream", price: 6.99, quantity: 1),
    ReceiptItem(name: "Coffee", price: 3.99, quantity: 2),
    ReceiptItem(name: "Chicken Wings", price: 13.99, quantity: 1),
    ReceiptItem(name: "Nachos", price: 11.99, quantity: 1),
    ReceiptItem(name: "Milkshake", price: 7.99, quantity: 2),
    ReceiptItem(name: "Garlic Bread", price: 5.99, quantity: 1),
    ReceiptItem(name: "Caesar Salad", price: 9.99, quantity: 1),
    ReceiptItem(name: "Appetizer", price: 15.99, quantity: 1),
  ];

  static final List<String> mockPeople = [
    "John",
    "Sarah",
    "Mike",
    "Emma",
  ];

  static final Map<String, List<ReceiptItem>> mockAssignments = {
    "John": [mockItems[0], mockItems[7]], // Burger and Chicken Wings
    "Sarah": [mockItems[2], mockItems[9]], // Soda and Milkshake
    "Mike": [mockItems[3], mockItems[11]], // Salad and Caesar Salad
    "Emma": [mockItems[4], mockItems[8]], // Pizza and Nachos
  };

  static final List<ReceiptItem> mockSharedItems = [
    mockItems[12], // Appetizer shared by John and Sarah
    mockItems[10], // Garlic Bread shared by everyone
  ];

  static final List<ReceiptItem> mockUnassignedItems = [
    mockItems[1], // Fries
    mockItems[5], // Ice Cream
    mockItems[6], // Coffee
  ];

  static SplitManager createMockSplitManager() {
    final splitManager = SplitManager();
    
    // Add people
    for (final personName in mockPeople) {
      splitManager.addPerson(personName);
    }
    
    // Add assigned items
    mockAssignments.forEach((personName, items) {
      final person = splitManager.people.firstWhere((p) => p.name == personName);
      for (final item in items) {
        splitManager.assignItemToPerson(item, person);
      }
    });
    
    // Add shared items
    // Appetizer - shared by John and Sarah
    splitManager.addSharedItem(mockSharedItems[0]);
    final johnAndSarah = splitManager.people.where((p) => p.name == "John" || p.name == "Sarah").toList();
    for (final person in johnAndSarah) {
      person.addSharedItem(mockSharedItems[0]);
    }

    // Garlic Bread - shared by everyone
    splitManager.addSharedItem(mockSharedItems[1]);
    for (final person in splitManager.people) {
      person.addSharedItem(mockSharedItems[1]);
    }

    // Add unassigned items
    for (final item in mockUnassignedItems) {
      splitManager.addUnassignedItem(item);
    }
    
    return splitManager;
  }
  
  // Mock image URIs from the design document
  static final List<String> mockImageUris = [
    'gs://billfie.firebasestorage.app/receipts/PXL_20240815_225730738.jpg', // Restaurant receipt
    'gs://billfie.firebasestorage.app/receipts/PXL_20241207_220416408.MP.jpg', // Grocery receipt
    'gs://billfie.firebasestorage.app/receipts/PXL_20250419_011719007.jpg', // Coffee shop receipt
    'gs://billfie.firebasestorage.app/receipts/PXL_20250504_180915852.jpg', // Takeout receipt
  ];

  // Mock restaurant names
  static final List<String> mockRestaurantNames = [
    'Pizza Place',
    'Grocery Store',
    'Coffee Shop',
    'Burger Joint',
    'Taco Truck',
  ];

  // Generate a single mock receipt history
  static ReceiptHistory createMockReceiptHistory({
    required String userId,
    String? id,
    String? status,
    String? restaurantName,
    DateTime? createdAt,
    String? imageUri,
  }) {
    final splitManager = createMockSplitManager();
    
    // Create receipt data structure
    final receiptItems = mockItems.map((item) => {
      'id': mockItems.indexOf(item),
      'item': item.name,
      'quantity': item.quantity,
      'price': item.price,
    }).toList();
    
    final receiptData = {
      'items': receiptItems,
      'subtotal': mockItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity)),
    };

    // Create person totals
    final personTotals = mockPeople.map((name) {
      final assignedItems = mockAssignments[name] ?? [];
      final assignedTotal = assignedItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
      
      // Calculate shared amount (simplified calculation)
      double sharedTotal = 0.0;
      if (name == "John" || name == "Sarah") {
        sharedTotal += mockSharedItems[0].price / 2; // Appetizer shared by 2
      }
      sharedTotal += mockSharedItems[1].price / 4; // Garlic bread shared by 4
      
      return {
        'name': name,
        'total': assignedTotal + sharedTotal,
      };
    }).toList();

    // Create split manager state
    final peopleData = mockPeople.map((name) {
      final assignedItems = mockAssignments[name] ?? [];
      return {
        'id': name,
        'name': name,
        'assignedItems': assignedItems.map((item) => {
          'id': mockItems.indexOf(item),
          'item': item.name,
          'quantity': item.quantity,
          'price': item.price,
        }).toList(),
      };
    }).toList();

    final sharedItemsData = [
      {
        'id': mockItems.indexOf(mockSharedItems[0]),
        'item': mockSharedItems[0].name,
        'quantity': mockSharedItems[0].quantity,
        'price': mockSharedItems[0].price,
        'shared_by': ['John', 'Sarah'],
      },
      {
        'id': mockItems.indexOf(mockSharedItems[1]),
        'item': mockSharedItems[1].name,
        'quantity': mockSharedItems[1].quantity,
        'price': mockSharedItems[1].price,
        'shared_by': ['John', 'Sarah', 'Mike', 'Emma'],
      },
    ];

    final unassignedItemsData = mockUnassignedItems.map((item) => {
      'id': mockItems.indexOf(item),
      'item': item.name,
      'quantity': item.quantity,
      'price': item.price,
    }).toList();

    final splitManagerState = {
      'people': peopleData,
      'sharedItems': sharedItemsData,
      'unassignedItems': unassignedItemsData,
      'tipAmount': 10.0,
      'taxAmount': 8.5,
      'subtotal': 120.0,
      'total': 138.5,
    };

    final timestamp = createdAt != null 
        ? Timestamp.fromDate(createdAt)
        : Timestamp.fromDate(DateTime.now().subtract(Duration(days: mockRestaurantNames.indexOf(restaurantName ?? mockRestaurantNames[0]))));

    return ReceiptHistory(
      id: id ?? 'mock_receipt_${DateTime.now().millisecondsSinceEpoch}',
      imageUri: imageUri ?? mockImageUris[mockRestaurantNames.indexOf(restaurantName ?? mockRestaurantNames[0]) % mockImageUris.length],
      createdAt: timestamp,
      updatedAt: timestamp,
      userId: userId,
      restaurantName: restaurantName ?? mockRestaurantNames[0],
      status: status ?? 'completed',
      totalAmount: 138.5,
      receiptData: receiptData,
      transcription: 'Mock voice transcription data for ${restaurantName ?? mockRestaurantNames[0]}',
      people: mockPeople,
      personTotals: personTotals.cast<Map<String, dynamic>>(),
      splitManagerState: splitManagerState,
    );
  }

  // Generate multiple mock receipt histories
  static List<ReceiptHistory> createMockReceiptHistories({
    required String userId,
    int count = 5,
  }) {
    final List<ReceiptHistory> receipts = [];
    
    // Create completed receipts
    for (int i = 0; i < count - 1; i++) {
      final daysAgo = i * 5; // Space them out by 5 days
      receipts.add(createMockReceiptHistory(
        userId: userId,
        restaurantName: mockRestaurantNames[i % mockRestaurantNames.length],
        status: 'completed',
        createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
        imageUri: mockImageUris[i % mockImageUris.length],
      ));
    }
    
    // Add one draft receipt
    receipts.add(createMockReceiptHistory(
      userId: userId,
      restaurantName: 'Draft Receipt',
      status: 'draft',
      createdAt: DateTime.now().subtract(Duration(days: 1)),
      imageUri: mockImageUris.last,
    ));
    
    return receipts;
  }
} 