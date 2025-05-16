import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../shared/item_row.dart';
import '../../theme/neumorphic_theme.dart';
import '../neumorphic/neumorphic_container.dart';
import '../neumorphic/neumorphic_avatar.dart';
import '../neumorphic/neumorphic_text_field.dart';
import '../neumorphic/neumorphic_icon_button.dart';

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
                  padding: const EdgeInsets.fromLTRB(16.0, 40.0, 100.0, 16.0),
                  child: Row(
                    children: [
                      // Neumorphic Avatar
                      NeumorphicAvatar(
                        text: person.name,
                        size: NeumorphicTheme.largeAvatarSize,
                        backgroundColor: NeumorphicTheme.slateBlue,
                      ),
                      const SizedBox(width: 16),
                      IntrinsicWidth(
                        child: Row(
                          children: [
                            Text(
                              person.name,
                              style: NeumorphicTheme.primaryText(
                                size: NeumorphicTheme.titleLarge,
                                weight: FontWeight.bold,
                              ),
                            ),
                            NeumorphicIconButton(
                              icon: Icons.edit_outlined,
                              type: NeumorphicType.inset,
                              size: 32,
                              iconSize: 16,
                              onPressed: () => _showEditNameDialog(context, person),
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
                        Icon(
                          Icons.group,
                          size: 18,
                          color: NeumorphicTheme.slateBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                'Sharing ${person.sharedItems.length} ${person.sharedItems.length == 1 ? 'item' : 'items'}',
                                style: NeumorphicTheme.primaryText(
                                  size: 14,
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
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: NeumorphicPricePill(
                price: person.totalAssignedAmount,
                color: NeumorphicTheme.slateBlue,
              ),
            ),
          ],
        ),
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
} 