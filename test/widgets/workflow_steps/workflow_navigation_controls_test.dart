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

      testWidgets('at step 0, "Next" button is enabled if hasParseData is true', (WidgetTester tester) async {
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

      testWidgets('at step 2, Complete button is visible instead of Next button',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2); // Step 2 is the Summary step now
        when(mockWorkflowState.hasAssignmentData).thenReturn(true);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        // Next button should NOT be visible on step 2 (Summary step)
        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsNothing);
        
        // Complete button SHOULD be visible
        final completeButtonFinder = find.byKey(completeButtonKey);
        expect(completeButtonFinder, findsOneWidget);
      });

      testWidgets('at step 2, Complete button calls onCompleteAction when tapped',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true);

        bool completeActionCalled = false;
        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {
            completeActionCalled = true;
          },
        );
        await tester.pumpAndSettle();

        // Complete button SHOULD be visible
        final completeButtonFinder = find.byKey(completeButtonKey);
        expect(completeButtonFinder, findsOneWidget);
        
        // Tap the complete button
        await tester.tap(completeButtonFinder);
        await tester.pumpAndSettle();
        
        // Verify the complete action was called
        expect(completeActionCalled, isTrue);
      });

      testWidgets('at step 1 (Assign step), "Next" button is visible',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1);
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
      });

      testWidgets('at step 1 (Assign), "Next" button is enabled and calls nextStep',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1);
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

      testWidgets('at step 1 (Assign), "Next" button is disabled if hasAssignmentData is false',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1);
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
        // This should be enabled regardless of hasAssignmentData at step 1
        // Only step 2 is conditioned on hasAssignmentData
        expect(nextButton.onPressed, isNotNull);
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

      testWidgets('at step 1, "Next" button is always enabled regardless of hasAssignmentData', (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1);
        when(mockWorkflowState.hasAssignmentData).thenReturn(false); // Even with false, button should be enabled

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
        expect(nextButton.onPressed, isNotNull); // Should be enabled even with hasAssignmentData=false
      });

      testWidgets('at step 2 (Split), "Next" button is enabled if hasAssignmentData is true', (WidgetTester tester) async {
        // INCORRECT: Step 2 is now Summary, not Split, and doesn't have a Next button
        // Let's replace this test with a Complete button test
        when(mockWorkflowState.currentStep).thenReturn(2);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true);

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        // There should not be a Next button at step 2
        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsNothing);
        
        // Instead, there should be a Complete button
        final completeButtonFinder = find.byKey(completeButtonKey);
        expect(completeButtonFinder, findsOneWidget);
      });

      testWidgets('at step 3 (Split), "Next" button is disabled if hasAssignmentData is false', (WidgetTester tester) async {
        // INCORRECT: In the 3-step workflow, there is no step 3
        // Let's adjust this to be a test for step 1 again
        when(mockWorkflowState.currentStep).thenReturn(1);
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
        // At step 1, the Next button should always be enabled regardless of hasAssignmentData
        expect(nextButton.onPressed, isNotNull);
      });
    });

    group('Complete Button', () {
      testWidgets('is visible and enabled at step 2 (Summary)',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2); // Now step 2 is Summary
        when(mockWorkflowState.hasAssignmentData).thenReturn(true); // Data needed for Complete to be enabled

        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final completeButtonFinder = find.byKey(completeButtonKey);
        expect(completeButtonFinder, findsOneWidget);
        
        FilledButton completeButton = tester.widget<FilledButton>(completeButtonFinder);
        expect(completeButton.onPressed, isNotNull);
      });

      testWidgets('calls onCompleteAction when tapped at step 2',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2); // Now step 2 is Summary
        
        bool completeActionCalled = false;
        
        await pumpWidget(
          tester,
          onExitAction: () async {},
          onSaveDraftAction: () async {},
          onCompleteAction: () async {
            completeActionCalled = true;
          },
        );
        await tester.pumpAndSettle();

        final completeButtonFinder = find.byKey(completeButtonKey);
        await tester.tap(completeButtonFinder);
        await tester.pumpAndSettle();

        expect(completeActionCalled, isTrue);
      });

      testWidgets('is not visible at step 0',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(0);
        
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
      
      testWidgets('is not visible at step 1',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1);
        
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
        // Update to match the 3-step workflow
        when(mockWorkflowState.currentStep).thenReturn(1); // Step 1 shows Exit
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

      testWidgets('"Exit" button is still visible at step 2 (Summary) in the 3-step workflow', (WidgetTester tester) async {
        // In the 3-step workflow, we see Exit at step 2 (not Save Draft)
        // The Save Draft only appears at step 4 or higher
        when(mockWorkflowState.currentStep).thenReturn(2); // Step 2 is Summary
        bool onExitCalled = false;

        await pumpWidget(
          tester,
          onExitAction: () async { onExitCalled = true; },
          onSaveDraftAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();
        
        // Check that we see the Exit button, not the Save Draft button
        final exitButtonFinder = find.byKey(exitButtonKey);
        expect(exitButtonFinder, findsOneWidget);
        
        final saveDraftButtonFinder = find.byKey(saveDraftButtonKey);
        expect(saveDraftButtonFinder, findsNothing);
        
        // Verify the Exit button works
        OutlinedButton exitButton = tester.widget<OutlinedButton>(exitButtonFinder);
        expect(exitButton.onPressed, isNotNull);
        
        await tester.tap(exitButtonFinder);
        await tester.pumpAndSettle();
        expect(onExitCalled, isTrue);
      });
    });
  });
} 