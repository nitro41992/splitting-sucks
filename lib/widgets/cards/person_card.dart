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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Text(
                    person.name.isNotEmpty ? person.name[0] : '?', // Handle empty name
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              person.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showEditNameDialog(context, person),
                            icon: Icon(Icons.edit_outlined, color: colorScheme.primary, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
                              padding: const EdgeInsets.all(8),
                              visualDensity: VisualDensity.compact,
                            ),
                            tooltip: 'Edit name',
                          ),
                        ],
                      ),
                      if (person.assignedItems.isNotEmpty)
                        Text(
                          '${person.assignedItems.length} item${person.assignedItems.length == 1 ? '' : 's'}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '\$${person.totalAssignedAmount.toStringAsFixed(2)}',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
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
    );
  }

  void _showEditNameDialog(BuildContext context, Person person) {
    final controller = TextEditingController(text: person.name);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                (context as Element).markNeedsBuild();
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName.length <= maxNameLength) {
                context.read<SplitManager>().updatePersonName(person, newName);
                Navigator.pop(context);
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