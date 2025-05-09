import 'package:billfie/providers/workflow_state.dart';
import 'package:billfie/widgets/workflow_steps/workflow_navigation_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../../../test/mocks.mocks.dart'; // Corrected import path

void main() {
  group('WorkflowNavigationControls Widget Tests', () {
    late MockWorkflowState mockWorkflowState;

    // Helper function to pump the widget
    Future<void> pumpWidget(WidgetTester tester, {
      required Future<void> Function() onExitAction,
      required Future<void> Function() onSaveDraftAction,
      required Future<void> Function() onCompleteAction,
    }) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<WorkflowState>.value(
          value: mockWorkflowState,
          child: MaterialApp(
            home: Scaffold(
              body: WorkflowNavigationControls(
                onExitAction: onExitAction,
                onSaveDraftAction: onSaveDraftAction,
                onCompleteAction: onCompleteAction,
              ),
            ),
          ),
        ),
      );
    }

    setUp(() {
      mockWorkflowState = MockWorkflowState();
      when(mockWorkflowState.currentStep).thenReturn(0);
      when(mockWorkflowState.hasParseData).thenReturn(false);
      when(mockWorkflowState.hasTranscriptionData).thenReturn(false);
      when(mockWorkflowState.hasAssignmentData).thenReturn(false);
      when(mockWorkflowState.isLoading).thenReturn(false);
      // Add when(...).thenAnswer(...) for methods like previousStep/nextStep if they return Futures
      when(mockWorkflowState.previousStep()).thenAnswer((_) async {});
      when(mockWorkflowState.nextStep()).thenAnswer((_) async {});
    });

    testWidgets('Back button is visible and enabled when currentStep > 0, calls previousStep on tap', (WidgetTester tester) async {
      when(mockWorkflowState.currentStep).thenReturn(1);

      await pumpWidget(
        tester,
        onExitAction: () async {},
        onSaveDraftAction: () async {},
        onCompleteAction: () async {},
      );
      await tester.pumpAndSettle();

      final backButtonFinder = find.byKey(backButtonKey);
      expect(backButtonFinder, findsOneWidget);
      TextButton backButton = tester.widget<TextButton>(backButtonFinder);
      expect(backButton.onPressed, isNotNull);

      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();

      verify(mockWorkflowState.previousStep()).called(1);
    });
    
    testWidgets('Back button is present but disabled when currentStep == 0', (WidgetTester tester) async {
      when(mockWorkflowState.currentStep).thenReturn(0);

      await pumpWidget(
        tester,
        onExitAction: () async {},
        onSaveDraftAction: () async {},
        onCompleteAction: () async {},
      );
      await tester.pumpAndSettle();

      final backButtonFinder = find.byKey(backButtonKey);
      expect(backButtonFinder, findsOneWidget);
      TextButton backButton = tester.widget<TextButton>(backButtonFinder);
      expect(backButton.onPressed, isNull, reason: "Back button should be disabled at step 0");
    });

    group('Next Button', () {
      testWidgets('at step 0, "Next" button is visible',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(0);
        when(mockWorkflowState.hasParseData).thenReturn(true);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
      });

      testWidgets(
          'at step 0, "Next" button is enabled if hasParseData is true and calls nextStep',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(0);
        when(mockWorkflowState.hasParseData).thenReturn(true);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        FilledButton nextButton = tester.widget<FilledButton>(nextButtonFinder);
        expect(nextButton.onPressed, isNotNull);

        await tester.tap(nextButtonFinder);
        await tester.pumpAndSettle();

        verify(mockWorkflowState.nextStep()).called(1);
      });

      testWidgets(
          'at step 0, "Next" button is disabled if hasParseData is false',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(0);
        when(mockWorkflowState.hasParseData).thenReturn(false);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();
        
        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        FilledButton nextButton = tester.widget<FilledButton>(nextButtonFinder);
        expect(nextButton.onPressed, isNull);
      });

      testWidgets('at step 1, "Next" button is visible and enabled, calls nextStep',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        expect(tester.widget<FilledButton>(nextButtonFinder).onPressed, isNotNull);

        await tester.tap(nextButtonFinder);
        await tester.pump();

        verify(mockWorkflowState.nextStep()).called(1);
      });

      testWidgets('at step 2, "Next" button is visible',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true); // For visibility, assume enabled

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();
        // Explicitly ensure this uses find.byKey
        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
      });

      testWidgets('at step 2, "Next" button is enabled if hasAssignmentData is true and calls nextStep',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(tester.widget<FilledButton>(nextButtonFinder).onPressed, isNotNull);

        await tester.tap(nextButtonFinder);
        await tester.pump();

        verify(mockWorkflowState.nextStep()).called(1);
      });

      testWidgets('at step 2, "Next" button is disabled if hasAssignmentData is false',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2);
        when(mockWorkflowState.hasAssignmentData).thenReturn(false);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(tester.widget<FilledButton>(nextButtonFinder).onPressed, isNull);
      });

      testWidgets('at step 3, "Next" button is visible',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(3);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true); // For visibility, assume enabled
        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();
        // Explicitly ensure this uses find.byKey
        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
      });

      testWidgets('at step 3, "Next" button is enabled if hasAssignmentData is true and calls nextStep',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(3);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(tester.widget<FilledButton>(nextButtonFinder).onPressed, isNotNull);

        await tester.tap(nextButtonFinder);
        await tester.pump();

        verify(mockWorkflowState.nextStep()).called(1);
      });

      testWidgets('at step 3, "Next" button is disabled if hasAssignmentData is false',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(3);
        when(mockWorkflowState.hasAssignmentData).thenReturn(false);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(tester.widget<FilledButton>(nextButtonFinder).onPressed, isNull);
      });

      testWidgets('at step 1 (Review), "Next" button is visible and enabled', (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1);
        // No specific data check for Review step to enable Next, it's always enabled if on this step.
        // The actual navigation to Review step would have checked for parseData.
        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        FilledButton nextButton = tester.widget<FilledButton>(nextButtonFinder);
        expect(nextButton.onPressed, isNotNull);

        await tester.tap(nextButtonFinder);
        await tester.pumpAndSettle();
        verify(mockWorkflowState.nextStep()).called(1);
      });

      testWidgets('at step 2 (Assign), "Next" button is enabled if hasAssignmentData is true', (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        FilledButton nextButton = tester.widget<FilledButton>(nextButtonFinder);
        expect(nextButton.onPressed, isNotNull);

        await tester.tap(nextButtonFinder);
        await tester.pumpAndSettle();
        verify(mockWorkflowState.nextStep()).called(1);
      });

      testWidgets('at step 2 (Assign), "Next" button is disabled if hasAssignmentData is false', (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2);
        when(mockWorkflowState.hasAssignmentData).thenReturn(false);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        FilledButton nextButton = tester.widget<FilledButton>(nextButtonFinder);
        expect(nextButton.onPressed, isNull);
      });
      
      testWidgets('at step 3 (Split), "Next" button is enabled if hasAssignmentData is true', (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(3);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        FilledButton nextButton = tester.widget<FilledButton>(nextButtonFinder);
        expect(nextButton.onPressed, isNotNull);

        await tester.tap(nextButtonFinder);
        await tester.pumpAndSettle();
        verify(mockWorkflowState.nextStep()).called(1);
      });

      testWidgets('at step 3 (Split), "Next" button is disabled if hasAssignmentData is false', (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(3);
        when(mockWorkflowState.hasAssignmentData).thenReturn(false);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        FilledButton nextButton = tester.widget<FilledButton>(nextButtonFinder);
        expect(nextButton.onPressed, isNull);
      });
    });

    group('Complete Button', () {
      testWidgets('is visible and enabled at step 4 (Summary)', (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(4);
        // For "Complete", there isn't an explicit enable/disable based on data like "Next".
        // It relies on the onCompleteAction callback.
        bool onCompleteCalled = false;
        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async { onCompleteCalled = true; },
        );
        await tester.pumpAndSettle();

        final completeButtonFinder = find.byKey(completeButtonKey);
        expect(completeButtonFinder, findsOneWidget);
        FilledButton completeButton = tester.widget<FilledButton>(completeButtonFinder);
        expect(completeButton.onPressed, isNotNull);

        await tester.tap(completeButtonFinder);
        await tester.pumpAndSettle();
        expect(onCompleteCalled, isTrue);
      });

      testWidgets('"Complete" button is not visible if currentStep < 4', (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(3); // e.g. Split step

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();
        
        final completeButtonFinder = find.byKey(completeButtonKey);
        expect(completeButtonFinder, findsNothing);
      });
    });

    group('Exit/Save Draft Button', () {
      testWidgets('"Exit" button is visible and calls onExitAction when currentStep < 4', (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1); // e.g. Review step
        bool onExitCalled = false;

        await pumpWidget(
          tester,
          onExitAction: () async { onExitCalled = true; },
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final exitButtonFinder = find.byKey(exitButtonKey);
        expect(exitButtonFinder, findsOneWidget);
        OutlinedButton exitButton = tester.widget<OutlinedButton>(exitButtonFinder);
        expect(exitButton.onPressed, isNotNull);

        await tester.tap(exitButtonFinder);
        await tester.pumpAndSettle();
        expect(onExitCalled, isTrue);
      });

      testWidgets('"Save Draft" button is visible and calls onSaveDraftAction when currentStep == 4', (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(4); // Summary step
        bool onSaveDraftCalled = false;

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async { onSaveDraftCalled = true; },
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();
        
        final saveDraftButtonFinder = find.byKey(saveDraftButtonKey);
        expect(saveDraftButtonFinder, findsOneWidget);
        OutlinedButton saveDraftButton = tester.widget<OutlinedButton>(saveDraftButtonFinder);
        expect(saveDraftButton.onPressed, isNotNull);
        
        await tester.tap(saveDraftButtonFinder);
        await tester.pumpAndSettle();
        expect(onSaveDraftCalled, isTrue);
      });
    });
  });
} 