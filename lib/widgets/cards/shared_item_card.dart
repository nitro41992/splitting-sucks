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
                      // ALWAYS use itemId for comparison to ensure consistent selection state
                      final isSelected = person.sharedItems.any((si) => si.itemId == item.itemId);
                      
                      // Debug print for diagnosing shared item selection
                      debugPrint('[SharedItemCard] Person: ${person.name}, has sharedItems: ${person.sharedItems.length}');
                      for (var si in person.sharedItems) {
                        debugPrint('[SharedItemCard] - SharedItem: ${si.name}, ID: ${si.itemId}');
                      }
                      debugPrint('[SharedItemCard] Current item: ${item.name}, ID: ${item.itemId}, Selected: $isSelected');
                      
                      return FilterChip(
                        label: Text(person.name, overflow: TextOverflow.ellipsis),
                        selected: isSelected,
                        onSelected: (selected) {
                          debugPrint('[SharedItemCard] Changing selection for ${person.name} to $selected');
                          if (selected) {
                            splitManager.addPersonToSharedItem(item, person);
                          } else {
                            splitManager.removePersonFromSharedItem(item, person);
                            final remainingSharers = splitManager.getPeopleForSharedItem(item);
                            if (remainingSharers.isEmpty) {
                              splitManager.removeItemFromShared(item);
                              splitManager.addUnassignedItem(item);
                            }
                          }
                          // Force UI refresh after the build phase is complete
                          Future.microtask(() => splitManager.notifyListeners());
                        },
                        selectedColor: colorScheme.primary.withOpacity(0.9),
                        backgroundColor: isSelected
                            ? colorScheme.primary.withOpacity(0.90)
                            : colorScheme.surfaceVariant,
                        checkmarkColor: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            width: isSelected ? 2.5 : 1.5,
                          ),
                        ),
                        elevation: isSelected ? 4 : 0,
                        shadowColor: isSelected ? colorScheme.primary.withOpacity(0.3) : null,
                        showCheckmark: true,
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
