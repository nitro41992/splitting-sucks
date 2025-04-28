import 'package:flutter/foundation.dart';
import 'person.dart';
import 'receipt_item.dart';

class SplitManager extends ChangeNotifier {
  List<Person> _people;
  List<ReceiptItem> _sharedItems;
  List<ReceiptItem> _unassignedItems;
  Map<String, int> _originalQuantities;  // Track original quantities from review

  SplitManager({
    List<Person>? people,
    List<ReceiptItem>? sharedItems,
    List<ReceiptItem>? unassignedItems,
  })  : _people = people ?? [],
        _sharedItems = sharedItems ?? [],
        _unassignedItems = unassignedItems ?? [],
        _originalQuantities = {};

  List<Person> get people => List.unmodifiable(_people);
  List<ReceiptItem> get sharedItems => List.unmodifiable(_sharedItems);
  List<ReceiptItem> get unassignedItems => List.unmodifiable(_unassignedItems);

  void reset() {
    _people = [];
    _sharedItems = [];
    _unassignedItems = [];
    notifyListeners();
  }

  void addPerson(String name) {
    _people.add(Person(name: name));
    notifyListeners();
  }

  void removePerson(Person person) {
    _people.remove(person);
    notifyListeners();
  }

  void updatePersonName(Person person, String newName) {
    person.updateName(newName);
    notifyListeners();
  }

  void addSharedItem(ReceiptItem item) {
    if (!_sharedItems.contains(item)) {
      _sharedItems.add(item);
      notifyListeners();
    }
  }

  void removeSharedItem(ReceiptItem item) {
    _sharedItems.remove(item);
    // Also remove from all people's shared items
    for (var person in _people) {
      person.removeSharedItem(item);
    }
    notifyListeners();
  }

  void assignItemToPerson(ReceiptItem item, Person person) {
    // Check if the person already has this item
    for (int i = 0; i < person.assignedItems.length; i++) {
      if (person.assignedItems[i].isSameItem(item)) {
        // Person already has this item, update the quantity
        int newQuantity = person.assignedItems[i].quantity + item.quantity;
        person.assignedItems[i].updateQuantity(newQuantity);
        notifyListeners();
        return;
      }
    }
    
    // If we get here, the person doesn't have this item yet
    person.addAssignedItem(item);
    notifyListeners();
  }

  void unassignItemFromPerson(ReceiptItem item, Person person) {
    person.removeAssignedItem(item);
    notifyListeners();
  }

  void addItemToShared(ReceiptItem item, List<Person> people) {
    // First add to shared items if not already there
    if (!_sharedItems.contains(item)) {
      _sharedItems.add(item);
    }
    
    // Then add to each person's shared items
    for (var person in people) {
      if (!person.sharedItems.contains(item)) {
        person.addSharedItem(item);
      }
    }
    notifyListeners();
  }

  void removeItemFromShared(ReceiptItem item) {
    _sharedItems.remove(item);
    notifyListeners();
  }

  void addUnassignedItem(ReceiptItem item) {
    if (!_unassignedItems.contains(item)) {
      // If this item doesn't have an original quantity set, set it to its current quantity
      if (!_originalQuantities.containsKey(item.name)) {
        setOriginalQuantity(item, item.quantity);
      }
      _unassignedItems.add(item);
      notifyListeners();
    }
  }

  void removeUnassignedItem(ReceiptItem item) {
    _unassignedItems.remove(item);
    notifyListeners();
  }

  double get totalAmount {
    double total = 0;
    // Sum individual assigned items only (not shared items)
    for (var person in _people) {
      total += person.totalAssignedAmount; // Only count individually assigned items
    }
    // Add shared items (counted only once)
    total += _sharedItems.fold(0, (sum, item) => sum + item.total);
    // Add unassigned items
    total += _unassignedItems.fold(0, (sum, item) => sum + item.total);
    return total;
  }

  double get sharedItemsTotal {
    return _sharedItems.fold(0, (sum, item) => sum + item.total);
  }

  double get unassignedItemsTotal {
    return _unassignedItems.fold(0, (sum, item) => sum + item.total);
  }

  // New method to add a single person to an existing shared item
  void addPersonToSharedItem(ReceiptItem item, Person person) {
    // Ensure the item is in the main shared list first (should usually be true)
    if (!_sharedItems.contains(item)) {
      _sharedItems.add(item);
    }
    // Add item to the specific person's shared list
    if (!person.sharedItems.contains(item)) {
      person.addSharedItem(item); // This should call notifyListeners in Person
    }
    notifyListeners(); // Notify SplitManager listeners
  }

  // New method to remove a single person from a shared item
  void removePersonFromSharedItem(ReceiptItem item, Person person) {
    // Remove item from the specific person's shared list
    if (person.sharedItems.contains(item)) {
      person.removeSharedItem(item); // This should call notifyListeners in Person
    }
    notifyListeners(); // Notify SplitManager listeners
  }

  // Method to set original quantity from review page
  void setOriginalQuantity(ReceiptItem item, int quantity) {
    _originalQuantities[item.name] = quantity;
  }

  // Method to get original quantity
  int getOriginalQuantity(ReceiptItem item) {
    return _originalQuantities[item.name] ?? item.quantity;
  }

  // Get total quantity currently used for an item across all sections
  int getTotalUsedQuantity(String itemName) {
    int total = 0;
    
    // Check unassigned items
    for (var item in _unassignedItems) {
      if (item.name == itemName) {
        total += item.quantity;
      }
    }
    
    // Check shared items
    for (var item in _sharedItems) {
      if (item.name == itemName) {
        total += item.quantity;
      }
    }
    
    // Check assigned items in all people
    for (var person in _people) {
      for (var item in person.assignedItems) {
        if (item.name == itemName) {
          total += item.quantity;
        }
      }
    }
    
    return total;
  }

  // Get remaining available quantity for an item
  int getAvailableQuantity(ReceiptItem item) {
    final originalQuantity = getOriginalQuantity(item);
    final usedQuantity = getTotalUsedQuantity(item.name);
    return originalQuantity - usedQuantity + item.quantity; // Add back the item's own quantity
  }

  // Update the quantity management method
  void updateItemQuantity(ReceiptItem item, int newQuantity) {
    final availableQuantity = getAvailableQuantity(item);
    
    // Cannot increase beyond available quantity
    if (newQuantity > availableQuantity) {
      return;
    }
    
    // Allow quantity to be zero (removed minimum of 1)
    if (newQuantity < 0) {
      return;
    }

    if (newQuantity < item.quantity) {
      // If decreasing quantity, move the decremented amount to unassigned
      final decrementedAmount = item.quantity - newQuantity;
      
      // Check if there's already an unassigned item with the same name and price
      bool foundExistingItem = false;
      
      for (int i = 0; i < _unassignedItems.length; i++) {
        if (_unassignedItems[i].isSameItem(item)) {
          // Found an existing item, increase its quantity
          int updatedQuantity = _unassignedItems[i].quantity + decrementedAmount;
          _unassignedItems[i].updateQuantity(updatedQuantity);
          foundExistingItem = true;
          break;
        }
      }
      
      // If no existing item was found, create a new one
      if (!foundExistingItem) {
        final unassignedItem = item.copyWithQuantity(decrementedAmount);
        addUnassignedItem(unassignedItem);
      }
    }

    // Update the item's quantity
    item.updateQuantity(newQuantity);
    
    // If quantity is now zero, remove the item from its current location
    if (newQuantity == 0) {
      // Check if it's in shared items
      if (_sharedItems.contains(item)) {
        removeItemFromShared(item);
      } else {
        // Check if it's in someone's assigned items
        for (var person in _people) {
          if (person.assignedItems.contains(item)) {
            unassignItemFromPerson(item, person);
            break;
          }
        }
      }
    }
    
    notifyListeners();
  }

  // Process quantity changes when an item is moved between sections
  void transferItemQuantity(ReceiptItem sourceItem, int quantityToTransfer) {
    if (quantityToTransfer <= 0 || quantityToTransfer > sourceItem.quantity) {
      return;
    }
    
    // Update the source item quantity
    sourceItem.updateQuantity(sourceItem.quantity - quantityToTransfer);
    
    // If source item quantity is 0, remove it
    if (sourceItem.quantity == 0) {
      // Remove from appropriate section
      if (_unassignedItems.contains(sourceItem)) {
        removeUnassignedItem(sourceItem);
      } else if (_sharedItems.contains(sourceItem)) {
        removeSharedItem(sourceItem);
      } else {
        // Check if it's in someone's assigned items
        for (var person in _people) {
          if (person.assignedItems.contains(sourceItem)) {
            unassignItemFromPerson(sourceItem, person);
            break;
          }
        }
      }
    }
  }
  
  // Get matching unassigned item by name and price, or null if not found
  ReceiptItem? findMatchingUnassignedItem(String name, double price) {
    for (var item in _unassignedItems) {
      if (item.name == name && item.price == price) {
        return item;
      }
    }
    return null;
  }

  // Get people who are sharing a specific item
  List<Person> getPeopleForSharedItem(ReceiptItem item) {
    return _people.where((person) => person.sharedItems.contains(item)).toList();
  }
} 