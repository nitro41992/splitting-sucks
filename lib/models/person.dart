import 'package:flutter/foundation.dart';
import 'receipt_item.dart';

class Person extends ChangeNotifier {
  String _name;
  List<ReceiptItem> _assignedItems;
  List<ReceiptItem> _sharedItems;

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
    _assignedItems.add(item);
    notifyListeners();
  }

  void removeAssignedItem(ReceiptItem item) {
    _assignedItems.remove(item);
    notifyListeners();
  }

  void addSharedItem(ReceiptItem item) {
    _sharedItems.add(item);
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

  double get totalAmount {
    return totalAssignedAmount + totalSharedAmount;
  }
} 