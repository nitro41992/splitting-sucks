import 'package:flutter/material.dart';
import '../widgets/split_view.dart'; // Import the SplitView widget

class AssignmentReviewScreen extends StatelessWidget {
  const AssignmentReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This screen simply displays the SplitView widget.
    // SplitView handles its interactions and state via Provider.
    return const SplitView();
    // Potential future enhancement: Add an explicit "Confirm Split" button here
    // that could navigate to the final summary or trigger an action.
  }
} 