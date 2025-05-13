import 'package:flutter/material.dart';
import '../../models/receipt_item.dart';
import '../../screens/receipt_review_screen.dart';
import '../../widgets/workflow_modal.dart'; // For GetCurrentItemsCallback typedef

class ReviewStepWidget extends StatelessWidget {
  final List<ReceiptItem> initialItems;
  final Function(List<ReceiptItem> updatedItems, List<ReceiptItem> deletedItems) onReviewComplete;
  final Function(List<ReceiptItem> currentItems) onItemsUpdated;
  final Function(GetCurrentItemsCallback getter) registerCurrentItemsGetter;
  final VoidCallback? onClose;

  const ReviewStepWidget({
    Key? key,
    required this.initialItems,
    required this.onReviewComplete,
    required this.onItemsUpdated,
    required this.registerCurrentItemsGetter,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // debugPrint('[_ReviewStepWidget] Building ReceiptReviewScreen with ${initialItems.length} items.');
    return ReceiptReviewScreen(
      initialItems: initialItems,
      onReviewComplete: onReviewComplete,
      onItemsUpdated: onItemsUpdated,
      registerCurrentItemsGetter: registerCurrentItemsGetter,
      onClose: onClose,
    );
  }
} 