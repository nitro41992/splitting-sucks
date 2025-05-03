import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../shared/item_row.dart';

class PersonCard extends StatelessWidget {
  final Person person;
  static const int maxNameLength = 9;

  const PersonCard({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    final splitManager = Provider.of<SplitManager>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Calculate proper shared amount (divide each item by number of people sharing)
    double calculatedSharedAmount = 0.0;
    for (final item in person.sharedItems) {
      final peopleSharing = splitManager.getPeopleForSharedItem(item);
      if (peopleSharing.isNotEmpty) {
        calculatedSharedAmount += (item.price * item.quantity) / peopleSharing.length;
      }
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
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 40.0, 100.0, 16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.secondaryContainer,
                      child: Text(
                        person.name.isNotEmpty ? person.name[0] : '?', // Handle empty name
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IntrinsicWidth(
                      child: Row(
                        children: [
                          Text(
                            person.name,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showEditNameDialog(context, person),
                            icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 20),
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(5),
                              visualDensity: VisualDensity.compact,
                            ),
                            tooltip: 'Edit name',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
              ),
              // Show shared items indicator if person has shared items
              if (person.sharedItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group,
                        size: 18,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'Sharing ${person.sharedItems.length} ${person.sharedItems.length == 1 ? 'item' : 'items'}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '+\$${calculatedSharedAmount.toStringAsFixed(2)}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (person.assignedItems.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: person.assignedItems.map((item) => ItemRow(item: item)).toList(),
                  ),
                ),
            ],
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
                '\$${(person.totalAssignedAmount + calculatedSharedAmount).toStringAsFixed(2)}',
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

  void _showEditNameDialog(BuildContext context, Person person) {
    // Capture the SplitManager here, outside the dialog
    final splitManager = Provider.of<SplitManager>(context, listen: false);
    final controller = TextEditingController(text: person.name);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Edit Name'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Enter name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '', // Remove default counter
              ),
              style: textTheme.bodyLarge,
              textCapitalization: TextCapitalization.words,
              maxLength: maxNameLength,
              autofocus: true,
              onChanged: (value) {
                // Update the state to rebuild the dialog and show the counter
                (dialogContext as Element).markNeedsBuild();
              },
            ),
            const SizedBox(height: 8),
            // Custom counter text
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${controller.text.length}/$maxNameLength',
                style: textTheme.bodySmall?.copyWith(
                  color: controller.text.length > maxNameLength
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName.length <= maxNameLength) {
                // Add debug logging
                print('DEBUG: Updating person name from "${person.name}" to "$newName"');
                
                // Use the previously captured splitManager, not context.read
                print('DEBUG: Split manager people count: ${splitManager.people.length}');
                
                // Update the name
                splitManager.updatePersonName(person, newName);
                
                // Log person name after update attempt
                print('DEBUG: After update - person name is now: "${person.name}"');
                
                Navigator.pop(dialogContext);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
} 