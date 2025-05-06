import 'package:flutter/foundation.dart';
import 'receipt_item.dart';

class Person extends ChangeNotifier {
  String _name;
  final List<ReceiptItem> _assignedItems;
  final List<ReceiptItem> _sharedItems;

  Person({
    required String name,
    List<ReceiptItem>? assignedItems,
    List<ReceiptItem>? sharedItems,
  })  : _name = name,
        _assignedItems = assignedItems ?? [],
        _sharedItems = sharedItems ?? [];

  String get name => _name;
  List<ReceiptItem> get assignedItems => List.unmodifiable(_assignedItems);
  List<ReceiptItem> get sharedItems => List.unmodifiable(_sharedItems);

  void updateName(String newName) {
    if (_name != newName) {
      _name = newName;
      notifyListeners();
    }
  }

  void addAssignedItem(ReceiptItem item) {
    debugPrint('Person.addAssignedItem: Adding item "${item.name}" to ${_name} with price ${item.price} and quantity ${item.quantity}');
    
    // Check if this exact item instance already exists
    bool itemExists = false;
    for (var existingItem in _assignedItems) {
      if (identical(existingItem, item)) {
        itemExists = true;
        debugPrint('  WARNING: This exact item instance already exists in assigned items');
        break;
      }
    }
    
    // Check if an item with the same name exists
    for (var existingItem in _assignedItems) {
      if (existingItem.name == item.name) {
        debugPrint('  WARNING: Item with same name "${item.name}" already exists but with different instance');
        debugPrint('  Existing: ID=${existingItem.itemId}, Price=${existingItem.price}, Quantity=${existingItem.quantity}');
        debugPrint('  New: ID=${item.itemId}, Price=${item.price}, Quantity=${item.quantity}');
      }
    }
    
    // Add the item
    _assignedItems.add(item);
    debugPrint('  Successfully added item - current assigned items count: ${_assignedItems.length}');
    
    notifyListeners();
  }

  void removeAssignedItem(ReceiptItem item) {
    _assignedItems.remove(item);
    notifyListeners();
  }

  void addSharedItem(ReceiptItem item) {
    debugPrint('Person.addSharedItem: Adding shared item "${item.name}" to ${_name} with price ${item.price} and quantity ${item.quantity}');
    
    // Check if this exact item instance already exists
    bool itemExists = false;
    for (var existingItem in _sharedItems) {
      if (identical(existingItem, item)) {
        itemExists = true;
        debugPrint('  WARNING: This exact shared item instance already exists');
        break;
      }
    }
    
    // Check if an item with the same name exists but different instance
    for (var existingItem in _sharedItems) {
      if (!identical(existingItem, item) && existingItem.name == item.name) {
        debugPrint('  WARNING: Shared item with same name "${item.name}" already exists but with different instance');
        debugPrint('  Existing: ID=${existingItem.itemId}, Price=${existingItem.price}, Quantity=${existingItem.quantity}');
        debugPrint('  New: ID=${item.itemId}, Price=${item.price}, Quantity=${item.quantity}');
      }
    }
    
    // Add the item if it doesn't exist
    if (!itemExists) {
      _sharedItems.add(item);
      debugPrint('  Successfully added shared item - current shared items count: ${_sharedItems.length}');
    } else {
      debugPrint('  Did not add duplicate shared item');
    }
    
    notifyListeners();
  }

  void removeSharedItem(ReceiptItem item) {
    _sharedItems.remove(item);
    notifyListeners();
  }

  double get totalAssignedAmount {
    return _assignedItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get totalSharedAmount {
    return _sharedItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  // The total amount a person owes - this includes:
  // 1. Full price of all individually assigned items
  // 2. Full price of all shared items
  // Note: When calculating the split total, you should only count shared items ONCE
  // and not add up each person's shared items (which would double-count)
  double get totalAmount {
    // This would typically be divided by the number of people sharing each item
    // in the final summary screen, but here we show the raw total
    return totalAssignedAmount + totalSharedAmount;
  }

  void debugLogItems() {
    double totalAmount = 0.0;
    
    print("DEBUG: Person \"$_name\" assigned items:");
    for (int i = 0; i < _assignedItems.length; i++) {
      final item = _assignedItems[i];
      final itemTotal = item.price * item.quantity;
      totalAmount += itemTotal;
      print("  - ${item.name} (${item.itemId}): ${item.quantity} x \$${item.price} = \$${itemTotal.toStringAsFixed(2)}");
    }
    
    print("DEBUG: Total amount: \$${totalAmount.toStringAsFixed(2)}");
    print("DEBUG: Total from getter: \$${totalAssignedAmount.toStringAsFixed(2)}");
  }
} 