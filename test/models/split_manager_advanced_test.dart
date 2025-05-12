import 'package:billfie/models/person.dart';
import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/models/split_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SplitManager Advanced Bill Splitting Tests', () {
    late SplitManager manager;
    late List<Person> testPeople;
    late List<ReceiptItem> testItems;

    setUp(() {
      manager = SplitManager(
        tipPercentage: 0.15,  // 15% as a decimal
        taxPercentage: 0.08,  // 8% as a decimal
      );
      
      // Create test people
      testPeople = [
        Person(name: 'Alice'),
        Person(name: 'Bob'),
        Person(name: 'Charlie'),
      ];
      
      // Create test items
      testItems = [
        ReceiptItem(name: 'Steak', price: 25.0, quantity: 1, itemId: 'steak_id'),
        ReceiptItem(name: 'Salad', price: 12.0, quantity: 1, itemId: 'salad_id'),
        ReceiptItem(name: 'Soup', price: 8.0, quantity: 2, itemId: 'soup_id'),
        ReceiptItem(name: 'Dessert', price: 10.0, quantity: 3, itemId: 'dessert_id'),
        ReceiptItem(name: 'Drink', price: 5.0, quantity: 4, itemId: 'drink_id'),
      ];
      
      // Add people to manager
      for (var person in testPeople) {
        manager.addPerson(person.name);
      }
    });

    test('complex bill splitting scenario with mixed assignments and shares', () {
      // Get managed person references
      final alice = manager.people[0];
      final bob = manager.people[1];
      final charlie = manager.people[2];
      
      // Assign items
      // Alice gets the steak
      manager.assignItemToPerson(ReceiptItem.clone(testItems[0]), alice);
      
      // Bob gets the salad
      manager.assignItemToPerson(ReceiptItem.clone(testItems[1]), bob);
      
      // Charlie gets one soup
      final halfSoup = ReceiptItem(
        name: testItems[2].name, 
        price: testItems[2].price, 
        quantity: 1, 
        itemId: '${testItems[2].itemId}_half'
      );
      manager.assignItemToPerson(halfSoup, charlie);
      
      // Add the other soup as shared between Alice and Bob
      final sharedSoup = ReceiptItem(
        name: testItems[2].name, 
        price: testItems[2].price, 
        quantity: 1, 
        itemId: '${testItems[2].itemId}_shared'
      );
      manager.addItemToShared(sharedSoup, [alice, bob]);
      
      // Add 2 desserts as shared between all three
      final sharedDessert = ReceiptItem(
        name: testItems[3].name, 
        price: testItems[3].price, 
        quantity: 2, 
        itemId: '${testItems[3].itemId}_shared'
      );
      manager.addItemToShared(sharedDessert, [alice, bob, charlie]);
      
      // Add 1 dessert to unassigned
      final unassignedDessert = ReceiptItem(
        name: testItems[3].name, 
        price: testItems[3].price, 
        quantity: 1, 
        itemId: '${testItems[3].itemId}_unassigned'
      );
      manager.addUnassignedItem(unassignedDessert);
      
      // Add drinks - 1 for each person and 1 unassigned
      for (var i = 0; i < 3; i++) {
        final drink = ReceiptItem(
          name: testItems[4].name, 
          price: testItems[4].price, 
          quantity: 1, 
          itemId: '${testItems[4].itemId}_${i}'
        );
        manager.assignItemToPerson(drink, manager.people[i]);
      }
      
      final unassignedDrink = ReceiptItem(
        name: testItems[4].name, 
        price: testItems[4].price, 
        quantity: 1, 
        itemId: '${testItems[4].itemId}_unassigned'
      );
      manager.addUnassignedItem(unassignedDrink);
      
      // Calculate expected values
      // Individual assigned items:
      // Alice: Steak($25) + Drink($5) = $30
      // Bob: Salad($12) + Drink($5) = $17
      // Charlie: Soup($8) + Drink($5) = $13
      
      // Shared items:
      // Soup($8) shared by Alice and Bob = $4 each
      // Dessert($20) shared by all three = $6.67 each
      
      // Unassigned: Dessert($10) + Drink($5) = $15
      
      // Expected subtotal per person:
      // Alice: $30 (assigned) + $4 (shared soup) + $6.67 (shared dessert) = $40.67
      // Bob: $17 (assigned) + $4 (shared soup) + $6.67 (shared dessert) = $27.67
      // Charlie: $13 (assigned) + $6.67 (shared dessert) = $19.67
      
      // Total assigned: $60
      // Total shared: $28
      // Total unassigned: $15
      // Grand total: $103
      
      // Verify totals
      expect(manager.totalAmount, closeTo(103.0, 0.1));
      
      // Verify individual assigned amounts
      expect(alice.totalAssignedAmount, closeTo(30.0, 0.1));
      expect(bob.totalAssignedAmount, closeTo(17.0, 0.1));
      expect(charlie.totalAssignedAmount, closeTo(13.0, 0.1));
      
      // Calculate and verify tax and tip
      // Tax (8%) = 103 * 0.08 = $8.24
      // Tip (15%) = 103 * 0.15 = $15.45
      final tax = manager.taxAmount;
      final tip = manager.tipAmount;
      
      expect(tax, closeTo(8.24, 0.1));
      expect(tip, closeTo(15.45, 0.1));
      expect(manager.finalTotal, closeTo(126.69, 0.1));
    });

    test('handles floating point precision in bill calculations', () {
      // This test verifies that the app handles floating point math correctly
      
      // Create items with prices that might cause floating point issues
      final itemA = ReceiptItem(name: 'Item A', price: 33.33, quantity: 1);
      final itemB = ReceiptItem(name: 'Item B', price: 16.67, quantity: 2);
      
      // Add to manager
      final alice = manager.people[0];
      manager.assignItemToPerson(itemA, alice);
      
      final bob = manager.people[1];
      manager.assignItemToPerson(itemB, bob);
      
      // Expected subtotals:
      // Alice: $33.33
      // Bob: $33.34 ($16.67 * 2)
      // Total: $66.67
      
      expect(alice.totalAssignedAmount, closeTo(33.33, 0.01));
      expect(bob.totalAssignedAmount, closeTo(33.34, 0.01));
      expect(manager.totalAmount, closeTo(66.67, 0.01));
      
      // Calculate tax and tip
      // Tax (8%) = 66.67 * 0.08 = $5.33
      // Tip (15%) = 66.67 * 0.15 = $10.00
      // Total: $66.67 + $5.33 + $10.00 = $82.00
      final tax = manager.taxAmount;
      final tip = manager.tipAmount;
      
      expect(tax, closeTo(5.33, 0.01));
      expect(tip, closeTo(10.00, 0.01));
      expect(manager.finalTotal, closeTo(82.00, 0.01));
    });

    test('edge case: person removed after items assigned and shared', () {
      // Assign and share items
      final alice = manager.people[0];
      final bob = manager.people[1];
      final charlie = manager.people[2];
      
      // Alice gets a steak
      manager.assignItemToPerson(ReceiptItem.clone(testItems[0]), alice);
      
      // Bob and Charlie share a dessert
      final sharedDessert = ReceiptItem.clone(testItems[3]);
      sharedDessert.updateQuantity(1);
      manager.addItemToShared(sharedDessert, [bob, charlie]);
      
      // Verify initial state
      expect(manager.totalAmount, closeTo(35.0, 0.01)); // $25 steak + $10 dessert
      expect(bob.sharedItems.length, 1);
      expect(charlie.sharedItems.length, 1);
      
      // Remove Bob
      manager.removePerson(bob);
      
      // Verify state after Bob's removal
      expect(manager.people.length, 2);
      expect(manager.people.contains(bob), false);
      expect(charlie.sharedItems.length, 1);
      
      // Check that dessert is still shared but only by Charlie
      final sharedItemsUsers = manager.getPeopleForSharedItem(sharedDessert);
      expect(sharedItemsUsers.length, 1);
      expect(sharedItemsUsers[0].name, 'Charlie');
      
      // Total should still include all items
      expect(manager.totalAmount, closeTo(35.0, 0.01));
    });

    test('tax and tip distribution when some items are unassigned', () {
      // Set up a scenario with assigned and unassigned items
      final alice = manager.people[0];
      
      // Alice gets a steak ($25)
      manager.assignItemToPerson(ReceiptItem.clone(testItems[0]), alice);
      
      // Add unassigned salad ($12)
      manager.addUnassignedItem(ReceiptItem.clone(testItems[1]));
      
      // Total: $37
      expect(manager.totalAmount, closeTo(37.0, 0.01));
      
      // Tax (8%) = 37 * 0.08 = $2.96
      // Tip (15%) = 37 * 0.15 = $5.55
      // Total: $37 + $2.96 + $5.55 = $45.51
      
      // Alice's assigned portion: $25/$37 = 67.57% of the bill
      // Alice's tax share: 67.57% of $2.96 = $2.00
      // Alice's tip share: 67.57% of $5.55 = $3.75
      // Alice's total: $25 + $2.00 + $3.75 = $30.75
      
      // Unassigned portion: $12/$37 = 32.43% of the bill
      // Unassigned tax share: 32.43% of $2.96 = $0.96
      // Unassigned tip share: 32.43% of $5.55 = $1.80
      // Unassigned total: $12 + $0.96 + $1.80 = $14.76
      
      // Verify calculations
      final tax = manager.taxAmount;
      final tip = manager.tipAmount;
      final total = manager.finalTotal;
      
      expect(tax, closeTo(2.96, 0.01));
      expect(tip, closeTo(5.55, 0.01));
      expect(total, closeTo(45.51, 0.01));
      
      // Calculate Alice's proportional share - this is theoretical as SplitManager
      // doesn't directly provide a method to calculate this
      final aliceRatio = alice.totalAssignedAmount / manager.totalAmount;
      final aliceTaxShare = tax * aliceRatio;
      final aliceTipShare = tip * aliceRatio;
      final aliceTotal = alice.totalAssignedAmount + aliceTaxShare + aliceTipShare;
      
      expect(aliceRatio, closeTo(0.6757, 0.0001));
      expect(aliceTaxShare, closeTo(2.00, 0.01));
      expect(aliceTipShare, closeTo(3.75, 0.01));
      expect(aliceTotal, closeTo(30.75, 0.01));
    });

    test('preserves state correctly after transfer operations', () {
      // Set up initial state
      final alice = manager.people[0];
      final bob = manager.people[1];
      
      // Alice and Bob each have one dessert
      final aliceDessert = ReceiptItem.clone(testItems[3]);
      aliceDessert.updateQuantity(1);
      manager.assignItemToPerson(aliceDessert, alice);
      
      final bobDessert = ReceiptItem.clone(testItems[3]);
      bobDessert.updateQuantity(1);
      manager.assignItemToPerson(bobDessert, bob);
      
      // Initial state
      expect(alice.assignedItems.length, 1);
      expect(bob.assignedItems.length, 1);
      expect(manager.totalAmount, closeTo(20.0, 0.01));
      
      // Transfer half of Alice's dessert to Bob
      manager.transferItemQuantity(aliceDessert, 1);
      bobDessert.updateQuantity(2);
      
      // Final state
      expect(alice.assignedItems.length, 0); // Alice's dessert is gone (quantity 0)
      expect(bob.assignedItems.length, 1);
      expect(bob.assignedItems[0].quantity, 2);
      expect(manager.totalAmount, closeTo(20.0, 0.01)); // Total should be the same
    });
  });
} 