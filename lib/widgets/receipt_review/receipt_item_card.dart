import 'package:flutter/material.dart';
import '../../models/receipt_item.dart';

class ReceiptItemCard extends StatelessWidget {
  final ReceiptItem item;
  final int index;
  final Function(ReceiptItem item, int index) onEdit;
  final Function(int index) onDelete;
  final Function(int index, int newQuantity) onQuantityChanged; // Add callback for quantity

  const ReceiptItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4.0), // Adjust margin for use in list
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => onEdit(item, index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Slightly reduce vertical padding
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // Center align vertically
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${item.price.toStringAsFixed(2)} each',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Quantity Stepper
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: item.quantity > 1 ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.4)),
                    onPressed: item.quantity > 1 ? () => onQuantityChanged(index, item.quantity - 1) : null,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0), // Padding around quantity number
                    child: Text(
                      '${item.quantity}',
                      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: colorScheme.primary),
                    onPressed: () => onQuantityChanged(index, item.quantity + 1),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
               const SizedBox(width: 8), // Spacing before delete
              // Delete Button
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                onPressed: () => onDelete(index),
                 tooltip: 'Delete Item',
                 visualDensity: VisualDensity.compact,
                 padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 