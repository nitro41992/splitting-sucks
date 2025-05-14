import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:billfie/providers/workflow_state.dart';
import 'package:billfie/widgets/workflow_steps/workflow_navigation_controls.dart';
import '../../test_helpers/firebase_mock_setup.dart';

class MockCallbackTracker {
  bool completeActionCalled = false;
  bool saveActionCalled = false;
  
  Future<void> completeAction() async {
    completeActionCalled = true;
    return Future.value();
  }
  
  Future<void> saveAction() async {
    saveActionCalled = true;
    return Future.value();
  }
}

void main() {
  // Setup Firebase mocks
  setUpAll(() async {
    await setupFirebaseForTesting();
  });
  
  group('Workflow Navigation', () {
    late MockCallbackTracker tracker;
    late WorkflowState workflowState;

    setUp(() {
      tracker = MockCallbackTracker();
      workflowState = WorkflowState(restaurantName: 'Test Restaurant');
      
      // Configure workflow state with test data to enable buttons
      workflowState.setParseReceiptResult({
        'items': [
          {'name': 'Test Item', 'price': 10.0, 'quantity': 1}
        ],
        'subtotal': 10.0
      });
      
      workflowState.setAssignPeopleToItemsResult({
        'assignments': [
          {'person_name': 'Test Person', 'items': [{'name': 'Test Item', 'price': 10.0, 'quantity': 1}]}
        ],
        'shared_items': [],
        'unassigned_items': []
      });
      
      // hasParseData and hasAssignmentData are calculated properties, no need to set them
    });

    testWidgets('Save button action calls the save callback', (WidgetTester tester) async {
      // Set current step to 0 (first step)
      workflowState.goToStep(0);
      
      // Create a test app with navigation controls
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<WorkflowState>.value(
              value: workflowState,
              child: WorkflowNavigationControls(
                onCompleteAction: tracker.completeAction,
                onSaveAction: tracker.saveAction,
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();

      // Find and press the save button
      final saveButtonFinder = find.byKey(saveButtonKey);
      expect(saveButtonFinder, findsOneWidget);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // Verify the save action callback was called
      expect(tracker.saveActionCalled, isTrue);
      expect(tracker.completeActionCalled, isFalse);
    });
    
    testWidgets('Save button action on summary step calls the complete action', (WidgetTester tester) async {
      // Set current step to 2 (summary step in 3-step workflow)
      workflowState.goToStep(2);
      
      // Create a test app with navigation controls
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<WorkflowState>.value(
              value: workflowState,
              child: WorkflowNavigationControls(
                onCompleteAction: tracker.completeAction,
                onSaveAction: tracker.saveAction,
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();

      // Find and press the save button
      final saveButtonFinder = find.byKey(saveButtonKey);
      expect(saveButtonFinder, findsOneWidget);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      // Verify the complete action callback was called
      expect(tracker.completeActionCalled, isTrue);
      expect(tracker.saveActionCalled, isFalse);
    });
  });
} 