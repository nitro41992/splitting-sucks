import 'package:billfie/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../shared/editable_price.dart';
import 'package:flutter/services.dart';
import '../shared/quantity_selector.dart';
import '../../theme/neumorphic_theme.dart';
import '../neumorphic/neumorphic_container.dart' hide NeumorphicPricePill;
import '../neumorphic/neumorphic_avatar.dart' hide NeumorphicPricePill;
import '../neumorphic/neumorphic_text_field.dart';

class UnassignedItemCard extends StatelessWidget {
  final ReceiptItem item;

  const UnassignedItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.watch<SplitManager>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: NeumorphicContainer(
        type: NeumorphicType.raised,
        radius: NeumorphicTheme.cardRadius,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 20.0, 80.0, 16.0),
                  child: Text(
                    item.name,
                    style: NeumorphicTheme.primaryText(
                      size: NeumorphicTheme.titleLarge,
                      weight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${item.quantity} x \$${item.price.toStringAsFixed(2)} each',
                        style: NeumorphicTheme.primaryText(),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Delete button
                          NeumorphicIconButton(
                            icon: Icons.delete_outline,
                            iconColor: NeumorphicTheme.mutedRed,
                            type: NeumorphicType.inset,
                            size: 36,
                            iconSize: 20,
                            onPressed: () => _confirmDelete(context, splitManager, item),
                          ),
                          const SizedBox(width: 8),
                          // Edit button
                          NeumorphicIconButton(
                            icon: Icons.edit_outlined,
                            iconColor: NeumorphicTheme.slateBlue,
                            type: NeumorphicType.inset,
                            size: 36,
                            iconSize: 20,
                            onPressed: () => _showEditDialog(context, splitManager, item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Divider(height: 1, thickness: 1, color: NeumorphicTheme.mediumGrey.withOpacity(0.3)),
                ),
                const SizedBox(height: 16),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
                  child: NeumorphicButton(
                    color: NeumorphicTheme.slateBlue,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_add, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Assign Item',
                          style: NeumorphicTheme.onAccentText(
                            size: 16,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    onPressed: () => _showAssignDialog(context, splitManager, item),
                  ),
                ),
              ],
            ),
            
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: NeumorphicTheme.slateBlue,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Text(
                  '\$${item.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: NeumorphicContainer(
          type: NeumorphicType.raised,
          radius: 16,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_add,
                    color: NeumorphicTheme.slateBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Assign Item',
                    style: NeumorphicTheme.primaryText(
                      size: 18,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Choose how to assign this item:',
                style: NeumorphicTheme.primaryText(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: NeumorphicButton(
                      color: NeumorphicTheme.slateBlue,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'To Person',
                            style: NeumorphicTheme.onAccentText(),
                          ),
                        ],
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Close this dialog first
                        _showAssignToPersonDialog(context, splitManager, item);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeumorphicButton(
                      color: NeumorphicTheme.mutedCoral,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.group, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Share',
                            style: NeumorphicTheme.onAccentText(),
                          ),
                        ],
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Close this dialog first
                        _showShareDialog(context, splitManager, item);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: NeumorphicTheme.mutedRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignToPersonDialog(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    // Initialize with 1 if the item quantity is greater than 1, otherwise use item.quantity
    int selectedQuantity = item.quantity > 1 ? 1 : item.quantity;
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
                      Row(
                        children: [
                          // Max button
                          OutlinedButton(
                            onPressed: selectedQuantity < item.quantity
                                ? () => setStateDialog(() => selectedQuantity = item.quantity)
                                : null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(50, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              side: BorderSide(color: colorScheme.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text('Max', style: textTheme.labelMedium),
                          ),
                          const SizedBox(width: 8),
                          // Quantity controls
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
    // Initialize with 1 if the item quantity is greater than 1, otherwise use item.quantity
    int selectedQuantity = item.quantity > 1 ? 1 : item.quantity;
    final List<Person> selectedPeople = []; // Track selected people within the dialog
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    bool hasAttemptedSubmitWithOnePerson = false; // Track submission attempts with one person

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
                        onPressed: selectedQuantity > 0 ? () {
                          if (hasOnlyOnePerson) {
                            setStateDialog(() {
                              hasAttemptedSubmitWithOnePerson = true;
                            });
                            return;
                          }
                          
                          if (isShareValid) {
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
                          }
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
                        Row(
                          children: [
                            // Max button
                            OutlinedButton(
                              onPressed: selectedQuantity < item.quantity
                                  ? () => setStateDialog(() => selectedQuantity = item.quantity)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(50, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                side: BorderSide(color: colorScheme.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text('Max', style: textTheme.labelMedium),
                            ),
                            const SizedBox(width: 8),
                            // Quantity controls
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
                  if (hasOnlyOnePerson && hasAttemptedSubmitWithOnePerson)
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
                                  // Reset the attempt status when selection changes
                                  hasAttemptedSubmitWithOnePerson = false;
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

  void _confirmDelete(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: colorScheme.error),
            const SizedBox(width: 8),
            const Text('Delete Item'),
          ],
        ),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              splitManager.removeUnassignedItem(item);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toStringAsFixed(2));
    int editedQuantity = item.quantity;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: NeumorphicContainer(
              type: NeumorphicType.raised,
              radius: 16,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        color: NeumorphicTheme.slateBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Edit Item',
                        style: NeumorphicTheme.primaryText(
                          size: 18,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  NeumorphicTextField(
                    controller: nameController,
                    labelText: 'Item Name',
                    hintText: 'Enter item name',
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  NeumorphicTextField(
                    controller: priceController,
                    labelText: 'Price',
                    hintText: 'Enter price',
                    prefixText: '\$',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity:',
                        style: NeumorphicTheme.primaryText(
                          weight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          NeumorphicIconButton(
                            icon: Icons.remove,
                            type: NeumorphicType.inset,
                            size: 36,
                            iconSize: 18,
                            radius: 18,
                            iconColor: editedQuantity > 1
                                ? NeumorphicTheme.slateBlue
                                : NeumorphicTheme.mediumGrey.withOpacity(0.5),
                            onPressed: editedQuantity > 1
                                ? () => setState(() => editedQuantity--)
                                : null,
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              editedQuantity.toString(),
                              style: NeumorphicTheme.primaryText(
                                weight: FontWeight.bold,
                              ),
                            ),
                          ),
                          NeumorphicIconButton(
                            icon: Icons.add,
                            type: NeumorphicType.inset,
                            size: 36,
                            iconSize: 18,
                            radius: 18,
                            iconColor: NeumorphicTheme.slateBlue,
                            onPressed: () => setState(() => editedQuantity++),
                          ),
                        ],
                      ),
                    ],
                  ),
                
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: NeumorphicTheme.mutedRed,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      NeumorphicButton(
                        color: NeumorphicTheme.slateBlue,
                        radius: 8,
                        onPressed: () {
                          // Validate inputs
                          final newName = nameController.text.trim();
                          if (newName.isEmpty) return;
                          
                          final double? newPrice = double.tryParse(priceController.text);
                          if (newPrice == null || newPrice <= 0) return;
                          
                          // Update the item
                          splitManager.updateUnassignedItem(
                            item,
                            editedQuantity,
                            newPrice,
                          );
                          
                          // Also update the name if changed
                          if (newName != item.name) {
                            item.updateName(newName);
                          }
                          
                          Navigator.pop(context);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Save',
                              style: NeumorphicTheme.onAccentText(
                                size: 15,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 