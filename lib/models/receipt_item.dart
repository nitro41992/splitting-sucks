import 'package:flutter/foundation.dart';

class ReceiptItem extends ChangeNotifier {
  String _name;
  double _price;
  int _quantity;
  final String _itemId; // Unique identifier for the item
  static int _nextId = 0;

  ReceiptItem({
    required String name,
    required double price,
    required int quantity,
    String? itemId,
  })  : _name = name,
        _price = price,
        _quantity = quantity,
        _itemId = itemId ?? 'item_${_nextId++}_$name';

  String get name => _name;
  double get price => _price;
  int get quantity => _quantity;
  String get itemId => _itemId;

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceiptItem &&
        other._itemId == _itemId;
  }

  @override
  int get hashCode => _itemId.hashCode;
} 