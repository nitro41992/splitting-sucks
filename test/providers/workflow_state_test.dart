import 'package:billfie/providers/workflow_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart'; // Import for verify function
import '../mocks.mocks.dart'; // Import the generated mocks

late WorkflowState workflowState;
late MockImageStateManager mockImageStateManager;
bool listenerCalled = false;

void main() {
  setUp(() {
    mockImageStateManager = MockImageStateManager();
    // Initialize workflowState here for global use by listener
    workflowState = WorkflowState(
      restaurantName: 'InitialRestaurant', // Provide a default name
      imageStateManager: mockImageStateManager,
    );
    listenerCalled = false;
    workflowState.addListener(() {
      listenerCalled = true;
    });
  });

  tearDown(() {
    workflowState.removeListener(() {
      listenerCalled = true; // This actual callback doesn't matter for removeListener
    });
  });

  test('initial state is correct', () {
    expect(workflowState.currentStep, 0);
    expect(workflowState.receiptId, isNull);
    expect(workflowState.restaurantName, 'InitialRestaurant');
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

  group('ImageStateManager delegation', () {
    // These tests verify that WorkflowState correctly calls methods on ImageStateManager
    // and notifies its own listeners.

    test('setUploadedGsUris delegates and notifies', () {
      const imageUrl = 'gs://bucket/image.jpg';
      const thumbUrl = 'gs://bucket/thumb.jpg';
      listenerCalled = false;

      workflowState.setUploadedGsUris(imageUrl, thumbUrl);

      verify(mockImageStateManager.setUploadedGsUris(imageUrl, thumbUrl)).called(1);
      expect(listenerCalled, isTrue);
    });

    test('setLoadedImageUrls delegates and notifies', () {
      const imageUrl = 'http://example.com/image.jpg';
      const thumbUrl = 'http://example.com/thumb.jpg';
      listenerCalled = false;

      workflowState.setLoadedImageUrls(imageUrl, thumbUrl);

      verify(mockImageStateManager.setLoadedImageUrls(imageUrl, thumbUrl)).called(1);
      expect(listenerCalled, isTrue);
    });

    test('setActualGsUrisOnLoad delegates and notifies', () {
      const imageUrl = 'gs://bucket/actual_image.jpg';
      const thumbUrl = 'gs://bucket/actual_thumb.jpg';
      listenerCalled = false;

      workflowState.setActualGsUrisOnLoad(imageUrl, thumbUrl);

      verify(mockImageStateManager.setActualGsUrisOnLoad(imageUrl, thumbUrl)).called(1);
      expect(listenerCalled, isTrue);
    });

    test('clearPendingDeletions delegates and notifies', () {
      listenerCalled = false;
      workflowState.clearPendingDeletions();
      verify(mockImageStateManager.clearPendingDeletionsList()).called(1);
      expect(listenerCalled, isTrue);
    });

    test('addUriToPendingDeletions delegates and notifies', () {
      const uri = 'gs://bucket/to_delete.jpg';
      listenerCalled = false;

      workflowState.addUriToPendingDeletions(uri);

      verify(mockImageStateManager.addUriToPendingDeletionsList(uri)).called(1);
      expect(listenerCalled, isTrue);
    });

    test('removeUriFromPendingDeletions delegates and notifies', () {
      const uri = 'gs://bucket/to_remove.jpg';
      listenerCalled = false;

      workflowState.removeUriFromPendingDeletions(uri);

      verify(mockImageStateManager.removeUriFromPendingDeletionsList(uri)).called(1);
      expect(listenerCalled, isTrue);
    });
  });

  // TODO: Add more test groups for other methods as outlined in test_coverage.md
  // - toReceipt()
  // - _extractPeopleFromAssignments()
  // - hasParseData, hasTranscriptionData, hasAssignmentData flags
  // - clearParseAndSubsequentData()
  // - clearTranscriptionAndSubsequentData()
  // - clearAssignmentAndSubsequentData()

  group('WorkflowState toReceipt()', () {
    test('correctly constructs a Receipt object with current state data', () {
      final mockImageStateManager = MockImageStateManager();
      when(mockImageStateManager.actualImageGsUri).thenReturn('gs://actual_image_uri');
      when(mockImageStateManager.actualThumbnailGsUri).thenReturn('gs://actual_thumbnail_uri');
      when(mockImageStateManager.loadedImageUrl).thenReturn('http://loaded_image_url');
      when(mockImageStateManager.loadedThumbnailUrl).thenReturn('http://loaded_thumbnail_url');

      // Declare workflowState here
      final workflowState = WorkflowState(
        imageStateManager: mockImageStateManager,
        restaurantName: 'Test Restaurant',
      );

      // Set some data in workflowState
      workflowState.setReceiptId('test-receipt-id');
      final parseResult = {
        'items': [
          {'name': 'Item 1', 'price': 10.0, 'quantity': 1}
        ],
        'total_amount': 10.0,
        'transaction_date': '2023-10-27',
        'description': 'Parsed Description'
      };
      workflowState.setParseReceiptResult(parseResult);
      final transcribeResult = {'text': 'transcribed audio text'};
      workflowState.setTranscribeAudioResult(transcribeResult);
      final assignResult = {
        'assignments': [
          {'item': 'Item 1', 'people': ['Alice']}
        ],
        'summary': 'Assignment summary'
      };
      workflowState.setAssignPeopleToItemsResult(assignResult);
      workflowState.setTip(1.0);
      workflowState.setTax(0.5);
      workflowState.setErrorMessage('Test Error');
      workflowState.setLoading(true); // Should not be part of receipt

      final receipt = workflowState.toReceipt();

      expect(receipt.id, 'test-receipt-id');
      expect(receipt.restaurantName, 'Test Restaurant');
      expect(receipt.parseReceipt, parseResult);
      expect(receipt.transcribeAudio, transcribeResult);
      expect(receipt.assignPeopleToItems, assignResult);
      expect(receipt.people, ['Alice']);
      expect(receipt.tip, 1.0);
      expect(receipt.tax, 0.5);
      expect(receipt.status, 'draft');

      expect(receipt.imageUri, 'gs://actual_image_uri');
      expect(receipt.thumbnailUri, 'gs://actual_thumbnail_uri');
    });
  });

  group('WorkflowState Data Flags', () {
    test('hasParseData returns true when _parseReceiptResult is not empty, false otherwise', () {
      final workflowState = WorkflowState(restaurantName: 'Test');
      expect(workflowState.hasParseData, isFalse, reason: 'Initially should be false');

      workflowState.setParseReceiptResult({'items': [
        {'name': 'Test Item', 'price': 1.0, 'quantity': 1}
      ], 'total_amount': 1.0}); // Ensure items list is non-empty for hasParseData logic
      expect(workflowState.hasParseData, isTrue, reason: 'Should be true after setting non-empty item data');

      workflowState.setParseReceiptResult({'items': []}); // Set to map with empty items list
      expect(workflowState.hasParseData, isFalse, reason: 'Should be false when items list is empty');
      
      workflowState.setParseReceiptResult({}); // Set to completely empty map
      expect(workflowState.hasParseData, isFalse, reason: 'Should be false when data is empty map');
      // No null test for setParseReceiptResult as it expects a non-nullable Map
    });

    test('hasTranscriptionData returns true when _transcribeAudioResult is not empty and has text, false otherwise', () {
      final workflowState = WorkflowState(restaurantName: 'Test');
      expect(workflowState.hasTranscriptionData, isFalse, reason: 'Initially should be false');

      workflowState.setTranscribeAudioResult({'text': 'hello'});
      expect(workflowState.hasTranscriptionData, isTrue, reason: 'Should be true after setting data with text');

      workflowState.setTranscribeAudioResult({'text': ''}); // Empty text
      expect(workflowState.hasTranscriptionData, isFalse, reason: 'Should be false when text is empty');

      workflowState.setTranscribeAudioResult({}); // Set to empty map
      expect(workflowState.hasTranscriptionData, isFalse, reason: 'Should be false when data is empty map');
      
      workflowState.setTranscribeAudioResult(null as Map<String, dynamic>?); // Set to null with explicit cast
      expect(workflowState.hasTranscriptionData, isFalse, reason: 'Should be false when data is null');
    });

    test('hasAssignmentData returns true when _assignPeopleToItemsResult is not empty and has assignments, false otherwise', () {
      final workflowState = WorkflowState(restaurantName: 'Test');
      expect(workflowState.hasAssignmentData, isFalse, reason: 'Initially should be false');

      workflowState.setAssignPeopleToItemsResult({'assignments': [
        {'item': 'Test Item', 'people': ['Alice']}
      ]}); // Ensure assignments list is non-empty
      expect(workflowState.hasAssignmentData, isTrue, reason: 'Should be true after setting non-empty assignment data');

      workflowState.setAssignPeopleToItemsResult({'assignments': []}); // Set to map with empty assignments list
      expect(workflowState.hasAssignmentData, isFalse, reason: 'Should be false when assignments list is empty');

      workflowState.setAssignPeopleToItemsResult({}); // Set to empty map
      expect(workflowState.hasAssignmentData, isFalse, reason: 'Should be false when data is empty map');

      workflowState.setAssignPeopleToItemsResult(null as Map<String, dynamic>?); // Set to null with explicit cast
      expect(workflowState.hasAssignmentData, isFalse, reason: 'Should be false when data is null');
    });
  });

  group('WorkflowState Data Clearing Methods', () {
    // Helper to reset workflowState to a known state with data and reset listenerCalled
    void resetWorkflowStateWithData() {
      // Re-initialize or set data on the global workflowState instance
      // This is tricky if other tests modified it. Better to re-init parts or use a fresh instance
      // For simplicity here, we'll re-initialize the global one for this group's specific needs.
      // OR, more simply, just set the data on the existing global instance.
      
      // Let's set data on the global workflowState from setUp
      workflowState.setParseReceiptResult({'items': [{'name': 'item1'}]});
      workflowState.setTranscribeAudioResult({'text': 'audio'});
      workflowState.setAssignPeopleToItemsResult({'assignments': [{'item': 'item1', 'people': ['A']}]});
      workflowState.setTip(1.0);
      workflowState.setTax(0.5);
      // Ensure other fields are in a known state if necessary, e.g., restaurant name
      if (workflowState.restaurantName != 'Test Data Clearing') {
        workflowState.setRestaurantName('Test Data Clearing'); //This will set listenerCalled = true
      }
      listenerCalled = false; // Reset after setup for the actual test action
    }

    test('clearParseAndSubsequentData clears relevant fields and notifies', () {
      resetWorkflowStateWithData(); // Sets up data and resets listenerCalled
      
      workflowState.clearParseAndSubsequentData();

      expect(workflowState.parseReceiptResult, isEmpty, reason: 'Parse result should be empty');
      expect(workflowState.transcribeAudioResult, isEmpty, reason: 'Transcribe result should be empty');
      expect(workflowState.assignPeopleToItemsResult, isEmpty, reason: 'Assign result should be empty');
      expect(workflowState.tip, isNull, reason: 'Tip should be null');
      expect(workflowState.tax, isNull, reason: 'Tax should be null');
      expect(workflowState.people, isEmpty, reason: 'People list should be empty');
      expect(listenerCalled, isTrue, reason: 'Notify listeners should have been called');
    });

    test('clearTranscriptionAndSubsequentData clears relevant fields and notifies', () {
      resetWorkflowStateWithData();
      // Specific setup for this test if parse data should remain
      // The global workflowState is used, resetWorkflowStateWithData already populates parseReceiptResult
      
      listenerCalled = false; // Crucial: reset after all setup, before the action under test
      workflowState.clearTranscriptionAndSubsequentData();

      expect(workflowState.parseReceiptResult, isNotEmpty, reason: 'Parse result should NOT be cleared');
      expect(workflowState.transcribeAudioResult, isEmpty, reason: 'Transcribe result should be empty');
      expect(workflowState.assignPeopleToItemsResult, isEmpty, reason: 'Assign result should be empty');
      expect(workflowState.tip, isNull, reason: 'Tip should be null');
      expect(workflowState.tax, isNull, reason: 'Tax should be null');
      expect(workflowState.people, isEmpty, reason: 'People list should be empty');
      expect(listenerCalled, isTrue, reason: 'Notify listeners should have been called');
    });

    test('clearAssignmentAndSubsequentData clears relevant fields and notifies', () {
      resetWorkflowStateWithData();
      // Specific setup: parse and transcribe data should remain
      // resetWorkflowStateWithData already populates them.

      listenerCalled = false; // Crucial: reset after all setup, before the action under test
      workflowState.clearAssignmentAndSubsequentData();

      expect(workflowState.parseReceiptResult, isNotEmpty, reason: 'Parse result should NOT be cleared');
      expect(workflowState.transcribeAudioResult, isNotEmpty, reason: 'Transcribe result should NOT be cleared');
      expect(workflowState.assignPeopleToItemsResult, isEmpty, reason: 'Assign result should be empty');
      expect(workflowState.tip, isNull, reason: 'Tip should be null (as per current implementation)');
      expect(workflowState.tax, isNull, reason: 'Tax should be null (as per current implementation)');
      expect(workflowState.people, isEmpty, reason: 'People list should be empty');
      expect(listenerCalled, isTrue, reason: 'Notify listeners should have been called');
    });
  });
} 