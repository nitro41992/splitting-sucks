import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:billfie/models/person.dart';
import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/models/split_manager.dart';
import 'package:billfie/widgets/workflow_steps/summary_step_widget.dart';
import 'package:billfie/screens/final_summary_screen.dart';
import 'package:billfie/providers/workflow_state.dart';
import '../../test_helpers/firebase_mock_setup.dart';
import '../../mocks.mocks.dart';

void main() {
  // Enable Firebase mock for tests
  setUp(() {
    // No need to set isTestEnvironment as it's already a getter that returns true
  });

  tearDown(() {
    // No need to reset isTestEnvironment
  });

  // Helper function to build the SummaryStepWidget with necessary providers
  Widget buildTestWidget({
    required Map<String, dynamic> parseResult,
    required Map<String, dynamic> assignResultMap,
    double? currentTip,
    double? currentTax,
  }) {
    final mockWorkflowState = MockWorkflowState();
    
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkflowState>.value(
            value: mockWorkflowState,
          ),
        ],
        child: Material(
          child: SummaryStepWidget(
            parseResult: parseResult,
            assignResultMap: assignResultMap,
            currentTip: currentTip,
            currentTax: currentTax,
          ),
        ),
      ),
    );
  }

  // Sample data for testing
  final sampleParseResult = {
    'subtotal': 100.0,
    'tax': 8.0,
    'tip': 15.0,
    'items': [
      {'name': 'Burger', 'price': 15.0, 'quantity': 2},
      {'name': 'Fries', 'price': 5.0, 'quantity': 3},
      {'name': 'Drink', 'price': 3.0, 'quantity': 4},
      {'name': 'Dessert', 'price': 8.0, 'quantity': 1},
    ],
  };

  final sampleAssignResultMap = {
    'assignments': [
      {
        'person_name': 'Alice',
        'items': [
          {'name': 'Burger', 'price': 15.0, 'quantity': 1},
          {'name': 'Fries', 'price': 5.0, 'quantity': 1},
          {'name': 'Drink', 'price': 3.0, 'quantity': 1},
        ],
      },
      {
        'person_name': 'Bob',
        'items': [
          {'name': 'Burger', 'price': 15.0, 'quantity': 1},
          {'name': 'Fries', 'price': 5.0, 'quantity': 1},
          {'name': 'Drink', 'price': 3.0, 'quantity': 2},
        ],
      },
    ],
    'shared_items': [
      {
        'name': 'Fries',
        'price': 5.0,
        'quantity': 1,
        'people': ['Alice', 'Bob'],
      },
    ],
    'unassigned_items': [
      {
        'name': 'Dessert',
        'price': 8.0,
        'quantity': 1,
      },
    ],
  };

  group('SummaryStepWidget', () {
    testWidgets('renders FinalSummaryScreen with SplitManager', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        parseResult: sampleParseResult,
        assignResultMap: sampleAssignResultMap,
        currentTip: 15.0,
        currentTax: 8.0,
      ));
      
      await tester.pumpAndSettle();
      
      // Verify that FinalSummaryScreen is rendered
      expect(find.byType(FinalSummaryScreen), findsOneWidget);
      
      // Verify SplitManager is provided (use Provider.of to get the instance)
      final BuildContext context = tester.element(find.byType(FinalSummaryScreen));
      final splitManager = Provider.of<SplitManager>(context, listen: false);
      
      expect(splitManager, isNotNull);
    });

    testWidgets('correctly initializes SplitManager with people and items', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        parseResult: sampleParseResult,
        assignResultMap: sampleAssignResultMap,
        currentTip: 15.0,
        currentTax: 8.0,
      ));
      
      await tester.pumpAndSettle();
      
      // Get SplitManager using Provider.of
      final BuildContext context = tester.element(find.byType(FinalSummaryScreen));
      final splitManager = Provider.of<SplitManager>(context, listen: false);
      
      // Verify people are correctly initialized
      expect(splitManager.people.length, 2);
      expect(splitManager.people.map((p) => p.name).toList(), ['Alice', 'Bob']);
      
      // Verify shared items are correctly initialized
      expect(splitManager.sharedItems.length, 1);
      expect(splitManager.sharedItems.first.name, 'Fries');
      
      // Verify unassigned items are correctly initialized
      expect(splitManager.unassignedItems.length, 1);
      expect(splitManager.unassignedItems.first.name, 'Dessert');
      
      // Verify tax and tip percentages
      expect(splitManager.taxPercentage, 8.0);
      expect(splitManager.tipPercentage, 15.0);
      
      // Verify original review total
      expect(splitManager.originalReviewTotal, 100.0);
    });

    testWidgets('shows warning when subtotal mismatch is detected', (WidgetTester tester) async {
      // Original subtotal is 100.0, but items sum to different amount to trigger warning
      final modifiedParseResult = Map<String, dynamic>.from(sampleParseResult);
      modifiedParseResult['subtotal'] = 120.0; // Different from items total to trigger warning
      
      await tester.pumpWidget(buildTestWidget(
        parseResult: modifiedParseResult,
        assignResultMap: sampleAssignResultMap,
        currentTip: 15.0,
        currentTax: 8.0,
      ));
      
      await tester.pumpAndSettle();
      
      // Look for warning message
      expect(find.textContaining('Warning:'), findsOneWidget);
    });

    testWidgets('displays correct individual totals for each person', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        parseResult: sampleParseResult,
        assignResultMap: sampleAssignResultMap,
        currentTip: 15.0,
        currentTax: 8.0,
      ));
      
      await tester.pumpAndSettle();
      
      // Verify Alice's total is displayed
      expect(find.textContaining('Alice'), findsAtLeastNWidgets(1));
      
      // Verify Bob's total is displayed
      expect(find.textContaining('Bob'), findsAtLeastNWidgets(1));
      
      // Verify unassigned items section
      expect(find.textContaining('Unclaimed'), findsOneWidget);
      expect(find.textContaining('Dessert'), findsOneWidget);
    });

    testWidgets('shows tax and tip adjustment controls', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        parseResult: sampleParseResult,
        assignResultMap: sampleAssignResultMap,
        currentTip: 15.0,
        currentTax: 8.0,
      ));
      
      await tester.pumpAndSettle();
      
      // Look for tax and tip adjustment UI elements
      expect(find.textContaining('Tip'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Tax'), findsAtLeastNWidgets(1));
    });

    testWidgets('handles edge case with no assigned items properly', (WidgetTester tester) async {
      // Create an empty assignment result map
      final emptyAssignmentMap = {
        'assignments': [],
        'shared_items': [],
        'unassigned_items': [
          {'name': 'Burger', 'price': 15.0, 'quantity': 2},
          {'name': 'Fries', 'price': 5.0, 'quantity': 3},
        ],
      };
      
      await tester.pumpWidget(buildTestWidget(
        parseResult: sampleParseResult,
        assignResultMap: emptyAssignmentMap,
        currentTip: 15.0,
        currentTax: 8.0,
      ));
      
      await tester.pumpAndSettle();
      
      // Verify that a proper message is shown for no assignments
      expect(find.textContaining('Unclaimed'), findsOneWidget);
      expect(find.textContaining('Burger'), findsOneWidget);
      expect(find.textContaining('Fries'), findsOneWidget);
    });

    testWidgets('handles edge case with only shared items properly', (WidgetTester tester) async {
      // Create an assignment result with only shared items
      final sharedOnlyAssignmentMap = {
        'assignments': [
          {'person_name': 'Alice', 'items': []},
          {'person_name': 'Bob', 'items': []},
        ],
        'shared_items': [
          {
            'name': 'Pizza',
            'price': 20.0,
            'quantity': 1,
            'people': ['Alice', 'Bob'],
          },
        ],
        'unassigned_items': [],
      };
      
      await tester.pumpWidget(buildTestWidget(
        parseResult: {'subtotal': 20.0, 'items': []},
        assignResultMap: sharedOnlyAssignmentMap,
        currentTip: 15.0,
        currentTax: 8.0,
      ));
      
      await tester.pumpAndSettle();
      
      // Verify both Alice and Bob are shown with equal shares
      expect(find.textContaining('Alice'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Bob'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Pizza'), findsOneWidget);
    });
    
    // Add test for the SummaryStepWidget's calculation accuracy
    testWidgets('calculates correct totals including tax and tip', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(
        parseResult: sampleParseResult,
        assignResultMap: sampleAssignResultMap,
        currentTip: 15.0,
        currentTax: 8.0,
      ));
      
      await tester.pumpAndSettle();
      
      // Get SplitManager using Provider.of
      final BuildContext context = tester.element(find.byType(FinalSummaryScreen));
      final splitManager = Provider.of<SplitManager>(context, listen: false);
      
      // Calculate expected totals
      final double subtotal = splitManager.totalAmount;
      final double tax = subtotal * (splitManager.taxPercentage! / 100.0);
      final double tip = subtotal * (splitManager.tipPercentage! / 100.0);
      final double grandTotal = subtotal + tax + tip;
      
      // Verify the grand total is displayed
      expect(find.textContaining(grandTotal.toStringAsFixed(2)), findsAtLeastNWidgets(1));
    });
  });
} 