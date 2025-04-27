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
  ];

  static final List<String> mockPeople = [
    "John",
    "Sarah",
    "Mike",
    "Emma",
  ];

  static final Map<String, List<ReceiptItem>> mockAssignments = {
    "John": [mockItems[0], mockItems[1]], // Burger and Fries
    "Sarah": [mockItems[2]], // Soda
    "Mike": [mockItems[3]], // Salad
    "Emma": [mockItems[4]], // Pizza
  };

  static final List<ReceiptItem> mockSharedItems = [
    mockItems[1], // Fries are shared
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
    for (final item in mockSharedItems) {
      splitManager.addSharedItem(item);
    }
    
    return splitManager;
  }
} 