import 'package:billfie/widgets/workflow_steps/workflow_step_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkflowStepIndicator Widget Tests', () {
    // Helper function to pump the widget with necessary MaterialApp and Scaffold
    Future<void> pumpWidget(WidgetTester tester, Widget widget) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: widget,
          ),
        ),
      );
    }

    final stepTitles = ['Upload', 'Review', 'Assign', 'Split', 'Summary'];
    final int totalSteps = stepTitles.length;

    testWidgets('renders the correct number of step indicators and titles', (WidgetTester tester) async {
      final indicator = WorkflowStepIndicator(
        currentStep: 0,
        stepTitles: stepTitles,
      );

      await pumpWidget(tester, indicator);

      // Verify step titles
      for (final title in stepTitles) {
        expect(find.text(title), findsOneWidget);
      }

      // Verify step dots (Containers with circle shape)
      // We find them by looking for a Container that is a child of a Row, 
      // and has a BoxDecoration with shape == BoxShape.circle.
      // This is a bit indirect but necessary without specific keys.
      expect(find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          return decoration.shape == BoxShape.circle;
        }
        return false;
      }), findsNWidgets(totalSteps));
      
      // Verify step lines (Containers with height 2, acting as lines)
      // There should be totalSteps - 1 lines.
      if (totalSteps > 1) {
        expect(find.byWidgetPredicate((widget) {
          if (widget is Container && widget.constraints?.maxHeight == 2.0 && widget.constraints?.minHeight == 2.0) {
            // Further check it's not one of the dot containers by checking it does not have a circle shape
            if (widget.decoration is BoxDecoration) {
                return (widget.decoration as BoxDecoration).shape != BoxShape.circle;
            }
            return true; // It's a container with height 2 and no box decoration (or not circle)
          }
          return false;
        }), findsNWidgets(totalSteps - 1));
      }
    });

    testWidgets('highlights the current step correctly and shows checkmarks for completed steps', (WidgetTester tester) async {
      const currentStepIndex = 2; // e.g., 'Assign'
      final indicator = WorkflowStepIndicator(
        currentStep: currentStepIndex,
        stepTitles: stepTitles,
      );

      await pumpWidget(tester, indicator);

      // Verify current step title style
      final currentStepTitleWidget = tester.widget<Text>(find.text(stepTitles[currentStepIndex]));
      expect(currentStepTitleWidget.style?.fontWeight, FontWeight.bold);
      // Color check needs Theme context, we'll assert it's not the default/inactive color for now
      // A more robust check would involve capturing the Theme or using a more specific predicate.
      final defaultColor = Theme.of(tester.element(find.byType(WorkflowStepIndicator))).colorScheme.onSurfaceVariant;
      final activeColor = Theme.of(tester.element(find.byType(WorkflowStepIndicator))).colorScheme.primary;
      expect(currentStepTitleWidget.style?.color, activeColor);

      // Verify previous step titles style (not bold, default color)
      if (currentStepIndex > 0) {
        final previousStepTitleWidget = tester.widget<Text>(find.text(stepTitles[currentStepIndex - 1]));
        expect(previousStepTitleWidget.style?.fontWeight, FontWeight.normal);
        expect(previousStepTitleWidget.style?.color, defaultColor);
      }

      // Verify current step dot style (active color)
      // This requires finding the specific dot. We can find all dots and check the one at currentStepIndex.
      final allDots = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          return (widget.decoration as BoxDecoration).shape == BoxShape.circle;
        }
        return false;
      });
      final currentStepDot = tester.widget<Container>(allDots.at(currentStepIndex));
      expect((currentStepDot.decoration as BoxDecoration).color, activeColor);
      expect((currentStepDot.decoration as BoxDecoration).border?.top.color, activeColor);

      // Verify completed step dots have checkmarks and completed colors
      for (int i = 0; i < currentStepIndex; i++) {
        final completedStepDot = tester.widget<Container>(allDots.at(i));
        final completedColor = Theme.of(tester.element(find.byType(WorkflowStepIndicator))).colorScheme.primaryContainer;
        final completedBorderColor = Theme.of(tester.element(find.byType(WorkflowStepIndicator))).colorScheme.primary;
        expect((completedStepDot.decoration as BoxDecoration).color, completedColor);
        expect((completedStepDot.decoration as BoxDecoration).border?.top.color, completedBorderColor);
        // Check for the check icon
        expect(find.descendant(of: allDots.at(i), matching: find.byIcon(Icons.check)), findsOneWidget);
      }

      // Verify future step dots have inactive colors and no checkmark
      for (int i = currentStepIndex + 1; i < totalSteps; i++) {
        final futureStepDot = tester.widget<Container>(allDots.at(i));
        final inactiveColor = Theme.of(tester.element(find.byType(WorkflowStepIndicator))).colorScheme.surfaceVariant;
        final inactiveBorderColor = Theme.of(tester.element(find.byType(WorkflowStepIndicator))).colorScheme.outline;
        expect((futureStepDot.decoration as BoxDecoration).color, inactiveColor);
        expect((futureStepDot.decoration as BoxDecoration).border?.top.color, inactiveBorderColor);
        expect(find.descendant(of: allDots.at(i), matching: find.byIcon(Icons.check)), findsNothing);
      }
      
      // Verify line colors
      final allLines = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.constraints?.maxHeight == 2.0 && widget.constraints?.minHeight == 2.0) {
           if (widget.decoration is BoxDecoration) { // Exclude dots that might accidentally match height if constrained
                return (widget.decoration as BoxDecoration).shape != BoxShape.circle;
            }
            return true; 
        }
        return false;
      });
      if (totalSteps > 1) {
          for (int i = 0; i < totalSteps -1; i++) {
            final lineWidget = tester.widget<Container>(allLines.at(i));
            if (i < currentStepIndex) { // Line before an active or completed step is active
                 expect(lineWidget.color, activeColor);
            } else { // Line after an active step or between future steps is inactive
                 final inactiveLineColor = Theme.of(tester.element(find.byType(WorkflowStepIndicator))).colorScheme.outline;
                 expect(lineWidget.color, inactiveLineColor);
            }
          }
      }

    });

    // Test tap handling when WorkflowModalBody tests are implemented
  });
} 