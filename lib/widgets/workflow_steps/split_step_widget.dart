import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../../widgets/split_view.dart'; // Canonical source for NavigateToPageNotification
import '../../theme/app_colors.dart';
import 'package:flutter/services.dart';

class SplitStepWidget extends StatelessWidget {
  // Data from WorkflowState needed to initialize SplitManager
  final Map<String, dynamic> parseResult; // Contains original items, subtotal, (optional initial tip/tax)
  final Map<String, dynamic> assignResultMap; // Contains assignments, shared_items, unassigned_items from voice
  final double? currentTip; // Tip from WorkflowState (might have been set by user)
  final double? currentTax; // Tax from WorkflowState (might have been set by user)
  final int initialSplitViewTabIndex; // To restore tab index if needed

  // Callbacks to interact with WorkflowState in _WorkflowModalBodyState
  final Function(double? newTip) onTipChanged;
  final Function(double? newTax) onTaxChanged;
  final Function(Map<String, dynamic> newAssignments) onAssignmentsUpdatedBySplit;
  final Function(int pageIndex) onNavigateToPage; // For "Go to Summary" or other internal navigation
  final VoidCallback? onClose;

  const SplitStepWidget({
    Key? key,
    required this.parseResult,
    required this.assignResultMap,
    this.currentTip,
    this.currentTax,
    this.initialSplitViewTabIndex = 0,
    required this.onTipChanged,
    required this.onTaxChanged,
    required this.onAssignmentsUpdatedBySplit,
    required this.onNavigateToPage,
    this.onClose,
  }) : super(key: key);

  List<Person> _extractPeopleFromAssignResult(Map<String, dynamic> assignResult) {
    final List<Map<String, dynamic>> assignments = (assignResult['assignments'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    return assignments.map((assignment) {
      final personName = assignment['person_name'] as String;
      final itemsForPerson = (assignment['items'] as List<dynamic>).map((itemMap) {
        final itemDetail = itemMap as Map<String, dynamic>;
        return ReceiptItem(
          name: itemDetail['name'] as String,
          quantity: (itemDetail['quantity'] as num).toInt(),
          price: (itemDetail['price'] as num).toDouble(),
        );
      }).toList();
      return Person(name: personName, assignedItems: itemsForPerson);
    }).toList();
  }

  List<ReceiptItem> _extractSharedItemsFromAssignResult(Map<String, dynamic> assignResult) {
     final List<Map<String, dynamic>> sharedItemsFromAssign = (assignResult['shared_items'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    return sharedItemsFromAssign.map((itemMap) {
      return ReceiptItem(
        name: itemMap['name'] as String,
        quantity: (itemMap['quantity'] as num).toInt(),
        price: (itemMap['price'] as num).toDouble(),
      );
    }).toList();
  }

  List<ReceiptItem> _extractUnassignedItemsFromAssignResult(Map<String, dynamic> assignResult) {
    final List<Map<String, dynamic>> unassignedItemsFromAssign = (assignResult['unassigned_items'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    return unassignedItemsFromAssign.map((itemMap) {
      return ReceiptItem(
        name: itemMap['name'] as String,
        quantity: (itemMap['quantity'] as num).toInt(),
        price: (itemMap['price'] as num).toDouble(),
      );
    }).toList();
  }
 
  List<ReceiptItem> _extractInitialItemsFromParseResult(Map<String, dynamic> pResult) {
      return (pResult['items'] as List<dynamic>?)
              ?.map((itemMap) => ReceiptItem.fromJson(itemMap as Map<String, dynamic>))
              .toList() ??
          [];
  }

  static const int personMaxNameLength = 24; // Match SplitView or PersonCard if needed

  void _showAddPersonDialog(BuildContext context, SplitManager splitManager) {
    final controller = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_add, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Add Person'),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter person\'s name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                    ),
                    maxLength: personMaxNameLength,
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    onChanged: (value) {
                      setStateDialog(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${controller.text.length}/$personMaxNameLength',
                      style: textTheme.bodySmall?.copyWith(
                        color: controller.text.length > personMaxNameLength
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName.length <= personMaxNameLength) {
                Provider.of<SplitManager>(context, listen: false).addPerson(newName);
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Add'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, SplitManager splitManager) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    int quantity = 1;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_shopping_cart, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Add Item'),
          ],
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Quantity:', style: textTheme.titleMedium),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: quantity > 1 
                              ? () => setStateDialog(() => quantity--) 
                              : null,
                            color: quantity > 1 ? colorScheme.primary : colorScheme.onSurfaceVariant.withOpacity(0.38),
                          ),
                          Text(
                            quantity.toString(),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => setStateDialog(() => quantity++),
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              double? price = double.tryParse(priceController.text);
              if (price == null || price <= 0) return;
              final newItem = ReceiptItem(
                name: name,
                price: price,
                quantity: quantity,
              );
              Provider.of<SplitManager>(context, listen: false).addUnassignedItem(newItem);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check),
            label: const Text('Add'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Person> people = _extractPeopleFromAssignResult(assignResultMap);
    final List<ReceiptItem> sharedItems = _extractSharedItemsFromAssignResult(assignResultMap);
    final List<ReceiptItem> unassignedItems = _extractUnassignedItemsFromAssignResult(assignResultMap);
    final List<ReceiptItem> initialItemsFromParse = _extractInitialItemsFromParseResult(parseResult);

    // --- BEGIN DEBUG LOGS ---
    debugPrint('[SplitStepWidget] Initializing SplitManager.');
    debugPrint('[SplitStepWidget] parseResult subtotal for originalReviewTotal: ${parseResult['subtotal']}');
    double calculatedSumForDebug = 0;
    debugPrint('[SplitStepWidget] People (${people.length}):');
    for (var p in people) {
      debugPrint('  ${p.name}, Items:');
      for (var item in p.assignedItems) {
        debugPrint('    - ${item.name}, Qty: ${item.quantity}, Price: ${item.price}, Total: ${item.total}');
        calculatedSumForDebug += item.total;
      }
    }
    debugPrint('[SplitStepWidget] Shared Items (${sharedItems.length}):');
    for (var item in sharedItems) {
      debugPrint('  - ${item.name}, Qty: ${item.quantity}, Price: ${item.price}, Total: ${item.total}');
      calculatedSumForDebug += item.total;
    }
    debugPrint('[SplitStepWidget] Unassigned Items (${unassignedItems.length}):');
    for (var item in unassignedItems) {
      debugPrint('  - ${item.name}, Qty: ${item.quantity}, Price: ${item.price}, Total: ${item.total}');
      calculatedSumForDebug += item.total;
    }
    debugPrint('[SplitStepWidget] Calculated sum of items passed to SplitManager: ${calculatedSumForDebug.toStringAsFixed(2)}');
    // --- END DEBUG LOGS ---

    // Link shared items to people (based on logic previously in _WorkflowModalBodyState)
    // This might need refinement if assignResultMap['shared_items'] contains 'people' lists directly
    final List<Map<String, dynamic>> sharedItemsDataFromAssign = (assignResultMap['shared_items'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ?? [];

    for (final sharedItemMap in sharedItemsDataFromAssign) {
        final String? itemName = sharedItemMap['name'] as String?;
        final num? itemPriceNum = sharedItemMap['price'] as num?;
        if (itemName == null || itemPriceNum == null) continue;
        final double itemPrice = itemPriceNum.toDouble();

        final sharedItemInstance = sharedItems.firstWhere(
            (ri) => ri.name == itemName && ri.price == itemPrice,
            orElse: () => ReceiptItem(name: 'dummy', price: 0, quantity: 0) // Should not happen if data is consistent
        );
        if (sharedItemInstance.name == 'dummy') continue;

        final List<String> personNamesSharingThisItem = (sharedItemMap['people'] as List<dynamic>?)?.cast<String>() ?? [];
        for (final personName in personNamesSharingThisItem) {
            final person = people.firstWhere((p) => p.name == personName, orElse: () => Person(name: 'dummy'));
            if (person.name != 'dummy' && !person.sharedItems.any((si) => si.itemId == sharedItemInstance.itemId)) { 
                person.addSharedItem(sharedItemInstance);
            }
        }
    }

    final splitManager = SplitManager(
      people: people,
      sharedItems: sharedItems,
      unassignedItems: unassignedItems,
      tipPercentage: currentTip ?? (parseResult['tip'] as num?)?.toDouble(),
      taxPercentage: currentTax ?? (parseResult['tax'] as num?)?.toDouble(),
      originalReviewTotal: (parseResult['subtotal'] as num?)?.toDouble(),
    );

    for (var item in initialItemsFromParse) {
      splitManager.setOriginalQuantity(item, item.quantity);
    }
    final allKnownItemsForQuantities = [
      ...people.expand((p) => p.assignedItems),
      ...sharedItems,
      ...unassignedItems,
    ];
    for (var item in allKnownItemsForQuantities) {
        if (splitManager.getOriginalQuantity(item) == 0 && item.quantity > 0) {
            splitManager.setOriginalQuantity(item, item.quantity);
        }
    }
    splitManager.initialSplitViewTabIndex = initialSplitViewTabIndex;

    // Add listener to SplitManager to propagate changes back to WorkflowState
    // IMPORTANT: This listener should be added carefully to avoid issues if SplitStepWidget rebuilds.
    // Consider if this listener should be managed by a StatefulWidget wrapper if SplitManager persists across rebuilds,
    // or ensure SplitManager is recreated on each build and listener re-added.
    // For simplicity now, assuming SplitManager is recreated with each build of SplitStepWidget.
    splitManager.addListener(() {
      // Check mounted if this widget were a StatefulWidget, but it's StatelessWidget.
      // Callbacks will handle context.
      final newTip = splitManager.tipPercentage;
      final newTax = splitManager.taxPercentage;
      final newAssignments = splitManager.generateAssignmentMap();

      onTipChanged(newTip);
      onTaxChanged(newTax);
      onAssignmentsUpdatedBySplit(newAssignments);
    });

    // Use showDialog for a true full-screen overlay
    Future<void> _showFullScreenSplitDialog() async {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return WillPopScope(
            onWillPop: () async {
              if (onClose != null) onClose!();
              return true;
            },
            child: ChangeNotifierProvider.value(
              value: splitManager,
              child: Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surface,
                body: Stack(
                  children: [
                    NotificationListener<Notification>(
                      onNotification: (notification) {
                        if (notification is NavigateToPageNotification) {
                          onNavigateToPage(notification.pageIndex);
                          Navigator.of(context).pop();
                          return true;
                        }
                        return false;
                      },
                      child: const SplitView(),
                    ),
                    // Persistent action row at the bottom
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Material(
                        elevation: 8,
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        child: SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                // Add Person (icon only)
                                Tooltip(
                                  message: 'Add Person',
                                  child: IconButton(
                                    icon: const Icon(Icons.person_add),
                                    onPressed: () => _showAddPersonDialog(context, Provider.of<SplitManager>(context, listen: false)),
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                // Add Item (icon only)
                                Tooltip(
                                  message: 'Add Item',
                                  child: IconButton(
                                    icon: const Icon(Icons.add_shopping_cart),
                                    onPressed: () => _showAddItemDialog(context, Provider.of<SplitManager>(context, listen: false)),
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const Spacer(),
                                // Done (confirm)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      // Prevent double pop: only call onClose if not already popped
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                        // Only call onClose if it does not itself pop
                                        // (Assume onClose is idempotent or a no-op if already closed)
                                        if (onClose != null) onClose!();
                                      } else if (onClose != null) {
                                        onClose!();
                                      }
                                    },
                                    icon: const Icon(Icons.check),
                                    label: const Text('Done'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
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
            ),
          );
        },
      );
      if (onClose != null) onClose!();
    }

    // Call the dialog when this widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFullScreenSplitDialog();
    });

    return const SizedBox.shrink();
  }
} 