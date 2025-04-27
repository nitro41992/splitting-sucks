import 'package:flutter/foundation.dart';

class ReceiptItem extends ChangeNotifier {
  String _name;
  double _price;
  int _quantity;

  ReceiptItem({
    required String name,
    required double price,
    required int quantity,
  })  : _name = name,
        _price = price,
        _quantity = quantity;

  String get name => _name;
  double get price => _price;
  int get quantity => _quantity;

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
} 