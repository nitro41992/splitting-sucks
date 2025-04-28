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
                const SizedBox(width: 24),
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
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Assign to Person',
                        style: textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the header
                  ],
                ),
                const Divider(),
                
                // Item info
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Card(
                    color: colorScheme.surface,
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '\$${item.price.toStringAsFixed(2)}',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Quantity selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('Quantity:', style: textTheme.titleMedium),
                      const Spacer(),
                      Material(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: selectedQuantity > 1
                                  ? () => setStateDialog(() => selectedQuantity--)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            SizedBox(
                              width: 32,
                              child: Text(
                                selectedQuantity.toString(),
                                style: textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: selectedQuantity < item.quantity
                                  ? () => setStateDialog(() => selectedQuantity++)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),
                
                // People section title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Select a person:',
                    style: textTheme.titleMedium,
                  ),
                ),
                
                // People grid
                Expanded(
                  child: splitManager.people.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 48, color: colorScheme.outline),
                              const SizedBox(height: 16),
                              Text(
                                'No people added yet',
                                style: textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add people using the + button first',
                                style: textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: splitManager.people.length,
                        itemBuilder: (context, index) {
                          final person = splitManager.people[index];
                          return Card(
                            elevation: 1,
                            color: colorScheme.surface,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: selectedQuantity > 0 ? () {
                                // Create a new item with the specified quantity
                                final newItem = ReceiptItem(
                                  name: item.name,
                                  price: item.price,
                                  quantity: selectedQuantity,
                                );

                                // Assign the new item
                                splitManager.assignItemToPerson(newItem, person);

                                // Handle the source item's quantity reduction or removal
                                if (selectedQuantity >= item.quantity) {
                                  splitManager.removeUnassignedItem(item);
                                } else {
                                  item.updateQuantity(item.quantity - selectedQuantity);
                                }

                                Navigator.pop(context); // Close the dialog
                              } : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: colorScheme.primary,
                                      child: Text(
                                        person.name.isNotEmpty ? person.name[0] : '?',
                                        style: TextStyle(color: colorScheme.onPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        person.name,
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            // Validation for selected people
            final bool hasSelectedPeople = selectedPeople.isNotEmpty;
            final bool hasOnlyOnePerson = selectedPeople.length == 1;
            final bool isShareValid = hasSelectedPeople && !hasOnlyOnePerson;
            
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Share Item',
                          style: textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: isShareValid && selectedQuantity > 0 ? () {
                          // Create a new item with the specified quantity
                          final newItem = ReceiptItem(
                            name: item.name,
                            price: item.price,
                            quantity: selectedQuantity,
                          );

                          // Add the item to shared section
                          splitManager.addItemToShared(newItem, List.from(selectedPeople));

                          // Handle the source item's quantity reduction or removal
                          if (selectedQuantity >= item.quantity) {
                            splitManager.removeUnassignedItem(item);
                          } else {
                            item.updateQuantity(item.quantity - selectedQuantity);
                          }

                          Navigator.pop(dialogContext);
                        } : null,
                      ),
                    ],
                  ),
                  const Divider(),
                  
                  // Item info
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Card(
                      color: colorScheme.surface,
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              '\$${item.price.toStringAsFixed(2)}',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Quantity selector
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text('Quantity:', style: textTheme.titleMedium),
                        const Spacer(),
                        Material(
                          color: colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: selectedQuantity > 1
                                    ? () => setStateDialog(() => selectedQuantity--)
                                    : null,
                                visualDensity: VisualDensity.compact,
                              ),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  selectedQuantity.toString(),
                                  style: textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: selectedQuantity < item.quantity
                                    ? () => setStateDialog(() => selectedQuantity++)
                                    : null,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(),
                  
                  // Selected people section header with hint - Fix the overflow
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select multiple people to share with:',
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Select at least 2 people',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            if (selectedPeople.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${selectedPeople.length} selected',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Validation message for single person selection
                  if (hasOnlyOnePerson)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'For a single person, use "Assign to Person" instead',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // People grid
                  if (splitManager.people.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: colorScheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              'No people added yet',
                              style: textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add people using the + button first',
                              style: textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: splitManager.people.length,
                        itemBuilder: (context, index) {
                          final person = splitManager.people[index];
                          final isSelected = selectedPeople.contains(person);
                          
                          return Card(
                            elevation: 1,
                            color: isSelected 
                                ? colorScheme.primaryContainer 
                                : colorScheme.surface,
                            child: InkWell(
                              onTap: () {
                                setStateDialog(() {
                                  if (isSelected) {
                                    selectedPeople.remove(person);
                                  } else {
                                    selectedPeople.add(person);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.primary,
                                      child: isSelected
                                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                                          : Text(
                                              person.name.isNotEmpty ? person.name[0] : '?',
                                              style: TextStyle(color: colorScheme.onPrimary),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        person.name,
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: isSelected
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
} 