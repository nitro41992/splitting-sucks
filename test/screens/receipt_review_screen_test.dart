import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/screens/receipt_review_screen.dart';
import 'package:billfie/widgets/receipt_review/receipt_item_card.dart';
import 'package:billfie/widgets/dialogs/add_item_dialog.dart'; // Corrected import
import 'package:billfie/widgets/dialogs/edit_item_dialog.dart'; // Corrected import
import 'package:billfie/widgets/workflow_modal.dart'; // For GetCurrentItemsCallback
import 'package:billfie/providers/workflow_state.dart'; // If direct interaction is needed
import 'package:flutter/foundation.dart'; // Import for debugPrintSynchronously

// Mocks
class MockNavigatorObserver extends Mock implements NavigatorObserver {}
class MockWorkflowState extends Mock implements WorkflowState {}

// Helper function to pump the widget
Widget _boilerplate({
  required List<ReceiptItem> initialItems,
  Function(List<ReceiptItem> updatedItems, List<ReceiptItem> deletedItems)? onReviewComplete,
  Function(List<ReceiptItem> currentItems)? onItemsUpdated,
  Function(GetCurrentItemsCallback getter)? registerCurrentItemsGetter,
  NavigatorObserver? navigatorObserver,
  WorkflowState? mockWorkflowState,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkflowState>.value(
        value: mockWorkflowState ?? MockWorkflowState(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ReceiptReviewScreen(
          initialItems: initialItems,
          onReviewComplete: onReviewComplete ?? (_, __) {},
          onItemsUpdated: onItemsUpdated ?? (_) {},
          registerCurrentItemsGetter: registerCurrentItemsGetter ?? (_) {},
        ),
      ),
      navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
    ),
  );
}

void main() {
  late List<ReceiptItem> mockInitialItems;

  setUp(() {
    mockInitialItems = [
      ReceiptItem(itemId: '1', name: 'Item 1', price: 10.0, quantity: 1),
      ReceiptItem(itemId: '2', name: 'Item 2', price: 5.50, quantity: 2),
    ];
  });

  group('ReceiptReviewScreen - Initial Display with Items', () {
    testWidgets('Displays ReceiptItemCard for each initial item, buttons, and correct total', (WidgetTester tester) async {
      await tester.pumpWidget(_boilerplate(initialItems: mockInitialItems));
      await tester.pumpAndSettle();

      expect(find.byType(ReceiptItemCard), findsNWidgets(mockInitialItems.length));

      for (var item in mockInitialItems) {
        final itemCardFinder = find.ancestor(
          of: find.text(item.name),
          matching: find.byType(ReceiptItemCard),
        );
        expect(itemCardFinder, findsOneWidget);
        expect(find.descendant(of: itemCardFinder, matching: find.textContaining('\$${item.price.toStringAsFixed(2)} each')), findsOneWidget);
      }

      expect(find.byKey(const ValueKey('addItemFAB')), findsOneWidget);
      expect(find.byKey(const ValueKey('confirmReviewButton')), findsOneWidget);

      double expectedTotal = mockInitialItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
      // expect(find.textContaining(expectedTotal.toStringAsFixed(2)), findsOneWidget);
      // expect(find.textContaining('Subtotal:'), findsOneWidget);

      // Verify Subtotal Label (Expanded)
      final subtotalLabelFinder = find.byKey(const ValueKey('subtotal_label_expanded'));
      expect(subtotalLabelFinder, findsOneWidget);
      expect(tester.widget<Text>(subtotalLabelFinder).data, 'Subtotal');

      // Verify Subtotal Amount (Expanded)
      final subtotalAmountFinder = find.byKey(const ValueKey('subtotal_amount_expanded'));
      expect(subtotalAmountFinder, findsOneWidget);
      expect(tester.widget<Text>(subtotalAmountFinder).data, '\$${expectedTotal.toStringAsFixed(2)}');
    });
  });

  group('ReceiptReviewScreen - Initial Display (No Items)', () {
    testWidgets('Displays "Items (0)" text, no item cards, "Add Item" button, and correct total when no items are present', (WidgetTester tester) async {
      await tester.pumpWidget(_boilerplate(initialItems: []));
      await tester.pumpAndSettle();

      // Expect "Items (0)" text
      expect(find.text('Items (0)'), findsOneWidget);

      // Expect no ReceiptItemCard widgets
      expect(find.byType(ReceiptItemCard), findsNothing);

      // Expect "Add Item" button
      expect(find.byKey(const ValueKey('addItemFAB')), findsOneWidget);

      // Expect "Confirm Review" button to be present and disabled
      final confirmButtonFinder = find.byKey(const ValueKey('confirmReviewButton'));
      expect(confirmButtonFinder, findsOneWidget);
      final ElevatedButton confirmButton = tester.widget<ElevatedButton>(confirmButtonFinder);
      expect(confirmButton.onPressed, isNull, reason: "Confirm button should be disabled when there are no items.");
      
      // Verify Subtotal Label (Expanded) - should still be present
      final subtotalLabelFinder = find.byKey(const ValueKey('subtotal_label_expanded'));
      expect(subtotalLabelFinder, findsOneWidget);
      expect(tester.widget<Text>(subtotalLabelFinder).data, 'Subtotal');

      // Verify Subtotal Amount (Expanded) - should be $0.00
      final subtotalAmountFinder = find.byKey(const ValueKey('subtotal_amount_expanded'));
      expect(subtotalAmountFinder, findsOneWidget);
      expect(tester.widget<Text>(subtotalAmountFinder).data, '\$0.00'); 
    });
  });

  group('ReceiptReviewScreen - Adding a New Item', () {
    testWidgets('Tapping "Add Item" FAB opens AddItemDialog', (WidgetTester tester) async {
      final mockNavigatorObserver = MockNavigatorObserver();
      await tester.pumpWidget(_boilerplate(
        initialItems: [], 
        navigatorObserver: mockNavigatorObserver,
      ));
      await tester.pumpAndSettle();

      // Verify dialog title is not visible initially
      expect(find.text('Add New Item'), findsNothing);

      // Tap the "Add Item" FAB
      await tester.tap(find.byKey(const ValueKey('addItemFAB')));
      await tester.pumpAndSettle(); // Allow dialog to appear

      // Verify dialog title is now visible (indicating the dialog is open)
      expect(find.text('Add New Item'), findsOneWidget);
      
      // TODO: Revisit Mockito verify issue with NavigatorObserver.didPush
      // verify(mockNavigatorObserver.didPush(any, any)).called(1);
    });

    testWidgets('Saving the dialog adds a new ReceiptItemCard to the list', (WidgetTester tester) async {
      List<ReceiptItem> currentItems = [];
      final List<ReceiptItem> initialItems = []; // Start with no items

      await tester.pumpWidget(_boilerplate(
        initialItems: initialItems,
        onItemsUpdated: (updatedItems) {
          currentItems = updatedItems;
        },
      ));
      await tester.pumpAndSettle();

      // Tap the "Add Item" FAB
      await tester.tap(find.byKey(const ValueKey('addItemFAB')));
      await tester.pumpAndSettle(); // Allow dialog to appear

      // Verify dialog is open
      expect(find.text('Add New Item'), findsOneWidget);

      // Enter item details
      const newItemName = 'New Test Item';
      const newItemPrice = '25.99';
      const newItemQuantity = 3;

      await tester.enterText(find.byKey(const ValueKey('addItemDialog_name_field')), newItemName);
      await tester.enterText(find.byKey(const ValueKey('addItemDialog_price_field')), newItemPrice);
      
      // Adjust quantity to 3 (starts at 1)
      for (int i = 0; i < newItemQuantity - 1; i++) {
        await tester.tap(find.byKey(const ValueKey('addItemDialog_quantity_increment_button'))); 
        await tester.pump(); // Pump after each tap to update quantity display
      }
      await tester.pumpAndSettle();


      // Tap the "Add Item" button in the dialog
      await tester.tap(find.byKey(const ValueKey('addItemDialog_add_button'))); 
      await tester.pumpAndSettle(); // Allow dialog to close and UI to update
      await tester.pumpAndSettle(const Duration(seconds: 5)); // Allow toast timer to flush

      // Verify the dialog is closed
      expect(find.text('Add New Item'), findsNothing);

      // Verify a new ReceiptItemCard is added
      expect(find.byType(ReceiptItemCard), findsOneWidget);
      expect(find.text(newItemName), findsOneWidget);

      // Find the specific card for the new item
      final newCardFinder = find.ancestor(
        of: find.text(newItemName),
        matching: find.byType(ReceiptItemCard)
      );
      expect(newCardFinder, findsOneWidget, reason: "Should find the card for the new item: $newItemName");

      // Find the ReceiptItem in currentItems to get its ID for the key
      final addedItem = currentItems.firstWhere((item) => item.name == newItemName);
      final priceTextFinder = find.byKey(ValueKey('receiptItemCard_price_${addedItem.itemId}'));
      expect(priceTextFinder, findsOneWidget);
      expect(tester.widget<Text>(priceTextFinder).data, '\$$newItemPrice each');

      // Verify onItemsUpdated callback was called with the new item
      expect(currentItems.length, 1);
      expect(currentItems.first.name, newItemName);
      expect(currentItems.first.price, double.parse(newItemPrice));
      expect(currentItems.first.quantity, newItemQuantity);

      // Verify total price is updated
      double expectedTotal = double.parse(newItemPrice) * newItemQuantity;
      final subtotalAmountFinder = find.byKey(const ValueKey('subtotal_amount_expanded'));
      expect(subtotalAmountFinder, findsOneWidget);
      expect(tester.widget<Text>(subtotalAmountFinder).data, '\$${expectedTotal.toStringAsFixed(2)}');
    });
  });

  group('ReceiptReviewScreen - Editing an Existing Item', () {
    testWidgets('Tapping an item card opens EditItemDialog pre-filled with item data', (WidgetTester tester) async {
      // Use the first item from mockInitialItems for this test
      final itemToEdit = mockInitialItems.first;

      await tester.pumpWidget(_boilerplate(initialItems: mockInitialItems));
      await tester.pumpAndSettle();

      // Find the specific ReceiptItemCard for itemToEdit by its name
      final itemCardFinder = find.ancestor(
        of: find.text(itemToEdit.name),
        matching: find.byType(Card), // The InkWell is on the Card
      );
      expect(itemCardFinder, findsOneWidget, reason: 'Should find the card for ${itemToEdit.name}');

      // Tap the item card to trigger the edit dialog
      await tester.tap(itemCardFinder);
      await tester.pumpAndSettle(); // Allow dialog to appear

      // Verify EditItemDialog is open by its title
      expect(find.text('Edit Item'), findsOneWidget);

      // Verify Item Name field is pre-filled
      final nameFieldFinder = find.byKey(const ValueKey('editItemDialog_name_field'));
      expect(nameFieldFinder, findsOneWidget);
      expect(tester.widget<TextField>(nameFieldFinder).controller?.text, itemToEdit.name);

      // Verify Price field is pre-filled
      final priceFieldFinder = find.byKey(const ValueKey('editItemDialog_price_field'));
      expect(priceFieldFinder, findsOneWidget);
      expect(tester.widget<TextField>(priceFieldFinder).controller?.text, itemToEdit.price.toStringAsFixed(2));
      
      // Close the dialog to clean up for the next test
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Saving the dialog updates the corresponding ReceiptItemCard', (WidgetTester tester) async {
      final itemToEdit = mockInitialItems.first;
      final originalName = itemToEdit.name;
      const updatedName = 'Edited Test Item';
      const updatedPriceString = '12.34';
      final updatedPriceDouble = double.parse(updatedPriceString);

      await tester.pumpWidget(_boilerplate(initialItems: mockInitialItems));
      await tester.pumpAndSettle();

      // Tap the item card to open the dialog
      await tester.tap(find.ancestor(of: find.text(originalName), matching: find.byType(Card)));
      await tester.pumpAndSettle();

      // Verify EditItemDialog is open
      expect(find.text('Edit Item'), findsOneWidget);

      // Edit details
      await tester.enterText(find.byKey(const ValueKey('editItemDialog_name_field')), updatedName);
      await tester.enterText(find.byKey(const ValueKey('editItemDialog_price_field')), updatedPriceString);
      await tester.pumpAndSettle();

      // Tap the "Save" button in the dialog
      await tester.tap(find.byKey(const ValueKey('editItemDialog_save_button')));
      await tester.pumpAndSettle(); // Allow dialog to close and UI to update

      // Verify the dialog is closed
      expect(find.text('Edit Item'), findsNothing);

      // Verify the original item card is GONE
      expect(find.text(originalName), findsNothing);

      // Verify the updated item card is present with new details
      final updatedItemCardFinder = find.ancestor(
        of: find.text(updatedName),
        matching: find.byType(ReceiptItemCard),
      );
      expect(updatedItemCardFinder, findsOneWidget);
      
      // Find the price Text widget by its new ValueKey
      final priceTextFinderAfterEdit = find.byKey(ValueKey('receiptItemCard_price_${itemToEdit.itemId}'));
      expect(priceTextFinderAfterEdit, findsOneWidget);
      expect(tester.widget<Text>(priceTextFinderAfterEdit).data, '\$$updatedPriceString each');

      // Also check the total price on the card itself
      final originalQuantity = itemToEdit.quantity;
      final expectedCardTotal = (updatedPriceDouble * originalQuantity).toStringAsFixed(2);
      expect(find.descendant(of: updatedItemCardFinder, matching: find.text('\$$expectedCardTotal')), findsOneWidget, reason: "Card total should update");
    });

    testWidgets('onItemsUpdated callback is triggered with updated item when saving dialog', (WidgetTester tester) async {
      final itemToEdit = mockInitialItems.first;
      final originalName = itemToEdit.name;
      const updatedName = 'Callback Test Item';
      const updatedPriceString = '98.76';
      final updatedPriceDouble = double.parse(updatedPriceString);
      final originalQuantity = itemToEdit.quantity; // Quantity is not changed in EditItemDialog

      List<ReceiptItem>? receivedItems;
      
      await tester.pumpWidget(_boilerplate(
        initialItems: List.from(mockInitialItems), // Use a copy to avoid modifying the original list directly
        onItemsUpdated: (items) {
          receivedItems = items;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.ancestor(of: find.text(originalName), matching: find.byType(Card)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('editItemDialog_name_field')), updatedName);
      await tester.enterText(find.byKey(const ValueKey('editItemDialog_price_field')), updatedPriceString);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('editItemDialog_save_button')));
      await tester.pumpAndSettle();

      expect(receivedItems, isNotNull, reason: 'onItemsUpdated should have been called.');
      expect(receivedItems!.length, mockInitialItems.length, reason: 'Number of items should remain the same.');
      
      final editedItemInCallback = receivedItems!.firstWhere((item) => item.itemId == itemToEdit.itemId);
      
      expect(editedItemInCallback.name, updatedName);
      expect(editedItemInCallback.price, updatedPriceDouble);
      expect(editedItemInCallback.quantity, originalQuantity, reason: 'Quantity should not change during edit via EditItemDialog.');
    });

    testWidgets('Total price is updated after editing an item', (WidgetTester tester) async {
      final initialItemsCopy = mockInitialItems.map((item) => 
        ReceiptItem(itemId: item.itemId, name: item.name, price: item.price, quantity: item.quantity)
      ).toList();
      
      final itemToEdit = initialItemsCopy.first;
      final originalName = itemToEdit.name;
      const updatedName = 'Price Update Item';
      const updatedPriceString = '7.50';
      final updatedPriceDouble = double.parse(updatedPriceString);

      await tester.pumpWidget(_boilerplate(initialItems: initialItemsCopy));
      await tester.pumpAndSettle();

      // Tap the item card to open the dialog
      await tester.tap(find.ancestor(of: find.text(originalName), matching: find.byType(Card)));
      await tester.pumpAndSettle();

      // Edit details (only price matters for this total calculation)
      await tester.enterText(find.byKey(const ValueKey('editItemDialog_name_field')), updatedName);
      await tester.enterText(find.byKey(const ValueKey('editItemDialog_price_field')), updatedPriceString);
      await tester.pumpAndSettle();

      // Tap the "Save" button in the dialog
      await tester.tap(find.byKey(const ValueKey('editItemDialog_save_button')));
      await tester.pumpAndSettle(); 

      // Calculate expected total
      // Create a new list for calculation reflecting the change
      final itemsForCalculation = initialItemsCopy.map((item) {
        if (item.itemId == itemToEdit.itemId) {
          // Return a new ReceiptItem with the updated price and original quantity
          return ReceiptItem(
            itemId: item.itemId, 
            name: updatedName, // Use the updated name for consistency if needed, though not for total
            price: updatedPriceDouble, 
            quantity: item.quantity
          );
        }
        return item;
      }).toList();
      
      double expectedTotal = itemsForCalculation.fold(0, (sum, item) => sum + (item.price * item.quantity));

      final subtotalAmountFinder = find.byKey(const ValueKey('subtotal_amount_expanded'));
      expect(subtotalAmountFinder, findsOneWidget);
      expect(tester.widget<Text>(subtotalAmountFinder).data, '\$${expectedTotal.toStringAsFixed(2)}');
    });
  });
} 