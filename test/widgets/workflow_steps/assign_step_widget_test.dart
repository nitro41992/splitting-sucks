import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/services/audio_transcription_service.dart';
import 'package:billfie/widgets/workflow_steps/assign_step_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../../test_helpers/firebase_mock_setup.dart';
import 'dart:async';
import 'dart:typed_data';

// Custom widget that wraps the AssignStepWidget for testing
class AssignStepTestWrapper extends StatelessWidget {
  final List<ReceiptItem> itemsToAssign;
  final String? initialTranscription;
  final Function(Map<String, dynamic>) onAssignmentProcessed;
  final Function(String?) onTranscriptionChanged;
  final Future<bool> Function() onReTranscribeRequested;
  final Future<bool> Function() onConfirmProcessAssignments;
  final AudioTranscriptionService mockAudioService;

  const AssignStepTestWrapper({
    Key? key,
    required this.itemsToAssign,
    this.initialTranscription,
    required this.onAssignmentProcessed,
    required this.onTranscriptionChanged,
    required this.onReTranscribeRequested,
    required this.onConfirmProcessAssignments,
    required this.mockAudioService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Provider<AudioTranscriptionService>.value(
          value: mockAudioService,
          child: AssignStepWidget(
            itemsToAssign: itemsToAssign,
            initialTranscription: initialTranscription,
            onAssignmentProcessed: onAssignmentProcessed,
            onTranscriptionChanged: onTranscriptionChanged,
            onReTranscribeRequested: onReTranscribeRequested,
            onConfirmProcessAssignments: onConfirmProcessAssignments,
          ),
        ),
      ),
    );
  }
}

// Mock callbacks
class MockCallbacks {
  Future<bool> Function() mockOnConfirmProcessAssignments = () async => true;
  Future<bool> Function() mockOnReTranscribeRequested = () async => true;
  void Function(Map<String, dynamic>) mockOnAssignmentProcessed = (_) {};
  void Function(String?) mockOnTranscriptionChanged = (_) {};
}

// MODIFIED Mock AudioTranscriptionService
class MockAudioService extends Mock implements AudioTranscriptionService {
  Completer<AssignmentResult>? _assignmentCompleterForTest;
  Future<String> Function(Uint8List)? getTranscriptionForTestOverride;

  void setAssignmentCompleter(Completer<AssignmentResult> completer) {
    _assignmentCompleterForTest = completer;
  }

  void setGetTranscriptionOverride(Future<String> Function(Uint8List) overrideFn) {
    getTranscriptionForTestOverride = overrideFn;
  }

  @override
  Future<String> getTranscription(Uint8List audioBytes) async {
    if (getTranscriptionForTestOverride != null) {
      return getTranscriptionForTestOverride!(audioBytes);
    }
    // Default mock behavior or use super.noSuchMethod if preferred for general cases
    return Future.value('Default mock transcription');
  }

  @override
  Future<AssignmentResult> assignPeopleToItems(String transcription, Map<String, dynamic> items) async {
    if (_assignmentCompleterForTest != null) {
      return _assignmentCompleterForTest!.future;
    }
    // Default fallback if no specific completer is set by a test
    return Future.value(AssignmentResult.fromJson({
      'assignments': [{'person_name': 'DefaultPerson', 'items': []}],
      'shared_items': [],
      'unassigned_items': []
    }));
  }
}

void main() {
  // Setup test environment
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Call setupFirebaseForTesting to configure the test environment
  setUpAll(() async {
    await setupFirebaseForTesting();
  });
  
  group('AssignStepWidget Tests', () {
    late List<ReceiptItem> testItems;
    late MockCallbacks mockCallbacks;
    late MockAudioService mockAudioService;

    setUp(() {
      // Setup test data
      testItems = [
        ReceiptItem(itemId: 'item1', name: 'Burger', price: 10.99, quantity: 1),
        ReceiptItem(itemId: 'item2', name: 'Fries', price: 3.99, quantity: 2),
        ReceiptItem(itemId: 'item3', name: 'Drink', price: 2.49, quantity: 1),
      ];
      
      mockCallbacks = MockCallbacks();
      mockAudioService = MockAudioService();
    });

    // Helper to pump the widget
    Future<void> pumpAssignStepWidget(WidgetTester tester, {String? initialTranscription}) async {
      await tester.pumpWidget(
        AssignStepTestWrapper(
          itemsToAssign: testItems,
          initialTranscription: initialTranscription,
          onAssignmentProcessed: mockCallbacks.mockOnAssignmentProcessed,
          onTranscriptionChanged: mockCallbacks.mockOnTranscriptionChanged,
          onReTranscribeRequested: mockCallbacks.mockOnReTranscribeRequested,
          onConfirmProcessAssignments: mockCallbacks.mockOnConfirmProcessAssignments,
          mockAudioService: mockAudioService,
        ),
      );
      
      // Pump a few frames to allow async operations to complete
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('Should render with items list and transcription field', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Verify there's a transcription text field
      expect(find.byType(TextField), findsOneWidget);
      
      // Verify item names are displayed
      expect(find.text('Burger'), findsOneWidget);
      expect(find.text('Fries'), findsOneWidget);
      expect(find.text('Drink'), findsOneWidget);
    });

    testWidgets('Should display initial transcription when provided', (WidgetTester tester) async {
      const testTranscription = 'Alice gets the burger, Bob gets the fries';
      
      await pumpAssignStepWidget(tester, initialTranscription: testTranscription);
      
      // Verify the transcription is displayed in a TextField
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      expect(find.text(testTranscription), findsOneWidget);
    });

    testWidgets('Should have mic button for voice input', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Look for a mic icon button
      expect(find.byIcon(Icons.mic), findsAtLeastNWidgets(1));
    });

    testWidgets('Should have process button for assignments', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Look for a button that processes assignments
      expect(find.widgetWithText(ElevatedButton, 'Process'), findsOneWidget);
    });

    testWidgets('Should trigger onTranscriptionChanged when text changes', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      bool callbackTriggered = false;
      String? capturedTranscription;
      
      mockCallbacks.mockOnTranscriptionChanged = (transcription) {
        callbackTriggered = true;
        capturedTranscription = transcription;
      };
      
      // Find and update the transcription field
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'New transcription text');
      await tester.pump();
      
      // Verify callback was triggered
      expect(callbackTriggered, isTrue);
      expect(capturedTranscription, 'New transcription text');
    });

    testWidgets('tapping "Process" button shows loading indicator, calls service, then hides indicator', (tester) async {
      // This test now uses proper mocks and doesn't need Firebase
      final assignmentCompleter = Completer<AssignmentResult>();
      final mockReturnResult = AssignmentResult.fromJson({
        'assignments': [{'person_name': 'TestPerson', 'items': []}],
        'shared_items': [],
        'unassigned_items': []
      });

      // Use the custom mock's method to set the completer
      mockAudioService.setAssignmentCompleter(assignmentCompleter);

      mockCallbacks.mockOnConfirmProcessAssignments = () async => true;
      bool onAssignmentProcessedCalled = false;
      mockCallbacks.mockOnAssignmentProcessed = (data) {
        onAssignmentProcessedCalled = true;
      };

      await pumpAssignStepWidget(tester, initialTranscription: 'Alice gets burger');

      final processButtonFinder = find.widgetWithText(ElevatedButton, 'Process');
      expect(processButtonFinder, findsOneWidget);

      await tester.tap(processButtonFinder);
      await tester.pump(); 

      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: "Loading indicator should be shown after tapping Process.");

      assignmentCompleter.complete(mockReturnResult);
      await tester.pumpAndSettle(); 

      expect(find.byType(CircularProgressIndicator), findsNothing, reason: "Loading indicator should be hidden after processing is complete.");
      expect(onAssignmentProcessedCalled, isTrue, reason: "onAssignmentProcessed callback should be triggered.");
    });

  });
} 