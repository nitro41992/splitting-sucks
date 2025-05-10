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
    final removed = _assignedItems.remove(item);
    if (removed) notifyListeners();
  }

  void addSharedItem(ReceiptItem item) {
    _sharedItems.add(item);
    notifyListeners();
  }

  void removeSharedItem(ReceiptItem item) {
    final removed = _sharedItems.remove(item);
    if (removed) notifyListeners();
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

  Map<String, dynamic> toJson() {
    return {
      'name': _name,
      'assignedItems': _assignedItems.map((item) => item.toJson()).toList(),
      'sharedItems': _sharedItems.map((item) => item.toJson()).toList(),
    };
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      name: json['name'] as String,
      assignedItems: (json['assignedItems'] as List<dynamic>?)
          ?.map((itemJson) => ReceiptItem.fromJson(itemJson as Map<String, dynamic>))
          .toList(),
      sharedItems: (json['sharedItems'] as List<dynamic>?)
          ?.map((itemJson) => ReceiptItem.fromJson(itemJson as Map<String, dynamic>))
          .toList(),
    );
  }
} 