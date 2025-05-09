import 'package:billfie/providers/workflow_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart'; // Import for verify function
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
    
    group('setRestaurantName', () {
      test('updates _restaurantName and calls notifyListeners', () {
        const newName = 'The Grand Cafe';
        listenerCalled = false; // Reset listener flag
        
        workflowState.setRestaurantName(newName);
        
        expect(workflowState.restaurantName, newName);
        expect(listenerCalled, isTrue);
      });
    });

    group('setReceiptId', () {
      test('updates _receiptId and calls notifyListeners', () {
        const newId = 'receipt-12345';
        listenerCalled = false; // Reset listener flag
        
        workflowState.setReceiptId(newId);
        
        expect(workflowState.receiptId, newId);
        expect(listenerCalled, isTrue);
      });
    });

    group('setImageFile', () {
      late MockFile mockFile;

      setUp(() {
        // Re-initialize workflowState here if its internal state needs to be fresh for these specific tests,
        // or ensure previous tests clean up state that might interfere.
        // For setImageFile, it clears a lot of state, so starting fresh or with known state is good.
        // We can rely on the top-level setUp for basic mockImageStateManager and listenerCalled reset.
        mockFile = MockFile();

        // Ensure fields that will be cleared are populated to verify they are cleared.
        workflowState.setParseReceiptResult({'items': ['item1']});
        workflowState.setTranscribeAudioResult({'text': 'audio text'});
        workflowState.setAssignPeopleToItemsResult({'assignments': ['assignment1']});
        workflowState.setTip(10.0);
        workflowState.setTax(5.0);
        // _people is derived, so clearing assignments will clear people.
        listenerCalled = false; // Reset for this specific group's action
      });

      test('delegates to imageStateManager.setNewImageFile, clears subsequent data, and calls notifyListeners', () {
        workflowState.setImageFile(mockFile);

        // Verify delegation
        verify(mockImageStateManager.setNewImageFile(mockFile)).called(1);

        // Verify data clearing
        expect(workflowState.parseReceiptResult, isEmpty);
        expect(workflowState.transcribeAudioResult, isEmpty);
        expect(workflowState.assignPeopleToItemsResult, isEmpty);
        expect(workflowState.tip, isNull);
        expect(workflowState.tax, isNull);
        expect(workflowState.people, isEmpty);

        // Verify notification
        expect(listenerCalled, isTrue);
      });
    });

    group('resetImageFile', () {
      setUp(() {
        // Ensure fields that will be cleared are populated to verify they are cleared.
        // Also, ensure there *is* an image file set initially to make resetImageFile meaningful.
        final mockInitialFile = MockFile();
        workflowState.setImageFile(mockInitialFile); // Set an initial file
        
        // Populate data again as setImageFile would have cleared it.
        workflowState.setParseReceiptResult({'items': ['item1']});
        workflowState.setTranscribeAudioResult({'text': 'audio text'});
        workflowState.setAssignPeopleToItemsResult({'assignments': ['assignment1']});
        workflowState.setTip(10.0);
        workflowState.setTax(5.0);
        listenerCalled = false; // Reset for this specific group's action
      });

      test('delegates to imageStateManager.resetImageFile, clears subsequent data, and calls notifyListeners', () {
        workflowState.resetImageFile();

        // Verify delegation
        verify(mockImageStateManager.resetImageFile()).called(1);

        // Verify data clearing
        expect(workflowState.parseReceiptResult, isEmpty);
        expect(workflowState.transcribeAudioResult, isEmpty);
        expect(workflowState.assignPeopleToItemsResult, isEmpty);
        expect(workflowState.tip, isNull);
        expect(workflowState.tax, isNull);
        expect(workflowState.people, isEmpty);

        // Verify notification
        expect(listenerCalled, isTrue);
      });
    });

    group('setParseReceiptResult', () {
      test('updates _parseReceiptResult, removes URI fields, and calls notifyListeners', () {
        final initialResult = <String, dynamic>{
          'items': ['item1', 'item2'],
          'total': 100.0,
          'image_uri': 'some/image/uri',        // Field to be removed
          'thumbnail_uri': 'some/thumb/uri',    // Field to be removed
        };
        final expectedResult = <String, dynamic>{
          'items': ['item1', 'item2'],
          'total': 100.0,
        };
        listenerCalled = false;

        workflowState.setParseReceiptResult(Map<String, dynamic>.from(initialResult)); // Pass a copy

        expect(workflowState.parseReceiptResult, expectedResult);
        expect(workflowState.parseReceiptResult.containsKey('image_uri'), isFalse);
        expect(workflowState.parseReceiptResult.containsKey('thumbnail_uri'), isFalse);
        expect(listenerCalled, isTrue);
      });
    });

    group('setTranscribeAudioResult', () {
      test('updates _transcribeAudioResult with valid data and calls notifyListeners', () {
        final mockResult = <String, dynamic>{'text': 'Hello world', 'confidence': 0.9};
        listenerCalled = false;

        workflowState.setTranscribeAudioResult(mockResult);

        expect(workflowState.transcribeAudioResult, mockResult);
        expect(listenerCalled, isTrue);
      });

      test('updates _transcribeAudioResult to empty map if null is passed and calls notifyListeners', () {
        // Ensure it's not already empty or null from a previous state for a robust test
        workflowState.setTranscribeAudioResult(<String, dynamic>{'text': 'initial text'}); 
        listenerCalled = false; // Reset after initial set

        workflowState.setTranscribeAudioResult(null);

        expect(workflowState.transcribeAudioResult, isEmpty);
        expect(listenerCalled, isTrue);
      });
    });

    group('setAssignPeopleToItemsResult', () {
      setUp((){
        // Set initial tip and tax to verify they are cleared
        workflowState.setTip(5.0);
        workflowState.setTax(2.5);
        listenerCalled = false; // Reset listener flag for this group
      });

      test('updates result, clears tip/tax, derives people, and calls notifyListeners with valid data', () {
        final mockResult = <String, dynamic>{
          'assignments': [
            {'item': 'Burger', 'people': ['Alice', 'Bob']},
            {'item': 'Fries', 'people': ['Alice']},
            {'item': 'Soda', 'people': ['Charlie']},
          ],
          'summary': 'Some summary'
        };
        final expectedPeople = <String>['Alice', 'Bob', 'Charlie']; // Order might vary due to Set conversion

        workflowState.setAssignPeopleToItemsResult(mockResult);

        expect(workflowState.assignPeopleToItemsResult, mockResult);
        expect(workflowState.tip, isNull);
        expect(workflowState.tax, isNull);
        expect(workflowState.people, unorderedEquals(expectedPeople)); // Use unorderedEquals for lists from sets
        expect(listenerCalled, isTrue);
      });

      test('updates result to empty map, clears tip/tax, derives empty people, and calls notifyListeners if null is passed', () {
        // Set some initial people to ensure it gets cleared
        workflowState.setAssignPeopleToItemsResult(<String, dynamic>{
          'assignments': [
            {'item': 'Burger', 'people': ['Dave']}
          ]
        });
        workflowState.setTip(1.0); // Set tip/tax again
        workflowState.setTax(0.5);
        listenerCalled = false; // Reset after initial setup

        workflowState.setAssignPeopleToItemsResult(null);

        expect(workflowState.assignPeopleToItemsResult, isEmpty);
        expect(workflowState.tip, isNull);
        expect(workflowState.tax, isNull);
        expect(workflowState.people, isEmpty);
        expect(listenerCalled, isTrue);
      });
    });

    group('setTip', () {
      test('updates _tip and calls notifyListeners if value changed', () {
        listenerCalled = false;
        workflowState.setTip(10.0);
        expect(workflowState.tip, 10.0);
        expect(listenerCalled, isTrue);

        listenerCalled = false; // Reset
        workflowState.setTip(15.0);
        expect(workflowState.tip, 15.0);
        expect(listenerCalled, isTrue);
      });

      test('does not call notifyListeners if value is the same', () {
        workflowState.setTip(10.0); // Set initial value
        listenerCalled = false;      // Reset listener after initial call

        workflowState.setTip(10.0); // Set same value
        expect(workflowState.tip, 10.0);
        expect(listenerCalled, isFalse);
      });

      test('updates _tip to null and calls notifyListeners', () {
        workflowState.setTip(10.0); // Set an initial non-null value
        listenerCalled = false;      // Reset listener

        workflowState.setTip(null);
        expect(workflowState.tip, isNull);
        expect(listenerCalled, isTrue);
      });
    });

    group('setTax', () {
      test('updates _tax and calls notifyListeners if value changed', () {
        listenerCalled = false;
        workflowState.setTax(5.0);
        expect(workflowState.tax, 5.0);
        expect(listenerCalled, isTrue);

        listenerCalled = false; // Reset
        workflowState.setTax(7.5);
        expect(workflowState.tax, 7.5);
        expect(listenerCalled, isTrue);
      });

      test('does not call notifyListeners if value is the same', () {
        workflowState.setTax(5.0); // Set initial value
        listenerCalled = false;   // Reset listener after initial call

        workflowState.setTax(5.0); // Set same value
        expect(workflowState.tax, 5.0);
        expect(listenerCalled, isFalse);
      });

      test('updates _tax to null and calls notifyListeners', () {
        workflowState.setTax(5.0); // Set an initial non-null value
        listenerCalled = false;   // Reset listener

        workflowState.setTax(null);
        expect(workflowState.tax, isNull);
        expect(listenerCalled, isTrue);
      });
    });

    group('setLoading', () {
      test('updates _isLoading to true and calls notifyListeners', () {
        // Ensure initial state is false if not already guaranteed by a group setUp
        workflowState.setLoading(false);
        listenerCalled = false; // Reset listener

        workflowState.setLoading(true);
        expect(workflowState.isLoading, isTrue);
        expect(listenerCalled, isTrue);
      });

      test('updates _isLoading to false and calls notifyListeners', () {
        workflowState.setLoading(true); // Ensure it's true first
        listenerCalled = false; // Reset listener

        workflowState.setLoading(false);
        expect(workflowState.isLoading, isFalse);
        expect(listenerCalled, isTrue);
      });

      // Note: setLoading currently always calls notifyListeners. 
      // If it were optimized to only call if the value changes, a test for that would be added.
      // For now, these tests cover the current behavior.
    });

    group('setErrorMessage', () {
      test('updates _errorMessage with a message and calls notifyListeners', () {
        listenerCalled = false;
        const message = 'An error occurred';

        workflowState.setErrorMessage(message);
        expect(workflowState.errorMessage, message);
        expect(listenerCalled, isTrue);
      });

      test('updates _errorMessage to null and calls notifyListeners', () {
        workflowState.setErrorMessage('Initial error'); // Set an initial message
        listenerCalled = false; // Reset listener

        workflowState.setErrorMessage(null);
        expect(workflowState.errorMessage, isNull);
        expect(listenerCalled, isTrue);
      });
       // Note: setErrorMessage currently always calls notifyListeners. 
      // If it were optimized to only call if the value changes, a test for that would be added.
    });

    // TODO: Add more test groups for other methods as outlined in test_coverage.md
    // - resetImageFile()
    // - setParseReceiptResult()
    // - setTranscribeAudioResult()
    // - setAssignPeopleToItemsResult()
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