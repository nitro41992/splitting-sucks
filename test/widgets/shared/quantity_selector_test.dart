import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/models/split_manager.dart';
import 'package:billfie/theme/app_colors.dart';
import 'package:billfie/widgets/shared/quantity_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

// Import generated mocks
import '../../mocks.mocks.dart'; // Assuming mocks.dart is in test/ and this is in test/widgets/shared/

void main() {
  late MockSplitManager mockSplitManager;
  late ReceiptItem testItem;

  setUp(() {
    mockSplitManager = MockSplitManager();
    // Default stub for getAvailableQuantity, can be overridden in specific tests
    when(mockSplitManager.getAvailableQuantity(any)).thenReturn(100); // Assume large available qty by default
  });

  // Helper function to pump the QuantitySelector widget
  Future<void> _pumpWidget(
    WidgetTester tester, {
    required ReceiptItem item,
    required Function(int) onChanged,
    bool allowIncreaseBeyondOriginal = false,
    bool isAssigned = false,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SplitManager>.value(
        value: mockSplitManager,
        child: MaterialApp(
          home: Scaffold( // Scaffold is needed for SnackBar testing
            body: QuantitySelector(
              item: item,
              onChanged: onChanged,
              allowIncreaseBeyondOriginal: allowIncreaseBeyondOriginal,
              isAssigned: isAssigned,
            ),
          ),
        ),
      ),
    );
  }

  group('QuantitySelector Tests', () {
    group('Initial Rendering & State', () {
      testWidgets('renders correctly with initial quantity and buttons', (WidgetTester tester) async {
        testItem = ReceiptItem(itemId: '1', name: 'Test Item', price: 10.0, quantity: 2);
        int changedQuantity = 0;

        await _pumpWidget(
          tester,
          item: testItem,
          onChanged: (qty) => changedQuantity = qty,
        );

        expect(find.text('2'), findsOneWidget); // Check initial quantity display
        expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
        
        // Check decrease button is enabled (color)
        final decreaseInkWell = tester.widget<InkWell>(find.ancestor(
          of: find.byIcon(Icons.remove_circle_outline),
          matching: find.byType(InkWell),
        ).first);
        final decreaseButtonContainer = decreaseInkWell.child as Container;
        expect(decreaseButtonContainer.decoration, isA<BoxDecoration>());
        expect((decreaseButtonContainer.decoration as BoxDecoration).color, AppColors.puce);

        // Check increase button is enabled (color) - assuming available quantity > current
        when(mockSplitManager.getAvailableQuantity(testItem)).thenReturn(testItem.originalQuantity);
        await tester.pump();

        final increaseInkWellEnabled = tester.widget<InkWell>(find.ancestor(
          of: find.byIcon(Icons.add_circle_outline),
          matching: find.byType(InkWell),
        ).first); // .first because it's the direct InkWell parent of the Container
        final increaseButtonContainerEnabled = increaseInkWellEnabled.child as Container;
        expect(increaseButtonContainerEnabled.decoration, isA<BoxDecoration>());
        expect((increaseButtonContainerEnabled.decoration as BoxDecoration).color, AppColors.puce);
      });

      testWidgets('decrease button is disabled and styled correctly when quantity is 0', (WidgetTester tester) async {
        testItem = ReceiptItem(itemId: '1', name: 'Test Item', price: 10.0, quantity: 0);
        await _pumpWidget(
          tester,
          item: testItem,
          onChanged: (_) {},
        );

        expect(find.text('0'), findsOneWidget);
        
        // Check decrease button is disabled (Container color and Icon color)
        final decreaseInkWellDisabled = tester.widget<InkWell>(find.ancestor(
          of: find.byIcon(Icons.remove_circle_outline),
          matching: find.byType(InkWell),
        ).first);
        final decreaseButtonContainerDisabled = decreaseInkWellDisabled.child as Container;
        expect((decreaseButtonContainerDisabled.decoration as BoxDecoration).color, Colors.transparent);

        final decreaseIcon = tester.widget<Icon>(find.byIcon(Icons.remove_circle_outline));
        expect(decreaseIcon.color, Theme.of(tester.element(find.text('0'))).colorScheme.onSurfaceVariant.withOpacity(0.38));
        
        // Check InkWell onTap is null for disabled decrease button
        final decreaseInkWell = tester.widget<InkWell>(find.ancestor(
            of: find.byIcon(Icons.remove_circle_outline),
            matching: find.byType(InkWell)
        ).first);
        expect(decreaseInkWell.onTap, isNull);
      });

      testWidgets('increase button is disabled and styled correctly when not allowIncreaseBeyondOriginal and quantity equals available', (WidgetTester tester) async {
        testItem = ReceiptItem(itemId: '1', name: 'Test Item', price: 10.0, quantity: 2);
        // Ensure originalQuantity is set correctly in the test item for this scenario
        // The factory constructor sets originalQuantity = quantity.
        // So, for item.quantity (2) to equal available (2) and original (2), this is fine.
        when(mockSplitManager.getAvailableQuantity(testItem)).thenReturn(2); // Available is same as current & original

        await _pumpWidget(
          tester,
          item: testItem,
          onChanged: (_) {},
          allowIncreaseBeyondOriginal: false,
        );

        expect(find.text('2'), findsOneWidget);

        final increaseInkWellDisabled = tester.widget<InkWell>(find.ancestor(
          of: find.byIcon(Icons.add_circle_outline),
          matching: find.byType(InkWell),
        ).first);
        final increaseButtonContainerDisabled = increaseInkWellDisabled.child as Container;
        expect((increaseButtonContainerDisabled.decoration as BoxDecoration).color, Colors.transparent);
        
        final increaseIcon = tester.widget<Icon>(find.byIcon(Icons.add_circle_outline));
        expect(increaseIcon.color, Theme.of(tester.element(find.text('2'))).colorScheme.onSurfaceVariant.withOpacity(0.38));
      });

       testWidgets('increase button is disabled and styled correctly when isAssigned is true', (WidgetTester tester) async {
        testItem = ReceiptItem(itemId: '1', name: 'Test Item', price: 10.0, quantity: 1);
        when(mockSplitManager.getAvailableQuantity(testItem)).thenReturn(5); // Available is more, but should be disabled due to isAssigned

        await _pumpWidget(
          tester,
          item: testItem,
          onChanged: (_) {},
          isAssigned: true, // Key condition
        );

        expect(find.text('1'), findsOneWidget);

        final increaseInkWellAssigned = tester.widget<InkWell>(find.ancestor(
          of: find.byIcon(Icons.add_circle_outline),
          matching: find.byType(InkWell),
        ).first);
        final increaseButtonContainerAssigned = increaseInkWellAssigned.child as Container;
        expect((increaseButtonContainerAssigned.decoration as BoxDecoration).color, Colors.transparent);
        
        final increaseIcon = tester.widget<Icon>(find.byIcon(Icons.add_circle_outline));
        expect(increaseIcon.color, Theme.of(tester.element(find.text('1'))).colorScheme.onSurfaceVariant.withOpacity(0.38));
      });
    });

    // Add more test groups here for:
    // - Decrease Button Interaction
    // - Increase Button Interaction (when isAssigned is false)
    //   - allowIncreaseBeyondOriginal = true
    //   - allowIncreaseBeyondOriginal = false (with available > current, and available <= current)
    // - Increase Button Interaction (when isAssigned is true)
    // - Quantity Display Tap Interaction (when isAssigned is true)
  });
} 