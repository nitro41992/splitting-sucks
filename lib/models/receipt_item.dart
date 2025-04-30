import 'package:flutter/foundation.dart';

class ReceiptItem extends ChangeNotifier {
  String _name;
  double _price;
  int _quantity;
  int _originalQuantity; // Added field to store the original quantity
  final String _itemId; // Unique identifier for the item
  static int _nextId = 0;

  // Private constructor used by factory and clone
  ReceiptItem._internal({
    required String name,
    required double price,
    required int quantity,
    required int originalQuantity,
    required String itemId,
  })  : _name = name,
        _price = price,
        _quantity = quantity,
        _originalQuantity = originalQuantity,
        _itemId = itemId;

  // Factory constructor for creating new items
  factory ReceiptItem({
    required String name,
    required double price,
    required int quantity,
    String? itemId, // Optional itemId for specific cases like mocks
  }) {
    return ReceiptItem._internal(
      name: name,
      price: price,
      quantity: quantity,
      originalQuantity: quantity, // Initialize original quantity
      itemId: itemId ?? 'item_${_nextId++}_$name',
    );
  }

  // Clone constructor
  ReceiptItem.clone(ReceiptItem other) : this._internal(
    name: other._name,
    price: other._price,
    quantity: other._quantity,
    originalQuantity: other._originalQuantity,
    itemId: other._itemId, // Keep the same ID for the clone
  );

  String get name => _name;
  double get price => _price;
  int get quantity => _quantity;
  String get itemId => _itemId;
  int get originalQuantity => _originalQuantity; // Getter for original quantity

  // Returns true if this item is originally the same as the other item
  // Items are considered the same if they have the same name and price
  bool isSameItem(ReceiptItem other) {
    return _name == other._name && _price == other._price;
  }

  // Create a copy of this item with a new quantity
  ReceiptItem copyWithQuantity(int newQuantity) {
    return ReceiptItem(
      name: _name,
      price: _price,
      quantity: newQuantity,
      itemId: _itemId, // Keep the same ID to track that it's the same item
    );
  }

  void updateName(String newName) {
    if (_name != newName) {
      _name = newName;
      notifyListeners();
    }
  }

  void updatePrice(double newPrice) {
    if (_price != newPrice) {
      _price = newPrice;
      notifyListeners();
    }
  }

  void updateQuantity(int newQuantity) {
    if (_quantity != newQuantity) {
      _quantity = newQuantity;
      notifyListeners();
    }
  }

  double get total => _price * _quantity;

  // Add a method to reset quantity to original
  void resetQuantity() {
    _quantity = _originalQuantity;
  }

  // Consider overriding == and hashCode if items need to be compared or used in Sets/Maps
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptItem &&
          runtimeType == other.runtimeType &&
          // Use itemId for robust equality check
          _itemId == other._itemId;
          // name == other.name &&
          // price == other.price && // Be cautious with double comparison
          // quantity == other.quantity;

  @override
  int get hashCode => _itemId.hashCode;
    // name.hashCode ^ price.hashCode ^ quantity.hashCode;

  // --- EDIT: Add a general copyWith method ---
  ReceiptItem copyWith({String? name, double? price, int? quantity}) {
    // Use the internal constructor to ensure originalQuantity and itemId are handled
    return ReceiptItem._internal(
      name: name ?? _name,
      price: price ?? _price,
      quantity: quantity ?? _quantity,
      originalQuantity: _originalQuantity, // Keep the original quantity reference
      itemId: _itemId,                  // Keep the same unique ID
    );
  }
  // --- END EDIT ---
} 