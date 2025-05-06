import 'package:flutter/foundation.dart';
import '../services/receipt_service.dart';
import 'person.dart';
import 'receipt_item.dart';

class SplitManager extends ChangeNotifier {
  // Static instance for global access
  static SplitManager? _instance;
  static SplitManager get instance => _instance ??= SplitManager();
  
  // Use this to explicitly set the instance (useful when you already have a reference)
  static void setInstance(SplitManager manager) {
    _instance = manager;
  }
  
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
  
  // Flag to track if assignments have been modified and need saving
  bool _assignmentsModified = false;
  
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
  List<ReceiptItem> get sharedItems {
    debugPrint('SHARED ITEMS GETTER CALLED. Count: ${_sharedItems.length}');
    if (_sharedItems.isEmpty) {
      debugPrint('WARNING: Shared items list is empty!');
    } else {
      debugPrint('Shared items available:');
      for (final item in _sharedItems) {
        debugPrint('  - ${item.name} (ID: ${item.itemId})');
      }
    }
    return List.unmodifiable(_sharedItems);
  }
  List<ReceiptItem> get unassignedItems => List.unmodifiable(_unassignedItems);
  List<ReceiptItem> get receiptItems => List.unmodifiable(_receiptItems);

  // --- EDIT: Add getters for new state ---
  bool get unassignedItemsWereModified => _unassignedItemsModified;
  double? get originalUnassignedSubtotal => _originalReviewTotal; // For backwards compatibility
  double? get originalReviewTotal => _originalReviewTotal; // New clearer name
  
  // Add getters and setters for properties used in ReceiptWorkflowModal
  bool get initialized => _initialized;
  set initialized(bool value) {
    // Set the flag without marking assignments as modified
    _initialized = value;
    
    // Use the parent notifyListeners directly to bypass our override
    // that would mark assignments as modified
    super.notifyListeners();
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

  // Add these getters near other getters
  bool get assignmentsModified => _assignmentsModified;
  set assignmentsModified(bool value) { _assignmentsModified = value; }

  // Override the notifyListeners method to mark assignments as modified
  @override
  void notifyListeners() {
    // Only mark assignments as modified if the manager is initialized
    // This prevents unnecessary auto-saves during initialization
    if (_initialized) {
      _assignmentsModified = true;
    }
    super.notifyListeners();
  }

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
    // Debug the operations
    debugPrint('SplitManager.addSharedItem called for item: ${item.name} (ID: ${item.itemId})');
    
    bool itemAlreadyExists = false;
    for (final existingItem in _sharedItems) {
      if (existingItem.isSameItem(item)) {
        itemAlreadyExists = true;
        debugPrint('  Item already exists in shared items list');
        break;
      }
    }
    
    if (!itemAlreadyExists) {
      debugPrint('  Adding item to shared items list');
      _sharedItems.add(item);
      
      // Important: Mark assignments as modified to trigger save
      _assignmentsModified = true;
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
    debugPrint('SplitManager.assignItemToPerson: Assigning ${item.name} with quantity ${item.quantity} to ${person.name}');
    
    // Add more debugging for item details
    debugPrint('  Item details: ID=${item.itemId}, Price=${item.price}, Total=${item.total}');
    debugPrint('  Person exists in people list: ${_people.contains(person)}');
    debugPrint('  Person\'s current items count: ${person.assignedItems.length}');
    
    // First, remove any existing instance of this item if it exists
    for (int i = 0; i < person.assignedItems.length; i++) {
      if (person.assignedItems[i].isSameItem(item)) {
        debugPrint('Found existing item - replacing instead of adding to quantity');
        person.removeAssignedItem(person.assignedItems[i]);
        break;
      }
    }
    
    // Now add the item with its exact quantity
    debugPrint('  Adding item directly to person');
    person.addAssignedItem(item);
    
    // Check if the item was successfully added
    debugPrint('  After assignment - Person\'s items count: ${person.assignedItems.length}');
    bool itemFound = false;
    for (var assignedItem in person.assignedItems) {
      if (assignedItem.name == item.name) {
        itemFound = true;
        debugPrint('  Confirmed item was added successfully: ${assignedItem.name}, Price: ${assignedItem.price}');
        break;
      }
    }
    if (!itemFound) {
      debugPrint('  WARNING: Item not found in person\'s assigned items after addition!');
    }
    
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
    
    // Debug logging for calculation
    debugPrint('=== CALCULATING TOTAL AMOUNT ===');
    
    // Sum individual assigned items only (not shared items)
    double assignedTotal = 0;
    for (var person in _people) {
      // IMPORTANT: Only count assigned items here, NOT shared items
      assignedTotal += person.totalAssignedAmount;
      debugPrint('Person ${person.name} assigned items: \$${person.totalAssignedAmount}');
    }
    total += assignedTotal;
    debugPrint('Total for assigned items: \$${assignedTotal}');
    
    // Add shared items (counted only once)
    double sharedTotal = _sharedItems.fold(0, (sum, item) => sum + item.total);
    total += sharedTotal;
    debugPrint('Total for shared items: \$${sharedTotal}');
    
    // Add unassigned items
    double unassignedTotal = _unassignedItems.fold(0, (sum, item) => sum + item.total);
    total += unassignedTotal;
    debugPrint('Total for unassigned items: \$${unassignedTotal}');
    
    // Debug output the final calculation breakdown
    debugPrint('TOTAL CALCULATION: $assignedTotal (assigned) + $sharedTotal (shared) + $unassignedTotal (unassigned) = $total');
    
    // Compare with original total
    if (_originalReviewTotal != null) {
      debugPrint('Current total: \$${total} vs Original total: \$${_originalReviewTotal}');
      if ((total - _originalReviewTotal!).abs() > 0.01) {
        debugPrint('WARNING: Current total ($total) differs from original total (${_originalReviewTotal})');
        debugPrint('Using calculated total instead of forcing original total');
        
        // DISABLED: Don't force the total to match the original - use actual calculated total
        /*
        debugPrint('Forcing total to match original total');
        _subtotal = _originalReviewTotal!;
        return _subtotal;
        */
        
        // Just update the subtotal with our calculated value
        _subtotal = total;
      }
    }
    
    // Ensure we're calculating with the correct subtotal
    _subtotal = total;
    debugPrint('Final total: \$${total}');
    debugPrint('===========================');
    
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
    final sharingPeople = _people.where((person) => person.sharedItems.contains(item)).toList();
    debugPrint('getPeopleForSharedItem: ${item.name} (ID: ${item.itemId}) is shared by ${sharingPeople.length} people: ${sharingPeople.map((p) => p.name).join(", ")}');
    return sharingPeople;
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
    debugPrint('markAsShared called for item: ${item.name}, ID: ${item.itemId}, quantity: ${item.quantity}');
    
    // First, check if an identical item already exists in shared items
    ReceiptItem? existingSharedItem;
    for (int i = 0; i < _sharedItems.length; i++) {
      if (_sharedItems[i].isSameItem(item)) {
        existingSharedItem = _sharedItems[i];
        debugPrint('Found existing shared item with same name/price, will update rather than add new');
        break;
      }
    }
    
    // If we found an existing item, replace it
    if (existingSharedItem != null) {
      final index = _sharedItems.indexOf(existingSharedItem);
      _sharedItems[index] = item;
      debugPrint('Replaced existing shared item with updated version, quantity: ${item.quantity}');
    } else {
      // Add to shared items list if not already there
      _sharedItems.add(item);
      debugPrint('Added new item to shared items list, quantity: ${item.quantity}');
    }
    
    // If people are specified, assign the shared item ONLY to those specific people
    if (people != null && people.isNotEmpty) {
      debugPrint('Assigning item ${item.name} to ${people.length} specific people: ${people.map((p) => p.name).join(", ")}');
      
      // First, remove this item from all people's shared items
      for (final person in _people) {
        for (int i = 0; i < person.sharedItems.length; i++) {
          if (person.sharedItems[i].isSameItem(item)) {
            debugPrint('Removing item ${item.name} from ${person.name}\'s shared items first');
            person.removeSharedItem(person.sharedItems[i]);
            break;
          }
        }
      }
      
      // Then add to specified people only
      for (final person in people) {
        // Check if person already has this exact item
        bool hasItem = false;
        for (final existingItem in person.sharedItems) {
          if (existingItem.isSameItem(item)) {
            hasItem = true;
            break;
          }
        }
        
        if (!hasItem) {
          debugPrint('Adding item ${item.name} to ${person.name}\'s shared items');
          person.addSharedItem(item);
        } else {
          debugPrint('Item ${item.name} already in ${person.name}\'s shared items, updating with new quantity');
          // Since we can't update directly, remove and add back
          for (int i = 0; i < person.sharedItems.length; i++) {
            if (person.sharedItems[i].isSameItem(item)) {
              person.removeSharedItem(person.sharedItems[i]);
              break;
            }
          }
          person.addSharedItem(item);
        }
      }
    } else {
      // Default behavior: assign to all people if no specific people are provided
      debugPrint('No specific people provided, assigning item ${item.name} to ALL ${_people.length} people');
      for (final person in _people) {
        // Check if person already has this exact item
        bool hasItem = false;
        for (final existingItem in person.sharedItems) {
          if (existingItem.isSameItem(item)) {
            hasItem = true;
            break;
          }
        }
        
        if (!hasItem) {
          person.addSharedItem(item);
        } else {
          // Since we can't update directly, remove and add back
          for (int i = 0; i < person.sharedItems.length; i++) {
            if (person.sharedItems[i].isSameItem(item)) {
              person.removeSharedItem(person.sharedItems[i]);
              break;
            }
          }
          person.addSharedItem(item);
        }
      }
    }
    
    // Explicitly mark assignments as modified to ensure they're saved
    _assignmentsModified = true;
    notifyListeners();
  }
  
  void markAsUnassigned(ReceiptItem item) {
    debugPrint('markAsUnassigned called for item: ${item.name}, ID: ${item.itemId}, quantity: ${item.quantity}');
    
    // Check if an identical item already exists in unassigned items
    ReceiptItem? existingUnassignedItem;
    for (int i = 0; i < _unassignedItems.length; i++) {
      if (_unassignedItems[i].isSameItem(item)) {
        existingUnassignedItem = _unassignedItems[i];
        debugPrint('Found existing unassigned item with same name/price, will update rather than add new');
        break;
      }
    }
    
    // If we found an existing item, replace it
    if (existingUnassignedItem != null) {
      final index = _unassignedItems.indexOf(existingUnassignedItem);
      _unassignedItems[index] = item;
      debugPrint('Replaced existing unassigned item with updated version, quantity: ${item.quantity}');
    } else {
      // Add as new item
      _unassignedItems.add(item);
      debugPrint('Added new item to unassigned items list, quantity: ${item.quantity}');
    }
    
    notifyListeners();
  }
  
  // Add a method to add receipt items with improved duplicate handling
  void addReceiptItem(ReceiptItem item) {
    debugPrint('Adding receipt item to SplitManager: ${item.name}, ID: ${item.itemId}, Price: ${item.price}, Quantity: ${item.quantity}');
    
    // Check if the item is already in the list by ID
    int existingIndex = -1;
    for (int i = 0; i < _receiptItems.length; i++) {
      if (_receiptItems[i].itemId == item.itemId) {
        existingIndex = i;
        break;
      }
    }
    
    // Also check by name if ID check didn't find anything
    if (existingIndex == -1) {
      for (int i = 0; i < _receiptItems.length; i++) {
        if (_receiptItems[i].name.toLowerCase() == item.name.toLowerCase()) {
          existingIndex = i;
          break;
        }
      }
    }
    
    if (existingIndex != -1) {
      // Replace existing item
      _receiptItems[existingIndex] = item;
      // Also update original quantity
      _originalQuantities[item.itemId] = item.quantity;
      debugPrint('Replaced existing receipt item at index $existingIndex: ${item.name}, ID: ${item.itemId}');
    } else {
      // Add new item
      _receiptItems.add(item);
      // Track original quantity
      _originalQuantities[item.itemId] = item.quantity;
      debugPrint('Added new receipt item: ${item.name}, ID: ${item.itemId}, Price: ${item.price}');
    }
    notifyListeners();
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

  // Add a method to extract assignment data for the database
  Map<String, dynamic> getAssignmentData() {
    // Convert the current state to the format expected by the database
    debugPrint('SplitManager.getAssignmentData called');
    final Map<String, dynamic> assignments = {};
    
    // Process people and their assigned items
    final Map<String, List<Map<String, dynamic>>> peopleAssignments = {};
    
    debugPrint('Processing ${_people.length} people for assignments data:');
    for (final person in _people) {
      final List<Map<String, dynamic>> personItems = [];
      
      for (final item in person.assignedItems) {
        // Find the position (1-based) for this item in receipt items
        int position = 0;
        for (int i = 0; i < _receiptItems.length; i++) {
          if (_receiptItems[i].name == item.name) {
            position = i + 1; // 1-based index
            break;
          }
        }
        
        // If position wasn't found, use a fallback ID (better than nothing)
        if (position == 0) {
          // Try to extract ID from the itemId if it's in the format Item_X_Name
          final idParts = item.itemId.split('_');
          if (idParts.length > 1) {
            try {
              position = int.parse(idParts[1]) + 1; // Add 1 for 1-based index
            } catch (e) {
              // If parsing fails, just use a placeholder position
              position = personItems.length + 1;
            }
          } else {
            // Fallback to item count + 1
            position = personItems.length + 1;
          }
          debugPrint('  Warning: Using fallback position $position for ${item.name} (missing in receiptItems)');
        }
        
        personItems.add({
          'name': item.name,
          'id': position,
          'quantity': item.quantity,
          'price': item.price,
        });
      }
      
      if (personItems.isNotEmpty) {
        debugPrint('  Person ${person.name}: ${personItems.length} assigned items');
        peopleAssignments[person.name] = personItems;
      } else {
        debugPrint('  Person ${person.name}: No assigned items');
      }
    }
    
    // Process shared items
    final List<Map<String, dynamic>> sharedItems = [];
    debugPrint('Processing ${_sharedItems.length} shared items:');
    for (final item in _sharedItems) {
      // Find the position (1-based) for this item in receipt items
      int position = 0;
      for (int i = 0; i < _receiptItems.length; i++) {
        if (_receiptItems[i].name == item.name) {
          position = i + 1; // 1-based index
          break;
        }
      }
      
      // Fallback position if not found
      if (position == 0) {
        // Try to extract ID from the itemId if it's in the format Item_X_Name
        final idParts = item.itemId.split('_');
        if (idParts.length > 1) {
          try {
            position = int.parse(idParts[1]) + 1; // Add 1 for 1-based index
          } catch (e) {
            // If parsing fails, just use a placeholder position
            position = sharedItems.length + 1;
          }
        } else {
          // Fallback to item count + 1
          position = sharedItems.length + 1;
        }
        debugPrint('  Warning: Using fallback position $position for ${item.name} (missing in receiptItems)');
      }
      
      // Get the list of people sharing this item
      final List<String> sharingPeople = [];
      for (final person in _people) {
        if (person.sharedItems.any((sharedItem) => sharedItem.name == item.name)) {
          sharingPeople.add(person.name);
        }
      }
      
      debugPrint('  Shared item: ${item.name}, ID: $position, Shared by: ${sharingPeople.join(", ")}');
      sharedItems.add({
        'name': item.name,
        'id': position,
        'quantity': item.quantity,
        'price': item.price,
        'people': sharingPeople,
      });
    }
    
    // Process unassigned items
    final List<Map<String, dynamic>> unassignedItems = [];
    debugPrint('Processing ${_unassignedItems.length} unassigned items:');
    for (final item in _unassignedItems) {
      // Find the position (1-based) for this item in receipt items
      int position = 0;
      for (int i = 0; i < _receiptItems.length; i++) {
        if (_receiptItems[i].name == item.name) {
          position = i + 1; // 1-based index
          break;
        }
      }
      
      // Fallback position if not found
      if (position == 0) {
        // Try to extract ID from the itemId if it's in the format Item_X_Name
        final idParts = item.itemId.split('_');
        if (idParts.length > 1) {
          try {
            position = int.parse(idParts[1]) + 1; // Add 1 for 1-based index
          } catch (e) {
            // If parsing fails, just use a placeholder position
            position = unassignedItems.length + 1; 
          }
        } else {
          // Fallback to item count + 1
          position = unassignedItems.length + 1;
        }
        debugPrint('  Warning: Using fallback position $position for ${item.name} (missing in receiptItems)');
      }
      
      debugPrint('  Unassigned item: ${item.name}, ID: $position, Price: \$${item.price}');
      unassignedItems.add({
        'name': item.name,
        'id': position,
        'quantity': item.quantity,
        'price': item.price,
      });
    }
    
    // Create the final data structure
    assignments['assignments'] = peopleAssignments;
    assignments['shared_items'] = sharedItems;
    assignments['unassigned_items'] = unassignedItems;
    
    debugPrint('Final assignments data structure:');
    debugPrint('  assignments count: ${peopleAssignments.length} people');
    debugPrint('  shared_items count: ${sharedItems.length} items');
    debugPrint('  unassigned_items count: ${unassignedItems.length} items');
    
    return assignments;
  }

  // Add a new method to safely save state using the current SplitManager instance
  // This allows saving without needing Provider context
  Future<void> saveAssignmentsToService(ReceiptService receiptService, String receiptId) async {
    if (!_initialized || !_assignmentsModified) {
      debugPrint('No changes to save or not initialized yet');
      return;
    }
    
    try {
      debugPrint('SplitManager.saveAssignmentsToService: Preparing to save to receipt $receiptId');
      
      // Get the assignment data directly from this instance
      final assignmentData = getAssignmentData();
      
      // Reset the flag right away
      _assignmentsModified = false;
      
      // Save to the receipt service
      debugPrint('Calling receiptService.saveAssignPeopleToItemsResults with receipt ID: $receiptId');
      await receiptService.saveAssignPeopleToItemsResults(
        receiptId,
        assignmentData
      );
      
      debugPrint('Successfully saved assignments directly from SplitManager');
    } catch (e) {
      debugPrint('Error saving assignments directly from SplitManager: $e');
      // Re-mark as modified since save failed
      _assignmentsModified = true;
      rethrow;
    }
  }
} 