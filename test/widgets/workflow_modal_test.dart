import 'package:billfie/providers/workflow_state.dart';
import 'package:billfie/widgets/workflow_modal.dart';
import 'package:billfie/widgets/workflow_steps/workflow_step_indicator.dart';
import 'package:billfie/utils/toast_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';

// Create a mock for WorkflowState
class MockWorkflowState extends Mock implements WorkflowState {
  int _currentStep = 0;
  bool _hasParseData = false;
  bool _hasTranscriptionData = false;
  bool _hasAssignmentData = false;
  
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
  bool get isLoading => false;
  
  // Track if goToStep was called and with what step
  int? lastCalledStepIndex;
  
  @override
  void goToStep(int step) {
    if (step >= 0 && step < 5) {
      lastCalledStepIndex = step;
      _currentStep = step;
      notifyListeners();
    }
  }
  
  // Helper methods for test setup
  void setCurrentStep(int step) {
    _currentStep = step;
  }
  
  void setHasParseData(bool value) {
    _hasParseData = value;
  }
  
  void setHasTranscriptionData(bool value) {
    _hasTranscriptionData = value;
  }
  
  void setHasAssignmentData(bool value) {
    _hasAssignmentData = value;
  }
  
  void reset() {
    lastCalledStepIndex = null;
  }
}

void main() {
  late MockWorkflowState mockWorkflowState;

  setUp(() {
    mockWorkflowState = MockWorkflowState();
  });

  // Create a simpler test widget that just tests the step indicator tapping logic
  Widget createStepIndicatorTestWidget({required MockWorkflowState workflowState}) {
    final stepTitles = ['Upload', 'Review', 'Assign', 'Split', 'Summary'];
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // The step indicator widget
            WorkflowStepIndicator(
              currentStep: workflowState.currentStep,
              stepTitles: stepTitles,
            ),
            // GestureDetector that simulates step indicator tap logic
            SizedBox(
              width: 500, // Fixed width for testing
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(stepTitles.length, (index) {
                  return GestureDetector(
                    key: Key('step_${stepTitles[index]}'),
                    onTap: () {
                      final currentStep = workflowState.currentStep;
                      
                      // Logic similar to WorkflowModalBody
                      if (index < currentStep) {
                        // Navigate backward
                        workflowState.goToStep(index);
                      } else if (index > currentStep) {
                        // Navigate forward with prerequisite checks
                        bool canNavigate = true;
                        
                        // Check prerequisites
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
      mockWorkflowState.setCurrentStep(0);
      
      await tester.pumpWidget(createStepIndicatorTestWidget(workflowState: mockWorkflowState));

      // Check for our keyed step widgets
      expect(find.byKey(const Key('text_Upload')), findsOneWidget);
      expect(find.byKey(const Key('text_Review')), findsOneWidget);
      expect(find.byKey(const Key('text_Assign')), findsOneWidget);
      expect(find.byKey(const Key('text_Split')), findsOneWidget);
      expect(find.byKey(const Key('text_Summary')), findsOneWidget);
    });

    testWidgets('Tapping previous step calls goToStep with correct step index', (WidgetTester tester) async {
      // Setup for current step at Assign (2)
      mockWorkflowState.setCurrentStep(2); 
      
      await tester.pumpWidget(createStepIndicatorTestWidget(workflowState: mockWorkflowState));
      
      // Find and tap on the Upload (0) step
      await tester.tap(find.byKey(const Key('step_Upload')));
      await tester.pump();

      // Verify goToStep was called with step index 0
      expect(mockWorkflowState.lastCalledStepIndex, 0);
    });
    
    testWidgets('Tapping future step with prerequisites met calls goToStep', (WidgetTester tester) async {
      // Setup for current step at Review (1) with prerequisites for next step
      mockWorkflowState.setCurrentStep(1);
      mockWorkflowState.setHasParseData(true);
      
      await tester.pumpWidget(createStepIndicatorTestWidget(workflowState: mockWorkflowState));
      
      // Find and tap on the Assign (2) step
      await tester.tap(find.byKey(const Key('step_Assign')));
      await tester.pump();

      // Verify goToStep was called with step index 2
      expect(mockWorkflowState.lastCalledStepIndex, 2);
    });
    
    testWidgets('Tapping future step without prerequisites does not call goToStep', (WidgetTester tester) async {
      // Setup for current step at Upload (0) without prerequisites for next step
      mockWorkflowState.setCurrentStep(0);
      mockWorkflowState.setHasParseData(false);
      mockWorkflowState.reset(); // Clear any previous call tracking
      
      await tester.pumpWidget(createStepIndicatorTestWidget(workflowState: mockWorkflowState));
      
      // Find and tap on the Review (1) step
      await tester.tap(find.byKey(const Key('step_Review')));
      await tester.pump();

      // Verify goToStep was NOT called (lastCalledStepIndex is null)
      expect(mockWorkflowState.lastCalledStepIndex, isNull);
    });
  });
} 