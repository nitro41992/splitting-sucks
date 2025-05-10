import 'package:billfie/models/person.dart';
import 'package:billfie/models/receipt_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Person Model Tests', () {
    late ReceiptItem item1;
    late ReceiptItem item2;
    late ReceiptItem sharedItem1;

    setUp(() {
      // It's good practice to create fresh instances for each test or test group
      // to avoid side effects if they are mutable (ReceiptItem is a ChangeNotifier).
      item1 = ReceiptItem(name: 'Burger', price: 10.0, quantity: 1, itemId: 'item_burger');
      item2 = ReceiptItem(name: 'Fries', price: 4.0, quantity: 2, itemId: 'item_fries');
      sharedItem1 = ReceiptItem(name: 'Salad', price: 8.0, quantity: 1, itemId: 'item_salad_shared');
    });

    group('Constructor and Getters', () {
      test('should correctly initialize with name and empty lists if items not provided', () {
        final person = Person(name: 'Alice');

        expect(person.name, 'Alice');
        expect(person.assignedItems, isEmpty);
        expect(person.sharedItems, isEmpty);
      });

      test('should correctly initialize with provided name and item lists', () {
        final person = Person(
          name: 'Bob',
          assignedItems: [item1, item2],
          sharedItems: [sharedItem1],
        );

        expect(person.name, 'Bob');
        expect(person.assignedItems, [item1, item2]);
        expect(person.sharedItems, [sharedItem1]);
      });

      test('getters for item lists should return unmodifiable lists', () {
        final person = Person(name: 'Charlie', assignedItems: [item1]);
        
        expect(() => person.assignedItems.add(item2), throwsA(isA<UnsupportedError>()));
        expect(() => person.sharedItems.add(sharedItem1), throwsA(isA<UnsupportedError>()));
      });
    });

    group('toJson and fromJson', () {
      test('toJson should serialize correctly with items', () {
        final person = Person(
          name: 'David',
          assignedItems: [item1],
          sharedItems: [sharedItem1],
        );
        final json = person.toJson();

        expect(json['name'], 'David');
        expect(json['assignedItems'], [item1.toJson()]);
        expect(json['sharedItems'], [sharedItem1.toJson()]);
      });

      test('toJson should serialize correctly with empty item lists', () {
        final person = Person(name: 'Eve');
        final json = person.toJson();

        expect(json['name'], 'Eve');
        expect(json['assignedItems'], isEmpty);
        expect(json['sharedItems'], isEmpty);
      });

      test('fromJson should deserialize correctly with items', () {
        final jsonData = {
          'name': 'Frank',
          'assignedItems': [item1.toJson(), item2.toJson()],
          'sharedItems': [sharedItem1.toJson()],
        };
        final person = Person.fromJson(jsonData);

        expect(person.name, 'Frank');
        // We need to compare properties as they are new instances of ReceiptItem
        expect(person.assignedItems.length, 2);
        expect(person.assignedItems[0].itemId, item1.itemId);
        expect(person.assignedItems[1].itemId, item2.itemId);
        expect(person.sharedItems.length, 1);
        expect(person.sharedItems[0].itemId, sharedItem1.itemId);
      });

      test('fromJson should deserialize correctly with empty or null item lists', () {
        final jsonDataEmpty = {
          'name': 'Grace',
          'assignedItems': [],
          'sharedItems': [],
        };
        final personEmpty = Person.fromJson(jsonDataEmpty);
        expect(personEmpty.name, 'Grace');
        expect(personEmpty.assignedItems, isEmpty);
        expect(personEmpty.sharedItems, isEmpty);

        final jsonDataNull = {
          'name': 'Heidi',
          'assignedItems': null,
          'sharedItems': null,
        };
        final personNull = Person.fromJson(jsonDataNull);
        expect(personNull.name, 'Heidi');
        expect(personNull.assignedItems, isEmpty);
        expect(personNull.sharedItems, isEmpty);
      });

      test('fromJson should throw if name is missing (as it is required by constructor)', () {
        // Based on current Person.fromJson: name: json['name'] as String, 
        // this will throw if 'name' is null or not a string.
        final jsonDataNoName = {
          'assignedItems': [],
          'sharedItems': [],
        };
        expect(() => Person.fromJson(jsonDataNoName), throwsA(isA<TypeError>())); // Or specific cast error

        final jsonDataNullName = {
          'name': null,
          'assignedItems': [],
          'sharedItems': [],
        };
        // This will also likely throw a TypeError due to `null as String`
        expect(() => Person.fromJson(jsonDataNullName as Map<String, dynamic>), throwsA(isA<TypeError>()));
      });
    });

    group('Helper Methods, Total Amounts, and ChangeNotifier', () {
      late Person person;
      late ReceiptItem item3; // Another distinct item
      bool listenerNotified = false;

      setUp(() {
        person = Person(name: 'InitialName', assignedItems: [item1], sharedItems: [sharedItem1]);
        item3 = ReceiptItem(name: 'Drink', price: 2.5, quantity: 1, itemId: 'item_drink');
        listenerNotified = false;
        person.addListener(() {
          listenerNotified = true;
        });
      });

      tearDown(() {
        // Important to remove listener to avoid affecting other tests if person instance was reused (though here it's per setUp)
        // person.removeListener(() => listenerNotified = true); // This lambda won't work for removal
        // To properly remove, you'd need to store the listener function. 
        // However, since person is new in each setUp, it's less critical for this specific structure.
      });

      test('updateName should change name and notify listeners', () {
        person.updateName('NewName');
        expect(person.name, 'NewName');
        expect(listenerNotified, isTrue);

        listenerNotified = false;
        person.updateName('NewName'); // No change
        expect(listenerNotified, isFalse);
      });

      test('addAssignedItem should add item and notify listeners', () {
        person.addAssignedItem(item2);
        expect(person.assignedItems, contains(item2));
        expect(person.assignedItems.length, 2);
        expect(listenerNotified, isTrue);
      });

      test('removeAssignedItem should remove item and notify listeners', () {
        person.addAssignedItem(item2); // Ensure item2 is there
        listenerNotified = false; // Reset for this action

        person.removeAssignedItem(item1); // item1 was from setUp
        expect(person.assignedItems, isNot(contains(item1)));
        expect(person.assignedItems, contains(item2));
        expect(person.assignedItems.length, 1);
        expect(listenerNotified, isTrue);
      });

      test('addSharedItem should add item and notify listeners', () {
        person.addSharedItem(item3);
        expect(person.sharedItems, contains(item3));
        expect(person.sharedItems.length, 2);
        expect(listenerNotified, isTrue);
      });

      test('removeSharedItem should remove item and notify listeners', () {
        person.addSharedItem(item3); // Ensure item3 is there
        listenerNotified = false; // Reset for this action

        person.removeSharedItem(sharedItem1); // sharedItem1 was from setUp
        expect(person.sharedItems, isNot(contains(sharedItem1)));
        expect(person.sharedItems, contains(item3));
        expect(person.sharedItems.length, 1);
        expect(listenerNotified, isTrue);
      });

      test('totalAssignedAmount should calculate correctly', () {
        // Initial: item1 (10.0 * 1 = 10.0)
        expect(person.totalAssignedAmount, 10.0);
        person.addAssignedItem(item2); // item2 (4.0 * 2 = 8.0)
        // Total: 10.0 + 8.0 = 18.0
        expect(person.totalAssignedAmount, 18.0);
      });

      test('totalSharedAmount should calculate correctly', () {
        // Initial: sharedItem1 (8.0 * 1 = 8.0)
        expect(person.totalSharedAmount, 8.0);
        person.addSharedItem(item3); // item3 (2.5 * 1 = 2.5)
        // Total: 8.0 + 2.5 = 10.5
        expect(person.totalSharedAmount, 10.5);
      });

      test('totalAmount should be sum of totalAssignedAmount and totalSharedAmount', () {
        // Assigned: item1 (10.0)
        // Shared: sharedItem1 (8.0)
        // Total: 18.0
        expect(person.totalAmount, 18.0);

        person.addAssignedItem(item2); // Adds 8.0 to assigned (total assigned = 18)
        person.addSharedItem(item3);   // Adds 2.5 to shared (total shared = 10.5)
        // New Total: 18.0 (assigned) + 10.5 (shared) = 28.5
        expect(person.totalAmount, 28.5);
      });
        test('removing non-existent item should not throw error and not notify', () {
        final nonExistentItem = ReceiptItem(name: 'Ghost', price: 1.0, quantity: 1, itemId: 'ghost_id');
        
        listenerNotified = false;
        person.removeAssignedItem(nonExistentItem);
        expect(listenerNotified, isFalse);
        expect(person.assignedItems, contains(item1)); // Ensure original item is still there

        listenerNotified = false;
        person.removeSharedItem(nonExistentItem);
        expect(listenerNotified, isFalse);
        expect(person.sharedItems, contains(sharedItem1)); // Ensure original item is still there
      });
    });
  });
} 