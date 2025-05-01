import 'package:flutter/material.dart';
import '../widgets/split_view.dart'; // Import the SplitView widget

/// Screen for reviewing item assignments after voice input.
///
/// This screen displays the SplitView widget which handles the assignment of items
/// to people. The actual processing of voice transcriptions and item assignments 
/// is performed via Firebase Cloud Functions, which call the OpenAI API.
/// SplitView handles its interactions and state via Provider.
class AssignmentReviewScreen extends StatelessWidget {
  const AssignmentReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This screen simply displays the SplitView widget.
    // SplitView handles its interactions and state via Provider.
    // The voice processing and AI assignment now happens via Firebase Cloud Functions
    return const SplitView();
    // Potential future enhancement: Add an explicit "Confirm Split" button here
    // that could navigate to the final summary or trigger an action.
  }
} 