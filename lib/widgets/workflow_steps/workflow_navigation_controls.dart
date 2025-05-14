import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workflow_state.dart'; // Added import

// Define Keys for testing
const Key backButtonKey = ValueKey('workflow_back_button');
const Key saveButtonKey = ValueKey('workflow_save_button');
const Key nextButtonKey = ValueKey('workflow_next_button');

class WorkflowNavigationControls extends StatelessWidget {
  final Future<void> Function() onSaveAction;
  final Future<void> Function() onCompleteAction;
  final Future<void> Function()? onBackAction;
  final Future<void> Function()? onNextAction;

  const WorkflowNavigationControls({
    Key? key,
    required this.onSaveAction,
    required this.onCompleteAction,
    this.onBackAction,
    this.onNextAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Consumer is used to react to changes in WorkflowState for enabling/disabling
    // buttons and for simple actions like nextStep/previousStep.
    return Consumer<WorkflowState>(
      builder: (context, workflowState, child) {
        final currentStep = workflowState.currentStep; // USE currentStep from WorkflowState

        bool isNextEnabled = true;
        if (currentStep == 0 && !workflowState.hasParseData) {
          isNextEnabled = false;
        } else if (currentStep == 1 && !workflowState.hasAssignmentData) {
          isNextEnabled = false;
        } else if (currentStep == 3 && !workflowState.hasAssignmentData) {
          // This condition implies that to go from Split (3) to Summary (4),
          // assignment data must be present.
          isNextEnabled = false;
        }

        // Check if current step is the Summary step - in the 3-step workflow, Summary is step 2
        final isSummaryStep = currentStep == 2;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button - Always visible if not on first step
              TextButton.icon(
                key: backButtonKey,
                onPressed: currentStep > 0 // Use local currentStep
                    ? () async {
                        // If custom back action provided, call it first
                        if (onBackAction != null) {
                          await onBackAction!();
                        }
                        workflowState.previousStep();
                      }
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              
              // Save button - Always in the middle
              FilledButton.icon(
                key: saveButtonKey,
                onPressed: isSummaryStep ? onCompleteAction : onSaveAction,
                label: const Text('Save'),
                icon: const Icon(Icons.save),
              ),
              
              // Right side button(s) - depend on current step
              if (!isSummaryStep) 
                // For non-summary steps, show Next button
                FilledButton.icon(
                  key: nextButtonKey,
                  onPressed: isNextEnabled
                      ? () async {
                          // If custom next action provided, call it first
                          if (onNextAction != null) {
                            await onNextAction!();
                          }
                          workflowState.nextStep();
                        }
                      : null,
                  label: const Text('Next'),
                  icon: const Icon(Icons.arrow_forward),
                )
              else
                // Empty container to maintain alignment when Next button isn't shown
                Container(width: 100, color: Colors.transparent),
            ],
          ),
        );
      },
    );
  }
} 