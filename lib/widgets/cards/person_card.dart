import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../shared/item_row.dart';
import '../../theme/neumorphic_theme.dart';
import '../neumorphic/neumorphic_container.dart' hide NeumorphicPricePill;
import '../neumorphic/neumorphic_avatar.dart';
import '../neumorphic/neumorphic_text_field.dart';
import '../neumorphic/neumorphic_icon_button.dart';
// Import the NeumorphicPricePill explicitly to avoid conflict
import '../neumorphic/neumorphic_container.dart' as price_pill show NeumorphicPricePill;


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
        final double shareAmount = (item.price * item.quantity) / peopleSharing.length;
        // Round to 2 decimal places for consistency with other calculations
        final double roundedShare = double.parse(shareAmount.toStringAsFixed(2));
        calculatedSharedAmount += roundedShare;
      }
    }

    // Check if person has any items (either assigned or shared)
    final bool hasNoItems = person.assignedItems.isEmpty && person.sharedItems.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: NeumorphicContainer(
        type: NeumorphicType.raised,
        radius: NeumorphicTheme.cardRadius,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 32.0, 100.0, 12.0),
                  child: Row(
                    children: [
                      // Neumorphic Avatar (slightly smaller)
                      NeumorphicAvatar(
                        text: person.name,
                        size: 48, // Reduced from NeumorphicTheme.largeAvatarSize
                        backgroundColor: NeumorphicTheme.slateBlue,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                person.name,
                                style: NeumorphicTheme.primaryText(
                                  size: 16.0, // Reduced from NeumorphicTheme.titleLarge
                                  weight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button
                                NeumorphicIconButton(
                                  icon: Icons.edit_outlined,
                                  type: NeumorphicType.inset,
                                  size: 32,
                                  iconSize: 16,
                                  onPressed: () => _showEditNameDialog(context, person),
                                ),
                                // Delete button (only visible when no items assigned)
                                if (hasNoItems)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: NeumorphicIconButton(
                                      icon: Icons.delete_outline,
                                      type: NeumorphicType.inset,
                                      size: 32,
                                      iconSize: 16,
                                      iconColor: NeumorphicTheme.mutedRed,
                                      onPressed: () => _showDeleteConfirmation(context, person),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(height: 1, thickness: 1, color: NeumorphicTheme.mediumGrey.withOpacity(0.3)),
                ),
                // Show shared items indicator if person has shared items
                if (person.sharedItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: NeumorphicTheme.slateBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.group,
                            size: 16, // Reduced from 18
                            color: NeumorphicTheme.slateBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                'Sharing ${person.sharedItems.length} ${person.sharedItems.length == 1 ? 'item' : 'items'}',
                                style: NeumorphicTheme.primaryText(
                                  size: 13, // Reduced from 14
                                  weight: FontWeight.w500,
                                  color: NeumorphicTheme.slateBlue,
                                ),
                              ),
                              const Spacer(),
                              NeumorphicPill(
                                color: NeumorphicTheme.mutedCoral,
                                child: Text(
                                  '+\$${calculatedSharedAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
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
                      color: NeumorphicTheme.pageBackground,
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
                // Show empty state indicator when person has no items
                if (hasNoItems)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    child: _buildEmptyPersonState(),
                  ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: price_pill.NeumorphicPricePill(
                price: person.totalAssignedAmount,
                color: NeumorphicTheme.slateBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build the empty state UI
  Widget _buildEmptyPersonState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 18,
            color: NeumorphicTheme.mediumGrey,
          ),
          const SizedBox(width: 8),
          Text(
            'No items assigned yet',
            style: TextStyle(
              fontSize: 14,
              color: NeumorphicTheme.mediumGrey,
              fontWeight: FontWeight.w500,
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

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: NeumorphicContainer(
          type: NeumorphicType.raised,
          radius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit, 
                    color: NeumorphicTheme.slateBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Name', 
                    style: NeumorphicTheme.primaryText(
                      size: 18, 
                      weight: FontWeight.w600
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              NeumorphicTextField(
                controller: controller,
                labelText: 'Name',
                hintText: 'Enter name',
                prefixIcon: Icon(
                  Icons.person_outline, 
                  color: NeumorphicTheme.slateBlue,
                  size: 18,
                ),
                maxLength: maxNameLength,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
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
                      final newName = controller.text.trim();
                      if (newName.isNotEmpty && newName.length <= maxNameLength) {
                        // Update the name
                        splitManager.updatePersonName(person, newName);
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check, 
                          color: Colors.white, 
                          size: 18
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Update',
                          style: NeumorphicTheme.onAccentText(
                            size: 15, 
                            weight: FontWeight.w500
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
      ),
    );
  }

  // Method to show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, Person person) {
    final splitManager = Provider.of<SplitManager>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: NeumorphicContainer(
          type: NeumorphicType.raised,
          radius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.delete_outline, 
                    color: NeumorphicTheme.mutedRed,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Remove Person', 
                    style: NeumorphicTheme.primaryText(
                      size: 18, 
                      weight: FontWeight.w600
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to remove ${person.name}?',
                style: NeumorphicTheme.primaryText(size: 15),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: NeumorphicTheme.slateBlue,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  NeumorphicButton(
                    color: NeumorphicTheme.mutedRed,
                    radius: 8,
                    onPressed: () {
                      splitManager.removePerson(person);
                      Navigator.pop(dialogContext);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.delete, 
                          color: Colors.white, 
                          size: 18
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remove',
                          style: NeumorphicTheme.onAccentText(
                            size: 15, 
                            weight: FontWeight.w500
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
      ),
    );
  }
} 