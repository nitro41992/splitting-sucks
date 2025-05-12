import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/screens/voice_assignment_screen.dart';
import 'package:billfie/widgets/workflow_steps/assign_step_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Mock callbacks
class MockCallbacks {
  Future<bool> Function() mockOnConfirmProcessAssignments = () async => true;
  Future<bool> Function() mockOnReTranscribeRequested = () async => true;
  void Function(Map<String, dynamic>) mockOnAssignmentProcessed = (_) {};
  void Function(String?) mockOnTranscriptionChanged = (_) {};
}

void main() {
  group('AssignStepWidget Tests', () {
    late List<ReceiptItem> testItems;
    late MockCallbacks mockCallbacks;

    setUp(() {
      // Setup test data
      testItems = [
        ReceiptItem(itemId: 'item1', name: 'Burger', price: 10.99, quantity: 1),
        ReceiptItem(itemId: 'item2', name: 'Fries', price: 3.99, quantity: 2),
        ReceiptItem(itemId: 'item3', name: 'Drink', price: 2.49, quantity: 1),
      ];
      
      mockCallbacks = MockCallbacks();
    });

    // Helper to pump the widget
    Future<void> pumpAssignStepWidget(WidgetTester tester, {String? initialTranscription}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssignStepWidget(
              itemsToAssign: testItems,
              initialTranscription: initialTranscription,
              onAssignmentProcessed: mockCallbacks.mockOnAssignmentProcessed,
              onTranscriptionChanged: mockCallbacks.mockOnTranscriptionChanged,
              onReTranscribeRequested: mockCallbacks.mockOnReTranscribeRequested,
              onConfirmProcessAssignments: mockCallbacks.mockOnConfirmProcessAssignments,
            ),
          ),
        ),
      );
    }

    testWidgets('Should render VoiceAssignmentScreen with correct items', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Verify VoiceAssignmentScreen is rendered
      expect(find.byType(VoiceAssignmentScreen), findsOneWidget);
      
      // Verify all test items are passed to VoiceAssignmentScreen
      // This requires exposing item names in the UI or having testable keys
      expect(find.text('Burger'), findsOneWidget);
      expect(find.text('Fries'), findsOneWidget);
      expect(find.text('Drink'), findsOneWidget);
    });

    testWidgets('Should display initial transcription when provided', (WidgetTester tester) async {
      const testTranscription = 'Alice gets the burger, Bob gets the fries, and they share the drink';
      
      await pumpAssignStepWidget(tester, initialTranscription: testTranscription);
      
      // TextFields often render text as part of their hierarchy
      expect(find.textContaining(testTranscription), findsAtLeastNWidgets(1));
    });

    testWidgets('Should have record button for voice input', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Look for a microphone icon button that would start recording
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('Should have process button for assignment processing', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Look for a button with text containing "Process" or similar
      expect(find.textContaining('Process', findRichText: true), findsAtLeastNWidgets(1));
    });

    // Tests for callback triggering
    testWidgets('Should trigger onTranscriptionChanged when transcription is updated', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      bool callbackTriggered = false;
      String? capturedTranscription;
      
      mockCallbacks.mockOnTranscriptionChanged = (transcription) {
        callbackTriggered = true;
        capturedTranscription = transcription;
      };
      
      // Find the transcription text field
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      
      // Enter new text
      const newTranscription = 'Charlie gets the burger';
      await tester.enterText(textField, newTranscription);
      await tester.pump();
      
      // Check if callback was triggered with correct data
      expect(callbackTriggered, isTrue);
      expect(capturedTranscription, equals(newTranscription));
    });
    
    testWidgets('Should trigger onConfirmProcessAssignments when process button is tapped', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      bool callbackTriggered = false;
      mockCallbacks.mockOnConfirmProcessAssignments = () async {
        callbackTriggered = true;
        return true;
      };
      
      // Find and tap the process button
      final processButton = find.textContaining('Process', findRichText: true);
      expect(processButton, findsAtLeastNWidgets(1));
      
      await tester.tap(processButton.first);
      await tester.pumpAndSettle();
      
      // Check if callback was triggered
      expect(callbackTriggered, isTrue);
    });
    
    testWidgets('Should trigger onReTranscribeRequested when re-transcribe button is tapped', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      bool callbackTriggered = false;
      mockCallbacks.mockOnReTranscribeRequested = () async {
        callbackTriggered = true;
        return true;
      };
      
      // Find and tap the re-transcribe button
      final reTranscribeButton = find.byIcon(Icons.refresh);
      expect(reTranscribeButton, findsOneWidget);
      
      await tester.tap(reTranscribeButton);
      await tester.pumpAndSettle();
      
      // Check if callback was triggered
      expect(callbackTriggered, isTrue);
    });
    
    // Tests for UI updates in response to state changes
    testWidgets('Should show loading indicator when processing assignments', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Setup a delayed response for the process callback
      mockCallbacks.mockOnConfirmProcessAssignments = () async {
        await Future.delayed(const Duration(milliseconds: 100));
        return true;
      };
      
      // Find and tap the process button
      final processButton = find.textContaining('Process', findRichText: true);
      await tester.tap(processButton.first);
      await tester.pump(); // Pump once to start showing loading
      
      // Check for loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Wait for processing to complete
      await tester.pumpAndSettle();
      
      // Loading indicator should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
    
    // Tests for error states
    testWidgets('Should show error message when processing fails', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Setup a failing response for the process callback
      mockCallbacks.mockOnConfirmProcessAssignments = () async {
        await Future.delayed(const Duration(milliseconds: 100));
        return false; // Indicates failure
      };
      
      // Find and tap the process button
      final processButton = find.textContaining('Process', findRichText: true);
      await tester.tap(processButton.first);
      await tester.pumpAndSettle();
      
      // Check for error message
      expect(find.textContaining('failed', findRichText: true), findsOneWidget);
    });
    
    testWidgets('Should disable process button when transcription is empty', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Find the transcription text field
      final textField = find.byType(TextField);
      
      // Clear the text
      await tester.enterText(textField, '');
      await tester.pump();
      
      // Find the process button
      final processButton = find.textContaining('Process', findRichText: true);
      
      // Check if the button is disabled
      final buttonWidget = tester.widget<ElevatedButton>(
        find.ancestor(
          of: processButton.first,
          matching: find.byType(ElevatedButton),
        ),
      );
      
      expect(buttonWidget.enabled, isFalse);
    });
  });
} 