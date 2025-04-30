import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/split_manager.dart';
import 'editable_price.dart';
import 'quantity_selector.dart';

class ItemRow extends StatelessWidget {
  final ReceiptItem item;

  const ItemRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.read<SplitManager>(); // Use read if only calling methods
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Function to show toast message when item is assigned
    void _showAssignedItemToast(BuildContext context) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Changes to price and quanitty can only be made if not assigned to a person'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        )
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis, // Prevent overflow
            ),
          ),
          const SizedBox(width: 16),
          // Wrap price in a GestureDetector to show toast when clicked
          GestureDetector(
            onTap: () => _showAssignedItemToast(context),
            child: Text(
              '\$${item.price.toStringAsFixed(2)}',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 16),
          QuantitySelector(
            item: item,
            onChanged: (newQuantity) => splitManager.updateItemQuantity(item, newQuantity),
            isAssigned: true, // Items in PersonCard are always assigned to someone
          ),
        ],
      ),
    );
  }
} 