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

  // Flag to track whether manager has been initialized from saved state
  bool _initialized = false;
  
  // Calculation properties
  double _subtotal = 0.0;
  double _tax = 0.0;
  double _tip = 0.0;
  double _tipPercentage = 15.0;
  String? _restaurantName;
  
  // List of all receipt items
  final List<ReceiptItem> _receiptItems = [];
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
  List<ReceiptItem> get receiptItems => List.unmodifiable(_receiptItems);

  // --- EDIT: Add getters for new state ---
  bool get unassignedItemsWereModified => _unassignedItemsModified;
  double? get originalUnassignedSubtotal => _originalReviewTotal; // For backwards compatibility
  double? get originalReviewTotal => _originalReviewTotal; // New clearer name
  
  // Add getters and setters for properties used in ReceiptWorkflowModal
  bool get initialized => _initialized;
  set initialized(bool value) {
    _initialized = value;
    notifyListeners();
  }
  
  set originalReviewTotal(double? value) {
    _originalReviewTotal = value;
    notifyListeners();
  }
  
  double get subtotal => _subtotal;
  set subtotal(double value) {
    _subtotal = value;
    notifyListeners();
  }
  
  double get tax => _tax;
  set tax(double value) {
    _tax = value;
    notifyListeners();
  }
  
  double get tip => _tip;
  set tip(double value) {
    _tip = value;
    notifyListeners();
  }
  
  double get tipPercentage => _tipPercentage;
  set tipPercentage(double value) {
    _tipPercentage = value;
    notifyListeners();
  }
  
  String? get restaurantName => _restaurantName;
  set restaurantName(String? value) {
    _restaurantName = value;
    notifyListeners();
  }
  // --- END EDIT ---

  void reset() {
    initialized = false;
    _people = [];
    _receiptItems.clear();
    _originalQuantities = {};
    _sharedItems = [];
    _unassignedItems = [];
    restaurantName = null;
    subtotal = 0.0;
    tax = 0.0;
    tip = 0.0;
    tipPercentage = 15.0;
    originalReviewTotal = 0.0;
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
    
    // Ensure we're calculating with the correct subtotal
    _subtotal = total;
    
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

  // New methods for receipt items management
  void markAsShared(ReceiptItem item, {List<Person>? people}) {
    if (!_sharedItems.contains(item)) {
      _sharedItems.add(item);
      
      // If people are specified, assign the shared item to those specific people
      if (people != null && people.isNotEmpty) {
        for (final person in people) {
          if (!person.sharedItems.contains(item)) {
            person.addSharedItem(item);
          }
        }
      } else {
        // Default behavior: assign to all people if no specific people are provided
        for (final person in _people) {
          if (!person.sharedItems.contains(item)) {
            person.addSharedItem(item);
          }
        }
      }
      
      notifyListeners();
    }
  }
  
  void markAsUnassigned(ReceiptItem item) {
    if (!_unassignedItems.contains(item)) {
      _unassignedItems.add(item);
      notifyListeners();
    }
  }
  
  // Add a method to add receipt items with improved duplicate handling
  void addReceiptItem(ReceiptItem item) {
    // Check if the item is already in the list by ID
    bool exists = _receiptItems.any((existingItem) => existingItem.itemId == item.itemId);
    
    if (!exists) {
      // Add new item
      _receiptItems.add(item);
      // Track original quantity
      _originalQuantities[item.itemId] = item.quantity;
      debugPrint('Added receipt item: ${item.name}, ID: ${item.itemId}, Price: ${item.price}');
      notifyListeners();
    } else {
      debugPrint('Item already exists with ID: ${item.itemId}');
    }
  }
  
  // Debug method to log all items in the split manager
  void logItems() {
    debugPrint('=== SPLIT MANAGER ITEMS ===');
    debugPrint('Total items: ${_receiptItems.length}');
    
    for (int i = 0; i < _receiptItems.length; i++) {
      final item = _receiptItems[i];
      debugPrint('Item $i: ${item.name}, ID: ${item.itemId}, Price: ${item.price}, Quantity: ${item.quantity}');
    }
    
    debugPrint('People count: ${_people.length}');
    for (final person in _people) {
      debugPrint('  Person: ${person.name}');
      for (final item in person.assignedItems) {
        debugPrint('    - ${item.name}, ID: ${item.itemId}, Price: ${item.price}');
      }
    }
    
    debugPrint('Shared items count: ${_sharedItems.length}');
    for (final item in _sharedItems) {
      debugPrint('  - ${item.name}, ID: ${item.itemId}, Price: ${item.price}');
    }
    
    debugPrint('===========================');
  }
} 