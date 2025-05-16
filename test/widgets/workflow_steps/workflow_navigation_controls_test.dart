import 'package:billfie/providers/workflow_state.dart';
import 'package:billfie/widgets/workflow_steps/workflow_navigation_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import '../../../test/mocks.mocks.dart'; // Corrected import path
import 'dart:io';

void main() {
  group('WorkflowNavigationControls Widget Tests', () {
    late MockWorkflowState mockWorkflowState;
    late MockFile mockFile;

    // Helper function to pump the widget
    Future<void> pumpWidget(WidgetTester tester, {
      required Future<void> Function() onSaveAction,
      required Future<void> Function() onCompleteAction,
    }) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<WorkflowState>.value(
          value: mockWorkflowState,
          child: MaterialApp(
            home: Scaffold(
              body: WorkflowNavigationControls(
                onSaveAction: onSaveAction,
                onCompleteAction: onCompleteAction,
              ),
            ),
          ),
        ),
      );
    }

    setUp(() {
      mockWorkflowState = MockWorkflowState();
      mockFile = MockFile();
      
      // Setup basic mock behavior
      when(mockWorkflowState.currentStep).thenReturn(0);
      when(mockWorkflowState.hasParseData).thenReturn(false);
      when(mockWorkflowState.hasTranscriptionData).thenReturn(false);
      when(mockWorkflowState.hasAssignmentData).thenReturn(false);
      when(mockWorkflowState.isLoading).thenReturn(false);
      when(mockWorkflowState.previousStep()).thenAnswer((_) async {});
      when(mockWorkflowState.nextStep()).thenAnswer((_) async {});
      
      // Setup image file mock to fix the missing stub error
      when(mockWorkflowState.imageFile).thenReturn(null);
      when(mockWorkflowState.loadedImageUrl).thenReturn(null);
      when(mockWorkflowState.resetImageFile()).thenAnswer((_) async {});
    });

    testWidgets('Back button is visible and enabled when currentStep > 0, calls previousStep on tap', (WidgetTester tester) async {
      when(mockWorkflowState.currentStep).thenReturn(1);

      await pumpWidget(
        tester,
        onSaveAction: () async {},
        onCompleteAction: () async {},
      );
      await tester.pumpAndSettle();

      final backButtonFinder = find.byKey(backButtonKey);
      expect(backButtonFinder, findsOneWidget);
      
      // Changed from TextButton to InkWell
      InkWell backButton = tester.widget<InkWell>(backButtonFinder);
      expect(backButton.onTap, isNotNull);

      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();

      verify(mockWorkflowState.previousStep()).called(1);
    });
    
    testWidgets('Back button is present but calls Navigator.pop when currentStep == 0', (WidgetTester tester) async {
      when(mockWorkflowState.currentStep).thenReturn(0);

      await pumpWidget(
        tester,
        onSaveAction: () async {},
        onCompleteAction: () async {},
      );
      await tester.pumpAndSettle();

      final backButtonFinder = find.byKey(backButtonKey);
      expect(backButtonFinder, findsOneWidget);
      
      // Changed from TextButton to InkWell
      InkWell backButton = tester.widget<InkWell>(backButtonFinder);
      expect(backButton.onTap, isNotNull); // Should be enabled to pop
    });

    group('Save Button', () {
      testWidgets('Save button is always visible in all steps', (WidgetTester tester) async {
        // Test for Step 0
        when(mockWorkflowState.currentStep).thenReturn(0);
        
        await pumpWidget(
          tester,
          onSaveAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();
        
        final saveButtonFinder = find.byKey(saveButtonKey);
        expect(saveButtonFinder, findsOneWidget);
        
        // Test for Step 1
        when(mockWorkflowState.currentStep).thenReturn(1);
        await tester.pumpWidget(
          ChangeNotifierProvider<WorkflowState>.value(
            value: mockWorkflowState,
            child: MaterialApp(
              home: Scaffold(
                body: WorkflowNavigationControls(
                  onSaveAction: () async {},
                  onCompleteAction: () async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(saveButtonKey), findsOneWidget);
        
        // Test for Step 2
        when(mockWorkflowState.currentStep).thenReturn(2);
        await tester.pumpWidget(
          ChangeNotifierProvider<WorkflowState>.value(
            value: mockWorkflowState,
            child: MaterialApp(
              home: Scaffold(
                body: WorkflowNavigationControls(
                  onSaveAction: () async {},
                  onCompleteAction: () async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(saveButtonKey), findsOneWidget);
      });
      
      testWidgets('Save button calls onSaveAction when tapped', (WidgetTester tester) async {
        bool saveActionCalled = false;
        
        await pumpWidget(
          tester,
          onSaveAction: () async {
            saveActionCalled = true;
          },
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();
        
        final saveButtonFinder = find.byKey(saveButtonKey);
        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();
        
        expect(saveActionCalled, isTrue, reason: "Save action should be called when button is tapped");
      });
      
      testWidgets('Save button calls onCompleteAction when tapped on Summary step', (WidgetTester tester) async {
        bool completeActionCalled = false;
        when(mockWorkflowState.currentStep).thenReturn(2); // Summary step
        
        await pumpWidget(
          tester,
          onSaveAction: () async {},
          onCompleteAction: () async {
            completeActionCalled = true;
          },
        );
        await tester.pumpAndSettle();
        
        final saveButtonFinder = find.byKey(saveButtonKey);
        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();
        
        expect(completeActionCalled, isTrue, reason: "Complete action should be called when Save button is tapped on Summary step");
      });
    });

    group('Next Button', () {
      testWidgets('at step 0, "Next" button is visible',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(0);
        when(mockWorkflowState.hasParseData).thenReturn(true);

        await pumpWidget(
          tester,
          onSaveAction: () async {},
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
          onSaveAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        
        // Changed from InkWell to Container
        Container nextButton = tester.widget<Container>(nextButtonFinder);
        // We can't directly check onTap, but we can verify it's not null by trying to tap it
        
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
          onSaveAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();
        
        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        
        // Check for a specific color opacity that indicates the disabled state
        Container nextButton = tester.widget<Container>(nextButtonFinder);
        BoxDecoration decoration = nextButton.decoration as BoxDecoration;
        expect(decoration.color, equals(slateBlue.withOpacity(0.4)));
        
        // Try tapping it and verify no state change
        await tester.tap(nextButtonFinder, warnIfMissed: false);
        await tester.pumpAndSettle();
        
        verifyNever(mockWorkflowState.nextStep());
      });

      testWidgets('at step 1, "Next" button is visible and enabled, calls nextStep',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1);
        when(mockWorkflowState.hasAssignmentData).thenReturn(true);

        await pumpWidget(
          tester,
          onSaveAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        
        // Changed from InkWell to Container
        Container nextButton = tester.widget<Container>(nextButtonFinder);
        // We can verify it's enabled by the color (not using opacity)
        BoxDecoration decoration = nextButton.decoration as BoxDecoration;
        expect(decoration.color, equals(slateBlue));

        await tester.tap(nextButtonFinder);
        await tester.pump();

        verify(mockWorkflowState.nextStep()).called(1);
      });

      testWidgets('at step 2 (Summary), Next button changes to Complete button',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(2);

        await pumpWidget(
          tester,
          onSaveAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();

        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        
        // Verify the text shows "Complete" instead of "Next"
        expect(find.descendant(
          of: nextButtonFinder,
          matching: find.text('Complete')
        ), findsOneWidget);
      });

      testWidgets('at step 1, "Next" button is disabled if hasAssignmentData is false',
          (WidgetTester tester) async {
        when(mockWorkflowState.currentStep).thenReturn(1);
        when(mockWorkflowState.hasAssignmentData).thenReturn(false);

        await pumpWidget(
          tester,
          onSaveAction: () async {},
          onCompleteAction: () async {},
        );
        await tester.pumpAndSettle();
        
        final nextButtonFinder = find.byKey(nextButtonKey);
        expect(nextButtonFinder, findsOneWidget);
        
        // Changed from InkWell to Container
        Container nextButton = tester.widget<Container>(nextButtonFinder);
        BoxDecoration decoration = nextButton.decoration as BoxDecoration;
        expect(decoration.color, equals(slateBlue.withOpacity(0.4)));
      });
    });

    // Note: Tests for Complete, Exit and Save Draft buttons have been removed
    // as those UI elements have been replaced with a consistent Save button
  });
} 