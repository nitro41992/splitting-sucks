import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/models/person.dart';
import 'package:billfie/models/split_manager.dart';
import 'package:billfie/widgets/cards/shared_item_card.dart';

// Mocks

// Since SplitManager extends ChangeNotifier, our mock needs to handle that.
// Mockito's Mock class should be sufficient if SplitManager's interface is clear.
class MockSplitManager extends Mock implements SplitManager {}

// We'll use real Person objects because managing their internal lists (like sharedItems)
// with Mockito stubs can be more complex than direct manipulation for this test.

void main() {
  late MockSplitManager mockSplitManager;
  late ReceiptItem sharedItemNachos;
  late Person personAlice;
  late Person personBob;
  late Person personCarol;

  setUp(() {
    mockSplitManager = MockSplitManager();
    
    sharedItemNachos = ReceiptItem(itemId: 'nachos_id_001', name: 'Nachos', price: 12.0, quantity: 1);
    
    // Initialize real Person objects
    personAlice = Person(name: 'Alice');
    personBob = Person(name: 'Bob');
    personCarol = Person(name: 'Carol');

    // Alice and Bob share the 'Nachos' item. Carol does not.
    // The Person model's addSharedItem method updates its internal list and calls notifyListeners.
    personAlice.addSharedItem(ReceiptItem.clone(sharedItemNachos)); // Use clone to ensure distinct instances if necessary
    personBob.addSharedItem(ReceiptItem.clone(sharedItemNachos));
    // personCarol.sharedItems remains empty or without 'nachos_id_001'

    final List<Person> peopleList = [personAlice, personBob, personCarol];

    // Stub the 'people' getter on MockSplitManager.
    // SharedItemCard uses context.select((SplitManager sm) => sm.people),
    // so the mock must correctly provide this list.
    when(mockSplitManager.people).thenReturn(peopleList);

    // If SharedItemCard calls other methods on SplitManager during build or interaction,
    // those might need stubbing too (e.g., getPeopleForSharedItem, updateItemQuantity, etc.)
    // For initial render and chip selection state, 'people' and 'person.sharedItems' are key.
  });

  Widget buildTestableWidget(ReceiptItem itemToDisplayInCard) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<SplitManager>.value( // Use ChangeNotifierProvider if SplitManager is a ChangeNotifier
          value: mockSplitManager,
          child: SharedItemCard(item: itemToDisplayInCard),
        ),
      ),
    );
  }

  testWidgets('SharedItemCard FilterChips correctly reflect item sharing status for each person', (tester) async {
    await tester.pumpWidget(buildTestableWidget(sharedItemNachos));
    
    // It might take a frame for context.select to update based on initial provider values.
    // Or for any internal state in SharedItemCard to settle if it reacts to SplitManager.
    await tester.pumpAndSettle(); 

    // Verify Alice's chip for Nachos
    final aliceChipFinder = find.widgetWithText(FilterChip, 'Alice');
    expect(aliceChipFinder, findsOneWidget, reason: "Alice's chip should be present.");
    final aliceChip = tester.widget<FilterChip>(aliceChipFinder);
    expect(aliceChip.selected, isTrue, reason: "Alice's chip should be selected as she shares 'Nachos'.");

    // Verify Bob's chip for Nachos
    final bobChipFinder = find.widgetWithText(FilterChip, 'Bob');
    expect(bobChipFinder, findsOneWidget, reason: "Bob's chip should be present.");
    final bobChip = tester.widget<FilterChip>(bobChipFinder);
    expect(bobChip.selected, isTrue, reason: "Bob's chip should be selected as he shares 'Nachos'.");

    // Verify Carol's chip for Nachos
    final carolChipFinder = find.widgetWithText(FilterChip, 'Carol');
    expect(carolChipFinder, findsOneWidget, reason: "Carol's chip should be present.");
    final carolChip = tester.widget<FilterChip>(carolChipFinder);
    expect(carolChip.selected, isFalse, reason: "Carol's chip should NOT be selected as she does not share 'Nachos'.");
  });
  
  // Consider adding tests for:
  // - Tapping a chip calls the correct SplitManager add/remove methods.
  // - What happens if a person is added/removed from SplitManager.people dynamically.
  // - UI when people list is empty (already handled by SharedItemCard's own check).
} 