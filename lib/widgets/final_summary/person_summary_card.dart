import 'package:flutter/material.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../../models/receipt_item.dart';
import '../../theme/app_colors.dart';

class PersonSummaryCard extends StatefulWidget {
  final Person person;
  final SplitManager splitManager;
  final double taxPercentage;
  final double tipPercentage;

  const PersonSummaryCard({
    Key? key,
    required this.person,
    required this.splitManager,
    required this.taxPercentage,
    required this.tipPercentage,
  }) : super(key: key);

  @override
  State<PersonSummaryCard> createState() => _PersonSummaryCardState();
}

class _PersonSummaryCardState extends State<PersonSummaryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    
    // Calculate subtotals and totals
    final double individualSubtotal = widget.person.assignedItems.fold(
      0.0, (sum, item) => sum + (item.price * item.quantity));
    
    // Calculate shared items subtotal for this person
    final double sharedSubtotal = widget.person.sharedItems.fold(
      0.0, (sum, item) {
        final sharingCount = widget.splitManager.people
            .where((p) => p.sharedItems.contains(item))
            .length;
        return sum + ((item.price * item.quantity) / (sharingCount > 0 ? sharingCount : 1));
      });
    
    final double personSubtotal = individualSubtotal + sharedSubtotal;
    final double taxRate = widget.taxPercentage / 100.0;
    final double tipRate = widget.tipPercentage / 100.0;
    final double personTax = personSubtotal * taxRate;
    final double personTip = personSubtotal * tipRate;
    final double personTotal = personSubtotal + personTax + personTip;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            // Outer shadow - bottom right (diffused)
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(4, 4),
              spreadRadius: 0,
            ),
            // Outer highlight - top left (diffused)
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 10,
              offset: const Offset(-4, -4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Person's name, expand/collapse icon, and total
                Row(
                  children: [
                    // Avatar with neumorphic effect
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.9),
                            blurRadius: 4,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Icon(Icons.person, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Person's name and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.person.name,
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          // Text(
                          //   _isExpanded ? 'Tap to collapse' : 'Tap to expand',
                          //   style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          // ),
                        ],
                      ),
                    ),
                    // Total amount owed in a slate blue pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                      ),
                      child: Text(
                        '\$${personTotal.toStringAsFixed(2)}',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Expand/collapse icon
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                
                // Expanded content - item details, shared items, cost breakdown
                if (_isExpanded) ...[
                  const SizedBox(height: 16),
                  
                  // Individual items list (if any)
                  if (widget.person.assignedItems.isNotEmpty) ...[
                    _buildItemList(context, 'Individual Items:', widget.person.assignedItems),
                    const SizedBox(height: 12),
                  ],
                  
                  // Shared items list (if any)
                  if (widget.person.sharedItems.isNotEmpty) ...[
                    _buildSharedItemList(
                      context, 
                      'Shared Items:', 
                      widget.person.sharedItems, 
                      widget.splitManager
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  
                  // Cost breakdown - Individual, Shared, Subtotal, Tax, Tip, Total
                  Column(
                    children: [
                      // if (widget.person.assignedItems.isNotEmpty)
                      //   _buildDetailRow(context, 'Individual Items:', individualSubtotal),
                      // if (widget.person.sharedItems.isNotEmpty)
                      //   _buildDetailRow(context, 'Shared Items:', sharedSubtotal),
                      _buildDetailRow(context, 'Subtotal:', personSubtotal, isBold: true),
                      _buildDetailRow(
                        context, 
                        'Tax (${widget.taxPercentage.toStringAsFixed(1)}%):', 
                        personTax
                      ),
                      _buildDetailRow(
                        context, 
                        'Tip (${widget.tipPercentage.toStringAsFixed(1)}%):', 
                        personTip
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        context, 
                        'Total Owed:', 
                        personTotal,
                        isBold: true,
                        isTotal: true,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to build item lists consistently  
  Widget _buildItemList(BuildContext context, String title, List<ReceiptItem> items) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          double displayPrice = item.price * item.quantity;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0, left: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${item.quantity}x ${item.name}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '\$${displayPrice.toStringAsFixed(2)}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // Helper to build shared item lists with split information
  Widget _buildSharedItemList(
    BuildContext context, 
    String title, 
    List<ReceiptItem> items, 
    SplitManager splitManager
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.tertiary, // Different color for shared items
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          // Calculate number of people sharing this item
          final sharingCount = splitManager.people
              .where((p) => p.sharedItems.contains(item))
              .length;
          
          // Calculate per-person cost
          double displayPrice = (item.price * item.quantity) / 
              (sharingCount > 0 ? sharingCount : 1);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0, left: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${item.quantity}x ${item.name} (${sharingCount}-way)',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '\$${displayPrice.toStringAsFixed(2)}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // Helper to build detail rows
  Widget _buildDetailRow(BuildContext context, String label, double amount, {bool isBold = false, bool isTotal = false}) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    
    final textStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: isTotal ? AppColors.primary : colorScheme.onSurface,
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textStyle),
          Text('\$${amount.toStringAsFixed(2)}', style: textStyle),
        ],
      ),
    );
  }
} 