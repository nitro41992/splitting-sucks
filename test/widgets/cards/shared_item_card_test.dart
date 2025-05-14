import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/models/person.dart';
import 'package:billfie/models/split_manager.dart';
import 'package:billfie/widgets/cards/shared_item_card.dart';

// Create a more complete mock implementation
class MockSplitManager extends Mock implements SplitManager {
  final List<Person> _people = [];
  
  @override
  List<Person> get people => _people;
  
  void addMockPerson(Person person) {
    _people.add(person);
  }
  
  @override
  List<Person> getPeopleForSharedItem(ReceiptItem item) {
    return _people.where((p) => p.sharedItems.any((si) => si.itemId == item.itemId)).toList();
  }
  
  @override
  void addPersonToSharedItem(ReceiptItem item, Person person, {bool notify = true}) {
    // Implementation for tests
  }
  
  @override
  void removePersonFromSharedItem(ReceiptItem item, Person person, {bool notify = true}) {
    // Implementation for tests
  }
  
  @override
  void removeItemFromShared(ReceiptItem item) {
    // Implementation for tests
  }
  
  @override
  void addUnassignedItem(ReceiptItem item) {
    // Implementation for tests
  }
  
  @override
  void updateItemQuantity(ReceiptItem item, int newQuantity) {
    // Implementation for tests
  }
}

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

    // Add people to the mock manager
    mockSplitManager.addMockPerson(personAlice);
    mockSplitManager.addMockPerson(personBob);
    mockSplitManager.addMockPerson(personCarol);
  });

  Widget buildTestableWidget(ReceiptItem itemToDisplayInCard) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<SplitManager>.value(
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