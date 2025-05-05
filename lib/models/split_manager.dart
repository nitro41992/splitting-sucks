import 'package:flutter/foundation.dart';
import 'person.dart';
import 'receipt_item.dart';

class SplitManager extends ChangeNotifier {
  List<Person> _people;
  List<ReceiptItem> _sharedItems;
  List<ReceiptItem> _unassignedItems;
  Map<String, int> _originalQuantities;  // Track original quantities from review
  int? initialSplitViewTabIndex; // Index for initial tab in SplitView

  // --- EDIT: Add state for tracking edits and original subtotal ---
  bool _unassignedItemsModified = false;
  double? _originalReviewTotal; // Store the total from review tab
  
  // Add a flag to track if the state has been preserved across hot reloads
  bool _statePreserved = false;
  // --- END EDIT ---

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

  // --- EDIT: Add getters for new state ---
  bool get unassignedItemsWereModified => _unassignedItemsModified;
  double? get originalUnassignedSubtotal => _originalReviewTotal; // For backwards compatibility
  double? get originalReviewTotal => _originalReviewTotal; // New clearer name
  // --- END EDIT ---

  void reset() {
    _people = [];
    _sharedItems = [];
    _unassignedItems = [];
    _originalQuantities = {};
    // --- EDIT: Reset modification state ---
    _unassignedItemsModified = false;
    _originalReviewTotal = null;
    // --- END EDIT ---
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
    print('DEBUG: SplitManager.updatePersonName called for "${person.name}" to "$newName"');
    // Check if person is in our list
    final personIndex = _people.indexOf(person);
    if (personIndex == -1) {
      print('DEBUG: ERROR - Person not found in _people list!');
      // Person not found in our list, let's print more details
      print('DEBUG: Person list contents:');
      for (int i = 0; i < _people.length; i++) {
        print('DEBUG:   Person[$i]: ${_people[i].name} (hash: ${_people[i].hashCode})');
      }
      print('DEBUG: Person to update: ${person.name} (hash: ${person.hashCode})');
      
      // Try to find by name as a fallback
      final matchByName = _people.firstWhere(
        (p) => p.name == person.name,
        orElse: () => person
      );
      if (matchByName != person) {
        print('DEBUG: Found person by name match instead, updating that one');
        matchByName.updateName(newName);
      } else {
        print('DEBUG: Could not find person by name either, using provided reference');
        person.updateName(newName);
      }
    } else {
      print('DEBUG: Person found at index $personIndex, updating name');
      person.updateName(newName);
    }
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

  // Alias for unassignedItemsTotal to fix compatibility issues
  double get subtotal {
    return unassignedItemsTotal;
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

  // --- EDIT: Add method to store the original subtotal ---
  void setOriginalUnassignedSubtotal(double subtotal) {
    _originalReviewTotal = subtotal;
    // Don't notify listeners here, as it's usually set during initialization
  }

  // New method with clearer name
  void setOriginalReviewTotal(double subtotal) {
    _originalReviewTotal = subtotal;
    _statePreserved = true; // Mark as preserved when we set the total
    notifyListeners();
  }
  // --- END EDIT ---

  // --- EDIT: Add update method for unassigned items ---
  void updateUnassignedItem(ReceiptItem itemToUpdate, int newQuantity, double newPrice) {
    final index = _unassignedItems.indexWhere((item) => item.itemId == itemToUpdate.itemId);
    if (index != -1) {
      // Update the item in the list using the new copyWith method
      _unassignedItems[index] = itemToUpdate.copyWith(quantity: newQuantity, price: newPrice);
      _unassignedItemsModified = true; // Mark as modified
      notifyListeners();
    }
  }
  // --- END EDIT ---

  // Set the receipt items from the review screen
  void setReceiptItems(List<ReceiptItem> items) {
    // Clear existing original quantities first to avoid stale data
    _originalQuantities = {};
    
    // Track original quantity for each item
    for (var item in items) {
      setOriginalQuantity(item, item.quantity);
    }
    
    // Add all items as unassigned initially
    // But first clear existing unassigned items to prevent duplication
    _unassignedItems = [];
    
    for (var item in items) {
      if (!_unassignedItems.any((i) => i.isSameItem(item))) {
        _unassignedItems.add(item);
      }
    }
    
    notifyListeners();
  }

  // Check if state has been preserved
  bool get isStatePreserved => _statePreserved;
  
  // Helper method for hot reload state preservation
  void preserveState(SplitManager other) {
    // Only copy state if the other manager has preserved state
    if (!other.isStatePreserved) return;
    
    _people = [...other.people];
    _sharedItems = [...other.sharedItems];
    _unassignedItems = [...other.unassignedItems];
    _originalQuantities = Map.from(other._originalQuantities);
    _originalReviewTotal = other._originalReviewTotal;
    _unassignedItemsModified = other._unassignedItemsModified;
    initialSplitViewTabIndex = other.initialSplitViewTabIndex;
    _statePreserved = true;
    
    // Notify listeners about the copied state
    notifyListeners();
  }

  // Check if all items are assigned to people
  bool areAllItemsAssigned() {
    // Return false if there are unassigned items
    if (_unassignedItems.isNotEmpty) {
      return false;
    }
    
    // We consider it fully assigned if all items are either:
    // 1. Assigned to specific people, or
    // 2. Added to shared items and assigned to at least one person
    
    // Check that all shared items are assigned to at least one person
    for (var item in _sharedItems) {
      bool itemAssigned = false;
      for (var person in _people) {
        if (person.sharedItems.contains(item)) {
          itemAssigned = true;
          break;
        }
      }
      if (!itemAssigned) {
        return false; // Found a shared item not assigned to anyone
      }
    }
    
    return true;
  }
  
  // Get all items in the split manager (assigned, shared, unassigned)
  List<ReceiptItem> getAllItems() {
    final allItems = <ReceiptItem>[];
    
    // Add assigned items
    for (var person in _people) {
      allItems.addAll(person.assignedItems);
    }
    
    // Add shared items
    allItems.addAll(_sharedItems);
    
    // Add unassigned items
    allItems.addAll(_unassignedItems);
    
    return allItems;
  }
  
  // Load the split manager state from a Firestore map
  void loadFromMap(Map<String, dynamic> map) {
    // Reset current state
    reset();
    
    // Load people and their assigned items
    final peopleData = map['people'] as List<dynamic>? ?? [];
    for (var personData in peopleData) {
      final name = personData['name'] as String;
      final person = Person(name: name);
      
      // Add assigned items
      final assignedItemsData = personData['assignedItems'] as List<dynamic>? ?? [];
      for (var itemData in assignedItemsData) {
        final item = _itemFromMap(itemData as Map<String, dynamic>);
        person.addAssignedItem(item);
      }
      
      _people.add(person);
    }
    
    // Load shared items and their assignments
    final sharedItemsData = map['sharedItems'] as List<dynamic>? ?? [];
    for (var itemData in sharedItemsData) {
      final item = _itemFromMap(itemData as Map<String, dynamic>);
      _sharedItems.add(item);
      
      // Assign shared item to people
      final sharedBy = itemData['shared_by'] as List<dynamic>? ?? [];
      for (var personName in sharedBy) {
        final person = _people.firstWhere(
          (p) => p.name == personName,
          orElse: () => Person(name: personName.toString()),
        );
        
        // If person wasn't found, add them
        if (!_people.contains(person)) {
          _people.add(person);
        }
        
        person.addSharedItem(item);
      }
    }
    
    // Load unassigned items
    final unassignedItemsData = map['unassignedItems'] as List<dynamic>? ?? [];
    for (var itemData in unassignedItemsData) {
      final item = _itemFromMap(itemData as Map<String, dynamic>);
      _unassignedItems.add(item);
      setOriginalQuantity(item, item.quantity); // Set original quantity
    }
    
    notifyListeners();
  }
  
  // Helper method to convert a Map to a ReceiptItem
  ReceiptItem _itemFromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      name: map['item'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      itemId: 'item_${map['id']}_${map['item']}',
    );
  }
  
  // Initialize the split manager from assignment results
  void initializeFromAssignments(
    List<ReceiptItem> items,
    Map<String, List<String>> assignmentResult,
    double subtotal,
  ) {
    reset();
    
    // Set original review total
    _originalReviewTotal = subtotal;
    
    // First, create a map of all items by name for quick lookup
    final itemMap = <String, ReceiptItem>{};
    for (var item in items) {
      itemMap[item.name] = item;
      setOriginalQuantity(item, item.quantity);
    }
    
    // Create people and assign items based on the assignment result
    for (var entry in assignmentResult.entries) {
      final personName = entry.key;
      final assignedItemNames = entry.value;
      
      // Create the person
      final person = Person(name: personName);
      
      // Assign items to this person
      for (var itemName in assignedItemNames) {
        if (itemMap.containsKey(itemName)) {
          final item = itemMap[itemName]!;
          person.addAssignedItem(item);
        }
      }
      
      // Add the person to the split manager
      _people.add(person);
    }
    
    // Items not assigned to any person go to unassigned items
    final assignedItems = <String>{};
    for (var items in assignmentResult.values) {
      assignedItems.addAll(items);
    }
    
    for (var item in items) {
      if (!assignedItems.contains(item.name)) {
        _unassignedItems.add(item);
      }
    }
    
    notifyListeners();
  }

  // Update all unassigned items with a new list and subtotal
  // Used primarily during auto-save to ensure consistent state
  void updateUnassignedItems(List<ReceiptItem> items, double subtotalValue) {
    // Clear existing unassigned items
    _unassignedItems.clear();
    
    // Add each item to the unassigned items list
    for (final item in items) {
      _unassignedItems.add(item);
      
      // Track original quantity
      if (!_originalQuantities.containsKey(item.name)) {
        _originalQuantities[item.name] = item.quantity;
      }
    }
    
    // Store the original review total
    _originalReviewTotal = subtotalValue;
    
    notifyListeners();
  }

  // Retrieve the current split manager state as a map
  // Used for saving to Firestore
  Map<String, dynamic> getSplitManagerState() {
    // Convert people data
    final peopleData = _people.map((person) {
      return {
        'id': person.name,
        'name': person.name,
        'assignedItems': person.assignedItems.map((item) => {
          'id': int.tryParse(item.itemId.split('_')[1]) ?? 0,
          'item': item.name,
          'quantity': item.quantity,
          'price': item.price,
        }).toList(),
      };
    }).toList();

    // Convert shared items
    final sharedItemsData = _sharedItems.map((item) {
      // Find which people have this shared item
      final sharedBy = _people
          .where((person) => person.sharedItems.contains(item))
          .map((person) => person.name)
          .toList();

      return {
        'id': int.tryParse(item.itemId.split('_')[1]) ?? 0,
        'item': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'shared_by': sharedBy,
      };
    }).toList();

    // Convert unassigned items
    final unassignedItemsData = _unassignedItems.map((item) => {
      'id': int.tryParse(item.itemId.split('_')[1]) ?? 0,
      'item': item.name,
      'quantity': item.quantity,
      'price': item.price,
    }).toList();

    // Create the state object
    return {
      'people': peopleData,
      'sharedItems': sharedItemsData,
      'unassignedItems': unassignedItemsData,
      'tipAmount': 0.0, // This should be updated with actual tip data when available
      'taxAmount': 0.0, // This should be updated with actual tax data when available
      'subtotal': _unassignedItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity)),
      'total': totalAmount,
    };
  }
} 