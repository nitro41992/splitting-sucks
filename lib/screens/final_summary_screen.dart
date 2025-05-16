import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../models/split_manager.dart';
import '../models/receipt_item.dart'; // Ensure ReceiptItem is available if needed for calculations/display
import '../theme/app_colors.dart'; // Ensure AppColors is correctly defined or replace with Theme colors
import '../widgets/split_view.dart'; // Import to get NavigateToPageNotification
import '../widgets/final_summary/person_summary_card.dart'; // Import the new card
import '../utils/platform_config.dart'; // Import platform config
import '../utils/toast_helper.dart'; // Import toast helper
import '../widgets/workflow_modal.dart'; // Import WorkflowState
import '../providers/workflow_state.dart'; // Added import
import '../models/receipt.dart';
import '../services/firestore_service.dart';

class FinalSummaryScreen extends StatefulWidget {
  const FinalSummaryScreen({
    super.key,
  });

  @override
  State<FinalSummaryScreen> createState() => _FinalSummaryScreenState();
}

class _FinalSummaryScreenState extends State<FinalSummaryScreen> with WidgetsBindingObserver {
  static const double DEFAULT_TAX_RATE = 8.875; // Default NYC tax rate

  double _tipPercentage = 20.0;
  double _taxPercentage = DEFAULT_TAX_RATE;
  late TextEditingController _taxController;
  
  @override
  void initState() {
    super.initState();
    
    // Register for app lifecycle changes to cache values when app is backgrounded
    WidgetsBinding.instance.addObserver(this);
    
    // --- Initialize tax/tip from WorkflowState if available --- 
    final workflowState = context.read<WorkflowState>();
    _tipPercentage = workflowState.tip ?? 20.0;
    _taxPercentage = workflowState.tax ?? DEFAULT_TAX_RATE;
    
    _taxController = TextEditingController(text: _taxPercentage.toStringAsFixed(3));
    // Update tax and calculations immediately on change
    _taxController.addListener(() {
      final newTax = double.tryParse(_taxController.text);
      if (newTax != null && newTax >= 0) {
        if (_taxPercentage != newTax) {
          setState(() {
            _taxPercentage = newTax;
            context.read<WorkflowState>().setTax(_taxPercentage);
          });
        }
      } else if (_taxController.text.isEmpty) {
        if (_taxPercentage != 0.0) {
          setState(() {
            _taxPercentage = 0.0;
            context.read<WorkflowState>().setTax(_taxPercentage);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    // Unregister from app lifecycle changes
    WidgetsBinding.instance.removeObserver(this);
    _taxController.dispose();
    super.dispose();
  }

  // Handle app lifecycle changes to ensure values are cached when app is backgrounded
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Cache the current tax and tip percentages to WorkflowState
      final workflowState = Provider.of<WorkflowState>(context, listen: false);
      workflowState.setTax(_taxPercentage);
      workflowState.setTip(_tipPercentage);
      debugPrint("[FinalSummaryScreen] App backgrounded, caching tax: $_taxPercentage, tip: $_tipPercentage");
    }
  }

  // Cache current state when navigating away from this screen
  @override
  void deactivate() {
    // This is called when navigating away from the screen
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    workflowState.setTax(_taxPercentage);
    workflowState.setTip(_tipPercentage);
    
    // Complete the receipt in the database when leaving this screen
    // This fixes the issue where receipts weren't being marked as completed
    _completeReceiptInDatabase();
    
    debugPrint("[FinalSummaryScreen] Screen deactivated, caching tax: $_taxPercentage, tip: $_tipPercentage");
    super.deactivate();
  }

  // Complete the receipt in the database to ensure it's marked as completed
  Future<void> _completeReceiptInDatabase() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    // Skip if there's no receipt ID (should never happen)
    if (workflowState.receiptId == null) {
      debugPrint("[FinalSummaryScreen] Cannot complete receipt: No receipt ID found");
      return;
    }
    
    try {
      // Create receipt object and update people from assignments data
      Receipt receipt = workflowState.toReceipt();
      final List<String> actualPeople = receipt.peopleFromAssignments;
      
      if (actualPeople.isNotEmpty) {
        receipt = receipt.copyWith(people: actualPeople);
      }
      
      // Update all split data from the SplitManager
      final splitManager = Provider.of<SplitManager>(context, listen: false);
      
      // Generate map of assignments to add to receipt
      final assignmentMap = splitManager.generateAssignmentMap();
      if (workflowState.assignPeopleToItemsResult == null || 
          workflowState.assignPeopleToItemsResult!.isEmpty) {
        // Update the WorkflowState with the current split data if needed
        workflowState.setAssignPeopleToItemsResult(assignmentMap);
      }
      
      // Update tax and tip in WorkflowState
      workflowState.setTip(_tipPercentage);
      workflowState.setTax(_taxPercentage);
      
      // Create receipt data map for database
      final Map<String, dynamic> receiptData = receipt.toMap();
      receiptData['metadata']['status'] = 'completed'; // Explicitly set status to completed
      
      // Update firestore with 'completed' status
      final firestoreService = FirestoreService();
      await firestoreService.completeReceipt(
        receiptId: receipt.id,
        data: receiptData,
      );
      
      debugPrint("[FinalSummaryScreen] Successfully completed receipt ${receipt.id} in database");
    } catch (e) {
      debugPrint("[FinalSummaryScreen] Error completing receipt: $e");
      // Don't show error toast since this happens during deactivation
    }
  }

  Future<void> _launchBuyMeACoffee(BuildContext context) async {
    // Try to get URL from environment first, fall back to hardcoded value
    String buyMeACoffeeLink;
    try {
      buyMeACoffeeLink = dotenv.env['BUY_ME_A_COFFEE_LINK'] ?? 'https://buymeacoffee.com/kuchiman';
    } catch (e) {
      // If dotenv isn't available or configured, use hardcoded URL
      buyMeACoffeeLink = 'https://buymeacoffee.com/kuchiman';
    }
    
    final Uri url = Uri.parse(buyMeACoffeeLink);
    try {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            throw 'Could not launch $url';
        }
    } catch (e) {
        if (!mounted) return;
        // Use either ScaffoldMessenger or ToastHelper based on availability
        try {
          ToastHelper.showToast(
              context, 
              'Could not launch link: ${e.toString()}',
              isError: true
          );
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not launch link: ${e.toString()}')),
          );
        }
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
      // Use the splitManager's getPersonTotal method for consistency
      final double personSubtotal = splitManager.getPersonTotal(person);
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
    // Try ToastHelper first, fallback to ScaffoldMessenger
    try {
      ToastHelper.showToast(
        context,
        'Receipt copied to clipboard!',
        isSuccess: true
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Receipt copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
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
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // Use context.watch here to rebuild when SplitManager changes (e.g., assignments update)
    final splitManager = context.watch<SplitManager>();

    // Check if there's anything to summarize. Rely on SplitManager state.
    if (splitManager.people.isEmpty && splitManager.unassignedItems.isEmpty && splitManager.sharedItems.isEmpty) {
       return Container(
        color: const Color(0xFFF5F5F7), // Light grey background
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNeumorphicContainer(
                child: Container(
                  width: 120,
                  height: 120,
                  padding: const EdgeInsets.all(24),
                  child: Icon(
                    Icons.summarize_outlined,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No Split Summary Available',
                style: textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
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
              _buildNeumorphicButton(
                heroTag: 'goToSplitView_empty',
                onPressed: () {
                  // Notify the parent PageView controller to navigate
                  NavigateToPageNotification(3).dispatch(context); // Go to Split View (index 3)
                },
                icon: Icons.arrow_back,
                label: 'Go to Split View',
                isPrimary: true,
                isSecondary: false,
              ),
            ],
          ),
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
    double sumOfIndividualSubtotals = 0.0;
    for (var person in people) {
      // Get person's total from the splitManager method for consistency
      double personSubtotal = splitManager.getPersonTotal(person);
      sumOfIndividualSubtotals += personSubtotal;
    }
    
    // Add subtotal of unassigned items
    if (splitManager.unassignedItems.isNotEmpty) {
      sumOfIndividualSubtotals += splitManager.unassignedItemsTotal;
    }
    
    // Allow for small floating point inaccuracies (increase threshold slightly)
    final bool subtotalsMatch = (subtotal - sumOfIndividualSubtotals).abs() < 0.05;

    return Container(
      color: const Color(0xFFF5F5F7), // Light grey background (near off-white)
      child: Stack(
        children: [
          ListView(
            // Add padding at the bottom to ensure content isn't hidden by FABs
            // Also add horizontal padding to prevent cards from touching the sides
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Show warning if subtotals don't match due to rounding/distribution
              if (!subtotalsMatch)
                _buildNeumorphicContainer(
                  backgroundColor: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded, 
                          color: colorScheme.error,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Warning: Sum of parts (\$${sumOfIndividualSubtotals.toStringAsFixed(2)}) '
                            'doesn\'t perfectly match subtotal (\$${subtotal.toStringAsFixed(2)}). '
                            'This is due to rounding when calculating shared items.',
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
            _buildNeumorphicContainer(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Receipt Totals',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
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
                          child: _buildNeumorphicContainer(
                            borderRadius: 8,
                            child: TextField(
                              key: const ValueKey('tax_field'),
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
                                border: InputBorder.none, // Remove default border
                              ),
                              textAlign: TextAlign.right,
                              style: textTheme.bodyLarge,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16), // Space between input and amount
                        SizedBox(
                          width: 80, // Width for the amount
                          child: Text(
                            '\$${tax.toStringAsFixed(2)}',
                            key: const ValueKey('tax_percentage_text'),
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
                        _buildNeumorphicContainer(
                          borderRadius: 24,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Text(
                              '${_tipPercentage.toStringAsFixed(1)}%',
                              key: const ValueKey('tip_percentage_text'),
                              style: textTheme.headlineSmall?.copyWith( // Make percentage stand out
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12), // Reduced space

                    // Tip Controls (Buttons and Slider)
                    Column(
                      children: [
                        // Quick select buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [15.0, 18.0, 20.0, 25.0].map((percentage) {
                            bool isSelected = (_tipPercentage - percentage).abs() < 0.01;
                            return _buildNeumorphicPercentButton(
                              percentage: percentage,
                              isSelected: isSelected,
                              onPressed: () {
                                _setTipPercentage(percentage);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Fine-tune slider
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: AppColors.surfaceDark,
                            thumbColor: AppColors.primary,
                            overlayColor: AppColors.primary.withOpacity(0.1),
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                              elevation: 4,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            key: const ValueKey('tip_slider'),
                            value: _tipPercentage,
                            min: 0,
                            max: 30, // Max tip percentage
                            divisions: 60, // Allows 0.5% increments
                            label: '${_tipPercentage.toStringAsFixed(1)}%',
                            onChanged: _onTipSliderChanged,
                          ),
                        ),
                      ],
                    ),
                     const SizedBox(height: 12), // Reduced space

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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16), // Add padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(  // Wrap in Flexible to allow the text to shrink if needed
                    child: Row(
                      children: [
                        Icon(Icons.people_outline, size: 24, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Flexible(  // Add Flexible here to allow text to shrink
                          child: Text(
                            'Split Summary (${people.length} ${people.length == 1 ? "Person" : "People"})',
                            style: textTheme.titleLarge?.copyWith( // Slightly larger title
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis, // Add overflow handling
                            maxLines: 1, // Limit to 1 line
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Edit Split Button with neumorphic styling
                  GestureDetector(
                    onTap: () {
                      // Navigate to Split View
                      NavigateToPageNotification(3).dispatch(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,  // Add this to make the button only as wide as needed
                        children: [
                          const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Edit Split',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
                  child: _buildNeumorphicContainer(
                    child: PersonSummaryCard(
                      key: ValueKey(person.name), // Use person's name as key (assuming unique)
                      person: person,
                      splitManager: splitManager,
                      taxPercentage: _taxPercentage,
                      tipPercentage: _tipPercentage,
                    ),
                  ),
                );
              },
            ),

            // Unassigned items section (if any)
            if (splitManager.unassignedItems.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16), // Add top margin
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 24, color: AppColors.error), // Different icon
                    const SizedBox(width: 8),
                    Text(
                      'Unassigned Items',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              // Wrap the Card with InkWell for tappable navigation
              InkWell(
                onTap: () {
                  // Set the initial tab index before navigating
                  context.read<SplitManager>().initialSplitViewTabIndex = 2; // 2 = Unassigned tab
                  // Notify the parent PageView controller to navigate
                  NavigateToPageNotification(3).dispatch(context); // Go to Split View (index 3)
                },
                borderRadius: BorderRadius.circular(24), // Match the Card's border radius for ripple effect
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
                  child: _buildNeumorphicContainer(
                    borderRadius: 24,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(2, 2),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  backgroundColor: Colors.transparent,
                                  child: Icon(Icons.question_mark, color: colorScheme.onErrorContainer),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Title and Subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Unclaimed',
                                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Tap to assign these items',
                                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              // Total cost
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 2,
                                      offset: const Offset(1, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '\$${splitManager.unassignedItemsTotal.toStringAsFixed(2)}', // Show subtotal here
                                  style: textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Add a trailing icon to indicate clickability
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
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
                ),
              ), // End of InkWell wrapper
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
              _buildNeumorphicButton(
                heroTag: 'buyMeACoffeeButton_final',
                onPressed: () => _launchBuyMeACoffee(context),
                icon: Icons.coffee_outlined,
                label: 'Support Me',
                isPrimary: false,
                isSecondary: true, // Use puce color
              ),
              const SizedBox(width: 12), // Space between buttons
              _buildNeumorphicButton(
                heroTag: 'shareButton_final',
                onPressed: () => _generateAndShareReceipt(context),
                icon: Icons.share_outlined,
                label: 'Share Bill',
                isPrimary: true,
                isSecondary: false,
              ),
            ],
          ),
        ),
      ]),
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
                         maxLines: 1, // Ensure it stays on one line
                       ),
                     ),
                     const SizedBox(width: 16), // Space before price
                     SizedBox(
                       width: 80, // Fixed width to ensure price has enough space
                       child: Text(
                         '\$${displayPrice.toStringAsFixed(2)}',
                         style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                         textAlign: TextAlign.right, // Right-align the price text
                       ),
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
           Flexible(  // Make label flexible to avoid overflow
             child: Text(
               label,
               style: textTheme.bodyMedium?.copyWith(
                 color: colorScheme.onSurfaceVariant, // Use a less prominent color for labels
                 fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
               ),
               overflow: TextOverflow.ellipsis,  // Add ellipsis for very long labels
             ),
           ),
           const SizedBox(width: 8), // Space between label and value
           SizedBox(
             width: 80, // Fixed width for consistent alignment
             child: Text(
               '\$${value.toStringAsFixed(2)}',
               style: textTheme.bodyMedium?.copyWith(
                 fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                 color: isBold ? colorScheme.onSurface : colorScheme.onSurface, // Consistent color for values
               ),
               textAlign: TextAlign.right, // Right-align the value
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
        Flexible(  // Make label flexible
          child: Text(
            label, 
            style: style,
            overflow: TextOverflow.ellipsis,  // Add ellipsis for very long labels
          ),
        ),
        const SizedBox(width: 8),  // Add space between label and value
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: style?.copyWith(
            color: isGrandTotal ? AppColors.primary : null, // Use AppColors.primary for Grand Total
          ),
        ),
      ],
    );
  }

  // Update these UI methods to cache to WorkflowState without persisting to DB
  
  // Quick select tip buttons onPressed
  void _setTipPercentage(double percentage) {
    setState(() { 
      _tipPercentage = percentage;
      // Update WorkflowState cache only (no DB persistence)
      context.read<WorkflowState>().setTip(_tipPercentage);
    });
  }

  // Tip slider onChanged
  void _onTipSliderChanged(double value) {
    // Round to one decimal place
    setState(() { 
      _tipPercentage = (value * 10).round() / 10.0;
      // Update WorkflowState cache only (no DB persistence)
      context.read<WorkflowState>().setTip(_tipPercentage);
    });
  }

  // Helper for neumorphic buttons
  Widget _buildNeumorphicButton({
    required String heroTag,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
    required bool isSecondary,
  }) {
    // Use AppColors for consistent styling
    final Color backgroundColor = isPrimary 
        ? AppColors.primary 
        : isSecondary 
            ? AppColors.secondary 
            : Colors.white;
    final Color textColor = (isPrimary || isSecondary) ? Colors.white : AppColors.primary;
    
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Stronger shadow for raised effect - bottom right
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(4, 4),
            spreadRadius: 0,
          ),
          // Lighter highlight for neumorphic effect - top left
          BoxShadow(
            color: Colors.white.withOpacity((isPrimary || isSecondary) ? 0.1 : 0.9),
            blurRadius: 10,
            offset: const Offset(-4, -4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: textColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for neumorphic percentage buttons
  Widget _buildNeumorphicPercentButton({
    required double percentage,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final Color backgroundColor = isSelected ? AppColors.primary : Colors.white;
    final Color textColor = isSelected ? Colors.white : AppColors.primary;
    
    return Container(
      width: 64,
      height: 36,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          // Stronger shadow for raised effect - bottom right
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(2, 2),
            spreadRadius: 0,
          ),
          // Lighter highlight for neumorphic effect - top left
          BoxShadow(
            color: Colors.white.withOpacity(isSelected ? 0.1 : 0.9),
            blurRadius: 6,
            offset: const Offset(-2, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Text(
              '${percentage.toInt()}%',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper to build neumorphic container with consistent styling
  Widget _buildNeumorphicContainer({
    required Widget child,
    Color? backgroundColor,
    double borderRadius = 16,
    bool isElevated = true,
  }) {
    final Color bgColor = backgroundColor ?? Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isElevated ? [
          // Outer shadow - bottom right
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(4, 4),
            spreadRadius: 0,
          ),
          // Outer highlight - top left
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 10,
            offset: const Offset(-4, -4),
            spreadRadius: 0,
          ),
        ] : [],
      ),
      child: child,
    );
  }
}

// Helper Notification classes 
class NavigateToPageNotification extends Notification {
  final int pageIndex;
  NavigateToPageNotification(this.pageIndex);
} 