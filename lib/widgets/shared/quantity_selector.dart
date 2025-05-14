import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/split_manager.dart';
import '../../theme/app_colors.dart';

class QuantitySelector extends StatelessWidget {
  final ReceiptItem item;
  final Function(int) onChanged;
  final bool allowIncreaseBeyondOriginal;
  final bool isAssigned;

  const QuantitySelector({
    super.key,
    required this.item,
    required this.onChanged,
    this.allowIncreaseBeyondOriginal = false,
    this.isAssigned = false,
  });

  @override
  Widget build(BuildContext context) {
    final splitManager = context.watch<SplitManager>(); // Keep watch here if needed for context or direct access
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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

    return Tooltip(
      message: 'Reduce quantity',
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decrease button - Allow decreasing even when assigned
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.quantity > 0 
                    ? () => onChanged(item.quantity - 1)
                    : null,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.quantity > 0
                        ? AppColors.puce
                        : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                  ),
                  child: Icon(
                    Icons.remove_circle_outline,
                    size: 22,
                    color: item.quantity > 0
                        ? Colors.white
                        : colorScheme.onSurfaceVariant.withOpacity(0.38),
                  ),
                ),
              ),
            ),
            // Quantity display
            GestureDetector(
              onTap: isAssigned ? () => _showAssignedItemToast(context) : null,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: Text(
                  item.quantity.toString(),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            // Increase button - Only show toast if assigned
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isAssigned
                    ? () => _showAssignedItemToast(context)
                    : () {
                        if (allowIncreaseBeyondOriginal) {
                          onChanged(item.quantity + 1);
                        } else {
                          final available = splitManager.getAvailableQuantity(item);
                          if (item.quantity < available) {
                            onChanged(item.quantity + 1);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cannot exceed original quantity for ${item.name}.'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: colorScheme.error,
                              )
                            );
                          }
                        }
                      },
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: !isAssigned && (allowIncreaseBeyondOriginal || splitManager.getAvailableQuantity(item) > item.quantity)
                        ? AppColors.puce
                        : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 22,
                    color: !isAssigned && (allowIncreaseBeyondOriginal || splitManager.getAvailableQuantity(item) > item.quantity)
                        ? Colors.white
                        : colorScheme.onSurfaceVariant.withOpacity(0.38),
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