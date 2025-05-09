import 'package:billfie/providers/workflow_state.dart';
import 'package:flutter_test/flutter_test.dart';
import '../mocks.mocks.dart'; // Import the generated mocks

void main() {
  group('WorkflowState', () {
    late WorkflowState workflowState;
    late MockImageStateManager mockImageStateManager;
    bool listenerCalled = false;

    setUp(() {
      mockImageStateManager = MockImageStateManager();
      workflowState = WorkflowState(
        restaurantName: 'Test Restaurant',
        imageStateManager: mockImageStateManager,
      );
      listenerCalled = false; // Reset before each test
      workflowState.addListener(() {
        listenerCalled = true;
      });
    });

    tearDown(() {
      workflowState.removeListener(() {
        listenerCalled = true; // Technically, the listener itself doesn't need to be removed with this exact signature, but good practice.
      });
    });

    test('initial state is correct', () {
      expect(workflowState.currentStep, 0);
      expect(workflowState.receiptId, isNull);
      expect(workflowState.restaurantName, 'Test Restaurant');
      expect(workflowState.imageStateManager, mockImageStateManager);
      expect(workflowState.parseReceiptResult, isEmpty);
      expect(workflowState.transcribeAudioResult, isEmpty);
      expect(workflowState.assignPeopleToItemsResult, isEmpty);
      expect(workflowState.tip, isNull);
      expect(workflowState.tax, isNull);
      expect(workflowState.people, isEmpty);
      expect(workflowState.isLoading, isFalse);
      expect(workflowState.errorMessage, isNull);
      expect(workflowState.hasParseData, isFalse);
      expect(workflowState.hasTranscriptionData, isFalse);
      expect(workflowState.hasAssignmentData, isFalse);
    });

    group('nextStep', () {
      test('correctly increments _currentStep and calls notifyListeners', () {
        expect(workflowState.currentStep, 0);
        workflowState.nextStep();
        expect(workflowState.currentStep, 1);
        expect(listenerCalled, isTrue);
      });

      test('does not increment beyond the maximum step count (4) and calls notifyListeners', () {
        workflowState.goToStep(4); // Go to last step
        listenerCalled = false; // Reset after goToStep call
        expect(workflowState.currentStep, 4);
        
        workflowState.nextStep(); // Try to go beyond
        expect(workflowState.currentStep, 4); // Should remain at 4
        expect(listenerCalled, isFalse); // Should not call listeners if state doesn't change (as per current nextStep impl)
      });
    });

    group('previousStep', () {
      test('correctly decrements _currentStep and calls notifyListeners', () {
        workflowState.goToStep(1); // Go to step 1
        listenerCalled = false; // Reset after goToStep call
        expect(workflowState.currentStep, 1);

        workflowState.previousStep();
        expect(workflowState.currentStep, 0);
        expect(listenerCalled, isTrue);
      });

      test('does not decrement below 0 and calls notifyListeners', () {
        expect(workflowState.currentStep, 0); // Already at step 0
        listenerCalled = false;
        
        workflowState.previousStep(); // Try to go below
        expect(workflowState.currentStep, 0); // Should remain at 0
        expect(listenerCalled, isFalse); // Should not call listeners if state doesn't change (as per current previousStep impl)
      });
    });

    group('goToStep', () {
      test('correctly sets _currentStep to a valid step and calls notifyListeners', () {
        workflowState.goToStep(2);
        expect(workflowState.currentStep, 2);
        expect(listenerCalled, isTrue);
      });

      test('ignores invalid step values (negative) and does not call notifyListeners', () {
        workflowState.goToStep(-1);
        expect(workflowState.currentStep, 0); // Should remain at initial/previous valid step
        expect(listenerCalled, isFalse);
      });

      test('ignores invalid step values (too high) and does not call notifyListeners', () {
        workflowState.goToStep(5); // Max step is 4 (0-4 for 5 steps)
        expect(workflowState.currentStep, 0); // Should remain at initial/previous valid step
        expect(listenerCalled, isFalse);
      });

      test('does NOT call notifyListeners if setting to the same step', (){
        expect(workflowState.currentStep, 0);
        listenerCalled = false; // Reset listener flag
        
        workflowState.goToStep(0); // Attempt to go to the same step
        
        expect(workflowState.currentStep, 0); // Step should remain the same
        expect(listenerCalled, isFalse); // Expect NOT to be notified
      });
    });
    
    // TODO: Add more test groups for other methods as outlined in test_coverage.md
    // - setRestaurantName()
    // - setReceiptId()
    // - setImageFile()
    // - resetImageFile()
    // - setParseReceiptResult()
    // - setTranscribeAudioResult()
    // - setAssignPeopleToItemsResult()
    // - setTip(), setTax()
    // - setLoading(), setErrorMessage()
    // - setUploadedGsUris(), setLoadedImageUrls(), setActualGsUrisOnLoad() (delegation to ImageStateManager)
    // - clearPendingDeletions(), removeUriFromPendingDeletions(), addUriToPendingDeletions() (delegation to ImageStateManager)
    // - toReceipt()
    // - _extractPeopleFromAssignments()
    // - hasParseData, hasTranscriptionData, hasAssignmentData flags
    // - clearParseAndSubsequentData()
    // - clearTranscriptionAndSubsequentData()
    // - clearAssignmentAndSubsequentData()

  });
} 