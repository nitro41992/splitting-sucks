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
  });
} 