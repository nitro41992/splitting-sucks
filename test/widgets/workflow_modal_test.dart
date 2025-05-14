import 'package:billfie/providers/workflow_state.dart';
import 'package:billfie/widgets/workflow_modal.dart';
import 'package:billfie/widgets/workflow_steps/workflow_step_indicator.dart';
import 'package:billfie/widgets/workflow_steps/workflow_navigation_controls.dart';
import 'package:billfie/services/firestore_service.dart';
import 'package:billfie/models/receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:async';

// Key for the complete button in WorkflowNavigationControls
const completeButtonKey = Key('complete_workflow_button');

// Create a mock for WorkflowState
class MockWorkflowState extends ChangeNotifier implements WorkflowState {
  int _currentStep = 0;
  bool _hasParseData = false;
  bool _hasTranscriptionData = false;
  bool _hasAssignmentData = false;
  String _receiptId = 'test-receipt-id';
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  int get currentStep => _currentStep;
  
  @override
  bool get hasParseData => _hasParseData;
  
  @override
  bool get hasTranscriptionData => _hasTranscriptionData;
  
  @override
  bool get hasAssignmentData => _hasAssignmentData;
  
  @override
  String get restaurantName => 'Mock Restaurant';
  
  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  String? get receiptId => _receiptId;

  @override
  Map<String, dynamic> get parseReceiptResult => {'items': []};

  @override
  Map<String, dynamic> get transcribeAudioResult => {'text': 'test'};

  @override
  Map<String, dynamic> get assignPeopleToItemsResult => 
    {'assignments': [{'item': 'Item 1', 'people': ['Person A']}]};
  
  int? lastCalledStepIndex;
  bool nextStepCalled = false;
  bool previousStepCalled = false;
  
  @override
  void goToStep(int step) {
    if (step >= 0 && step < 5) { // Assuming max 5 steps for mock
      lastCalledStepIndex = step;
      _currentStep = step;
      notifyListeners();
    }
  }
  
  @override
  void nextStep() {
    nextStepCalled = true;
    // Simplified logic for mock, doesn't check max step like real one
    if (_currentStep < 4) { // Let's keep < 4 to align with real WorkflowState
        _currentStep++;
    }
    notifyListeners();
  }

  @override
  void previousStep() {
    previousStepCalled = true;
    if (_currentStep > 0) {
      _currentStep--;
    }
    notifyListeners();
  }
  
  void setCurrentStep(int step) {
    _currentStep = step;
    notifyListeners();
  }
  
  void setHasParseData(bool value) {
    _hasParseData = value;
    notifyListeners();
  }
  
  void setHasTranscriptionData(bool value) {
    _hasTranscriptionData = value;
    notifyListeners();
  }
  
  void setHasAssignmentData(bool value) {
    _hasAssignmentData = value;
    notifyListeners();
  }
  
  void reset() {
    lastCalledStepIndex = null;
    nextStepCalled = false;
    previousStepCalled = false;
    _currentStep = 0;
    _hasParseData = false;
    _hasTranscriptionData = false;
    _hasAssignmentData = false;
    _isLoading = false;
    _errorMessage = null;
  }

  @override
  void setReceiptId(String id) {
    _receiptId = id;
    notifyListeners();
  }

  @override
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void removeUriFromPendingDeletions(String? uri) {}

  @override
  Receipt toReceipt() {
    return Receipt(
      id: _receiptId,
      status: 'draft',
      restaurantName: restaurantName,
    );
  }
  
  // Add stubs for methods used by saveTranscriptionToPrefs if called by WorkflowNavigationControls indirectly
  @override
  Future<void> saveTranscriptionToPrefs() async {}
  @override
  Future<void> loadTranscriptionFromPrefs() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // This will catch any WorkflowState methods not explicitly mocked
    // For tests focusing on WorkflowNavigationControls, most deep WorkflowState logic isn't critical
    // as long as currentStep, hasParseData, etc. are controllable.
    print('Called unmocked method on MockWorkflowState: \${invocation.memberName}');
    if (invocation.memberName == Symbol('tip')) return null;
    if (invocation.memberName == Symbol('tax')) return null;
    if (invocation.memberName == Symbol('setTranscribeAudioResult')) return;
    if (invocation.memberName == Symbol('setTip')) return;
    if (invocation.memberName == Symbol('setTax')) return;

    return super.noSuchMethod(invocation);
  }
}

// Mock FirestoreService implementation with simple tracking
class MockFirestoreService implements FirestoreService {
  bool completeReceiptWasCalled = false;
  String? lastReceiptId;
  Map<String, dynamic>? lastData;

  @override
  Future<String> completeReceipt({
    required String receiptId,
    required Map<String, dynamic> data,
  }) async {
    completeReceiptWasCalled = true;
    lastReceiptId = receiptId;
    lastData = data;
    return receiptId;
  }

  // Create a stub implementation for any other methods
  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError();
  }
}

void main() {
  late MockWorkflowState mockWorkflowStateMainInstance; // Renamed to avoid conflict

  setUp(() {
    mockWorkflowStateMainInstance = MockWorkflowState();
  });

  Widget createStepIndicatorTestWidget({required MockWorkflowState workflowState}) {
    final stepTitles = ['Upload', 'Review', 'Assign', 'Split', 'Summary'];
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            WorkflowStepIndicator(
              currentStep: workflowState.currentStep,
              stepTitles: stepTitles,
            ),
            SizedBox(
              width: 500,
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(stepTitles.length, (index) {
                  return InkWell(
                    key: Key('step_${stepTitles[index]}'),
                    onTap: () {
                      final currentStep = workflowState.currentStep;
                      if (index < currentStep) {
                        workflowState.goToStep(index);
                      } else if (index > currentStep) {
                        bool canNavigate = true;
                        if (index > 0 && !workflowState.hasParseData) {
                          canNavigate = false;
                        }
                        if (canNavigate) {
                          workflowState.goToStep(index);
                        }
                      }
                    },
                    child: Container(
                      width: 60,
                      color: Colors.transparent,
                      child: Center(
                        child: Text(
                          stepTitles[index],
                          key: Key('text_${stepTitles[index]}'),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  group('WorkflowStepIndicator Tests', () {
    testWidgets('Step indicator shows correct number of steps', (WidgetTester tester) async {
      mockWorkflowStateMainInstance.setCurrentStep(0);
      await tester.pumpWidget(createStepIndicatorTestWidget(workflowState: mockWorkflowStateMainInstance));
      expect(find.byKey(const Key('text_Upload')), findsOneWidget);
      expect(find.byKey(const Key('text_Review')), findsOneWidget);
      expect(find.byKey(const Key('text_Assign')), findsOneWidget);
      expect(find.byKey(const Key('text_Split')), findsOneWidget);
      expect(find.byKey(const Key('text_Summary')), findsOneWidget);
    });

    testWidgets('Tapping previous step calls goToStep with correct step index', (WidgetTester tester) async {
      mockWorkflowStateMainInstance.setCurrentStep(2); 
      await tester.pumpWidget(createStepIndicatorTestWidget(workflowState: mockWorkflowStateMainInstance));
      await tester.tap(find.byKey(const Key('step_Upload')));
      await tester.pump();
      expect(mockWorkflowStateMainInstance.lastCalledStepIndex, 0);
    });
    // Add more tests for WorkflowStepIndicator as needed
  }); // CORRECTED: End of WorkflowStepIndicator Tests group

  // Helper to build WorkflowNavigationControls with a WorkflowState for focused testing
  Widget _buildNavControlsTestWidget(
    MockWorkflowState workflowState, {
    Future<void> Function()? onExit,
    Future<void> Function()? onSaveDraft,
    Future<void> Function()? onComplete,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea( // Add SafeArea to avoid layout issues
          child: Column(
            children: [
              Expanded(child: Container()), // Add content for the Scaffold body
              ChangeNotifierProvider<WorkflowState>.value(
                value: workflowState,
                child: WorkflowNavigationControls(
                  onExitAction: onExit ?? () async {},
                  onSaveDraftAction: onSaveDraft ?? () async {},
                  onCompleteAction: onComplete ?? () async {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New group for WorkflowNavigationControls tests
  group('WorkflowNavigationControls Tests (3-step flow context)', () {
    late MockWorkflowState mockWorkflowState; // This instance is for this group

    setUp(() {
      mockWorkflowState = MockWorkflowState();
      // Default setup for a 3-step flow context (Upload 0, Assign 1, Summary 2)
      // WorkflowNavigationControls itself uses logic like currentStep < 4 etc.
      // The tests verify behavior assuming the component correctly handles the *actual* last step.
    });

    testWidgets('On Upload step (0 of 3), Next is visible and enabled if data present, Complete is hidden', (tester) async {
      mockWorkflowState.setCurrentStep(0);
      mockWorkflowState.setHasParseData(true); 

      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState));

      expect(find.byKey(nextButtonKey), findsOneWidget, reason: "Next button should be visible on Upload step.");
      expect(find.byKey(completeButtonKey), findsNothing, reason: "Complete button should be hidden on Upload step.");

      final nextButtonWidget = tester.widget<FilledButton>(find.byKey(nextButtonKey));
      expect(nextButtonWidget.onPressed, isNotNull, reason: "Next button should be enabled on Upload step when hasParseData is true.");
    });

    testWidgets('On Upload step (0 of 3), Next is visible and disabled if data NOT present, Complete is hidden', (tester) async {
      mockWorkflowState.setCurrentStep(0);
      mockWorkflowState.setHasParseData(false);

      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState));

      expect(find.byKey(nextButtonKey), findsOneWidget, reason: "Next button should be visible on Upload step.");
      expect(find.byKey(completeButtonKey), findsNothing, reason: "Complete button should be hidden on Upload step.");

      final nextButtonWidget = tester.widget<FilledButton>(find.byKey(nextButtonKey));
      expect(nextButtonWidget.onPressed, isNull, reason: "Next button should be disabled on Upload step when hasParseData is false.");
    });

    testWidgets('On Assign step (1 of 3), Next is visible and enabled, Complete is hidden', (tester) async {
      mockWorkflowState.setCurrentStep(1); 
      mockWorkflowState.setHasParseData(true); // Prereq to reach step 1

      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState));

      expect(find.byKey(nextButtonKey), findsOneWidget, reason: "Next button should be visible on Assign step.");
      expect(find.byKey(completeButtonKey), findsNothing, reason: "Complete button should be hidden on Assign step.");

      final nextButtonWidget = tester.widget<FilledButton>(find.byKey(nextButtonKey));
      expect(nextButtonWidget.onPressed, isNotNull, reason: "Next button should be enabled on Assign step.");
    });

    testWidgets('On Summary step (2 of 3 - actual last step), Next is hidden, Complete is visible and enabled', (tester) async {
      mockWorkflowState.setCurrentStep(2); 
      mockWorkflowState.setHasParseData(true); 
      mockWorkflowState.setHasAssignmentData(true); 

      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState));

      expect(find.byKey(nextButtonKey), findsNothing, reason: "Next button should be HIDDEN on the actual final Summary step.");
      expect(find.byKey(completeButtonKey), findsOneWidget, reason: "Complete button should be VISIBLE on the actual final Summary step.");

      final completeButtonWidget = tester.widget<FilledButton>(find.byKey(completeButtonKey));
      expect(completeButtonWidget.onPressed, isNotNull, reason: "Complete button should be enabled on the final Summary step if data is valid.");
    });
    
    testWidgets('Back button is enabled on step 1, disabled on step 0', (tester) async {
      mockWorkflowState.setCurrentStep(1);
      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState));
      var backButtonWidget = tester.widget<TextButton>(find.byKey(backButtonKey));
      expect(backButtonWidget.onPressed, isNotNull, reason: "Back button should be enabled on step 1.");

      mockWorkflowState.setCurrentStep(0);
      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState)); 
      backButtonWidget = tester.widget<TextButton>(find.byKey(backButtonKey));
      expect(backButtonWidget.onPressed, isNull, reason: "Back button should be disabled on step 0.");
    });

    // Test for Exit/Save Draft button logic
    // The current WorkflowNavigationControls shows Exit if currentStep < 4, else Save Draft.
    // This means for a 3-step workflow (0, 1, 2), Exit will always be shown.
    // If "Save Draft" is expected on the "Summary" (step 2, the actual final step), this test will highlight the discrepancy.
    testWidgets('Exit button is shown on steps 0, 1, 2 (as currentStep < 4 for these)', (tester) async {
      // Step 0
      mockWorkflowState.setCurrentStep(0);
      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState));
      expect(find.byKey(exitButtonKey), findsOneWidget, reason: "Exit button on step 0.");
      expect(find.byKey(saveDraftButtonKey), findsNothing, reason: "Save Draft button not on step 0.");

      // Step 1
      mockWorkflowState.setCurrentStep(1);
      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState));
      expect(find.byKey(exitButtonKey), findsOneWidget, reason: "Exit button on step 1.");
      expect(find.byKey(saveDraftButtonKey), findsNothing, reason: "Save Draft button not on step 1.");
      
      // Step 2 (Summary)
      mockWorkflowState.setCurrentStep(2);
      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState));
      expect(find.byKey(exitButtonKey), findsOneWidget, reason: "Exit button on step 2 (since 2 < 4).");
      expect(find.byKey(saveDraftButtonKey), findsNothing, reason: "Save Draft button not on step 2 (since 2 < 4).");
    });

    testWidgets('Tapping Next button calls workflowState.nextStep()', (tester) async {
      mockWorkflowState.setCurrentStep(0);
      mockWorkflowState.setHasParseData(true); // Enable Next button
      mockWorkflowState.nextStepCalled = false; // Reset flag

      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState));
      await tester.tap(find.byKey(nextButtonKey));
      await tester.pump();

      expect(mockWorkflowState.nextStepCalled, isTrue, reason: "workflowState.nextStep() should be called.");
    });

    testWidgets('Tapping Back button calls workflowState.previousStep()', (tester) async {
      mockWorkflowState.setCurrentStep(1); // Enable Back button
      mockWorkflowState.previousStepCalled = false; // Reset flag

      await tester.pumpWidget(_buildNavControlsTestWidget(mockWorkflowState));
      await tester.tap(find.byKey(backButtonKey));
      await tester.pump();

      expect(mockWorkflowState.previousStepCalled, isTrue, reason: "workflowState.previousStep() should be called.");
    });

    testWidgets('Tapping Complete button calls onCompleteAction', (tester) async {
      bool onCompleteCalled = false;
      Future<void> testOnCompleteAction() async {
        onCompleteCalled = true;
      }
      mockWorkflowState.setCurrentStep(2); // To show Complete button (assuming fix)
      mockWorkflowState.setHasAssignmentData(true); // Generally needed for completion

      // This test relies on the previous assumption that for step 2 (actual last step),
      // the 'Complete' button is shown. If the component wasn't fixed as such, this test would fail finding the button.
      await tester.pumpWidget(_buildNavControlsTestWidget(
        mockWorkflowState,
        onComplete: testOnCompleteAction,
      ));
      
      // Verify Complete button is actually there before trying to tap
      expect(find.byKey(completeButtonKey), findsOneWidget, reason: "Complete button should be present on final step for this test to be valid.");

      await tester.tap(find.byKey(completeButtonKey));
      await tester.pump();

      expect(onCompleteCalled, isTrue, reason: "onCompleteAction should be called when Complete button is tapped.");
    });
  });

  // TODO: Add tests for the main WorkflowModal logic, e.g. _saveDraft, _loadReceiptData 
} 