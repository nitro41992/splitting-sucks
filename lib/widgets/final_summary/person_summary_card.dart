import 'package:flutter/material.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../../models/receipt_item.dart';

class PersonSummaryCard extends StatelessWidget {
  final Person person;
  final SplitManager splitManager;
  final double taxPercentage;
  final double tipPercentage;

  const PersonSummaryCard({
    super.key,
    required this.person,
    required this.splitManager,
    required this.taxPercentage,
    required this.tipPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final double taxRate = taxPercentage / 100.0;
    final double tipRate = tipPercentage / 100.0;

    // Calculate individual items total
    final double individualItemsTotal = person.totalAssignedAmount;
    
    // Get person's total from SplitManager (includes shared items split by number of people sharing)
    final double personSubtotal = splitManager.getPersonTotal(person);
    
    // Calculate shared items portion for display
    final double sharedItemsTotal = personSubtotal - individualItemsTotal;
    
    final double personTax = personSubtotal * taxRate;
    final double personTip = personSubtotal * tipRate;
    final double personTotal = personSubtotal + personTax + personTip;

    // Debug the calculation
    debugPrint('[PersonSummaryCard] ${person.name} totals:');
    debugPrint('  - Individual: \$${individualItemsTotal.toStringAsFixed(2)}');
    debugPrint('  - Shared: \$${sharedItemsTotal.toStringAsFixed(2)}');
    debugPrint('  - Subtotal: \$${personSubtotal.toStringAsFixed(2)}');
    // Debug shared items in detail
    if (person.sharedItems.isNotEmpty) {
      debugPrint('[PersonSummaryCard] Shared items for ${person.name}:');
      for (var item in person.sharedItems) {
        final int sharerCount = splitManager.people
            .where((p) => p.sharedItems.any((si) => si.itemId == item.itemId))
            .length;
        debugPrint('  - ${item.name} (${item.itemId}): \$${item.price.toStringAsFixed(1)} × ${item.quantity} ÷ ${sharerCount} people = \$${(item.total / sharerCount).toStringAsFixed(2)} per person');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ExpansionTile(
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Match card shape
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Match card shape
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                person.name,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${personTotal.toStringAsFixed(2)}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                if (person.assignedItems.isNotEmpty)
                  _buildItemList(context, 'Individual Items', person.assignedItems),
                if (person.sharedItems.isNotEmpty)
                  _buildItemList(context, 'Shared Items', person.sharedItems, isShared: true),
                if (person.assignedItems.isEmpty && person.sharedItems.isEmpty)
                   Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No items assigned or shared.', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ),
                const Divider(),
                
                // Show individual and shared subtotals if both exist
                if (individualItemsTotal > 0 && sharedItemsTotal > 0) ...[
                  _buildCostDetailRow(context, 'Individual Items:', '\$${individualItemsTotal.toStringAsFixed(2)}'),
                  _buildCostDetailRow(context, 'Shared Items:', '\$${sharedItemsTotal.toStringAsFixed(2)}'),
                  _buildCostDetailRow(context, 'Subtotal:', '\$${personSubtotal.toStringAsFixed(2)}', isBold: true),
                ] else 
                  // Just show total subtotal if only one type exists
                  _buildCostDetailRow(context, 'Subtotal:', '\$${personSubtotal.toStringAsFixed(2)}'),
                
                _buildCostDetailRow(context, '+ Tax (${taxPercentage.toStringAsFixed(1)}%):', '\$${personTax.toStringAsFixed(2)}'),
                _buildCostDetailRow(context, '+ Tip (${tipPercentage.toStringAsFixed(1)}%):', '\$${personTip.toStringAsFixed(2)}'),
                const Divider(),
                _buildCostDetailRow(context, 'Total Owed:', '\$${personTotal.toStringAsFixed(2)}', isTotal: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(BuildContext context, String title, List<ReceiptItem> items, {bool isShared = false}) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title:', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          ...items.map((item) {
            String details = '';
            double itemCost = item.price * item.quantity;
            if (isShared) {
              final sharingCount = splitManager.people
                  .where((p) => p.sharedItems.any((si) => si.itemId == item.itemId))
                  .length;
              
              final individualShare = sharingCount > 0 ? (itemCost / sharingCount) : 0.0;
              details = '(${sharingCount}-way split: \$${individualShare.toStringAsFixed(2)})';
            } else {
              details = '(\$${itemCost.toStringAsFixed(2)})';
            }
            return Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
              child: Text(
                '• ${item.quantity}x ${item.name} ${details}',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCostDetailRow(BuildContext context, String label, String value, {bool isTotal = false, bool isBold = false}) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: isTotal || isBold ? FontWeight.bold : null,
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isTotal ? colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
} 