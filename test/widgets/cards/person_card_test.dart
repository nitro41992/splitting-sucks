import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:billfie/models/person.dart';
import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/models/split_manager.dart';
import 'package:billfie/widgets/cards/person_card.dart';

void main() {
  group('PersonCard', () {
    late Person person;
    late SplitManager splitManager;
    late ReceiptItem assignedItem;
    late ReceiptItem sharedItem;

    setUp(() {
      assignedItem = ReceiptItem(
        name: 'Burger',
        price: 10.0,
        quantity: 1,
        itemId: 'burger_id',
      );
      
      sharedItem = ReceiptItem(
        name: 'Fries',
        price: 5.0,
        quantity: 2,
        itemId: 'fries_id',
      );
      
      person = Person(
        name: 'Alice',
        assignedItems: [assignedItem],
        sharedItems: [sharedItem],
      );
      
      splitManager = SplitManager();
      splitManager.addPerson(person.name);
      // Get the managed person instance
      final managedPerson = splitManager.people.first;
      // Assign the same items
      splitManager.assignItemToPerson(ReceiptItem.clone(assignedItem), managedPerson);
      splitManager.addSharedItem(ReceiptItem.clone(sharedItem));
      splitManager.addPersonToSharedItem(splitManager.sharedItems.first, managedPerson);
    });

    testWidgets('blue total pill shows only assigned items amount, not shared items amount', (WidgetTester tester) async {
      // Build the PersonCard widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<SplitManager>.value(
              value: splitManager,
              child: PersonCard(person: splitManager.people.first),
            ),
          ),
        ),
      );
      
      // Wait for any animations
      await tester.pumpAndSettle();
      
      // Find the blue pill container using its ValueKey
      final pillContainerFinder = find.byKey(const ValueKey('person_card_total_pill'));
      
      // Verify the pill exists
      expect(pillContainerFinder, findsOneWidget);
      
      // Verify the container has the blue color (primaryContainer)
      final Container pillContainer = tester.widget<Container>(pillContainerFinder);
      final BoxDecoration decoration = pillContainer.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      
      // Find the text within using its ValueKey
      final pillTextFinder = find.byKey(const ValueKey('person_card_total_amount'));
      
      // Verify the text exists
      expect(pillTextFinder, findsOneWidget);
      
      // Verify the text shows the correct amount
      final Text textWidget = tester.widget<Text>(pillTextFinder);
      expect(textWidget.data, '\$${person.totalAssignedAmount.toStringAsFixed(2)}');
      
      // Double-check the correctness of our test setup
      expect(person.totalAssignedAmount, 10.0);
      expect(sharedItem.total, 10.0); // 5.0 * 2
    });
  });
} 