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
} 