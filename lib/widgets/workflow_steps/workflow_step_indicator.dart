import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class WorkflowStepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> stepTitles;

  const WorkflowStepIndicator({
    Key? key,
    required this.currentStep,
    required this.stepTitles,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (stepTitles.isEmpty) {
      return const SizedBox.shrink(); // Avoid errors if titles are not ready
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step indicator dots and lines
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              stepTitles.length * 2 - 1,
              (index) {
                // If index is even, show a dot
                if (index % 2 == 0) {
                  final stepIndex = index ~/ 2;
                  final isActive = stepIndex == currentStep;
                  final isCompleted = stepIndex < currentStep;
                  
                  return Container(
                    width: 20, // Slightly larger dots
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.primary // Slate Blue for active step
                          : isCompleted
                              ? AppColors.primary.withOpacity(0.7) // Lighter Slate Blue for completed
                              : Colors.transparent, // Transparent for inactive steps
                      border: Border.all(
                        color: isActive || isCompleted
                            ? AppColors.primary // Slate Blue border for active/completed
                            : Colors.grey.shade400, // Medium grey for inactive
                        width: 2, // Thicker border
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: isCompleted
                        ? Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  );
                } else {
                  // If index is odd, show a line
                  final lineIndex = index ~/ 2;
                  final isCompleted = lineIndex < currentStep;
                  
                  return Container(
                    width: 35, // Slightly longer lines
                    height: 2.5, // Slightly thicker lines
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.primary // Slate Blue for completed
                          : Colors.grey.shade300, // Light grey for inactive
                      borderRadius: BorderRadius.circular(1.0),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 10), // More space
          // Step titles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              stepTitles.length,
              (index) {
                final isActive = index == currentStep;
                return Container(
                  width: 90, // Wider to accommodate text better
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    stepTitles[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13, // Larger font size
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive
                          ? AppColors.primary // Slate Blue for active
                          : Colors.grey.shade600, // Darker grey for inactive 
                    ),
                    overflow: TextOverflow.ellipsis, // Handle long titles
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 