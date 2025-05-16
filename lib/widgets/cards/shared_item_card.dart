import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/split_manager.dart';
import '../shared/quantity_selector.dart';
import '../../theme/neumorphic_theme.dart';
import '../neumorphic/neumorphic_container.dart';
import '../neumorphic/neumorphic_avatar.dart';

class SharedItemCard extends StatelessWidget {
  final ReceiptItem item;

  const SharedItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.read<SplitManager>();
    final people = context.select((SplitManager sm) => sm.people);

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
                      // Wrap the text in GestureDetector to show toast when clicked
                      GestureDetector(
                        onTap: () => _showAssignedItemToast(context),
                        child: Text(
                          '${item.quantity} x \$${item.price.toStringAsFixed(2)} each',
                          style: NeumorphicTheme.primaryText(),
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
                ),
                
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Divider(height: 1, thickness: 1, color: NeumorphicTheme.mediumGrey.withOpacity(0.3)),
                ),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shared with:',
                        style: NeumorphicTheme.primaryText(
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (people.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'No people added yet.',
                            style: NeumorphicTheme.secondaryText(),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: people.map((person) {
                            // ALWAYS use itemId for comparison to ensure consistent selection state
                            final isSelected = person.sharedItems.any((si) => 
                              // Try by itemId match first (most reliable)
                              (si.itemId != null && item.itemId != null && si.itemId == item.itemId) ||
                              // Fall back to name and price match
                              (si.name == item.name && si.price == item.price)
                            );
                            
                            return NeumorphicPill(
                              color: isSelected ? NeumorphicTheme.slateBlue : Colors.white,
                              onTap: () {
                                if (isSelected) {
                                  // Remove person from shared item
                                  Provider.of<SplitManager>(context, listen: false).removePersonFromSharedItem(item, person);
                                } else {
                                  // Add person to shared item
                                  Provider.of<SplitManager>(context, listen: false).addPersonToSharedItem(item, person);
                                }
                              },
                              child: Text(
                                person.name,
                                style: isSelected 
                                  ? const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    )
                                  : TextStyle(
                                      color: NeumorphicTheme.slateBlue,
                                      fontWeight: FontWeight.normal,
                                      fontSize: 14,
                                    ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),

            Positioned(
              top: 8,
              right: 8,
              child: NeumorphicPricePill(
                price: item.total,
                color: NeumorphicTheme.slateBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

