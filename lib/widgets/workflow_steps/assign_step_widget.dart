import 'package:flutter/material.dart';
import '../../models/receipt_item.dart';
import '../../screens/voice_assignment_screen.dart';

class AssignStepWidget extends StatelessWidget {
  final List<ReceiptItem> itemsToAssign; 
  final String? initialTranscription;
  final Function(Map<String, dynamic> assignmentsData) onAssignmentProcessed;
  final Function(String? newTranscription) onTranscriptionChanged;
  final Future<bool> Function() onReTranscribeRequested;
  final Future<bool> Function() onConfirmProcessAssignments;
  final VoidCallback? onEditItems;

  const AssignStepWidget({
    Key? key,
    required this.itemsToAssign,
    required this.onAssignmentProcessed,
    this.initialTranscription,
    required this.onTranscriptionChanged,
    required this.onReTranscribeRequested,
    required this.onConfirmProcessAssignments,
    this.onEditItems,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return VoiceAssignmentScreen(
      key: ValueKey('VoiceAssignmentScreen_AssignStep_${itemsToAssign.length}_${initialTranscription?.hashCode ?? 0}'),
      itemsToAssign: itemsToAssign,
      onAssignmentProcessed: onAssignmentProcessed,
      initialTranscription: initialTranscription,
      onTranscriptionChanged: onTranscriptionChanged,
      onReTranscribeRequested: onReTranscribeRequested,
      onConfirmProcessAssignments: onConfirmProcessAssignments,
      onEditItems: onEditItems,
    );
  }
} 