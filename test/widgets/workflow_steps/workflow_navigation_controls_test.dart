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
      // No need to pass controls directly, it will be built using currentStep from mock
      required Future<void> Function() onExitAction, // Corrected type
      required Future<void> Function() onSaveDraftAction, // Corrected type
      required Future<void> Function() onCompleteAction, // Corrected type
    }) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<WorkflowState>.value(
          value: mockWorkflowState, // Reads currentStep from here
          child: MaterialApp(
            home: Scaffold(
              body: WorkflowNavigationControls(
                currentStep: mockWorkflowState.currentStep, // Pass currentStep from mock
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

      final backButtonFinder = find.widgetWithText(TextButton, 'Back');
      expect(backButtonFinder, findsOneWidget);
      TextButton backButton = tester.widget<TextButton>(backButtonFinder);
      expect(backButton.onPressed, isNotNull);

      await tester.tap(backButtonFinder);
      await tester.pump();

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
      
      final backButtonFinder = find.widgetWithText(TextButton, 'Back');
      expect(backButtonFinder, findsOneWidget); 
      TextButton backButton = tester.widget<TextButton>(backButtonFinder);
      expect(backButton.onPressed, isNull, reason: "Back button should be disabled at step 0");
    });

    group('Next Button', () {
      testWidgets('at step 0, "Next" button is visible',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(0);
        when(mockWorkflowState.hasParseData).thenReturn(true); // Enable button initially

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );

        expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
        expect(find.widgetWithIcon(FilledButton, Icons.arrow_forward), findsOneWidget);
      });

      testWidgets('at step 0, "Next" button is enabled if hasParseData is true and calls nextStep',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(0);
        when(mockWorkflowState.hasParseData).thenReturn(true);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );

        final nextButton = find.widgetWithText(FilledButton, 'Next');
        expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);

        await tester.tap(nextButton);
        await tester.pump();

        verify(mockWorkflowState.nextStep()).called(1);
      });

      testWidgets('at step 0, "Next" button is disabled if hasParseData is false',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(0);
        when(mockWorkflowState.hasParseData).thenReturn(false);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );

        final nextButton = find.widgetWithText(FilledButton, 'Next');
        expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
      });

      testWidgets('at step 1, "Next" button is visible and enabled, calls nextStep',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1);
        // No specific data required for step 1 according to current logic in WorkflowNavigationControls

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );

        final nextButton = find.widgetWithText(FilledButton, 'Next');
        expect(nextButton, findsOneWidget);
        expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);

        await tester.tap(nextButton);
        await tester.pump();

        verify(mockWorkflowState.nextStep()).called(1);
      });

      testWidgets('at step 2, "Next" button is visible',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true); // Enable initially

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
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

        final nextButton = find.widgetWithText(FilledButton, 'Next');
        expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);

        await tester.tap(nextButton);
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

        final nextButton = find.widgetWithText(FilledButton, 'Next');
        expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
      });

      testWidgets('at step 3, "Next" button is visible',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(3);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true); // Enable initially
        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
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

        final nextButton = find.widgetWithText(FilledButton, 'Next');
        expect(tester.widget<FilledButton>(nextButton).onPressed, isNotNull);

        await tester.tap(nextButton);
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

        final nextButton = find.widgetWithText(FilledButton, 'Next');
        expect(tester.widget<FilledButton>(nextButton).onPressed, isNull);
      });
    });

    group('Complete Button', () {
      testWidgets('at step 4, "Complete" button is visible and calls onCompleteAction',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(4);
        bool completeActionCalled = false;

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async { completeActionCalled = true; },
        );

        final completeButton = find.widgetWithText(FilledButton, 'Complete');
        expect(completeButton, findsOneWidget);
        expect(find.widgetWithIcon(FilledButton, Icons.check), findsOneWidget);
        expect(tester.widget<FilledButton>(completeButton).onPressed, isNotNull);

        // Verify "Next" button is not present
        expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);

        await tester.tap(completeButton);
        await tester.pump();

        expect(completeActionCalled, isTrue);
      });
    });

    group('Middle Button (Exit / Save Draft)', () {
      testWidgets('"Exit" button is visible and calls onExitAction when currentStep < 4',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1); // Example step < 4
        bool exitActionCalled = false;

        await pumpWidget(
          tester,
          onExitAction: () async { exitActionCalled = true; },
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );

        final exitButton = find.widgetWithText(OutlinedButton, 'Exit');
        expect(exitButton, findsOneWidget);
        expect(tester.widget<OutlinedButton>(exitButton).onPressed, isNotNull);

        // Verify "Save Draft" button is not present
        expect(find.widgetWithText(OutlinedButton, 'Save Draft'), findsNothing);

        await tester.tap(exitButton);
        await tester.pump();

        expect(exitActionCalled, isTrue);
      });

      testWidgets('"Save Draft" button is visible and calls onSaveDraftAction when currentStep == 4',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(4);
        bool saveDraftActionCalled = false;

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async { saveDraftActionCalled = true; },
          onCompleteAction: () async {},
        );

        final saveDraftButton = find.widgetWithText(OutlinedButton, 'Save Draft');
        expect(saveDraftButton, findsOneWidget);
        expect(tester.widget<OutlinedButton>(saveDraftButton).onPressed, isNotNull);

        // Verify "Exit" button is not present
        expect(find.widgetWithText(OutlinedButton, 'Exit'), findsNothing);

        await tester.tap(saveDraftButton);
        await tester.pump();

        expect(saveDraftActionCalled, isTrue);
      });
    });
  });
} 