import 'package:flutter/foundation.dart';
import 'person.dart';
import 'receipt_item.dart';

class SplitManager extends ChangeNotifier {
  List<Person> _people;
  List<ReceiptItem> _sharedItems;

  SplitManager({
    List<Person>? people,
    List<ReceiptItem>? sharedItems,
  })  : _people = people ?? [],
        _sharedItems = sharedItems ?? [];

  List<Person> get people => List.unmodifiable(_people);
  List<ReceiptItem> get sharedItems => List.unmodifiable(_sharedItems);

  void reset() {
    _people = [];
    _sharedItems = [];
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
    _sharedItems.add(item);
    notifyListeners();
  }

  void removeSharedItem(ReceiptItem item) {
    _sharedItems.remove(item);
    notifyListeners();
  }

  void assignItemToPerson(ReceiptItem item, Person person) {
    person.addAssignedItem(item);
    notifyListeners();
  }

  void unassignItemFromPerson(ReceiptItem item, Person person) {
    person.removeAssignedItem(item);
    notifyListeners();
  }

  void addItemToShared(ReceiptItem item, List<Person> people) {
    _sharedItems.add(item);
    for (var person in people) {
      person.addSharedItem(item);
    }
    notifyListeners();
  }

  void removeItemFromShared(ReceiptItem item) {
    _sharedItems.remove(item);
    for (var person in _people) {
      person.removeSharedItem(item);
    }
    notifyListeners();
  }

  double get totalAmount {
    double total = 0;
    for (var person in _people) {
      total += person.totalAmount;
    }
    return total;
  }

  double get sharedItemsTotal {
    return _sharedItems.fold(0, (sum, item) => sum + item.total);
  }
} 