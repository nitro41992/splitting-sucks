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
} 