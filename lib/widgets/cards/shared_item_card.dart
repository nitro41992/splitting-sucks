import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/split_manager.dart';
import '../../models/person.dart';
import '../shared/quantity_selector.dart';

class SharedItemCard extends StatelessWidget {
  final ReceiptItem item;

  const SharedItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.read<SplitManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Get only the people who are sharing this specific item
    final sharingPeople = context.select<SplitManager, List<Person>>(
      (sm) => sm.getPeopleForSharedItem(item)
    );
    
    // Debug output
    debugPrint('SharedItemCard: ${item.name} (ID: ${item.itemId}) is shared by ${sharingPeople.length} people: ${sharingPeople.map((p) => p.name).join(", ")}');
    
    // Get all people for potential assignment
    final allPeople = context.select<SplitManager, List<Person>>((sm) => sm.people);
    debugPrint('SharedItemCard: All people count: ${allPeople.length}');

    // Function to show toast message for assigned items
    void _showAssignedItemToast(BuildContext context) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Changes to price and quantity can only be made if not assigned to a person'),
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

                // Shared with section header with count
                Row(
                  children: [
                    Text(
                      'Shared with:',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${sharingPeople.length} ${sharingPeople.length == 1 ? 'person' : 'people'}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // People section
                if (allPeople.isEmpty)
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
                    children: allPeople.map((person) {
                      final isSelected = sharingPeople.contains(person);
                      return FilterChip(
                        label: Text(person.name, overflow: TextOverflow.ellipsis),
                        selected: isSelected,
                        onSelected: (selected) {
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
                        },
                        selectedColor: colorScheme.primaryContainer,
                        checkmarkColor: colorScheme.onPrimaryContainer,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          // Total price
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
