import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:billfie/providers/workflow_state.dart';
import 'package:billfie/widgets/workflow_steps/workflow_navigation_controls.dart';

class MockCallbackTracker {
  bool completeActionCalled = false;
  bool exitActionCalled = false;
  bool saveDraftActionCalled = false;
  
  Future<void> completeAction() async {
    completeActionCalled = true;
  }
  
  Future<void> exitAction() async {
    exitActionCalled = true;
  }
  
  Future<void> saveDraftAction() async {
    saveDraftActionCalled = true;
  }
}

void main() {
  group('Workflow Navigation', () {
    late MockCallbackTracker tracker;
    late WorkflowState workflowState;

    setUp(() {
      tracker = MockCallbackTracker();
      workflowState = WorkflowState(restaurantName: 'Test Restaurant');
      workflowState.goToStep(2); // Set to Summary step to show Complete button (step 2 in 3-step workflow)
    });

    testWidgets('Complete button action calls the complete callback', (WidgetTester tester) async {
      // Create a test app with navigation controls
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<WorkflowState>.value(
              value: workflowState,
              child: WorkflowNavigationControls(
                onCompleteAction: tracker.completeAction,
                onExitAction: tracker.exitAction,
                onSaveDraftAction: tracker.saveDraftAction,
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();

      // Find and press the complete button
      final completeButtonFinder = find.byKey(completeButtonKey);
      expect(completeButtonFinder, findsOneWidget);
      await tester.tap(completeButtonFinder);
      await tester.pumpAndSettle();

      // Verify the complete action callback was called
      expect(tracker.completeActionCalled, isTrue);
      expect(tracker.exitActionCalled, isFalse);
      expect(tracker.saveDraftActionCalled, isFalse);
    });
  });
} 