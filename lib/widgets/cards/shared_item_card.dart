import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/split_manager.dart';
import '../shared/quantity_selector.dart';

class SharedItemCard extends StatelessWidget {
  final ReceiptItem item;

  const SharedItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.read<SplitManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final people = context.select((SplitManager sm) => sm.people);

    // Function to show toast message for assigned items
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 60.0),
                  child: Text(
                    item.name,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Wrap the text in GestureDetector to show toast when clicked
                    GestureDetector(
                      onTap: () => _showAssignedItemToast(context),
                      child: Text(
                        '${item.quantity} x \$${item.price.toStringAsFixed(2)} each',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    QuantitySelector(
                      item: item,
                      onChanged: (newQuantity) =>
                          splitManager.updateItemQuantity(item, newQuantity),
                      isAssigned: true, // Shared items are always assigned to people
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: 16),

                Text(
                  'Shared with:',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (people.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'No people added yet.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: people.map((person) {
                      final isSelected = person.sharedItems.contains(item);
                      return FilterChip(
                        label: Text(person.name, overflow: TextOverflow.ellipsis),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            splitManager.addPersonToSharedItem(item, person);
                            splitManager.notifyListeners();
                          } else {
                            splitManager.removePersonFromSharedItem(item, person);
                            final remainingSharers = splitManager.people
                                .where((p) => p.sharedItems.contains(item))
                                .toList();
                            if (remainingSharers.isEmpty) {
                              splitManager.removeItemFromShared(item);
                              splitManager.addUnassignedItem(item);
                            }
                            splitManager.notifyListeners();
                          }
                        },
                        selectedColor: colorScheme.primary,
                        backgroundColor: isSelected ? colorScheme.primary.withOpacity(0.15) : colorScheme.surfaceVariant,
                        checkmarkColor: colorScheme.onPrimary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                            width: 1.5,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '\$${item.total.toStringAsFixed(2)}',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
