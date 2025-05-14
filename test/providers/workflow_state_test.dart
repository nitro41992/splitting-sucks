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
  
  // Reset SharedPreferences before each test to ensure isolation
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);
      await prefs.remove(key); // Ensure clean slate
      
      listenerCalled = false;
      workflowState.setTranscribeAudioResult({'text': 'Hello world', 'confidence': 0.9});
      
      expect(workflowState.transcribeAudioResult['text'], 'Hello world');
      expect(workflowState.transcribeAudioResult['confidence'], 0.9);
      expect(listenerCalled, isTrue);
      
      // After a slight delay for async operations to complete
      await Future.delayed(Duration.zero);
      
      // Check the data saved to SharedPreferences
      final jsonString = prefs.getString(key);
      expect(jsonString, isNotNull);
      
      // Check JSON contents
      final savedData = jsonDecode(jsonString!) as Map<String, dynamic>;
      expect(savedData['text'], 'Hello world');
    });

    test('setTranscribeAudioResult updates _transcribeAudioResult with null, calls notifyListeners, and clears text in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);
      await prefs.remove(key); // Start with clean state
      
      // Set the tip and tax values to simulate existing values
      workflowState.setTip(10.0);
      workflowState.setTax(5.0);
      
      // Setup initial data and verify
      workflowState.setTranscribeAudioResult({'text': 'Hello world'});
      
      // Allow async operations to complete
      await Future.delayed(Duration.zero);
      
      final initialPrefs = prefs.getString(key);
      expect(initialPrefs, isNotNull);
      
      // Reset listener flag
      listenerCalled = false;
      
      // Act: Set to null
      workflowState.setTranscribeAudioResult(null);
      
      // Allow async operations to complete
      await Future.delayed(Duration.zero);
      
      // Verify state
      expect(workflowState.transcribeAudioResult, isEmpty);
      expect(listenerCalled, isTrue); // Our implementation always calls listeners
      
      // Verify SharedPreferences - with tip/tax still there, the key will exist
      final finalPrefs = prefs.getString(key);
      
      // Since we set tip and tax values earlier, they should still be in the preferences
      // even though the text was removed
      expect(finalPrefs, isNotNull);
      final data = jsonDecode(finalPrefs!);
      expect(data.containsKey('text'), isFalse); // Text should be removed
      expect(data['tip'], equals(10.0)); // Tip should still be there
      expect(data['tax'], equals(5.0)); // Tax should still be there
    });

    test('setTranscribeAudioResult updates _transcribeAudioResult with empty map, calls notifyListeners, and clears text in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);
      await prefs.remove(key); // Start with clean state
      
      // Set the tip and tax values to simulate existing values
      workflowState.setTip(10.0);
      workflowState.setTax(5.0);
      
      // Setup initial data
      workflowState.setTranscribeAudioResult({'text': 'Hello world'});
      
      // Allow async operations to complete
      await Future.delayed(Duration.zero);
      
      // Reset listener flag
      listenerCalled = false;
      
      // Act: Set to empty map
      workflowState.setTranscribeAudioResult({});
      
      // Allow async operations to complete
      await Future.delayed(Duration.zero);
      
      // Verify state
      expect(workflowState.transcribeAudioResult, isEmpty);
      expect(listenerCalled, isTrue); // Our implementation always calls listeners
      
      // Verify SharedPreferences
      final finalPrefs = prefs.getString(key);
      
      // Since we set tip and tax values earlier, they should still be in the preferences
      // even though the text was removed
      expect(finalPrefs, isNotNull);
      final data = jsonDecode(finalPrefs!);
      expect(data.containsKey('text'), isFalse); // Text should be removed
      expect(data['tip'], equals(10.0)); // Tip should still be there
      expect(data['tax'], equals(5.0)); // Tax should still be there
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
    setUp(() async {
      // Ensure a text value is set to be preserved in saveTranscriptionToPrefs
      workflowState.setTranscribeAudioResult({'text': 'some text'});
      
      // Reset and wait for all async to complete
      listenerCalled = false;
      await Future.delayed(Duration.zero);
    });

    test('updates _tip, calls notifyListeners, and saves tip (and existing text/tax) to SharedPreferences', () async {
      // Setup by ensuring we have clean state
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance().then((prefs) async {
        final key = getTestTranscriptionPrefsKey(workflowState.receiptId);
        await prefs.remove(key);
      });
      
      // Set transcription first
      workflowState.setTranscribeAudioResult({'text': 'some text'});
      
      // Wait for async operations to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      // Create a fresh reference to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);
      
      // Confirm we have text but no tip yet
      final initialJson = prefs.getString(key);
      expect(initialJson, isNotNull);
      final initialData = jsonDecode(initialJson!);
      expect(initialData['text'], equals('some text'));
      expect(initialData.containsKey('tip'), isFalse);
      
      // Reset flag just before the specific action we're testing
      listenerCalled = false;
      
      // Act: Set tip
      final tipValue = 1.0;
      workflowState.setTip(tipValue);
      
      // Wait for async operations to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify state
      expect(workflowState.tip, equals(tipValue));
      
      // The listener is called by setTip in the actual implementation
      expect(listenerCalled, isTrue); // Per the updated implementation, setTip always calls notifyListeners
      
      // Verify SharedPreferences
      final finalJson = prefs.getString(key);
      expect(finalJson, isNotNull);
      final data = jsonDecode(finalJson!);
      expect(data['tip'], equals(tipValue));
      expect(data['text'], equals('some text')); // Original text preserved
    });

    test('updates _tip to null, calls notifyListeners, and removes tip from SharedPreferences', () async {
      // Start with a fresh SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Setup with initial tip value
      workflowState.setTranscribeAudioResult({'text': 'some text'});
      workflowState.setTip(5.0);
      
      // Wait for async operations to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);
      
      // Verify initial state saved correctly
      final initialJson = prefs.getString(key);
      expect(initialJson, isNotNull);
      expect(jsonDecode(initialJson!)['tip'], equals(5.0));
      
      // Reset listener flag
      listenerCalled = false;
      
      // Act: Set tip to null
      workflowState.setTip(null);
      
      // Wait for async operations to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify state
      expect(workflowState.tip, isNull);
      expect(listenerCalled, isTrue);
      
      // Verify SharedPreferences
      final finalJson = prefs.getString(key);
      
      // Either the key is removed entirely, or tip is no longer in the JSON
      if (finalJson == null) {
        // Key was removed (valid case if no other data)
      } else {
        // Key exists but should not contain 'tip'
        final data = jsonDecode(finalJson);
        expect(data['tip'], isNull);
        expect(data['text'], equals('some text')); // Text preserved
      }
    });
  });

  group('setTax', () {
    setUp(() async {
      // Ensure a text value is set to be preserved in saveTranscriptionToPrefs
      workflowState.setTranscribeAudioResult({'text': 'other text'});
      
      // Reset and wait for all async to complete
      listenerCalled = false;
      await Future.delayed(Duration.zero);
    });

    test('updates _tax, calls notifyListeners, and saves tax (and existing text/tip) to SharedPreferences', () async {
      // Start with a fresh SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Setup
      final taxValue = 2.0;
      
      // Setup text first
      workflowState.setTranscribeAudioResult({'text': 'other text'});
      
      // Wait for setup to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);
      
      // Reset listener flag
      listenerCalled = false;
      
      // Act
      workflowState.setTax(taxValue);
      
      // Wait for async operations to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify state
      expect(workflowState.tax, equals(taxValue));
      expect(listenerCalled, isTrue);
      
      // Verify SharedPreferences
      final storedJsonString = prefs.getString(key);
      expect(storedJsonString, isNotNull);
      
      final storedData = jsonDecode(storedJsonString!);
      expect(storedData['tax'], equals(taxValue));
      expect(storedData['text'], equals('other text')); // Original text preserved
    });

    test('updates _tax to null, calls notifyListeners, and removes tax from SharedPreferences', () async {
      // Start with a fresh SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Setup with initial text and tax value
      workflowState.setTranscribeAudioResult({'text': 'other text'});
      workflowState.setTax(7.5);
      
      // Wait for async operations to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(workflowState.receiptId);
      
      // Verify initial state saved correctly
      final initialJson = prefs.getString(key);
      expect(initialJson, isNotNull);
      expect(jsonDecode(initialJson!)['tax'], equals(7.5));
      
      // Reset listener flag
      listenerCalled = false;
      
      // Act: Set tax to null
      workflowState.setTax(null);
      
      // Wait for async operations to complete
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify state
      expect(workflowState.tax, isNull);
      expect(listenerCalled, isTrue);
      
      // Verify SharedPreferences
      final finalJson = prefs.getString(key);
      
      // Either the key is removed entirely, or tax is no longer in the JSON
      if (finalJson == null) {
        // Key was removed (valid case if no other data)
      } else {
        // Key exists but should not contain 'tax'
        final data = jsonDecode(finalJson);
        expect(data['tax'], isNull);
        expect(data['text'], equals('other text')); // Text preserved
      }
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

    test('_extractPeopleFromAssignments handles non-string person names in people list gracefully (if possible, though typing should prevent)', () {
      // This test simulates edge cases where a person name might not be a string, which
      // we need to handle gracefully even though our types *should* prevent this
      final mockAssignments = {
        'assignments': [
          {
            'item': 'ItemX',
            'people': ['Eve', 123, 'Frank', true, null]
          }
        ]
      };
      
      workflowState.setAssignPeopleToItemsResult(mockAssignments);
      // Expect Eve, Frank, and string representations of other non-null values
      expect(workflowState.people, unorderedEquals(['Eve', '123', 'Frank', 'true']));
    });

  });

  group('Persistence and Loading (loadTranscriptionFromPrefs / Constructor)', () {
    const testReceiptId = 'test-receipt-123';

    setUp(() async {
      // Reset and initialize SharedPreferences for each test separately
      SharedPreferences.setMockInitialValues({});
      
      // Create a fresh mock for the imageStateManager
      mockImageStateManager = MockImageStateManager();
      
      // Initialize workflowState
      workflowState = WorkflowState(
        restaurantName: 'Testaurant',
        receiptId: testReceiptId,
        imageStateManager: mockImageStateManager,
      );
      
      listenerCalled = false;
      workflowState.addListener(() {
        listenerCalled = true;
      });
    });

    test('loads transcription, tip, and tax from SharedPreferences by loadTranscriptionFromPrefs', () async {
      // Get the SharedPreferences instance for this test
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(testReceiptId);
      
      // Create test data
      final testData = {'text': 'loaded text', 'tip': 1.0, 'tax': 0.5};
      
      // Reset current state 
      workflowState.setTranscribeAudioResult({}); 
      workflowState.setTip(null); 
      workflowState.setTax(null);
      
      // Clear any existing data and save our test data
      await prefs.clear();
      await prefs.setString(key, jsonEncode(testData));
      
      // Reset listener flag before calling the method
      listenerCalled = false;
      
      // Call the method and wait properly for it to complete
      await workflowState.loadTranscriptionFromPrefs();
      // Additional wait to ensure all async operations are complete
      await Future.delayed(Duration(milliseconds: 50));
      
      // Verify state is updated
      expect(workflowState.transcribeAudioResult, containsValue('loaded text'));
      expect(workflowState.tip, equals(1.0));
      expect(workflowState.tax, equals(0.5));
      
      // Verify listener is called
      expect(listenerCalled, isTrue);
    });

    test('loads only available data from SharedPreferences via loadTranscriptionFromPrefs', () async {
      // Get the SharedPreferences instance for this test
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(testReceiptId);
      
      // Create test data with only text
      final testData = {'text': 'only text here'};
      
      // Reset current state and SharedPreferences
      workflowState.setTranscribeAudioResult({});
      workflowState.setTip(null);
      workflowState.setTax(null);
      
      // Clear and set our test data
      await prefs.clear();
      await prefs.setString(key, jsonEncode(testData));
      
      // Reset listener flag
      listenerCalled = false;
      
      // Call the method and ensure we wait for it to complete
      await workflowState.loadTranscriptionFromPrefs();
      // Additional wait to ensure all async operations are complete
      await Future.delayed(Duration(milliseconds: 50));
      
      // Verify state is updated
      expect(workflowState.transcribeAudioResult, containsValue('only text here'));
      expect(workflowState.tip, isNull);
      expect(workflowState.tax, isNull);
      
      // Verify listener is called
      expect(listenerCalled, isTrue);
    });

    test('handles empty or missing SharedPreferences entry gracefully during loadTranscriptionFromPrefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(testReceiptId);
      await prefs.remove(key); // Ensure no data

      // Set some initial state to ensure it's not wiped by a faulty load
      workflowState.setTranscribeAudioResult({'text': 'pre-existing'});
      workflowState.setTip(10.0);
      workflowState.setTax(5.0);
      
      // Reset listener flag
      listenerCalled = false;
      
      await workflowState.loadTranscriptionFromPrefs(); 

      // If no data for a field in prefs, it should not overwrite existing valid data with null.
      // The current implementation of loadTranscriptionFromPrefs sets fields if they exist in the loaded JSON.
      // If a key (like 'text') is not in JSON, it won't update that part of state.
      // If the entire entry for `key` is missing, nothing is loaded, state remains.
      expect(workflowState.transcribeAudioResult['text'], equals('pre-existing'));
      expect(workflowState.tip, equals(10.0));
      expect(workflowState.tax, equals(5.0));
      // Our implementation doesn't call notifyListeners in this case, but it doesn't matter
      // for the functional test - we're just testing the state remains unchanged
    });

    test('handles malformed JSON in SharedPreferences gracefully during loadTranscriptionFromPrefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(testReceiptId);
      await prefs.setString(key, "{malformed_json'");

      // Set some initial state to ensure it's not wiped by a faulty load
      workflowState.setTranscribeAudioResult({'text': 'stable text'});
      workflowState.setTip(1.0);
      workflowState.setTax(0.5);
      
      // Reset listener flag
      listenerCalled = false;
      
      await workflowState.loadTranscriptionFromPrefs();

      // Expect that state remains unchanged and no unhandled exception occurred
      expect(workflowState.transcribeAudioResult['text'], equals('stable text'));
      expect(workflowState.tip, equals(1.0));
      expect(workflowState.tax, equals(0.5));
      // Our implementation may call notifyListeners in error cases, but that's an implementation
      // detail - the important thing is that the state remains unchanged
    });

    test('correctly uses "draft" key for SharedPreferences when receiptId is null during save and load', () async {
      // First clear any existing SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Get the SharedPreferences instance for this test
      final prefs = await SharedPreferences.getInstance();
      final draftKey = getTestTranscriptionPrefsKey(null); // "transcription_draft"
      
      // Clear any existing data
      await prefs.remove(draftKey);
      
      // Create a new WorkflowState without a receiptId
      final mockImgManager = MockImageStateManager();
      final draftState = WorkflowState(
        restaurantName: 'Draft Restaurant',
        imageStateManager: mockImgManager, // receiptId is null
      );
      
      // Set some data to save
      draftState.setTranscribeAudioResult({'text': 'draft text'});
      draftState.setTip(1.1);
      
      // Wait for async operations to complete
      await Future.delayed(Duration(milliseconds: 100));

      // Verify data was saved under the draft key
      String? jsonString = prefs.getString(draftKey);
      expect(jsonString, isNotNull);
      
      final savedData = jsonDecode(jsonString!) as Map<String, dynamic>;
      expect(savedData['text'], equals('draft text'));
      expect(savedData['tip'], equals(1.1));

      // Set up the SharedPreferences again to ensure clean test
      await prefs.clear();
      await prefs.setString(draftKey, jsonEncode({'text': 'draft text', 'tip': 1.1}));
      
      // Create a fresh state to load the data
      final newMockImgManager = MockImageStateManager();
      final newDraftState = WorkflowState(
        restaurantName: 'New Draft Restaurant',
        imageStateManager: newMockImgManager,
        // No receiptId
      );
      
      // Wait for auto-loading to complete - use longer delay
      await Future.delayed(Duration(milliseconds: 100));
      
      // Verify data was loaded
      expect(newDraftState.transcribeAudioResult, containsValue('draft text'));
      expect(newDraftState.tip, equals(1.1));
      
      // Clean up
      await prefs.remove(draftKey);
    });

    test('WorkflowState constructor loads data if receiptId is present and data exists in SharedPreferences', () async {
      // First clear any existing SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Now get a reference to the fresh mock instance and set our data
      final prefs = await SharedPreferences.getInstance();
      final key = getTestTranscriptionPrefsKey(testReceiptId);
      final constructorTestData = {'text': 'constructor load', 'tip': 2.0, 'tax': 1.5};
      
      // Set the data in SharedPreferences
      await prefs.setString(key, jsonEncode(constructorTestData));
      
      // Create a new WorkflowState instance to trigger constructor loading logic
      final freshWorkflowState = WorkflowState(
        restaurantName: 'Constructor Test',
        receiptId: testReceiptId,
        imageStateManager: MockImageStateManager(),
      );
      
      // Allow loadTranscriptionFromPrefs (called by constructor) to complete
      // Use a longer delay to ensure async operations complete
      await Future.delayed(Duration(milliseconds: 100)); 

      // Check that data was loaded in constructor
      expect(freshWorkflowState.transcribeAudioResult, containsValue('constructor load'));
      expect(freshWorkflowState.tip, 2.0);
      expect(freshWorkflowState.tax, 1.5);
    });

  });

  group('toReceipt', () {
    test('generates a valid temporary ID when receiptId is null', () {
      // Create a fresh mock to avoid any state from previous tests
      final mockImgManager = MockImageStateManager();
      
      // Setup the mock behavior
      when(mockImgManager.actualImageGsUri).thenReturn('mock-image-uri');
      when(mockImgManager.actualThumbnailGsUri).thenReturn('mock-thumbnail-uri');
      
      // Create a new WorkflowState without a receiptId
      final workflowState = WorkflowState(
        restaurantName: 'Test Restaurant',
        receiptId: null,
        imageStateManager: mockImgManager,
      );

      // Get a Receipt from the WorkflowState
      final receipt = workflowState.toReceipt();

      // Verify the Receipt has a non-empty ID
      expect(receipt.id, isNotEmpty);
      // Verify the ID starts with our temporary prefix
      expect(receipt.id, startsWith('temp_'));
    });

    test('uses existing receiptId when available', () {
      // Create a fresh mock to avoid any state from previous tests
      final mockImgManager = MockImageStateManager();
      
      // Setup the mock behavior
      when(mockImgManager.actualImageGsUri).thenReturn('mock-image-uri');
      when(mockImgManager.actualThumbnailGsUri).thenReturn('mock-thumbnail-uri');
      
      // Create a WorkflowState with a receiptId
      final workflowState = WorkflowState(
        restaurantName: 'Test Restaurant',
        receiptId: 'existing-receipt-id',
        imageStateManager: mockImgManager,
      );

      // Get a Receipt from the WorkflowState
      final receipt = workflowState.toReceipt();

      // Verify the Receipt uses the existing ID
      expect(receipt.id, equals('existing-receipt-id'));
    });

    test('creates Receipt with correct data from WorkflowState', () {
      // Create a fresh mock to avoid any state from previous tests
      final mockImgManager = MockImageStateManager();
      
      // Setup the mock behavior
      when(mockImgManager.actualImageGsUri).thenReturn('gs://image-uri');
      when(mockImgManager.actualThumbnailGsUri).thenReturn('gs://thumbnail-uri');
      
      // Setup WorkflowState with all relevant data
      final workflowState = WorkflowState(
        restaurantName: 'Test Restaurant',
        receiptId: 'test-receipt-id',
        imageStateManager: mockImgManager,
      );

      // Set other WorkflowState properties
      workflowState.setParseReceiptResult({'items': [{'name': 'Item', 'price': 10}]});
      workflowState.setTranscribeAudioResult({'text': 'Sample text'});
      workflowState.setAssignPeopleToItemsResult({
        'assignments': [
          {'item': 'Item', 'people': ['Person1', 'Person2']}
        ]
      });
      workflowState.setTip(5.0);
      workflowState.setTax(2.0);

      // Get a Receipt from the WorkflowState
      final receipt = workflowState.toReceipt();

      // Verify Receipt properties match WorkflowState values
      expect(receipt.id, equals('test-receipt-id'));
      expect(receipt.restaurantName, equals('Test Restaurant'));
      expect(receipt.imageUri, equals('gs://image-uri'));
      expect(receipt.thumbnailUri, equals('gs://thumbnail-uri'));
      expect(receipt.parseReceipt, isNotEmpty);
      expect(receipt.transcribeAudio, isNotEmpty);
      expect(receipt.assignPeopleToItems, isNotEmpty);
      expect(receipt.status, equals('draft'));
      expect(receipt.people, isNotEmpty);
      expect(receipt.tip, equals(5.0));
      expect(receipt.tax, equals(2.0));
    });
  });
} 