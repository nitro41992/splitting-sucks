import 'package:billfie/models/receipt_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptItem Model Tests', () {
    // Reset static _nextId before each test group or test if necessary 
    // to ensure itemId predictability if tests rely on its format.
    // This can be done in a setUp or by carefully managing test cases.
    // For now, we'll assume tests don't strictly depend on the _nextId sequence for correctness,
    // but rather on the presence and uniqueness of itemId.

    setUp(() {
      // If _nextId needs to be reset for predictable itemId generation in tests:
      // ReceiptItem.resetNextId(); // Assuming such a method exists or can be added for testing.
      // For now, we will proceed without resetting _nextId as the model doesn't expose a reset.
      // Tests should focus on the properties rather than the exact auto-generated ID sequence.
    });

    group('Factory Constructor and Getters', () {
      test('should correctly initialize fields using the factory constructor', () {
        final item = ReceiptItem(name: 'Test Item', price: 10.99, quantity: 2);

        expect(item.name, 'Test Item');
        expect(item.price, 10.99);
        expect(item.quantity, 2);
        expect(item.originalQuantity, 2); // Original quantity should match initial quantity
        expect(item.itemId, isNotNull);
        expect(item.itemId, startsWith('item_')); // Basic check for itemId format
        // expect(item.itemId, 'item_0_Test Item'); // If _nextId reset was implemented and predictable
      });

      test('should use provided itemId if specified in factory constructor', () {
        final item = ReceiptItem(name: 'Specific Item', price: 5.0, quantity: 1, itemId: 'customId123');
        expect(item.itemId, 'customId123');
      });

      test('total getter should calculate price * quantity correctly', () {
        final item = ReceiptItem(name: 'Calculated Item', price: 2.5, quantity: 4);
        expect(item.total, 10.0);

        final itemZeroQuantity = ReceiptItem(name: 'Zero Qty', price: 5.0, quantity: 0);
        expect(itemZeroQuantity.total, 0.0);
      });
    });

    group('fromJson and toJson', () {
      test('toJson should serialize all fields correctly', () {
        // Need to use _internal or a known itemId for predictable toJson output if _nextId is not reset.
        // Or, construct with a specific itemId.
        final item = ReceiptItem(name: 'Serial Item', price: 20.50, quantity: 3, itemId: 'fixedId_1');
        // Manually set originalQuantity if it could differ and toJson needs to include it based on a specific state.
        // For a fresh item from factory, originalQuantity == quantity.
        
        final json = item.toJson();

        expect(json['name'], 'Serial Item');
        expect(json['price'], 20.50);
        expect(json['quantity'], 3);
        expect(json['originalQuantity'], 3); // As initialized by factory
        expect(json['itemId'], 'fixedId_1');
      });

      test('fromJson should deserialize correctly with all fields present', () {
        final jsonData = {
          'name': 'Deserialized Item',
          'price': 15.75,
          'quantity': 1,
          'originalQuantity': 1,
          'itemId': 'deserialId_1'
        };

        final item = ReceiptItem.fromJson(jsonData);

        expect(item.name, 'Deserialized Item');
        expect(item.price, 15.75);
        expect(item.quantity, 1);
        expect(item.originalQuantity, 1);
        expect(item.itemId, 'deserialId_1');
      });

      test('fromJson should handle missing optional fields with defaults', () {
        final jsonData = <String, dynamic>{
          // Missing: name, price, quantity, originalQuantity, itemId
        };
        // Note: itemId generation in fromJson for missing itemId will depend on _nextId state.
        // To make this test fully predictable, we either need to reset _nextId or not assert the exact itemId.

        final item = ReceiptItem.fromJson(jsonData);

        expect(item.name, 'Unknown Item'); // Default value
        expect(item.price, 0.0);          // Default value
        expect(item.quantity, 1);         // Default value
        expect(item.originalQuantity, 1); // Defaults to quantity
        expect(item.itemId, isNotNull);    // Should still generate an ID
        // Example: expect(item.itemId, 'item_X_Unknown Item'); // where X is current _nextId
      });

      test('fromJson should use quantity for originalQuantity if originalQuantity is missing', () {
        final jsonData = {
          'name': 'Test Original Qty',
          'price': 10.0,
          'quantity': 5,
          // 'originalQuantity': missing
          'itemId': 'origQtyTestId'
        };

        final item = ReceiptItem.fromJson(jsonData);
        expect(item.originalQuantity, 5);
      });
       test('fromJson should handle null values for nullable fields from JSON', () {
        final jsonData = <String, dynamic>{
          'name': null, // Name can be null in JSON, defaults to 'Unknown Item'
          'price': null, // Price can be null, defaults to 0.0
          'quantity': null, // Quantity can be null, defaults to 1
          'originalQuantity': null, // Defaults to quantity (which defaults to 1)
          'itemId': null, // ItemId can be null, generates a new one
        };

        final item = ReceiptItem.fromJson(jsonData);

        expect(item.name, 'Unknown Item');
        expect(item.price, 0.0);
        expect(item.quantity, 1);
        expect(item.originalQuantity, 1);
        expect(item.itemId, isNotNull); // A new ID should be generated
      });
    });

    group('ReceiptItem.clone() Constructor', () {
      test('should create an exact copy of the original item', () {
        final original = ReceiptItem(name: 'Original', price: 12.34, quantity: 5, itemId: 'cloneTestId');
        // Manually update quantity to differ from originalQuantity for a more robust test
        original.updateQuantity(3); // quantity is now 3, originalQuantity remains 5
        
        final clone = ReceiptItem.clone(original);

        expect(clone.name, original.name);
        expect(clone.price, original.price);
        expect(clone.quantity, original.quantity); // Should be 3
        expect(clone.originalQuantity, original.originalQuantity); // Should be 5
        expect(clone.itemId, original.itemId); // Crucially, itemId should be the same
        expect(clone, isNot(same(original))); // Should be a new instance
      });

      test('cloned item should have independent state (mutating clone does not affect original)', () {
        final original = ReceiptItem(name: 'ModOriginal', price: 9.99, quantity: 2, itemId: 'modTestId');
        final clone = ReceiptItem.clone(original);

        clone.updateName('Modified Clone');
        clone.updatePrice(1.23);
        clone.updateQuantity(10);

        expect(original.name, 'ModOriginal');
        expect(original.price, 9.99);
        expect(original.quantity, 2);

        expect(clone.name, 'Modified Clone');
        expect(clone.price, 1.23);
        expect(clone.quantity, 10);
      });
    });

    group('Helper Methods and ChangeNotifier', () {
      test('isSameItem should return true for items with same name and price, false otherwise', () {
        final item1 = ReceiptItem(name: 'Apple', price: 1.0, quantity: 1);
        final item2 = ReceiptItem(name: 'Apple', price: 1.0, quantity: 2); // Same name and price, different quantity
        final item3 = ReceiptItem(name: 'Banana', price: 1.0, quantity: 1); // Different name
        final item4 = ReceiptItem(name: 'Apple', price: 1.5, quantity: 1); // Different price

        expect(item1.isSameItem(item2), isTrue);
        expect(item1.isSameItem(item3), isFalse);
        expect(item1.isSameItem(item4), isFalse);
      });

      test('updateName should change name and notify listeners', () {
        final item = ReceiptItem(name: 'Old Name', price: 1.0, quantity: 1);
        bool notified = false;
        item.addListener(() => notified = true);

        item.updateName('New Name');
        expect(item.name, 'New Name');
        expect(notified, isTrue);

        // Test that no notification if name is the same
        notified = false;
        item.updateName('New Name');
        expect(notified, isFalse);
      });

      test('updatePrice should change price and notify listeners', () {
        final item = ReceiptItem(name: 'Item', price: 10.0, quantity: 1);
        bool notified = false;
        item.addListener(() => notified = true);

        item.updatePrice(12.5);
        expect(item.price, 12.5);
        expect(notified, isTrue);

        notified = false;
        item.updatePrice(12.5);
        expect(notified, isFalse);
      });

      test('updateQuantity should change quantity and notify listeners', () {
        final item = ReceiptItem(name: 'Item', price: 1.0, quantity: 5);
        bool notified = false;
        item.addListener(() => notified = true);

        item.updateQuantity(3);
        expect(item.quantity, 3);
        expect(notified, isTrue);

        notified = false;
        item.updateQuantity(3);
        expect(notified, isFalse);
        // Note: originalQuantity is not affected by updateQuantity
        expect(item.originalQuantity, 5);
      });

      test('resetQuantity should revert quantity to originalQuantity and NOT notify (as per current impl)', () {
        final item = ReceiptItem(name: 'Item', price: 1.0, quantity: 5); // originalQuantity is 5
        item.updateQuantity(2); // quantity is now 2

        bool notified = false;
        item.addListener(() => notified = true);

        item.resetQuantity();
        expect(item.quantity, 5);
        expect(notified, isFalse); // Current resetQuantity doesn't call notifyListeners
      });

      test('copyWithQuantity should create a new item with updated quantity, preserving other fields', () {
        final original = ReceiptItem(name: 'CopyQtyItem', price: 7.77, quantity: 3, itemId: 'cqId');
        // original.originalQuantity will be 3

        final copied = original.copyWithQuantity(10);

        expect(copied.name, 'CopyQtyItem');
        expect(copied.price, 7.77);
        expect(copied.quantity, 10);
        expect(copied.itemId, 'cqId'); // itemId should be preserved
        expect(copied.originalQuantity, 10); // Should match the new quantity for split assignments
        expect(copied, isNot(same(original)));
      });
    });

    group('copyWith Method', () {
      final baseItem = ReceiptItem(name: 'Base', price: 10.0, quantity: 2, itemId: 'baseId');
      // baseItem.originalQuantity is 2 initially

      test('should copy with new name', () {
        final copied = baseItem.copyWith(name: 'NewName');
        expect(copied.name, 'NewName');
        expect(copied.price, baseItem.price);
        expect(copied.quantity, baseItem.quantity);
        expect(copied.originalQuantity, baseItem.originalQuantity); // Should preserve originalQuantity
        expect(copied.itemId, baseItem.itemId); // Should preserve itemId
        expect(copied, isNot(same(baseItem)));
      });

      test('should copy with new price', () {
        final copied = baseItem.copyWith(price: 12.5);
        expect(copied.price, 12.5);
        expect(copied.name, baseItem.name);
        expect(copied.quantity, baseItem.quantity);
        expect(copied.originalQuantity, baseItem.originalQuantity);
        expect(copied.itemId, baseItem.itemId);
      });

      test('should copy with new quantity', () {
        final copied = baseItem.copyWith(quantity: 5);
        expect(copied.quantity, 5);
        expect(copied.name, baseItem.name);
        expect(copied.price, baseItem.price);
        expect(copied.originalQuantity, baseItem.originalQuantity);
        expect(copied.itemId, baseItem.itemId);
      });

      test('should copy with all new values', () {
        final copied = baseItem.copyWith(name: 'Fully New', price: 99.9, quantity: 7);
        expect(copied.name, 'Fully New');
        expect(copied.price, 99.9);
        expect(copied.quantity, 7);
        expect(copied.originalQuantity, baseItem.originalQuantity); // Original and itemId are key to preserve
        expect(copied.itemId, baseItem.itemId);
      });

      test('should return identical (but new instance) if no parameters provided', () {
        final copied = baseItem.copyWith();
        expect(copied.name, baseItem.name);
        expect(copied.price, baseItem.price);
        expect(copied.quantity, baseItem.quantity);
        expect(copied.originalQuantity, baseItem.originalQuantity);
        expect(copied.itemId, baseItem.itemId);
        expect(copied, isNot(same(baseItem)));
      });

      test('copyWith should preserve originalQuantity and itemId from the source item', () {
        // Create an item and then modify its quantity so originalQuantity and quantity differ
        final item = ReceiptItem(name: 'SourceItem', price: 5.0, quantity: 10, itemId: 'sourceItemId');
        item.updateQuantity(3); // Now quantity = 3, originalQuantity = 10

        final copiedItem = item.copyWith(name: 'CopiedName');

        expect(copiedItem.name, 'CopiedName');
        expect(copiedItem.price, item.price);
        expect(copiedItem.quantity, item.quantity); // Quantity should be copied (3)
        expect(copiedItem.originalQuantity, 10);    // Original quantity from source should be preserved (10)
        expect(copiedItem.itemId, 'sourceItemId');   // ItemId from source should be preserved
      });
    });

    group('Equality (==) and hashCode', () {
      test('items with the same itemId should be equal and have same hashCode', () {
        // Use the _internal constructor or the factory with a specified itemId to ensure identical itemIds
        final item1 = ReceiptItem(name: 'Item A', price: 10.0, quantity: 1, itemId: 'commonId');
        final item2 = ReceiptItem(name: 'Item B', price: 20.0, quantity: 2, itemId: 'commonId'); // Different props, same ID
        
        expect(item1 == item2, isTrue);
        expect(item1.hashCode, item2.hashCode);
      });

      test('items with different itemIds should NOT be equal', () {
        final item1 = ReceiptItem(name: 'Same Props', price: 5.0, quantity: 1, itemId: 'id1');
        final item2 = ReceiptItem(name: 'Same Props', price: 5.0, quantity: 1, itemId: 'id2'); // Same props, different ID
        
        expect(item1 == item2, isFalse);
        // Hash codes might coincidentally be the same for different strings, so primarily test inequality.
      });

      test('item should be equal to itself', () {
        final item = ReceiptItem(name: 'Self', price: 1.0, quantity: 1, itemId: 'selfId');
        expect(item == item, isTrue);
      });

      test('item should not be equal to null or different type', () {
        final item = ReceiptItem(name: 'TypeTest', price: 1.0, quantity: 1, itemId: 'typeId');
        expect(item == null, isFalse);
        // ignore: unrelated_type_equality_checks
        expect(item == Object(), isFalse);
      });

      // Note: Current implementation of == and hashCode ONLY considers itemId.
      // If logic changes to include other fields (name, price, quantity), these tests would need an update.
    });
    
    // Test for ChangeNotifier is implicitly covered by testing update methods trigger listeners.
    // If more complex listener management was in place, dedicated tests for add/remove listener might be needed.
  });
} 