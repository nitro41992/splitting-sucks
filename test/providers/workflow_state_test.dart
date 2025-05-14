import 'package:billfie/providers/workflow_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart'; // Import for verify function
import '../mocks.mocks.dart'; // Import the generated mocks
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

late WorkflowState workflowState;
late MockImageStateManager mockImageStateManager;
bool listenerCalled = false;

// Replicate the key prefix and logic from WorkflowState.dart for test purposes
const String _testTranscriptionPrefsKeyPrefix = 'transcription_';
String getTestTranscriptionPrefsKey(String? receiptId) {
  return _testTranscriptionPrefsKeyPrefix + (receiptId ?? 'draft');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
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

    test('delegates to imageStateManager.setNewImageFile, clears data except tip/tax, and calls notifyListeners', () {
      workflowState.setImageFile(mockFile);

      // Verify delegation
      verify(mockImageStateManager.setNewImageFile(mockFile)).called(1);

      // Verify data clearing
      expect(workflowState.parseReceiptResult, isEmpty);
      expect(workflowState.transcribeAudioResult, isEmpty);
      expect(workflowState.assignPeopleToItemsResult, isEmpty);
      expect(workflowState.tip, isNotNull, reason: 'Tip should be preserved');
      expect(workflowState.tip, equals(10.0), reason: 'Tip value should remain unchanged');
      expect(workflowState.tax, isNotNull, reason: 'Tax should be preserved');
      expect(workflowState.tax, equals(5.0), reason: 'Tax value should remain unchanged');
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

    test('delegates to imageStateManager.resetImageFile, clears data except tip/tax, and calls notifyListeners', () {
      workflowState.resetImageFile();

      // Verify delegation
      verify(mockImageStateManager.resetImageFile()).called(1);

      // Verify data clearing
      expect(workflowState.parseReceiptResult, isEmpty);
      expect(workflowState.transcribeAudioResult, isEmpty);
      expect(workflowState.assignPeopleToItemsResult, isEmpty);
      expect(workflowState.tip, isNotNull, reason: 'Tip should be preserved');
      expect(workflowState.tip, equals(10.0), reason: 'Tip value should remain unchanged');
      expect(workflowState.tax, isNotNull, reason: 'Tax should be preserved');
      expect(workflowState.tax, equals(5.0), reason: 'Tax value should remain unchanged');
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
    test('updates _transcribeAudioResult with valid data, calls notifyListeners, and saves to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId); // Use test helper
      
      // Ensure prefs are clean for this key or set known state
      await prefs.remove(key);

      final mockResult = <String, dynamic>{'text': 'Hello world', 'confidence': 0.9};
      listenerCalled = false;

      workflowState.setTranscribeAudioResult(mockResult);

      expect(workflowState.transcribeAudioResult, mockResult);
      expect(listenerCalled, isTrue);
      
      // Verify SharedPreferences interaction
      final jsonString = prefs.getString(key);
      expect(jsonString, isNotNull);
      final savedData = jsonDecode(jsonString!) as Map<String, dynamic>;
      expect(savedData['text'], 'Hello world');
    });

    test('updates _transcribeAudioResult with null, calls notifyListeners, and clears text in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);

      // Pre-populate with some data including tip/tax to ensure only text is affected or key is removed if only text was there
      final initialData = {'text': 'Existing text', 'tip': 5.0};
      await prefs.setString(key, jsonEncode(initialData));
      
      workflowState.setTip(5.0); // Ensure tip is in WorkflowState to be re-saved
      listenerCalled = false;
      workflowState.setTranscribeAudioResult(null);

      expect(workflowState.transcribeAudioResult, isEmpty);
      expect(listenerCalled, isTrue);

      final jsonString = prefs.getString(key);
      if (workflowState.tip != null || workflowState.tax != null) { // If other data like tip/tax exists, key should remain with text removed
        expect(jsonString, isNotNull);
        final savedData = jsonDecode(jsonString!) as Map<String, dynamic>;
        expect(savedData.containsKey('text'), isFalse);
        expect(savedData['tip'], 5.0); // Check if other data is preserved
      } else { // If only text was there, key might be removed
         final currentData = prefs.getString(key);
         if (currentData != null) {
            final decodedCurrentData = jsonDecode(currentData) as Map<String, dynamic>;
            expect(decodedCurrentData.containsKey('text'), isFalse);
         } else {
            expect(currentData, isNull); // Or key is removed
         }
      }
    });

    test('updates _transcribeAudioResult with empty map, calls notifyListeners, and clears text in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);
       // Pre-populate with some data including tip/tax to ensure only text is affected or key is removed if only text was there
      final initialData = {'text': 'Existing text', 'tax': 2.0};
      await prefs.setString(key, jsonEncode(initialData));

      workflowState.setTax(2.0); // Ensure tax is in WorkflowState to be re-saved
      listenerCalled = false;
      workflowState.setTranscribeAudioResult({});

      expect(workflowState.transcribeAudioResult, isEmpty);
      expect(listenerCalled, isTrue);
      
      final jsonString = prefs.getString(key);
       if (workflowState.tip != null || workflowState.tax != null) {
        expect(jsonString, isNotNull);
        final savedData = jsonDecode(jsonString!) as Map<String, dynamic>;
        expect(savedData.containsKey('text'), isFalse);
        expect(savedData['tax'], 2.0); 
      } else {
         final currentData = prefs.getString(key);
         if (currentData != null) {
            final decodedCurrentData = jsonDecode(currentData) as Map<String, dynamic>;
            expect(decodedCurrentData.containsKey('text'), isFalse);
         } else {
            expect(currentData, isNull);
         }
      }
    });
  });

  group('setAssignPeopleToItemsResult', () {
    setUp((){
      // Set initial tip and tax to verify they are preserved
      workflowState.setTip(5.0);
      workflowState.setTax(2.5);
      listenerCalled = false; // Reset listener flag for this group
    });

    test('updates result, preserves tip/tax, derives people, and calls notifyListeners with valid data', () {
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
      expect(workflowState.tip, equals(5.0), reason: 'Tip should be preserved');
      expect(workflowState.tax, equals(2.5), reason: 'Tax should be preserved');
      expect(workflowState.people, unorderedEquals(expectedPeople)); // Use unorderedEquals for lists from sets
      expect(listenerCalled, isTrue);
    });

    test('updates result to empty map, preserves tip/tax, derives empty people, and calls notifyListeners if null is passed', () {
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
      expect(workflowState.tip, equals(1.0), reason: 'Tip should be preserved');
      expect(workflowState.tax, equals(0.5), reason: 'Tax should be preserved');
      expect(workflowState.people, isEmpty);
      expect(listenerCalled, isTrue);
    });
  });

  group('setTip', () {
    test('updates _tip, calls notifyListeners, and saves tip (and existing text/tax) to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);
      
      // Setup initial state with transcription text
      workflowState.setTranscribeAudioResult({'text': 'some text'});
      await prefs.setString(key, jsonEncode({'text': 'some text'})); // Simulate initial save

      listenerCalled = false;
      workflowState.setTip(7.5);

      expect(workflowState.tip, 7.5);
      expect(listenerCalled, isTrue);

      final jsonString = prefs.getString(key);
      expect(jsonString, isNotNull);
      final savedData = jsonDecode(jsonString!) as Map<String, dynamic>;
      expect(savedData['tip'], 7.5);
      expect(savedData['text'], 'some text'); // Ensure existing text is preserved
    });

    test('updates _tip to null, calls notifyListeners, and removes tip from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);

      // Setup initial state with transcription text and tip
      workflowState.setTranscribeAudioResult({'text': 'some text'});
      workflowState.setTip(7.5);
      await prefs.setString(key, jsonEncode({'text': 'some text', 'tip': 7.5}));


      listenerCalled = false;
      workflowState.setTip(null);

      expect(workflowState.tip, isNull);
      expect(listenerCalled, isTrue);

      final jsonString = prefs.getString(key);
      expect(jsonString, isNotNull); // Key should still exist if other data (text) is present
      final savedData = jsonDecode(jsonString!) as Map<String, dynamic>;
      expect(savedData.containsKey('tip'), isFalse);
      expect(savedData['text'], 'some text');
    });
  });

  group('setTax', () {
    test('updates _tax, calls notifyListeners, and saves tax (and existing text/tip) to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);

      // Setup initial state with transcription text and tip
      workflowState.setTranscribeAudioResult({'text': 'other text'});
      workflowState.setTip(3.0);
      await prefs.setString(key, jsonEncode({'text': 'other text', 'tip': 3.0}));


      listenerCalled = false;
      workflowState.setTax(2.5);

      expect(workflowState.tax, 2.5);
      expect(listenerCalled, isTrue);

      final jsonString = prefs.getString(key);
      expect(jsonString, isNotNull);
      final savedData = jsonDecode(jsonString!) as Map<String, dynamic>;
      expect(savedData['tax'], 2.5);
      expect(savedData['text'], 'other text');
      expect(savedData['tip'], 3.0);
    });

    test('updates _tax to null, calls notifyListeners, and removes tax from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);

       // Setup initial state with transcription text and tax
      workflowState.setTranscribeAudioResult({'text': 'another text'});
      workflowState.setTax(2.5);
      await prefs.setString(key, jsonEncode({'text': 'another text', 'tax': 2.5}));

      listenerCalled = false;
      workflowState.setTax(null);

      expect(workflowState.tax, isNull);
      expect(listenerCalled, isTrue);

      final jsonString = prefs.getString(key);
      expect(jsonString, isNotNull);
      final savedData = jsonDecode(jsonString!) as Map<String, dynamic>;
      expect(savedData.containsKey('tax'), isFalse);
      expect(savedData['text'], 'another text');
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

    test('clearParseAndSubsequentData clears relevant fields and preserves tax/tip values', () {
      resetWorkflowStateWithData(); // Sets up data and resets listenerCalled
      
      workflowState.clearParseAndSubsequentData();

      expect(workflowState.parseReceiptResult, isEmpty, reason: 'Parse result should be empty');
      expect(workflowState.transcribeAudioResult, isEmpty, reason: 'Transcribe result should be empty');
      expect(workflowState.assignPeopleToItemsResult, isEmpty, reason: 'Assign result should be empty');
      expect(workflowState.tip, isNotNull, reason: 'Tip should be preserved');
      expect(workflowState.tip, equals(1.0), reason: 'Tip value should remain unchanged');
      expect(workflowState.tax, isNotNull, reason: 'Tax should be preserved');
      expect(workflowState.tax, equals(0.5), reason: 'Tax value should remain unchanged');
      expect(workflowState.people, isEmpty, reason: 'People list should be empty');
      expect(listenerCalled, isTrue, reason: 'Notify listeners should have been called');
    });

    test('clearTranscriptionAndSubsequentData clears relevant fields and preserves tax/tip values', () {
      resetWorkflowStateWithData();
      // Specific setup for this test if parse data should remain
      // The global workflowState is used, resetWorkflowStateWithData already populates parseReceiptResult
      
      listenerCalled = false; // Crucial: reset after all setup, before the action under test
      workflowState.clearTranscriptionAndSubsequentData();

      expect(workflowState.parseReceiptResult, isNotEmpty, reason: 'Parse result should NOT be cleared');
      expect(workflowState.transcribeAudioResult, isEmpty, reason: 'Transcribe result should be empty');
      expect(workflowState.assignPeopleToItemsResult, isEmpty, reason: 'Assign result should be empty');
      expect(workflowState.tip, isNotNull, reason: 'Tip should be preserved');
      expect(workflowState.tip, equals(1.0), reason: 'Tip value should remain unchanged');
      expect(workflowState.tax, isNotNull, reason: 'Tax should be preserved');
      expect(workflowState.tax, equals(0.5), reason: 'Tax value should remain unchanged');
      expect(workflowState.people, isEmpty, reason: 'People list should be empty');
      expect(listenerCalled, isTrue, reason: 'Notify listeners should have been called');
    });

    test('clearAssignmentAndSubsequentData clears relevant fields and preserves tax/tip values', () {
      resetWorkflowStateWithData();
      // Specific setup: parse and transcribe data should remain
      // resetWorkflowStateWithData already populates them.

      listenerCalled = false; // Crucial: reset after all setup, before the action under test
      workflowState.clearAssignmentAndSubsequentData();

      expect(workflowState.parseReceiptResult, isNotEmpty, reason: 'Parse result should NOT be cleared');
      expect(workflowState.transcribeAudioResult, isNotEmpty, reason: 'Transcribe result should NOT be cleared');
      expect(workflowState.assignPeopleToItemsResult, isEmpty, reason: 'Assign result should be empty');
      expect(workflowState.tip, isNotNull, reason: 'Tip should be preserved');
      expect(workflowState.tip, equals(1.0), reason: 'Tip value should remain unchanged');
      expect(workflowState.tax, isNotNull, reason: 'Tax should be preserved');
      expect(workflowState.tax, equals(0.5), reason: 'Tax value should remain unchanged');
      expect(workflowState.people, isEmpty, reason: 'People list should be empty');
      expect(listenerCalled, isTrue, reason: 'Notify listeners should have been called');
    });
  });

  // Test for _extractPeopleFromAssignments (tested via setAssignPeopleToItemsResult and people getter)
  group('_extractPeopleFromAssignments', () {
    test('extracts unique people names correctly from valid assignments', () {
      final assignments = {
        'assignments': [
          {'item': 'Burger', 'people': ['Alice', 'Bob']},
          {'item': 'Fries', 'people': ['Alice']},
          {'item': 'Soda', 'people': ['Charlie', 'Bob']},
          {'item': 'Salad', 'people': []}, // No people assigned
          {'item': 'Water'} // No 'people' key
        ]
      };
      workflowState.setAssignPeopleToItemsResult(assignments);
      expect(workflowState.people, unorderedEquals(['Alice', 'Bob', 'Charlie']));
    });

    test('returns empty list if assignments map is null or empty', () {
      workflowState.setAssignPeopleToItemsResult(null);
      expect(workflowState.people, isEmpty);

      workflowState.setAssignPeopleToItemsResult({});
      expect(workflowState.people, isEmpty);
    });

    test('returns empty list if "assignments" key is missing or list is empty', () {
      workflowState.setAssignPeopleToItemsResult({'other_key': []});
      expect(workflowState.people, isEmpty);

      workflowState.setAssignPeopleToItemsResult({'assignments': []});
      expect(workflowState.people, isEmpty);
    });

    test('handles malformed data gracefully (e.g., non-list assignments, non-map item)', () {
      // "assignments" is not a list
      workflowState.setAssignPeopleToItemsResult({'assignments': 'not_a_list'});
      expect(workflowState.people, isEmpty, reason: 'Assignments not a list');

      // Item in assignments is not a map
      workflowState.setAssignPeopleToItemsResult({
        'assignments': ['not_a_map', {'item': 'Burger', 'people': ['Alice']}]
      });
      // Should still extract from valid parts.
      expect(workflowState.people, unorderedEquals(['Alice']), reason: 'Should process valid map item even if other items are not maps'); 

      // Reset and test a slightly different malformed case
      workflowState = WorkflowState(restaurantName: 'Test'); // Re-initialize to clear previous state
      workflowState.addListener(() { listenerCalled = true; }); // Re-add listener for consistency if needed by other parts, though not strictly for .people
      workflowState.setAssignPeopleToItemsResult({
        'assignments': [
          {'item': 'Valid Item', 'people': ['ValidPerson']},
          'another_string_instead_of_map' 
        ]
      });
      expect(workflowState.people, unorderedEquals(['ValidPerson']), reason: 'Should process valid items even if one is malformed string');

    });

    test('handles items where "people" key is missing or people list is null/not a list', () {
      workflowState.setAssignPeopleToItemsResult({
        'assignments': [
          {'item': 'ItemA'}, // No 'people' key
          {'item': 'ItemB', 'people': null}, // 'people' is null
          {'item': 'ItemC', 'people': 'not_a_list'}, // 'people' is not a list
          {'item': 'ItemD', 'people': ['Dave']}
        ]
      });
      expect(workflowState.people, unorderedEquals(['Dave']));
    });

     test('handles non-string person names in people list gracefully (if possible, though typing should prevent)', () {
      workflowState.setAssignPeopleToItemsResult({
        'assignments': [
          {'item': 'ItemX', 'people': ['Eve', 123, 'Frank', true, null]}
        ]
      });
      // Expect only strings to be added
      expect(workflowState.people, unorderedEquals(['Eve', 'Frank']));
    });

  });

  group('Persistence and Loading (loadTranscriptionFromPrefs / Constructor)', () {
    const testReceiptId = 'test-receipt-123';

    setUp(() {
      // Reset workflowState for these tests to ensure constructor loading logic is hit cleanly
      // or use a unique receiptId to avoid clashes if prefs are not cleared perfectly.
       mockImageStateManager = MockImageStateManager();
       // Initialize SharedPreferences *before* WorkflowState instance for constructor load test
       SharedPreferences.setMockInitialValues({}); // Clear initially for the group

       workflowState = WorkflowState(
        restaurantName: 'Testaurant',
        receiptId: testReceiptId, // Critical for loading by specific key
        imageStateManager: mockImageStateManager,
      );
      listenerCalled = false;
      workflowState.addListener(() {
        listenerCalled = true;
      });
    });

    test('loads transcription, tip, and tax from SharedPreferences by loadTranscriptionFromPrefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(testReceiptId);
      final testData = {'text': 'loaded text', 'tip': 1.0, 'tax': 0.5};
      await prefs.setString(key, jsonEncode(testData));

      // Simulate being freshly loaded by clearing current state if needed, then call load
      workflowState.setTranscribeAudioResult(null); 
      workflowState.setTip(null); 
      workflowState.setTax(null); 
      await prefs.setString(key, jsonEncode(testData)); // Ensure desired data is in prefs before load

      await workflowState.loadTranscriptionFromPrefs();

      expect(workflowState.transcribeAudioResult['text'], 'loaded text');
      expect(workflowState.tip, 1.0);
      expect(workflowState.tax, 0.5);
      expect(listenerCalled, isTrue); // loadTranscriptionFromPrefs calls notifyListeners
    });

    test('WorkflowState constructor loads data if receiptId is present and data exists in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(testReceiptId);
      final constructorTestData = {'text': 'constructor load', 'tip': 2.0, 'tax': 1.5};
      // Set SharedPreferences *before* creating the instance we want to test loading with
      SharedPreferences.setMockInitialValues({key: jsonEncode(constructorTestData)});

      // Create a new WorkflowState instance to trigger constructor loading logic
      final freshWorkflowState = WorkflowState(
        restaurantName: 'Constructor Test',
        receiptId: testReceiptId,
        imageStateManager: MockImageStateManager(),
      );
      // Allow loadTranscriptionFromPrefs (called by constructor) to complete
      await Future.delayed(Duration.zero); 

      expect(freshWorkflowState.transcribeAudioResult['text'], 'constructor load');
      expect(freshWorkflowState.tip, 2.0);
      expect(freshWorkflowState.tax, 1.5);
    });


    test('loads only available data from SharedPreferences via loadTranscriptionFromPrefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(testReceiptId);
      final testData = {'text': 'only text here'};
      await prefs.setString(key, jsonEncode(testData));
      
      workflowState.setTranscribeAudioResult(null);
      workflowState.setTip(null);
      workflowState.setTax(null);
      await prefs.setString(key, jsonEncode(testData));


      await workflowState.loadTranscriptionFromPrefs();

      expect(workflowState.transcribeAudioResult['text'], 'only text here');
      expect(workflowState.tip, isNull);
      expect(workflowState.tax, isNull);
    });

    test('handles empty or missing SharedPreferences entry gracefully during loadTranscriptionFromPrefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(testReceiptId);
      await prefs.remove(key); // Ensure no data

      workflowState.setTranscribeAudioResult({'text': 'pre-existing'});
      workflowState.setTip(10.0);
      workflowState.setTax(5.0);
      
      await workflowState.loadTranscriptionFromPrefs(); 

      // If no data for a field in prefs, it should not overwrite existing valid data with null.
      // The current implementation of loadTranscriptionFromPrefs sets fields if they exist in the loaded JSON.
      // If a key (like 'text') is not in JSON, it won't update that part of state.
      // If the entire entry for `key` is missing, nothing is loaded, state remains.
      expect(workflowState.transcribeAudioResult['text'], 'pre-existing');
      expect(workflowState.tip, 10.0);
      expect(workflowState.tax, 5.0);
    });

    test('handles malformed JSON in SharedPreferences gracefully during loadTranscriptionFromPrefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(testReceiptId);
      await prefs.setString(key, "{malformed_json'");

      // Set some initial state to ensure it's not wiped by a faulty load
      workflowState.setTranscribeAudioResult({'text': 'stable text'});
      workflowState.setTip(1.0);
      workflowState.setTax(0.5);
      
      await workflowState.loadTranscriptionFromPrefs();

      // Expect that state remains unchanged and no unhandled exception occurred
      expect(workflowState.transcribeAudioResult['text'], 'stable text');
      expect(workflowState.tip, 1.0);
      expect(workflowState.tax, 0.5);
    });

    test('correctly uses "draft" key for SharedPreferences when receiptId is null during save and load', () async {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = getTestTranscriptionPrefsKey(null); // Test with explicit null for draft
      await prefs.remove(draftKey); // Clear any previous draft state

      // Create WorkflowState without a receiptId
      final draftState = WorkflowState(
        restaurantName: 'Draft Restaurant',
        imageStateManager: mockImageStateManager, // receiptId is null
      );
      draftState.setTranscribeAudioResult({'text': 'draft text'});
      draftState.setTip(1.1);

      // Verify data is saved under the draft key
      var jsonString = prefs.getString(draftKey);
      expect(jsonString, isNotNull);
      var savedData = jsonDecode(jsonString!) as Map<String, dynamic>;
      expect(savedData['text'], 'draft text');
      expect(savedData['tip'], 1.1);

      // Now test loading for a draft state
      // Simulate app restart by creating a new instance without receiptId
      final newDraftState = WorkflowState(
        restaurantName: 'New Draft Restaurant',
        imageStateManager: mockImageStateManager,
      );
      // Manually call load, as constructor with null receiptId might not auto-load this specific key unless explicitly designed
      // The current constructor calls loadTranscriptionFromPrefs if _receiptId != null.
      // So for draft (receiptId == null), we need to call it manually or ensure the constructor logic covers it.
      // Let's assume the constructor calls loadTranscriptionFromPrefs which then correctly uses (_receiptId ?? 'draft')
      await newDraftState.loadTranscriptionFromPrefs();

      expect(newDraftState.transcribeAudioResult['text'], 'draft text');
      expect(newDraftState.tip, 1.1);
      await prefs.remove(draftKey); // Clean up
    });

  });
} 