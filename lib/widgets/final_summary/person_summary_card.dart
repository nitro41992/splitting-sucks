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

    final double personSubtotal = person.totalAssignedAmount +
        splitManager.sharedItems.where((item) => person.sharedItems.contains(item)).fold(
            0.0,
            (sum, item) {
              final sharingCount = splitManager.people.where((p) => p.sharedItems.contains(item)).length;
              return sum + (sharingCount > 0 ? (item.price * item.quantity / sharingCount) : 0.0);
            },
          );
    final double personTax = personSubtotal * taxRate;
    final double personTip = personSubtotal * tipRate;
    final double personTotal = personSubtotal + personTax + personTip;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Match card shape
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Match card shape
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              final sharingCount = splitManager.people.where((p) => p.sharedItems.contains(item)).length;
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

  Widget _buildCostDetailRow(BuildContext context, String label, String value, {bool isTotal = false}) {
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
              fontWeight: isTotal ? FontWeight.bold : null,
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