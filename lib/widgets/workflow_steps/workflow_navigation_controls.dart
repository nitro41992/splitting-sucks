import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workflow_state.dart';

// Define Keys for testing
const Key backButtonKey = ValueKey('workflow_back_button');
const Key saveButtonKey = ValueKey('workflow_save_button');
const Key nextButtonKey = ValueKey('workflow_next_button');

// Define the Slate Blue color constant
const Color slateBlue = Color(0xFF5D737E);
const Color mediumGrey = Color(0xFF8A8A8E);

class WorkflowNavigationControls extends StatelessWidget {
  final Future<void> Function() onSaveAction;
  final Future<void> Function() onCompleteAction;
  final Future<void> Function()? onBackAction;
  final Future<void> Function()? onNextAction;
  final bool hideMiddleButton;

  const WorkflowNavigationControls({
    Key? key,
    required this.onSaveAction,
    required this.onCompleteAction,
    this.onBackAction,
    this.onNextAction,
    this.hideMiddleButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkflowState>(
      builder: (context, workflowState, child) {
        final currentStep = workflowState.currentStep;
        final shouldHideSaveButton = hideMiddleButton || currentStep == 0;
        
        // Enhanced next button enabling logic
        bool isNextEnabled = true;
        if (currentStep == 0) {
          // On Upload step, only enable Next if we have a selected image or parsed data
          isNextEnabled = workflowState.imageFile != null || 
                         workflowState.loadedImageUrl != null || 
                         workflowState.hasParseData;
        } else if (currentStep == 1 && !workflowState.hasAssignmentData) {
          isNextEnabled = false;
        } else if (currentStep == 3 && !workflowState.hasAssignmentData) {
          isNextEnabled = false;
        }

        // Check if current step is the Summary step
        final isSummaryStep = currentStep == 2;
        
        // Configure button labels and icons based on the step
        String nextButtonLabel = 'Next';
        IconData nextButtonIcon = Icons.arrow_forward_rounded;
        
        String backButtonLabel = currentStep == 0 ? 'Cancel' : 'Back';
        IconData backButtonIcon = currentStep == 0 ? Icons.close : Icons.arrow_back_rounded;
        
        // Special case for image preview (currentStep == 0 with image selected)
        if (currentStep == 0 && isNextEnabled) {
          backButtonLabel = 'Retake';
          backButtonIcon = Icons.refresh_rounded;
        }
        
        // Special case for final step
        if (isSummaryStep) {
          nextButtonLabel = 'Complete';
          nextButtonIcon = Icons.check_rounded;
        }

        return Container(
          height: 84, // Increased height to accommodate buttons better
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              // Top shadow for raised effect (darker)
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -4),
                spreadRadius: 0,
              ),
              // Subtle highlight at the top (lighter)
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 0,
                offset: const Offset(0, 1),
                spreadRadius: 0,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true, // Ensure we respect the bottom safe area
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LEFT ZONE: "Back / Retake" button
                  _buildZoneButton(
                    icon: backButtonIcon,
                    label: backButtonLabel,
                    onPressed: () async {
                      if (currentStep > 0) {
                        if (onBackAction != null) {
                          await onBackAction!();
                        }
                        workflowState.previousStep();
                      } else {
                        // For step 0 with image, retake; otherwise cancel
                        if (isNextEnabled) {
                          workflowState.resetImageFile();
                        } else {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    key: backButtonKey,
                  ),
                  
                  // MIDDLE ZONE: "Save Draft" button 
                  if (!shouldHideSaveButton)
                    _buildZoneButton(
                      icon: Icons.save_outlined,
                      label: 'Save Draft',
                      onPressed: onSaveAction,
                      isSlateBlue: true,
                      key: saveButtonKey,
                    )
                  else
                    _buildZoneButton(
                      icon: Icons.save_outlined,
                      label: 'Save Draft',
                      onPressed: onSaveAction,
                      isSlateBlue: true,
                      key: saveButtonKey,
                      opacity: 0.0, // Invisible but maintains layout
                    ),
                  
                  // RIGHT ZONE: "Next / Complete" button (primary)
                  _buildPrimaryActionButton(
                    label: nextButtonLabel,
                    icon: nextButtonIcon,
                    onPressed: isNextEnabled ? () async {
                      if (onNextAction != null) {
                        await onNextAction!();
                      }
                      if (isSummaryStep) {
                        await onCompleteAction();
                      } else {
                        workflowState.nextStep();
                      }
                    } : null,
                    key: nextButtonKey,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method for building the zone buttons (left and center)
  Widget _buildZoneButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isSlateBlue = false,
    required Key key,
    double opacity = 1.0,
  }) {
    final Color iconColor = isSlateBlue ? slateBlue : mediumGrey;
    
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 80,
        height: 40, // Fixed height to prevent overflow
        child: InkWell(
          key: key,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center, // Center items vertically
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 20, // Smaller icon size
              ),
              const SizedBox(height: 2), // Reduced spacing
              Text(
                label,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 10, // Smaller font size
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for the primary action button (right zone)
  Widget _buildPrimaryActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required Key key,
  }) {
    // Different styling based on enabled state
    if (onPressed == null) {
      // Disabled state - still a filled pill but desaturated
      return Container(
        height: 40, // Match height with the zone buttons
        decoration: BoxDecoration(
          color: slateBlue.withOpacity(0.4), // Desaturated color
          borderRadius: BorderRadius.circular(20), // Rounded corners
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 12, // Smaller text
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                color: Colors.white.withOpacity(0.7),
                size: 16, // Smaller icon
              ),
            ],
          ),
        ),
      );
    }
    
    // Enabled primary button as a filled button
    return Container(
      height: 40, // Match height with the zone buttons
      decoration: BoxDecoration(
        color: slateBlue,
        borderRadius: BorderRadius.circular(20), // Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(2, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20), // Match the container
        child: InkWell(
          key: key,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20), // Match the container
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12, // Smaller text
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  icon,
                  color: Colors.white,
                  size: 16, // Smaller icon
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 