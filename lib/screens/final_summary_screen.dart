import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/split_manager.dart';
import '../models/receipt_item.dart'; // Ensure ReceiptItem is available if needed for calculations/display
import '../theme/app_colors.dart'; // Ensure AppColors is correctly defined or replace with Theme colors
import '../widgets/split_view.dart'; // Import to get NavigateToPageNotification
import '../widgets/final_summary/person_summary_card.dart'; // Import the new card

class FinalSummaryScreen extends StatefulWidget {
  const FinalSummaryScreen({
    super.key,
  });

  @override
  State<FinalSummaryScreen> createState() => _FinalSummaryScreenState();
}

class _FinalSummaryScreenState extends State<FinalSummaryScreen> {
  static const double DEFAULT_TAX_RATE = 8.875; // Default NYC tax rate

  double _tipPercentage = 20.0;
  double _taxPercentage = DEFAULT_TAX_RATE;
  late TextEditingController _taxController;

  @override
  void initState() {
    super.initState();
    // Initialize tax percentage potentially from SplitManager if needed, otherwise use default
    // Example: _taxPercentage = context.read<SplitManager>().initialTaxRate ?? DEFAULT_TAX_RATE;
    // For now, just use the default or last known value.
    _taxController = TextEditingController(text: _taxPercentage.toStringAsFixed(3));

    _taxController.addListener(() {
      final newTax = double.tryParse(_taxController.text);
      if (newTax != null && newTax >= 0) {
        if (_taxPercentage != newTax) {
           setState(() {
             _taxPercentage = newTax;
             // Optionally update SplitManager if tax is global
             // context.read<SplitManager>().updateTaxRate(newTax);
           });
        }
      } else if (_taxController.text.isEmpty) {
        if (_taxPercentage != 0.0) { // Avoid rebuild if already 0
          setState(() {
            _taxPercentage = 0.0; // Set tax to 0 if input is cleared
            // context.read<SplitManager>().updateTaxRate(0.0);
          });
        }
      }
      // If input is invalid (not empty, not parsable), keep the last valid percentage
    });
  }

  @override
  void dispose() {
    _taxController.dispose();
    super.dispose();
  }

  Future<void> _launchBuyMeACoffee(BuildContext context) async {
    final String? buyMeACoffeeLink = dotenv.env['BUY_ME_A_COFFEE_LINK'];
    if (buyMeACoffeeLink == null || buyMeACoffeeLink.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buy Me a Coffee link is not configured.')),
      );
      return;
    }

    final Uri url = Uri.parse(buyMeACoffeeLink);
    try {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            throw 'Could not launch $url';
        }
    } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch link: ${e.toString()}')),
        );
    }
  }

  Future<void> _generateAndShareReceipt(BuildContext context) async {
    // Access SplitManager via context.read since we don't need to listen for changes here
    final splitManager = context.read<SplitManager>();
    final people = splitManager.people;
    final colorScheme = Theme.of(context).colorScheme; // Use Theme context

    // Use the current state values for tax and tip percentages
    final double subtotal = splitManager.totalAmount;
    final double taxRate = _taxPercentage / 100.0;
    final double tipRate = _tipPercentage / 100.0;
    final double tax = subtotal * taxRate;
    final double tip = subtotal * tipRate;
    final double total = subtotal + tax + tip;

    // Build receipt text
    StringBuffer receipt = StringBuffer();
    receipt.writeln('🧾 RECEIPT SUMMARY');
    receipt.writeln('═══════════════════\\n');
    receipt.writeln('📊 TOTALS');
    receipt.writeln('Subtotal: \$${subtotal.toStringAsFixed(2)}');
    receipt.writeln('Tax (${_taxPercentage.toStringAsFixed(1)}%): \$${tax.toStringAsFixed(2)}');
    receipt.writeln('Tip (${_tipPercentage.toStringAsFixed(1)}%): \$${tip.toStringAsFixed(2)}');
    receipt.writeln('TOTAL: \$${total.toStringAsFixed(2)}\\n');
    receipt.writeln('👥 INDIVIDUAL BREAKDOWNS');
    receipt.writeln('═══════════════════');

    for (var person in people) {
      final double personSubtotal = person.totalAssignedAmount +
          splitManager.sharedItems.where((item) =>
            person.sharedItems.contains(item)).fold(0.0,
            (sum, item) {
              final sharingCount = splitManager.people.where((p) => p.sharedItems.contains(item)).length;
              return sum + (sharingCount > 0 ? (item.price * item.quantity / sharingCount) : 0.0);
            });
      final double personTax = personSubtotal * taxRate;
      final double personTip = personSubtotal * tipRate;
      final double personTotal = personSubtotal + personTax + personTip;

      receipt.writeln('\\n👤 ${person.name.toUpperCase()} → YOU OWE: \$${personTotal.toStringAsFixed(2)}');
      receipt.writeln('───────────────');

      if (person.assignedItems.isNotEmpty) {
        receipt.writeln('Individual Items:');
        for (var item in person.assignedItems) {
          receipt.writeln('  • ${item.quantity}x ${item.name} (\$${(item.price * item.quantity).toStringAsFixed(2)})');
        }
      }

      if (person.sharedItems.isNotEmpty) {
        receipt.writeln('\\nShared Items:');
        for (var item in person.sharedItems) {
          final sharingCount = splitManager.people.where((p) => p.sharedItems.contains(item)).length;
          final individualShare = sharingCount > 0 ? (item.price * item.quantity / sharingCount) : 0.0;
          receipt.writeln('  • ${item.quantity}x ${item.name} (${sharingCount}-way split: \$${individualShare.toStringAsFixed(2)})');
        }
      }

      receipt.writeln('\\nDetails:');
      receipt.writeln('  Subtotal: \$${personSubtotal.toStringAsFixed(2)}');
      receipt.writeln('  + Tax (${_taxPercentage.toStringAsFixed(1)}%): \$${personTax.toStringAsFixed(2)}');
      receipt.writeln('  + Tip (${_tipPercentage.toStringAsFixed(1)}%): \$${personTip.toStringAsFixed(2)}');
      receipt.writeln('  = Total: \$${personTotal.toStringAsFixed(2)}');
    }

    if (splitManager.unassignedItems.isNotEmpty) {
      receipt.writeln('\\n⚠️ UNASSIGNED ITEMS');
      receipt.writeln('═══════════════════');
      for (var item in splitManager.unassignedItems) {
        receipt.writeln('• ${item.quantity}x ${item.name} (\$${(item.price * item.quantity).toStringAsFixed(2)})');
      }
      final double unassignedSubtotal = splitManager.unassignedItemsTotal;
      final double unassignedTax = unassignedSubtotal * taxRate;
      final double unassignedTip = unassignedSubtotal * tipRate;
      final double unassignedTotal = unassignedSubtotal + unassignedTax + unassignedTip;
      receipt.writeln('\\nUnassigned Total (inc. tax/tip): \$${unassignedTotal.toStringAsFixed(2)}');
    }

    await Clipboard.setData(ClipboardData(text: receipt.toString()));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Receipt copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(dialogContext).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Receipt Copied!'),
          ],
        ),
        content: const Text('The receipt summary has been copied to your clipboard. You can now paste it anywhere!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // Use context.watch here to rebuild when SplitManager changes (e.g., assignments update)
    final splitManager = context.watch<SplitManager>();

    // Check if there's anything to summarize. Rely on SplitManager state.
    if (splitManager.people.isEmpty && splitManager.unassignedItems.isEmpty && splitManager.sharedItems.isEmpty) {
       return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.summarize_outlined,
                size: 60,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Split Summary Available',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Assign items to people or mark them as shared first.', // More specific message
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                  // Notify the parent PageView controller to navigate
                  NavigateToPageNotification(3).dispatch(context); // Go to Split View (index 3)
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go to Split View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final people = splitManager.people;
    final double subtotal = splitManager.totalAmount;
    // Use current state for tax/tip rates
    final double taxRate = _taxPercentage / 100.0;
    final double tipRate = _tipPercentage / 100.0;
    final double tax = subtotal * taxRate;
    final double tip = subtotal * tipRate;
    final double total = subtotal + tax + tip;

    // Verification calculation
    double sumOfIndividualTotals = 0.0;
    for (var person in people) {
      final double personSubtotal = person.totalAssignedAmount +
          splitManager.sharedItems.where((item) =>
            person.sharedItems.contains(item)).fold(0.0,
            (sum, item) {
              final sharingCount = splitManager.people.where((p) => p.sharedItems.contains(item)).length;
              return sum + (sharingCount > 0 ? (item.price * item.quantity / sharingCount) : 0.0);
            });
      final double personTax = personSubtotal * taxRate;
      final double personTip = personSubtotal * tipRate;
      sumOfIndividualTotals += personSubtotal + personTax + personTip;
    }
    // Add total cost of unassigned items (including their portion of tax/tip)
    if (splitManager.unassignedItems.isNotEmpty) {
      final double unassignedSubtotal = splitManager.unassignedItemsTotal;
      final double unassignedTax = unassignedSubtotal * taxRate;
      final double unassignedTip = unassignedSubtotal * tipRate;
      sumOfIndividualTotals += unassignedSubtotal + unassignedTax + unassignedTip;
    }
    // Allow for small floating point inaccuracies
    final bool totalsMatch = (total - sumOfIndividualTotals).abs() < 0.01;

    return Stack(
      children: [
        ListView(
          // Add padding at the bottom to ensure content isn't hidden by FABs
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // Show warning if totals don't match due to rounding/distribution
            if (!totalsMatch)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                color: colorScheme.errorContainer.withOpacity(0.8), // Slightly transparent
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Warning: Sum of parts (\$${sumOfIndividualTotals.toStringAsFixed(2)}) '
                          'doesn\'t perfectly match total (\$${total.toStringAsFixed(2)}). '
                          'This might be due to rounding.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Header Card: Overall Totals, Tax/Tip Adjustment
            Card(
              elevation: 1, // Subtle elevation
              shadowColor: colorScheme.shadow.withOpacity(0.2),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                // side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)), // Optional border
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Receipt Totals',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Subtotal row
                    _buildTotalRow(context, 'Subtotal:', subtotal),
                    const SizedBox(height: 16),

                    // Tax Input Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Tax:', style: textTheme.titleMedium), // Match Subtotal style
                        const Spacer(), // Pushes input field and amount to the right
                        SizedBox(
                          width: 90, // Adjusted width
                          height: 40, // Constrain height
                          child: TextField(
                            controller: _taxController,
                            textAlignVertical: TextAlignVertical.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                               FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')), // Allow digits and up to 3 decimal points
                            ],
                            decoration: InputDecoration(
                              suffixText: '%',
                              isDense: true, // Makes it more compact
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Adjust padding
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            textAlign: TextAlign.right,
                            style: textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(width: 16), // Space between input and amount
                        SizedBox(
                          width: 80, // Width for the amount
                          child: Text(
                            '\$${tax.toStringAsFixed(2)}',
                            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tip Section Label
                    Row(
                       children: [ Text('Tip:', style: textTheme.titleMedium) ], // Match Subtotal style
                    ),
                    const SizedBox(height: 8),

                    // Tip Percentage Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_tipPercentage.toStringAsFixed(1)}%',
                          style: textTheme.headlineSmall?.copyWith( // Make percentage stand out
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4), // Reduced space

                    // Tip Controls (Buttons and Slider)
                    Column(
                      children: [
                        // Quick select buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [15.0, 18.0, 20.0, 25.0].map((percentage) {
                            bool isSelected = (_tipPercentage - percentage).abs() < 0.01;
                            return ElevatedButton(
                              onPressed: () {
                                setState(() { _tipPercentage = percentage; });
                              },
                              style: ElevatedButton.styleFrom(
                                elevation: isSelected ? 2 : 0,
                                backgroundColor: isSelected ? colorScheme.primary : colorScheme.surfaceVariant,
                                foregroundColor: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Pill shape
                              ),
                              child: Text('${percentage.toInt()}%'), // Show integer percentage on button
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),

                        // Fine-tune slider
                        Slider(
                          value: _tipPercentage,
                          min: 0,
                          max: 30, // Max tip percentage
                          divisions: 60, // Allows 0.5% increments
                          label: '${_tipPercentage.toStringAsFixed(1)}%',
                          onChanged: (value) {
                             // Round to one decimal place
                            setState(() { _tipPercentage = (value * 10).round() / 10.0; });
                          },
                        ),
                      ],
                    ),
                     const SizedBox(height: 4), // Reduced space

                    // Tip Amount Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Tip Amount: ',
                          style: textTheme.bodyLarge,
                        ),
                        SizedBox(
                          width: 80, // Align with tax amount width
                           child: Text(
                             '\$${tip.toStringAsFixed(2)}',
                             style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                             textAlign: TextAlign.right,
                           ),
                        ),
                      ],
                    ),

                    const Divider(height: 32, thickness: 1), // Increased spacing around divider

                    // Grand Total Row
                    _buildTotalRow(context, 'Total:', total, isGrandTotal: true),
                  ],
                ),
              ),
            ),

            // People section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Add padding
              child: Row(
                children: [
                  Icon(Icons.people_outline, size: 24, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Split Summary (${people.length} ${people.length == 1 ? "Person" : "People"})',
                    style: textTheme.titleLarge?.copyWith( // Slightly larger title
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Individual Person Cards
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: splitManager.people.length,
              itemBuilder: (context, index) {
                final person = splitManager.people[index];
                return PersonSummaryCard(
                  key: ValueKey(person.name), // Use person's name as key (assuming unique)
                  person: person,
                  splitManager: splitManager,
                  taxPercentage: _taxPercentage,
                  tipPercentage: _tipPercentage,
                );
              },
            ),

            // Unassigned items section (if any)
            if (splitManager.unassignedItems.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16), // Add top margin
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 24, color: colorScheme.error), // Different icon
                    const SizedBox(width: 8),
                    Text(
                      'Unassigned Items',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                 elevation: 1,
                 shadowColor: colorScheme.shadow.withOpacity(0.2),
                 margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(24),
                 ),
                 child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         children: [
                            CircleAvatar(
                              backgroundColor: colorScheme.errorContainer.withOpacity(0.5),
                              child: Icon(Icons.question_mark, color: colorScheme.onErrorContainer),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Unclaimed',
                                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Total cost of unassigned items (subtotal only)
                            Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: colorScheme.errorContainer,
                                 borderRadius: BorderRadius.circular(20),
                               ),
                               child: Text(
                                '\$${splitManager.unassignedItemsTotal.toStringAsFixed(2)}', // Show subtotal here
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                 ),
                               ),
                            ),
                          ],
                       ),
                       const SizedBox(height: 16),
                       _buildItemList(context, 'Items:', splitManager.unassignedItems),
                       const SizedBox(height: 12),
                       Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
                       Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Column(
                             children: [
                                // Show the tax/tip associated with these items for clarity
                                _buildDetailRow(context, 'Tax (${_taxPercentage.toStringAsFixed(1)}%)', splitManager.unassignedItemsTotal * taxRate),
                                const SizedBox(height: 4),
                                _buildDetailRow(context, 'Tip (${_tipPercentage.toStringAsFixed(1)}%)', splitManager.unassignedItemsTotal * tipRate),
                             ],
                          ),
                       ),
                     ],
                  ),
                 ),
              ),
            ],

             // Add some extra space at the bottom
             const SizedBox(height: 20),

          ],
        ),

        // Floating Action Buttons (Positioned)
        Positioned(
          // Position FABs at the bottom right with padding
          right: 16,
          bottom: 16,
          child: Row( // Use Row for side-by-side buttons
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'buyMeACoffeeButton_final', // Ensure unique heroTag
                onPressed: () => _launchBuyMeACoffee(context),
                icon: const Icon(Icons.coffee_outlined), // Coffee icon
                label: const Text('Support Me'), // Shorter label
                tooltip: 'Buy me a coffee (optional)', // Tooltip
                backgroundColor: AppColors.secondary.withOpacity(0.9), // Use AppColor, add slight transparency
                foregroundColor: Colors.white, // Ensure text is readable
                 elevation: 2,
              ),
              const SizedBox(width: 12), // Space between buttons
              FloatingActionButton.extended(
                heroTag: 'shareButton_final', // Ensure unique heroTag
                onPressed: () => _generateAndShareReceipt(context),
                icon: const Icon(Icons.share_outlined), // Share icon
                label: const Text('Share'),
                tooltip: 'Copy summary to clipboard', // Tooltip
                backgroundColor: colorScheme.primary, // Use primary theme color
                foregroundColor: colorScheme.onPrimary, // Ensure text is readable
                elevation: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

   // Helper to build item lists consistently
  Widget _buildItemList(BuildContext context, String title, List<ReceiptItem> items, {SplitManager? splitManager}) {
     final textTheme = Theme.of(context).textTheme;
     final colorScheme = Theme.of(context).colorScheme;
     bool isSharedList = splitManager != null; // Check if we are building the shared list

     return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
             title,
             style: textTheme.titleSmall?.copyWith( // Use titleSmall for section headers
               fontWeight: FontWeight.bold,
               color: isSharedList ? colorScheme.tertiary : colorScheme.secondary, // Different color for shared
             ),
           ),
           const SizedBox(height: 8),
           ...items.map((item) {
              double displayPrice = item.price * item.quantity;
              String suffix = '';

              if (isSharedList) {
                 final sharingCount = splitManager.people
                     .where((p) => p.sharedItems.contains(item))
                     .length;
                 if (sharingCount > 0) {
                   displayPrice = item.price * item.quantity / sharingCount;
                   suffix = ' (${sharingCount}-way)';
                 } else {
                   displayPrice = 0; // Should not happen if item is in person's list
                   suffix = ' (Error)';
                 }
              }

              return Padding(
                 padding: const EdgeInsets.only(bottom: 6.0, left: 8.0), // Indent items
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Expanded(
                       child: Text(
                         '${item.quantity}x ${item.name}$suffix',
                         style: textTheme.bodyMedium,
                         overflow: TextOverflow.ellipsis, // Prevent long names from breaking layout
                       ),
                     ),
                     const SizedBox(width: 16), // Space before price
                     Text(
                       '\$${displayPrice.toStringAsFixed(2)}',
                       style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                     ),
                   ],
                 ),
              );
           }).toList(),
        ],
     );
  }

  // Helper for consistent detail rows (Tax, Tip, Subtotal for person)
  Widget _buildDetailRow(BuildContext context, String label, double value, {bool isBold = false}) {
     final textTheme = Theme.of(context).textTheme;
     final colorScheme = Theme.of(context).colorScheme;
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 2.0), // Small vertical padding
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           Text(
             label,
             style: textTheme.bodyMedium?.copyWith(
               color: colorScheme.onSurfaceVariant, // Use a less prominent color for labels
               fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
             ),
           ),
           Text(
             '\$${value.toStringAsFixed(2)}',
             style: textTheme.bodyMedium?.copyWith(
               fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
               color: isBold ? colorScheme.onSurface : colorScheme.onSurface, // Consistent color for values
             ),
           ),
         ],
       ),
     );
  }

   // Helper for Total rows (Subtotal, Grand Total)
  Widget _buildTotalRow(BuildContext context, String label, double value, {bool isGrandTotal = false}) {
     final textTheme = Theme.of(context).textTheme;
     final colorScheme = Theme.of(context).colorScheme;
     final style = isGrandTotal
         ? textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
         : textTheme.titleMedium; // Use titleMedium for Subtotal

     return Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Text(label, style: style),
         Text(
           '\$${value.toStringAsFixed(2)}',
           style: style?.copyWith(
             color: isGrandTotal ? colorScheme.primary : null, // Highlight Grand Total
           ),
         ),
       ],
     );
  }
}

// Helper Notification class (can be moved to a shared location)
// class NavigateToPageNotification extends Notification {
//   final int pageIndex;
//   NavigateToPageNotification(this.pageIndex);
// } 