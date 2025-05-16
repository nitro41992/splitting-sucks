import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../models/split_manager.dart';
// import '../models/receipt_item.dart'; // Not directly used in this snippet but keep if PersonSummaryCard needs it
import '../models/person.dart'; 
import '../theme/app_colors.dart'; 
import '../widgets/split_view.dart'; 
import '../widgets/final_summary/person_summary_card.dart'; 
import '../utils/platform_config.dart'; 
import '../utils/toast_helper.dart'; 
// import '../widgets/workflow_modal.dart'; // Not directly used in this snippet
import '../providers/workflow_state.dart'; 
import '../models/receipt.dart';
import '../services/firestore_service.dart';
import '../widgets/workflow_steps/split_step_widget.dart';

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
    
    WidgetsBinding.instance.addObserver(this);
    
    final workflowState = context.read<WorkflowState>();
    _tipPercentage = workflowState.tip ?? 20.0;
    _taxPercentage = workflowState.tax ?? DEFAULT_TAX_RATE;
    
    _taxController = TextEditingController(text: _taxPercentage.toStringAsFixed(3));
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
    WidgetsBinding.instance.removeObserver(this);
    _taxController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      final workflowState = Provider.of<WorkflowState>(context, listen: false);
      workflowState.setTax(_taxPercentage);
      workflowState.setTip(_tipPercentage);
      debugPrint("[FinalSummaryScreen] App backgrounded, caching tax: $_taxPercentage, tip: $_tipPercentage");
    }
  }

  @override
  void deactivate() {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    workflowState.setTax(_taxPercentage);
    workflowState.setTip(_tipPercentage);
    
    _completeReceiptInDatabase();
    
    debugPrint("[FinalSummaryScreen] Screen deactivated, caching tax: $_taxPercentage, tip: $_tipPercentage");
    super.deactivate();
  }

  Future<void> _completeReceiptInDatabase() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    if (workflowState.receiptId == null) {
      debugPrint("[FinalSummaryScreen] Cannot complete receipt: No receipt ID found");
      return;
    }
    
    try {
      Receipt receipt = workflowState.toReceipt();
      final List<String> actualPeople = receipt.peopleFromAssignments;
      
      if (actualPeople.isNotEmpty) {
        receipt = receipt.copyWith(people: actualPeople);
      }
      
      final splitManager = Provider.of<SplitManager>(context, listen: false);
      
      final assignmentMap = splitManager.generateAssignmentMap();
      if (workflowState.assignPeopleToItemsResult == null || 
          workflowState.assignPeopleToItemsResult!.isEmpty) {
        workflowState.setAssignPeopleToItemsResult(assignmentMap);
      }
      
      workflowState.setTip(_tipPercentage);
      workflowState.setTax(_taxPercentage);
      
      final Map<String, dynamic> receiptData = receipt.toMap();
      receiptData['metadata']['status'] = 'completed'; 
      
      final firestoreService = FirestoreService();
      await firestoreService.completeReceipt(
        receiptId: receipt.id,
        data: receiptData,
      );
      
      debugPrint("[FinalSummaryScreen] Successfully completed receipt ${receipt.id} in database");
    } catch (e) {
      debugPrint("[FinalSummaryScreen] Error completing receipt: $e");
    }
  }

  Future<void> _launchBuyMeACoffee(BuildContext context) async {
    String buyMeACoffeeLink;
    try {
      buyMeACoffeeLink = dotenv.env['BUY_ME_A_COFFEE_LINK'] ?? 'https://buymeacoffee.com/kuchiman';
    } catch (e) {
      buyMeACoffeeLink = 'https://buymeacoffee.com/kuchiman';
    }
    
    final Uri url = Uri.parse(buyMeACoffeeLink);
    try {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            throw 'Could not launch $url';
        }
    } catch (e) {
        if (!mounted) return;
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
    final splitManager = context.read<SplitManager>();
    final people = splitManager.people;
    // final colorScheme = Theme.of(context).colorScheme; // Not directly used here

    final double subtotal = splitManager.totalAmount;
    final double taxRate = _taxPercentage / 100.0;
    final double tipRate = _tipPercentage / 100.0;
    final double tax = subtotal * taxRate;
    final double tip = subtotal * tipRate;
    final double total = subtotal + tax + tip;

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: Icon(Icons.celebration_rounded, color: colorScheme.primary, size: 36),
          title: const Text('Receipt Copied! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your summary is ready to paste! ✨',
                 textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
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
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.coffee_outlined),
              label: const Text('Support the App'),
              onPressed: () {
                Navigator.pop(dialogContext);
                _launchBuyMeACoffee(context);
              },
              style: FilledButton.styleFrom(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
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
    final splitManager = context.watch<SplitManager>();

    if (splitManager.people.isEmpty && splitManager.unassignedItems.isEmpty && splitManager.sharedItems.isEmpty) {
       return Container(
        color: const Color(0xFFF5F5F7), 
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
                'Assign items to people or mark them as shared first.', 
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 40),
              _buildNeumorphicButton(
                heroTag: 'goToSplitView_empty',
                onPressed: () {
                  NavigateToPageNotification(3).dispatch(context); 
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
    final double taxRate = _taxPercentage / 100.0;
    final double tipRate = _tipPercentage / 100.0;
    final double tax = subtotal * taxRate;
    final double tip = subtotal * tipRate;
    final double total = subtotal + tax + tip;

    double sumOfIndividualSubtotals = 0.0;
    for (var person in people) {
      double personSubtotal = splitManager.getPersonTotal(person);
      sumOfIndividualSubtotals += personSubtotal;
    }
    
    if (splitManager.unassignedItems.isNotEmpty) {
      sumOfIndividualSubtotals += splitManager.unassignedItemsTotal;
    }
    
    final bool subtotalsMatch = (subtotal - sumOfIndividualSubtotals).abs() < 0.05;

    return Container(
      color: const Color(0xFFF5F5F7), 
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Bill Overview',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

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

              _buildNeumorphicContainer(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTotalRow(context, 'Subtotal:', subtotal),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('Tax:', style: textTheme.titleMedium),
                          const Spacer(),
                          SizedBox(
                            width: 90,
                            height: 40,
                            child: _buildNeumorphicContainer(
                              borderRadius: 8,
                              isElevated: false, 
                              child: TextField(
                                key: const ValueKey('tax_field'),
                                controller: _taxController,
                                textAlignVertical: TextAlignVertical.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                   FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                                ],
                                decoration: InputDecoration(
                                  suffixText: '%',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: InputBorder.none,
                                ),
                                textAlign: TextAlign.right,
                                style: textTheme.bodyLarge,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 80,
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

                      Text('Tip:', style: textTheme.titleMedium),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildNeumorphicPercentButton(
                            percentage: 15.0,
                            isSelected: _tipPercentage == 15.0,
                            onPressed: () => _setTipPercentage(15.0),
                          ),
                          _buildNeumorphicPercentButton(
                            percentage: 18.0,
                            isSelected: _tipPercentage == 18.0,
                            onPressed: () => _setTipPercentage(18.0),
                          ),
                          _buildNeumorphicPercentButton(
                            percentage: 20.0,
                            isSelected: _tipPercentage == 20.0,
                            onPressed: () => _setTipPercentage(20.0),
                          ),
                          _buildNeumorphicPercentButton(
                            percentage: 25.0,
                            isSelected: _tipPercentage == 25.0,
                            onPressed: () => _setTipPercentage(25.0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                                thumbColor: AppColors.primary,
                                overlayColor: AppColors.primary.withOpacity(0.2),
                                trackHeight: 4.0,
                              ),
                              child: Slider(
                                value: _tipPercentage,
                                min: 0.0,
                                max: 30.0,
                                divisions: 60, 
                                onChanged: _onTipSliderChanged,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '\$${tip.toStringAsFixed(2)}',
                              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildTotalRow(context, 'Total:', total, isGrandTotal: true),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24), 

              Padding(
                padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people_alt_outlined, color: AppColors.primary, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Split Breakdown',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(16),
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
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            debugPrint("[FinalSummaryScreen] Attempting to navigate to SplitView (index 3)");
                            
                            final workflowState = Provider.of<WorkflowState>(context, listen: false);
                            final splitManager = Provider.of<SplitManager>(context, listen: false);
                            
                            splitManager.initialSplitViewTabIndex = 0; 
                            
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (context) => ChangeNotifierProvider<WorkflowState>.value(
                                  value: workflowState,
                                  child: SplitStepWidget(
                                    parseResult: workflowState.parseReceiptResult,
                                    assignResultMap: workflowState.assignPeopleToItemsResult ?? {},
                                    currentTip: workflowState.tip,
                                    currentTax: workflowState.tax,
                                    initialSplitViewTabIndex: splitManager.initialSplitViewTabIndex ?? 0,
                                    onTipChanged: (newTip) {
                                      workflowState.setTip(newTip);
                                    },
                                    onTaxChanged: (newTax) {
                                      workflowState.setTax(newTax);
                                    },
                                    onAssignmentsUpdatedBySplit: (newAssignments) {
                                      workflowState.setAssignPeopleToItemsResult(newAssignments);
                                    },
                                    onNavigateToPage: (pageIndex) {
                                      debugPrint("[FinalSummaryScreen] SplitView requested navigation to page: $pageIndex");
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
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
                      ),
                    ),
                  ],
                ),
              ),

              if (splitManager.unassignedItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 0), 
                  child: InkWell(
                    onTap: () {
                      context.read<SplitManager>().initialSplitViewTabIndex = 2; 
                      NavigateToPageNotification(3).dispatch(context); 
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: _buildNeumorphicContainer(
                      borderRadius: 16,
                      backgroundColor: colorScheme.errorContainer.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.secondary.withOpacity(0.2),
                                  child: Icon(
                                    Icons.help_outline,
                                    size: 20,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${splitManager.unassignedItems.length} Unassigned ${splitManager.unassignedItems.length == 1 ? 'Item' : 'Items'}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  'Tap to assign',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              _buildPeopleSection(context, splitManager, people, taxRate, tipRate),

              const SizedBox(height: 80),
            ],
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7), 
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildNeumorphicButton(
                      heroTag: 'buyMeACoffeeButton_final',
                      onPressed: () => _launchBuyMeACoffee(context),
                      icon: Icons.coffee_outlined,
                      label: 'Support Me',
                      isPrimary: false,
                      isSecondary: true, 
                    ),
                  ),
                  const SizedBox(width: 16), 
                  Expanded(
                    child: _buildNeumorphicButton(
                      heroTag: 'shareButton_final',
                      onPressed: () => _generateAndShareReceipt(context),
                      icon: Icons.share_outlined,
                      label: 'Share Bill',
                      isPrimary: true,
                      isSecondary: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build the people cards section - CODE FIX APPLIED HERE
  Widget _buildPeopleSection(BuildContext context, SplitManager splitManager, List<Person> people, double taxRate, double tipRate) {
    // final textTheme = Theme.of(context).textTheme; // Not used directly here
    // final colorScheme = Theme.of(context).colorScheme; // Not used directly here

    // If there are no people, return an empty container to avoid rendering an empty Column.
    if (splitManager.people.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: splitManager.people.length,
          itemBuilder: (context, index) {
            final person = splitManager.people[index];
            return Padding(
              padding: EdgeInsets.only(
                // If it's the first card (index == 0):
                // - If unassigned items banner is present, no top padding (0.0).
                // - If no unassigned items banner, add 8.0 top padding to separate from the "Split Breakdown" header.
                // For subsequent cards (index > 0), always add 8.0 top padding for separation from the card above.
                top: (index == 0) 
                    ? (splitManager.unassignedItems.isNotEmpty ? 0.0 : 8.0) 
                    : 8.0,
                bottom: 8.0 // Add 8.0 padding below each person card.
              ),
              child: PersonSummaryCard(
                key: ValueKey(person.name), // Ensure unique key for each person
                person: person,
                splitManager: splitManager,
                taxPercentage: _taxPercentage,
                tipPercentage: _tipPercentage,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTotalRow(BuildContext context, String label, double value, {bool isGrandTotal = false}) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final style = isGrandTotal
        ? textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        : textTheme.titleMedium; 

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(  
          child: Text(
            label, 
            style: style?.copyWith(
              color: isGrandTotal ? AppColors.primary : colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,  
          ),
        ),
        const SizedBox(width: 8),  
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: style?.copyWith(
            color: isGrandTotal ? AppColors.primary : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _setTipPercentage(double percentage) {
    setState(() { 
      _tipPercentage = percentage;
      context.read<WorkflowState>().setTip(_tipPercentage);
    });
  }

  void _onTipSliderChanged(double value) {
    setState(() { 
      _tipPercentage = (value * 10).round() / 10.0;
      context.read<WorkflowState>().setTip(_tipPercentage);
    });
  }

  Widget _buildNeumorphicButton({
    required String heroTag,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
    required bool isSecondary,
  }) {
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
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(4, 4),
            spreadRadius: 0,
          ),
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
              mainAxisAlignment: MainAxisAlignment.center, // Center content in button
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
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(2, 2),
            spreadRadius: 0,
          ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(4, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 10,
            offset: const Offset(-4, -4),
            spreadRadius: 0,
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(2, 2),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 4,
            offset: const Offset(-2, -2),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}

class NavigateToPageNotification extends Notification {
  final int pageIndex;
  NavigateToPageNotification(this.pageIndex);
}