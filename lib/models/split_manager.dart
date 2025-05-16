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

  // Add properties for tip and tax percentages
  double? _tipPercentage;
  double? _taxPercentage;

  SplitManager({
    List<Person>? people,
    List<ReceiptItem>? sharedItems,
    List<ReceiptItem>? unassignedItems,
    double? tipPercentage,
    double? taxPercentage,
    double? originalReviewTotal, // Add new parameter here
  })  : _people = people ?? [],
        _sharedItems = sharedItems ?? [],
        _unassignedItems = unassignedItems ?? [],
        _originalQuantities = {},
        _tipPercentage = tipPercentage,
        _taxPercentage = taxPercentage,
        _originalReviewTotal = originalReviewTotal; // Initialize here

  List<Person> get people => List.unmodifiable(_people);
  List<ReceiptItem> get sharedItems => List.unmodifiable(_sharedItems);
  List<ReceiptItem> get unassignedItems => List.unmodifiable(_unassignedItems);

  // --- EDIT: Add getters for new state ---
  bool get unassignedItemsWereModified => _unassignedItemsModified;
  double? get originalUnassignedSubtotal => _originalReviewTotal; // For backwards compatibility
  double? get originalReviewTotal => _originalReviewTotal; // New clearer name
  // --- END EDIT ---

  // Add getters and setters for tip and tax
  double? get tipPercentage => _tipPercentage;
  set tipPercentage(double? value) {
    _tipPercentage = value;
    notifyListeners();
  }

  double? get taxPercentage => _taxPercentage;
  set taxPercentage(double? value) {
    _taxPercentage = value;
    notifyListeners();
  }

  void reset() {
    _people = [];
    _sharedItems = [];
    _unassignedItems = [];
    _originalQuantities = {};
    // --- EDIT: Reset modification state ---
    _unassignedItemsModified = false;
    // _originalReviewTotal = null; // No longer reset to null if passed in constructor, unless intended
    // --- END EDIT ---
    // Reset tip and tax to default values
    _tipPercentage = null;
    _taxPercentage = null;
    notifyListeners();
  }

  void addPerson(String name) {
    _people.add(Person(name: name));
    notifyListeners();
  }

  void removePerson(Person person) {
    // Only allow removal if the person has no items
    if (person.assignedItems.isEmpty && person.sharedItems.isEmpty) {
      _people.remove(person);
      notifyListeners();
    }
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
      if (person.assignedItems[i].itemId == item.itemId) {
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
    
    // Sum individual assigned items for each person (but NOT their shared items)
    for (var person in _people) {
      total += person.totalAssignedAmount;
    }
    
    // Add shared items (counted once, not per person)
    total += _sharedItems.fold(0, (sum, item) => sum + item.total);
    
    // Add unassigned items
    total += _unassignedItems.fold(0, (sum, item) => sum + item.total);
    
    // Debug logging to trace calculation
    debugPrint('[SplitManager] totalAmount calculation:');
    debugPrint('  - Assigned items sum: ${_people.fold(0.0, (sum, p) => sum + p.totalAssignedAmount)}');
    debugPrint('  - Shared items sum: ${_sharedItems.fold(0.0, (sum, item) => sum + item.total)}');
    debugPrint('  - Unassigned items sum: ${_unassignedItems.fold(0.0, (sum, item) => sum + item.total)}');
    debugPrint('  - Total: $total');
    
    return total;
  }

  double get sharedItemsTotal {
    return _sharedItems.fold(0, (sum, item) => sum + item.total);
  }

  double get unassignedItemsTotal {
    return _unassignedItems.fold(0, (sum, item) => sum + item.total);
  }

  // New method to add a single person to an existing shared item
  void addPersonToSharedItem(ReceiptItem item, Person person, {bool notify = true}) {
    // Ensure the item is in the main shared list first (should usually be true)
    // Check if the item already exists in _sharedItems by itemId
    bool itemExists = _sharedItems.any((si) => si.itemId == item.itemId);
    if (!itemExists) {
      _sharedItems.add(item);
    }
    
    // Add item to the specific person's shared list if they don't already have it
    // Check by itemId to avoid duplicate references
    if (!person.sharedItems.any((si) => si.itemId == item.itemId)) {
      person.addSharedItem(item); // This should call notifyListeners in Person
    }
    
    // debugPrint('[SplitManager] addPersonToSharedItem: ${person.name} now sharing ${item.name}.');
    // Log the people sharing this item using itemId comparison
    // debugPrint('[SplitManager] Shared item: ${item.name}, shared by: '
      // + _people.where((p) => p.sharedItems.any((si) => si.itemId == item.itemId)).map((p) => p.name).join(', '));
    // debugPrint('[SplitManager] SharedItems: ' + _sharedItems.map((i) => i.name).join(', '));
    // debugPrint('[SplitManager] Subtotal after add: $totalAmount');
    
    // Only notify listeners if requested (allows batching multiple operations)
    if (notify) {
      notifyListeners(); // Notify SplitManager listeners
    }
  }

  // New method to remove a single person from a shared item
  void removePersonFromSharedItem(ReceiptItem item, Person person, {bool notify = true}) {
    // Find the matching shared item in the person's list by itemId
    ReceiptItem? sharedItemInPerson;
    try {
      sharedItemInPerson = person.sharedItems.firstWhere(
        (si) => si.itemId == item.itemId
      );
      
      // Remove item from the specific person's shared list if found
      person.removeSharedItem(sharedItemInPerson); // This should call notifyListeners in Person
    } catch (e) {
      // debugPrint('[SplitManager] Warning: Could not find shared item ${item.name} (${item.itemId}) in ${person.name}\'s shared items');
    }
    
    // debugPrint('[SplitManager] removePersonFromSharedItem: ${person.name} no longer sharing ${item.name}.');
    // debugPrint('[SplitManager] Shared item: ${item.name}, shared by: '
      // + _people.where((p) => p.sharedItems.any((si) => si.itemId == item.itemId)).map((p) => p.name).join(', '));
    // debugPrint('[SplitManager] SharedItems: ' + _sharedItems.map((i) => i.name).join(', '));
    // debugPrint('[SplitManager] Subtotal after remove: [38;5;1m$totalAmount[0m');
    
    // Only notify listeners if requested
    if (notify) {
      notifyListeners(); // Notify SplitManager listeners
    }
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
    
    // Notify listeners if state was not preserved
    if (!_statePreserved) {
      notifyListeners();
      _statePreserved = true; // Mark as preserved for future hot reloads
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
        removeSharedItem(item);
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
    
    // debugPrint('[SplitManager] updateItemQuantity: ${item.name} set to $newQuantity. Subtotal: $totalAmount');
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

  // Get people who have a specific shared item
  List<Person> getPeopleForSharedItem(ReceiptItem item) {
    return _people.where((person) {
      return person.sharedItems.any((sharedItem) => 
        // Try by itemId first (most reliable)
        (sharedItem.itemId != null && item.itemId != null && sharedItem.itemId == item.itemId) ||
        // Fall back to name and price match
        (sharedItem.name == item.name && sharedItem.price == item.price)
      );
    }).toList();
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

  // --- EDIT: Add getter for current people names ---
  List<String> get currentPeopleNames => _people.map((p) => p.name).toList();
  // --- END EDIT ---

  // --- EDIT: Add method to generate assign_people_to_items map ---
  Map<String, dynamic> generateAssignmentMap() {
    // Convert current state back to the format expected by assign_people_to_items
    final List<Map<String, dynamic>> assignments = _people.map((person) {
      return {
        'person_name': person.name,
        'items': person.assignedItems.map((item) {
          return {
            'itemId': item.itemId,
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
          };
        }).toList(),
      };
    }).toList();

    final List<Map<String, dynamic>> sharedItemsMap = _sharedItems.map((item) {
       // Find people sharing this specific item instance
      final List<String> peopleNames = _people
          .where((p) => p.sharedItems.any((si) => si.itemId == item.itemId))
          .map((p) => p.name)
          .toList();
      return {
        'itemId': item.itemId,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'people': peopleNames, // List of names sharing this item
      };
    }).toList();

    final List<Map<String, dynamic>> unassignedItemsMap = _unassignedItems.map((item) {
      return {
        'itemId': item.itemId,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
      };
    }).toList();

    return {
      'assignments': assignments,
      'shared_items': sharedItemsMap,
      'unassigned_items': unassignedItemsMap,
    };
  }
  // --- END EDIT ---

  // --- TIP, TAX, and FINAL TOTAL GETTERS ---
  double get tipAmount {
    return totalAmount * (_tipPercentage ?? 0.0);
  }

  double get taxAmount {
    return totalAmount * (_taxPercentage ?? 0.0);
  }

  double get finalTotal {
    return totalAmount + tipAmount + taxAmount;
  }
  // --- END TIP, TAX, and FINAL TOTAL GETTERS ---

  // Calculate the per-person total including their share of shared items
  double getPersonTotal(Person person) {
    // Start with their assigned items
    double total = person.totalAssignedAmount;
    // debugPrint('[SplitManager] ${person.name}\'s assigned items total: ${total}');
    
    // Add their fair share of each shared item
    for (var sharedItem in person.sharedItems) {
      // Count how many people are sharing this item (using itemId for exact matching)
      int sharerCount = _people
          .where((p) => p.sharedItems.any((si) => si.itemId == sharedItem.itemId))
          .length;
      
      if (sharerCount > 0) {
        // Calculate and add this person's fraction of the shared item
        // Use double division and round to 2 decimal places to prevent floating point errors
        final double individualShare = (sharedItem.total / sharerCount);
        final double roundedShare = double.parse(individualShare.toStringAsFixed(2));
        
        // debugPrint('[SplitManager] ${person.name}\'s share of ${sharedItem.name}: ${roundedShare.toStringAsFixed(2)} (${sharedItem.total} ÷ $sharerCount people)');
        total += roundedShare;
      }
    }
    
    // debugPrint('[SplitManager] ${person.name}\'s total: ${total} = ${person.totalAssignedAmount} (assigned) + ${total - person.totalAssignedAmount} (shared)');
    return total;
  }
} 