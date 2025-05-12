import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/split_manager.dart';
import '../models/receipt_item.dart'; // Ensure ReceiptItem is available if needed for calculations/display
import '../theme/app_colors.dart'; // Ensure AppColors is correctly defined or replace with Theme colors
import '../widgets/split_view.dart' hide NavigateToPageNotification;
import '../widgets/final_summary/person_summary_card.dart'; // Import the new card
import '../utils/platform_config.dart'; // Import platform config
import '../utils/toast_helper.dart'; // Import toast helper
import '../widgets/workflow_modal.dart'; // Import WorkflowState
import '../../providers/workflow_state.dart'; // Added import
import '../../models/receipt.dart';

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
    
    // --- Initialize local state from WorkflowState if available --- 
    final workflowState = context.read<WorkflowState>();
    _tipPercentage = workflowState.tip ?? 20.0;
    _taxPercentage = workflowState.tax ?? DEFAULT_TAX_RATE;
    // --- End Initialization ---
    
    _taxController = TextEditingController(text: _taxPercentage.toStringAsFixed(3));

    _taxController.addListener(() {
      final newTax = double.tryParse(_taxController.text);
      if (newTax != null && newTax >= 0) {
        if (_taxPercentage != newTax) {
           setState(() {
             _taxPercentage = newTax;
             // --- ADDED: Update WorkflowState --- 
             context.read<WorkflowState>().setTax(_taxPercentage);
             // --- END ADDED ---
           });
        }
      } else if (_taxController.text.isEmpty) {
        if (_taxPercentage != 0.0) { // Avoid rebuild if already 0
          setState(() {
            _taxPercentage = 0.0; // Set tax to 0 if input is cleared
            // --- ADDED: Update WorkflowState --- 
            context.read<WorkflowState>().setTax(_taxPercentage);
            // --- END ADDED ---
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

  // Helper method to build the tip adjustment slider with a key for testing
  Widget _buildTipAdjustment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tip'),
            Text(
              '${_tipPercentage.toStringAsFixed(1)}%',
              key: const ValueKey('tip_percentage_text'),
            ),
          ],
        ),
        Slider(
          key: const ValueKey('tip_slider'),
          value: _tipPercentage,
          min: 0,
          max: 30,
          divisions: 60,
          onChanged: (value) {
            setState(() {
              _tipPercentage = value;
              // --- ADDED: Update WorkflowState --- 
              context.read<WorkflowState>().setTip(_tipPercentage);
              // --- END ADDED ---
            });
          },
        ),
      ],
    );
  }

  // Helper method to build the tax adjustment field with a key for testing
  Widget _buildTaxAdjustment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tax'),
            Text(
              '${_taxPercentage.toStringAsFixed(1)}%',
              key: const ValueKey('tax_percentage_text'),
            ),
          ],
        ),
        TextField(
          key: const ValueKey('tax_field'),
          controller: _taxController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Enter tax percentage',
          ),
        ),
      ],
    );
  }

  // Helper method to build a subtotal row with label and amount
  Widget _buildSubtotalRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('\$${amount.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  // Helper method to build the total row with a bold style
  Widget _buildTotalRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _launchBuyMeACoffee(BuildContext context) async {
    // Hardcode the buy me a coffee link instead of using dotenv
    const String buyMeACoffeeLink = 'https://buymeacoffee.com/kuchiman';
    
    final Uri url = Uri.parse(buyMeACoffeeLink);
    try {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            throw 'Could not launch $url';
        }
    } catch (e) {
        if (!mounted) return;
        ToastHelper.showToast(
            context, 
            'Could not launch link: ${e.toString()}',
            isError: true
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
    receipt.writeln('═══════════════════');
    receipt.writeln('');
    receipt.writeln('📊 TOTALS');
    receipt.writeln('Subtotal: \$${subtotal.toStringAsFixed(2)}');
    receipt.writeln('Tax (${_taxPercentage.toStringAsFixed(1)}%): \$${tax.toStringAsFixed(2)}');
    receipt.writeln('Tip (${_tipPercentage.toStringAsFixed(1)}%): \$${tip.toStringAsFixed(2)}');
    receipt.writeln('TOTAL: \$${total.toStringAsFixed(2)}');
    receipt.writeln('');
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

      receipt.writeln('');
      receipt.writeln('👤 ${person.name.toUpperCase()} → YOU OWE: \$${personTotal.toStringAsFixed(2)}');
      receipt.writeln('───────────────');

      if (person.assignedItems.isNotEmpty) {
        receipt.writeln('Individual Items:');
        for (var item in person.assignedItems) {
          receipt.writeln('• ${item.quantity}x ${item.name} (\$${(item.price * item.quantity).toStringAsFixed(2)})');
        }
      }

      if (person.sharedItems.isNotEmpty) {
        receipt.writeln('');
        receipt.writeln('Shared Items:');
        for (var item in person.sharedItems) {
          final sharingCount = splitManager.people.where((p) => p.sharedItems.contains(item)).length;
          final individualShare = sharingCount > 0 ? (item.price * item.quantity / sharingCount) : 0.0;
          receipt.writeln('• ${item.quantity}x ${item.name} (${sharingCount}-way split: \$${individualShare.toStringAsFixed(2)})');
        }
      }

      receipt.writeln('');
      receipt.writeln('Details:');
      receipt.writeln('Subtotal: \$${personSubtotal.toStringAsFixed(2)}');
      receipt.writeln('+ Tax (${_taxPercentage.toStringAsFixed(1)}%): \$${personTax.toStringAsFixed(2)}');
      receipt.writeln('+ Tip (${_tipPercentage.toStringAsFixed(1)}%): \$${personTip.toStringAsFixed(2)}');
      // receipt.writeln('= Total: \$${personTotal.toStringAsFixed(2)}');
    }

    if (splitManager.unassignedItems.isNotEmpty) {
      receipt.writeln('');
      receipt.writeln('⚠️ UNASSIGNED ITEMS');
      receipt.writeln('═══════════════════');
      for (var item in splitManager.unassignedItems) {
        receipt.writeln('• ${item.quantity}x ${item.name} (\$${(item.price * item.quantity).toStringAsFixed(2)})');
      }
      final double unassignedSubtotal = splitManager.unassignedItemsTotal;
      final double unassignedTax = unassignedSubtotal * taxRate;
      final double unassignedTip = unassignedSubtotal * tipRate;
      final double unassignedTotal = unassignedSubtotal + unassignedTax + unassignedTip;
      receipt.writeln('');
      receipt.writeln('Unassigned Total (inc. tax/tip): \$${unassignedTotal.toStringAsFixed(2)}');
    }

    await Clipboard.setData(ClipboardData(text: receipt.toString()));

    if (!mounted) return;
    ToastHelper.showToast(
      context,
      'Receipt copied to clipboard!',
      isSuccess: true
    );
    showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // Modern rounded corners
          icon: Icon(Icons.celebration_rounded, color: colorScheme.primary, size: 36), // Fun icon
          title: const Text('Receipt Copied! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Prevent excessive vertical space
            children: [
              const Text(
                'Your summary is ready to paste! ✨',
                 textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container( // Container for subtle background
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Keeping the magic alive (and the AI fed!) costs a little. If Billfie made your day easier, consider fueling future features!',
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center, // Center the buttons
          actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16), // Add padding
          actions: [
            // Use FilledButton for primary action (support)
            FilledButton.icon(
              icon: const Icon(Icons.coffee_outlined),
              label: const Text('Support the App'),
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog first
                _launchBuyMeACoffee(context); // Launch link
              },
              style: FilledButton.styleFrom(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            // Use TextButton for secondary action (close)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Maybe Later'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    // Access SplitManager provider in read-only mode for the build
    final splitManager = context.watch<SplitManager>(); // Using watch, not read
    final people = splitManager.people;
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate totals based on subtotal, tax, and tip 
    final double subtotal = splitManager.totalAmount;
    final double tax = subtotal * (_taxPercentage / 100);
    final double tip = subtotal * (_tipPercentage / 100);
    final double total = subtotal + tax + tip;
    
    // Build UI
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Summary'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Breakdown', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      _buildSubtotalRow('Subtotal', subtotal),
                      _buildSubtotalRow('+ Tax (${_taxPercentage.toStringAsFixed(1)}%)', tax),
                      _buildSubtotalRow('+ Tip (${_tipPercentage.toStringAsFixed(1)}%)', tip),
                      const Divider(),
                      _buildTotalRow('= Total', total),
                      const SizedBox(height: 16),
                      // Use the helper methods for tax and tip controls
                      _buildTipAdjustment(),
                      const SizedBox(height: 8),
                      _buildTaxAdjustment(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ... rest of the slivers
        ],
      ),
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
}

// Helper Notification class (can be moved to a shared location)
// class NavigateToPageNotification extends Notification {
//   final int pageIndex;
//   NavigateToPageNotification(this.pageIndex);
// } 