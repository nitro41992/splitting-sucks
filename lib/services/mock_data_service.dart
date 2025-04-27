import 'package:flutter/foundation.dart';
import '../models/receipt_item.dart';
import '../models/person.dart';
import '../models/split_manager.dart';

class MockDataService {
  static final List<ReceiptItem> mockItems = [
    ReceiptItem(name: "Burger", price: 12.99, quantity: 1),
    ReceiptItem(name: "Fries", price: 4.99, quantity: 2),
    ReceiptItem(name: "Soda", price: 2.99, quantity: 3),
    ReceiptItem(name: "Salad", price: 8.99, quantity: 1),
    ReceiptItem(name: "Pizza", price: 15.99, quantity: 1),
    ReceiptItem(name: "Ice Cream", price: 6.99, quantity: 1),
    ReceiptItem(name: "Coffee", price: 3.99, quantity: 2),
  ];

  static final List<String> mockPeople = [
    "John",
    "Sarah",
    "Mike",
    "Emma",
  ];

  static final Map<String, List<ReceiptItem>> mockAssignments = {
    "John": [mockItems[0]], // Burger
    "Sarah": [mockItems[2]], // Soda
    "Mike": [mockItems[3]], // Salad
    "Emma": [mockItems[4]], // Pizza
  };

  static final List<ReceiptItem> mockSharedItems = [
    mockItems[1], // Fries are shared by everyone
    ReceiptItem(name: "Appetizer", price: 15.99, quantity: 1), // Appetizer shared by John and Sarah only
  ];

  static final List<ReceiptItem> mockUnassignedItems = [
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
    // First shared item (Fries) - shared by everyone
    splitManager.addSharedItem(mockSharedItems[0]);
    for (final person in splitManager.people) {
      person.addSharedItem(mockSharedItems[0]);
    }

    // Second shared item (Appetizer) - shared by John and Sarah only
    splitManager.addSharedItem(mockSharedItems[1]);
    final johnAndSarah = splitManager.people.where((p) => p.name == "John" || p.name == "Sarah").toList();
    for (final person in johnAndSarah) {
      person.addSharedItem(mockSharedItems[1]);
    }

    // Add unassigned items
    for (final item in mockUnassignedItems) {
      splitManager.addUnassignedItem(item);
    }
    
    return splitManager;
  }
} 