import 'package:billfie/models/receipt_item.dart';
import 'package:billfie/services/audio_transcription_service.dart';
import 'package:billfie/widgets/workflow_steps/assign_step_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../../test_helpers/firebase_mock_setup.dart';

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

// Mock AudioTranscriptionService
class MockAudioService extends Mock implements AudioTranscriptionService {
  @override
  Future<String> getTranscription(dynamic _) async {
    return 'This is a mock transcription';
  }

  @override
  Future<AssignmentResult> assignPeopleToItems(String _, Map<String, dynamic> __) async {
    return AssignmentResult.fromJson({
      'assignments': [
        {
          'person_name': 'Alice',
          'items': [{'name': 'Burger', 'price': 10.99, 'quantity': 1}],
        },
      ],
      'shared_items': [],
      'unassigned_items': []
    });
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
    }, skip: true);

    testWidgets('Should display initial transcription when provided', (WidgetTester tester) async {
      const testTranscription = 'Alice gets the burger, Bob gets the fries';
      
      await pumpAssignStepWidget(tester, initialTranscription: testTranscription);
      
      // Verify the transcription is displayed in a TextField
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      expect(find.text(testTranscription), findsOneWidget);
    }, skip: true);

    testWidgets('Should have mic button for voice input', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Look for a mic icon button
      expect(find.byIcon(Icons.mic), findsAtLeastNWidgets(1));
    }, skip: true);

    testWidgets('Should have process button for assignments', (WidgetTester tester) async {
      await pumpAssignStepWidget(tester);
      
      // Look for a button that processes assignments
      expect(find.widgetWithText(ElevatedButton, 'Process'), findsOneWidget);
    }, skip: true);

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
    }, skip: true);
  });
} 