import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/split_manager.dart';
import '../shared/editable_price.dart';
import '../shared/quantity_selector.dart';

class SharedItemCard extends StatelessWidget {
  final ReceiptItem item;

  const SharedItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // Use read here if only calling methods, watch if rebuilding based on SplitManager changes
    final splitManager = context.read<SplitManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Watch people list directly if the card needs to rebuild when people change
    // Otherwise, getting it once via splitManager.people is fine if only used in callbacks
    final people = context.select((SplitManager sm) => sm.people);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Non-editable quantity display
                          Text(
                            'Qty: ${item.quantity}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Quantity selector for shared item (might need different logic?)
                          // This reuses the selector that DECREASES quantity.
                          // Consider if shared items need an ADD button or different logic.
                          QuantitySelector(
                            item: item,
                            // This directly updates the item's quantity in the model
                            onChanged: (newQuantity) => splitManager.updateItemQuantity(item, newQuantity),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    EditablePrice(
                      price: item.price,
                      onChanged: (newPrice) => item.updatePrice(newPrice),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: \$${item.total.toStringAsFixed(2)}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Shared with:',
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (people.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'No people added yet.',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: people.map((person) {
                  // Check if this person is currently sharing this specific item instance
                  // This requires the item object in person.sharedItems to be the exact same instance
                  final isSelected = person.sharedItems.contains(item);

                  return FilterChip(
                    label: Text(person.name, overflow: TextOverflow.ellipsis),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        splitManager.addPersonToSharedItem(item, person);
                      } else {
                        splitManager.removePersonFromSharedItem(item, person);

                        // Check if removing this person leaves the item unshared
                        // Need to re-evaluate based on the updated state
                        final remainingSharers = splitManager.people
                            .where((p) => p.sharedItems.contains(item))
                            .toList();

                        // If no one is sharing it anymore, move it back to unassigned
                        if (remainingSharers.isEmpty) {
                           // Ensure the UI rebuilds to reflect this change if needed
                          splitManager.removeItemFromShared(item);
                          splitManager.addUnassignedItem(item);
                        }
                      }
                    },
                    selectedColor: colorScheme.primaryContainer,
                    checkmarkColor: colorScheme.onPrimaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                    // Use default border or customize if needed
                    // shape: RoundedRectangleBorder(
                    //   borderRadius: BorderRadius.circular(20),
                    //   side: BorderSide(
                    //     color: isSelected
                    //         ? colorScheme.primaryContainer
                    //         : colorScheme.outlineVariant,
                    //   ),
                    // ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
} 