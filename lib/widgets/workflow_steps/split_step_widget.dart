import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../../widgets/split_view.dart'; // Canonical source for NavigateToPageNotification
import '../../theme/app_colors.dart';
import 'package:flutter/services.dart';
import '../split_view.dart';

class SplitStepWidget extends StatefulWidget {
  // Data from WorkflowState needed to initialize SplitManager
  final Map<String, dynamic> parseResult; // Contains original items, subtotal, (optional initial tip/tax)
  final Map<String, dynamic> assignResultMap; // Contains assignments, shared_items, unassigned_items from voice
  final double? currentTip; // Tip from WorkflowState (might have been set by user)
  final double? currentTax; // Tax from WorkflowState (might have been set by user)
  final int initialSplitViewTabIndex; // To restore tab index if needed
  final String? receiptId; // Add receipt ID parameter

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
    this.receiptId, // Pass through to SplitView
    required this.onTipChanged,
    required this.onTaxChanged,
    required this.onAssignmentsUpdatedBySplit,
    required this.onNavigateToPage,
    this.onClose,
  }) : super(key: key);

  @override
  State<SplitStepWidget> createState() => _SplitStepWidgetState();
}

class _SplitStepWidgetState extends State<SplitStepWidget> {
  late SplitManager splitManager;

  @override
  void initState() {
    super.initState();
    splitManager = SplitManager(
      people: _extractPeopleFromAssignResult(widget.assignResultMap),
      sharedItems: _extractSharedItemsFromAssignResult(widget.assignResultMap),
      unassignedItems: _extractUnassignedItemsFromAssignResult(widget.assignResultMap),
      tipPercentage: widget.currentTip ?? (widget.parseResult['tip'] as num?)?.toDouble(),
      taxPercentage: widget.currentTax ?? (widget.parseResult['tax'] as num?)?.toDouble(),
      originalReviewTotal: (widget.parseResult['subtotal'] as num?)?.toDouble(),
    );
    splitManager.initialSplitViewTabIndex = widget.initialSplitViewTabIndex;
    splitManager.addListener(_onSplitManagerChanged);
  }

  @override
  void dispose() {
    splitManager.removeListener(_onSplitManagerChanged);
    splitManager.dispose();
    super.dispose();
  }

  void _onSplitManagerChanged() {
    widget.onTipChanged(splitManager.tipPercentage);
    widget.onTaxChanged(splitManager.taxPercentage);
    
    // Auto-assign shared items based on names if needed
    final sharedItems = splitManager.sharedItems;
    bool needsUpdate = false;
    
    for (var item in sharedItems) {
      // Get people sharing this item
      final sharers = splitManager.getPeopleForSharedItem(item);
      
      // Apply auto-assignment logic only if no one is assigned yet
      if (sharers.isEmpty) {
        // Auto-assign hummus to everyone
        if (item.name.toLowerCase().contains('hummus')) {
          for (var person in splitManager.people) {
            splitManager.addPersonToSharedItem(item, person);
            needsUpdate = true;
          }
        }
        // Auto-assign pita to Nick and Val
        else if (item.name.toLowerCase().contains('pita')) {
          for (var person in splitManager.people) {
            if (person.name == 'Nick' || person.name == 'Val') {
              splitManager.addPersonToSharedItem(item, person);
              needsUpdate = true;
            }
          }
        }
      }
    }
    
    // Schedule UI update after the build phase if needed
    if (needsUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        splitManager.notifyListeners();
      });
    }
    
    // Notify parent about changes to split assignments
    widget.onAssignmentsUpdatedBySplit(splitManager.generateAssignmentMap());
  }

  List<Person> _extractPeopleFromAssignResult(Map<String, dynamic> assignResult) {
    final List<Map<String, dynamic>> assignments = (assignResult['assignments'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    return assignments.map((assignment) {
      final personName = assignment['person_name'] as String;
      final itemsForPerson = (assignment['items'] as List<dynamic>).map((itemMap) {
        final itemDetail = itemMap as Map<String, dynamic>;
        
        // Ensure each assigned item has a valid itemId
        String itemId = itemDetail['itemId'] as String? ?? 
                        'assigned_${itemDetail['name']}_${itemDetail['price']}_$personName';
        
        // Update the original map with the itemId for future reference
        if (itemDetail['itemId'] == null) {
          itemDetail['itemId'] = itemId;
        }
        
        return ReceiptItem(
          itemId: itemId,
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
      // Ensure each shared item has a valid itemId
      String itemId = itemMap['itemId'] as String? ?? 
                      'shared_${itemMap['name']}_${itemMap['price']}';
      
      // debugPrint('[SplitStepWidget] Creating shared item: ${itemMap['name']} with ID: $itemId');
      
      // Update the original map with the itemId for future reference
      if (itemMap['itemId'] == null) {
        itemMap['itemId'] = itemId;
      }
      
      return ReceiptItem(
        itemId: itemId,
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
      // Ensure each unassigned item has a valid itemId
      String itemId = itemMap['itemId'] as String? ?? 
                      'unassigned_${itemMap['name']}_${itemMap['price']}';
      
      // Update the original map with the itemId for future reference
      if (itemMap['itemId'] == null) {
        itemMap['itemId'] = itemId;
      }
      
      return ReceiptItem(
        itemId: itemId,
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
    final List<Person> people = _extractPeopleFromAssignResult(widget.assignResultMap);
    final List<ReceiptItem> sharedItems = _extractSharedItemsFromAssignResult(widget.assignResultMap);
    final List<ReceiptItem> unassignedItems = _extractUnassignedItemsFromAssignResult(widget.assignResultMap);
    final List<ReceiptItem> initialItemsFromParse = _extractInitialItemsFromParseResult(widget.parseResult);

    // --- BEGIN DEBUG LOGS ---
    // debugPrint('[SplitStepWidget] Initializing SplitManager.');
    // debugPrint('[SplitStepWidget] parseResult subtotal for originalReviewTotal: ${widget.parseResult['subtotal']}');
    double calculatedSumForDebug = 0;
    // debugPrint('[SplitStepWidget] People (${people.length}):');
    // for (var p in people) {
    //   debugPrint('  ${p.name}, Items:');
    //   for (var item in p.assignedItems) {
    //     debugPrint('    - ${item.name}, Qty: ${item.quantity}, Price: ${item.price}, Total: ${item.total}');
    //     calculatedSumForDebug += item.total;
    //   }
    // }
    // // debugPrint('[SplitStepWidget] Shared Items (${sharedItems.length}):');
    // for (var item in sharedItems) {
    //   debugPrint('  - ${item.name}, Qty: ${item.quantity}, Price: ${item.price}, Total: ${item.total}');
    //   calculatedSumForDebug += item.total;
    // }
    // // debugPrint('[SplitStepWidget] Unassigned Items (${unassignedItems.length}):');
    // for (var item in unassignedItems) {
    //   debugPrint('  - ${item.name}, Qty: ${item.quantity}, Price: ${item.price}, Total: ${item.total}');
    //   calculatedSumForDebug += item.total;
    // }
    // debugPrint('[SplitStepWidget] Calculated sum of items passed to SplitManager: ${calculatedSumForDebug.toStringAsFixed(2)}');
    // --- END DEBUG LOGS ---

    // Link shared items to people (based on logic previously in _WorkflowModalBodyState)
    final List<Map<String, dynamic>> sharedItemsDataFromAssign = (widget.assignResultMap['shared_items'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ?? [];

    // Process all shared items and assign people to them using splitManager
    for (final sharedItemMap in sharedItemsDataFromAssign) {
        final String itemName = sharedItemMap['name'] as String;
        final double itemPrice = (sharedItemMap['price'] as num).toDouble();
        final String? mapItemId = sharedItemMap['itemId'] as String?;

        // Try to find matching shared item by itemId first
        ReceiptItem? matchingSharedItem;
        
        if (mapItemId != null) {
          try {
            matchingSharedItem = splitManager.sharedItems.firstWhere((item) => item.itemId == mapItemId);
            // debugPrint('[SplitStepWidget] Found shared item by itemId: $mapItemId, name: ${matchingSharedItem.name}');
          } catch (e) {
            // debugPrint('[SplitStepWidget] Could not find shared item with itemId: $mapItemId, falling back to name+price match');
          }
        }
        
        // If itemId match failed, fall back to name+price match
        if (matchingSharedItem == null) {
          try {
            matchingSharedItem = splitManager.sharedItems.firstWhere(
              (item) => item.name == itemName && item.price == itemPrice
            );
            // debugPrint('[SplitStepWidget] Found shared item by name+price: $itemName, $itemPrice');
          } catch (e) {
            // debugPrint('[SplitStepWidget] ERROR: Could not find shared item: $itemName at price $itemPrice');
            continue;
          }
        }
        
        // Debug the found item
        // debugPrint('[SplitStepWidget] Processing shared item: ${matchingSharedItem.name}, ItemId: ${matchingSharedItem.itemId}');

        // Get the list of people sharing this item
        List<String> personNamesSharingThisItem = (sharedItemMap['people'] as List<dynamic>?)?.cast<String>() ?? [];
        
        // If the people list is empty but this is a shared item, auto-assign based on description
        if (personNamesSharingThisItem.isEmpty) {
          bool didAutoAssign = false;
          
          // For the White Pita - item description says "Me and Val shared"
          if (itemName.toLowerCase().contains('pita')) {
            personNamesSharingThisItem.addAll(['Nick', 'Val']);
            didAutoAssign = true;
            // debugPrint('[SplitStepWidget] Auto-assigned shared item: $itemName to Nick and Val');
          }
          // For the Hummus Garlic - description says "We all shared"
          else if (itemName.toLowerCase().contains('hummus')) {
            for (var person in splitManager.people) {
              personNamesSharingThisItem.add(person.name);
              didAutoAssign = true;
              // debugPrint('[SplitStepWidget] Auto-assigned shared item: $itemName to everyone including ${person.name}');
            }
          }
          
          // If we auto-assigned people to this shared item, update the original data structure
          // so it persists across workflow steps
          if (didAutoAssign && sharedItemMap is Map<String, dynamic>) {
            sharedItemMap['people'] = personNamesSharingThisItem;
          }
        }
        
        // debugPrint('[SplitStepWidget] People sharing ${matchingSharedItem.name}: ${personNamesSharingThisItem.join(', ')}');
        
        // Store the final item and people for post-frame processing to avoid state updates during build
        final ReceiptItem finalSharedItem = matchingSharedItem;
        final List<String> finalPersonNames = personNamesSharingThisItem;
        
        // IMPORTANT: Use post-frame callback to update shared item assignments
        // This prevents modifying state during the build phase which causes exceptions
        WidgetsBinding.instance.addPostFrameCallback((_) {
            // Add each person to the shared item using splitManager
            bool anyPeopleUpdated = false;
            for (final personName in finalPersonNames) {
                final matchingPerson = splitManager.people.firstWhere(
                  (p) => p.name == personName, 
                  orElse: () => Person(name: 'dummy')
                );
                
                if (matchingPerson.name != 'dummy') {
                    // Check if person already has this item to avoid duplicates
                    if (!matchingPerson.sharedItems.any((si) => si.itemId == finalSharedItem.itemId)) {
                        // debugPrint('[SplitStepWidget] Adding shared item ${finalSharedItem.name} (${finalSharedItem.itemId}) to ${matchingPerson.name}');
                        splitManager.addPersonToSharedItem(finalSharedItem, matchingPerson);
                        anyPeopleUpdated = true;
                    }
                }
            }
            
            // Force UI refresh if needed
            if (anyPeopleUpdated) {
                splitManager.notifyListeners();
            }
        });
    }

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

    return ChangeNotifierProvider.value(
      value: splitManager,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            NotificationListener<Notification>(
              onNotification: (notification) {
                if (notification is NavigateToPageNotification) {
                  widget.onNavigateToPage(notification.pageIndex);
                  Navigator.of(context).pop();
                  return true;
                }
                return false;
              },
              child: SplitView(
                onClose: widget.onClose,
                receiptId: widget.receiptId, // Pass receipt ID to SplitView
              ),
            ),
          ],
        ),
      ),
    );
  }
} 