import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../shared/editable_price.dart';

class UnassignedItemCard extends StatelessWidget {
  final ReceiptItem item;

  const UnassignedItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.watch<SplitManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: ${item.quantity}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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
            FilledButton.icon(
              onPressed: () => _showAssignDialog(context, splitManager, item),
              icon: const Icon(Icons.person_add),
              label: const Text('Assign Item'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Item'),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose how to assign this item:'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('To Person'),
                  onPressed: () {
                    Navigator.pop(context); // Close this dialog first
                    _showAssignToPersonDialog(context, splitManager, item);
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: colorScheme.onPrimaryContainer,
                    backgroundColor: colorScheme.primaryContainer,
                  ),
                ),
                // const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.group),
                  label: const Text('Share'),
                  onPressed: () {
                    Navigator.pop(context); // Close this dialog first
                    _showShareDialog(context, splitManager, item);
                  },
                   style: ElevatedButton.styleFrom(
                    foregroundColor: colorScheme.onSecondaryContainer,
                    backgroundColor: colorScheme.secondaryContainer,
                  ),
                ),
              ],
            ),
             const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAssignToPersonDialog(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    int selectedQuantity = item.quantity; // Track quantity within the dialog state
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) { // Use a different name for dialog's setState
          return AlertDialog(
            title: const Text('Assign to Person'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quantity selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Quantity: ', style: textTheme.titleMedium),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: selectedQuantity > 0 ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.38)),
                        tooltip: 'Decrease quantity',
                        onPressed: selectedQuantity > 0
                            ? () => setStateDialog(() => selectedQuantity--)
                            : null,
                      ),
                      SizedBox(
                        width: 24,
                        child: Text(
                          selectedQuantity.toString(),
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: selectedQuantity < item.quantity ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.38)),
                        tooltip: 'Increase quantity',
                        onPressed: selectedQuantity < item.quantity
                            ? () => setStateDialog(() => selectedQuantity++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Person list
                  if (splitManager.people.isEmpty)
                    const Text('Add people first using the + button.')
                  else
                    SizedBox(
                      width: double.maxFinite,
                      height: 300, // Constrain height
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: splitManager.people.length,
                        itemBuilder: (context, index) {
                          final person = splitManager.people[index];
                          return ListTile(
                            leading: CircleAvatar(
                                child: Text(person.name.isNotEmpty ? person.name[0] : '?')
                            ),
                            title: Text(person.name, overflow: TextOverflow.ellipsis),
                            onTap: selectedQuantity > 0 ? () {
                              // Create a new item with the specified quantity
                              final newItem = ReceiptItem(
                                name: item.name,
                                price: item.price,
                                quantity: selectedQuantity,
                              );

                              // First assign the new item
                              splitManager.assignItemToPerson(newItem, person);

                              // Then handle the source item's quantity reduction or removal
                              if (selectedQuantity >= item.quantity) {
                                splitManager.removeUnassignedItem(item);
                              } else {
                                item.updateQuantity(item.quantity - selectedQuantity);
                              }

                              Navigator.pop(context); // Close the dialog
                            } : null, // Disable tap if quantity is 0
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showShareDialog(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    int selectedQuantity = item.quantity;
    final List<Person> selectedPeople = []; // Track selected people within the dialog
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) { // Use a different name for dialog's setState
            return AlertDialog(
              title: const Text('Share Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quantity selector
                     Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Quantity: ', style: textTheme.titleMedium),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: selectedQuantity > 0 ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.38)),
                          tooltip: 'Decrease quantity',
                          onPressed: selectedQuantity > 0
                              ? () => setStateDialog(() => selectedQuantity--)
                              : null,
                        ),
                        SizedBox(
                          width: 24,
                          child: Text(
                            selectedQuantity.toString(),
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: selectedQuantity < item.quantity ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.38)),
                          tooltip: 'Increase quantity',
                          onPressed: selectedQuantity < item.quantity
                              ? () => setStateDialog(() => selectedQuantity++)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    // People selection
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select people to share with:',
                        style: textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                     if (splitManager.people.isEmpty)
                      const Text('Add people first using the + button.')
                     else
                      SizedBox(
                        width: double.maxFinite,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: splitManager.people.map((person) {
                            final isSelected = selectedPeople.contains(person);
                            return FilterChip(
                              label: Text(person.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setStateDialog(() { // Update dialog state
                                  if (selected) {
                                    selectedPeople.add(person);
                                  } else {
                                    selectedPeople.remove(person);
                                  }
                                });
                              },
                              selectedColor: colorScheme.primaryContainer,
                              checkmarkColor: colorScheme.onPrimaryContainer,
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  // Disable if no people selected or quantity is invalid
                  onPressed: selectedPeople.isEmpty || selectedQuantity <= 0 ? null : () {
                    // Create a new item with the specified quantity
                    final newItem = ReceiptItem(
                      name: item.name,
                      price: item.price,
                      quantity: selectedQuantity,
                    );

                    // First add the item to shared section
                    splitManager.addItemToShared(newItem, List.from(selectedPeople)); // Pass a copy

                    // Then handle the source item's quantity reduction or removal
                    if (selectedQuantity >= item.quantity) {
                      splitManager.removeUnassignedItem(item);
                    } else {
                      item.updateQuantity(item.quantity - selectedQuantity);
                    }

                    Navigator.pop(dialogContext); // Close the dialog
                  },
                  child: const Text('Share'),
                ),
              ],
            );
          },
        );
      },
    );
  }
} 