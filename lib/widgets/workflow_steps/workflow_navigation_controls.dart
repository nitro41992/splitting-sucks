import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workflow_state.dart'; // Added import

class WorkflowNavigationControls extends StatelessWidget {
  final int currentStep; // Passed to simplify logic, though also in WorkflowState
  final Future<void> Function() onExitAction;
  final Future<void> Function() onSaveDraftAction;
  final Future<void> Function() onCompleteAction;

  const WorkflowNavigationControls({
    Key? key,
    required this.currentStep,
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
                onPressed: currentStep > 0
                    ? () => workflowState.previousStep()
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),

              // Middle button - Exit for steps 0-3, Save Draft for step 4 (Summary)
              currentStep < 4
                  ? OutlinedButton(
                      onPressed: onExitAction,
                      child: const Text('Exit'),
                    )
                  : OutlinedButton(
                      onPressed: onSaveDraftAction,
                      child: const Text('Save Draft'),
                    ),

              // Next/Complete button
              if (currentStep < 4) ...[
                FilledButton.icon(
                  onPressed: isNextEnabled
                      ? () => workflowState.nextStep()
                      : null,
                  label: const Text('Next'),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: onCompleteAction, // Directly use the passed callback
                  label: const Text('Complete'),
                  icon: const Icon(Icons.check),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
} 