import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workflow_state.dart'; // Added import

// Define Keys for testing
const Key backButtonKey = ValueKey('workflow_back_button');
const Key exitButtonKey = ValueKey('workflow_exit_button');
const Key saveDraftButtonKey = ValueKey('workflow_save_draft_button');
const Key nextButtonKey = ValueKey('workflow_next_button');
const Key completeButtonKey = ValueKey('complete_workflow_button');

class WorkflowNavigationControls extends StatelessWidget {
  // final int currentStep; // REMOVE: Get from WorkflowState via Consumer
  final Future<void> Function() onExitAction;
  final Future<void> Function() onSaveDraftAction;
  final Future<void> Function() onCompleteAction;

  const WorkflowNavigationControls({
    Key? key,
    // required this.currentStep, // REMOVE
    required this.onExitAction,
    required this.onSaveDraftAction,
    required this.onCompleteAction,
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
        } else if (currentStep == 2 && !workflowState.hasAssignmentData) {
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
              // Back button
              TextButton.icon(
                key: backButtonKey,
                onPressed: currentStep > 0 // Use local currentStep
                    ? () => workflowState.previousStep()
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),

              // Middle button - Exit for steps 0-3, Save Draft for step 4 (Summary)
              currentStep < 4 // Use local currentStep
                  ? OutlinedButton(
                      key: exitButtonKey,
                      onPressed: onExitAction,
                      child: const Text('Exit'),
                    )
                  : OutlinedButton(
                      key: saveDraftButtonKey,
                      onPressed: onSaveDraftAction,
                      child: const Text('Save Draft'),
                    ),

              // Next/Complete button - Show Complete button on Summary step (2), Next button otherwise
              if (!isSummaryStep) ...[
                FilledButton.icon(
                  key: nextButtonKey,
                  onPressed: isNextEnabled
                      ? () => workflowState.nextStep()
                      : null,
                  label: const Text('Next'),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ] else ...[
                FilledButton.icon(
                  key: completeButtonKey,
                  onPressed: onExitAction,
                  label: const Text('Exit'),
                  icon: const Icon(Icons.exit_to_app),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
} 