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
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 35.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IntrinsicWidth(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  item.name,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ],
                          ),
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
                  const SizedBox(width: 20),
                  // Quantity Stepper
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: item.quantity > 1 ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.4)),
                        onPressed: item.quantity > 1 ? () => onQuantityChanged(index, item.quantity - 1) : null,
                        visualDensity: VisualDensity.comfortable,
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
                        visualDensity: VisualDensity.comfortable,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(width: 10), // Spacing before delete
                  // Delete Button
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                    onPressed: () => onDelete(index),
                    tooltip: 'Delete Item',
                    visualDensity: VisualDensity.comfortable,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            // Total price badge in top right corner
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  '\$${item.total.toStringAsFixed(2)}',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 