import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../../widgets/split_view.dart'; // Canonical source for NavigateToPageNotification

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

    return NotificationListener<Notification>(
      onNotification: (notification) {
        if (notification is NavigateToPageNotification) {
          onNavigateToPage(notification.pageIndex);
          return true; // Notification handled
        }
        return false; // Notification not handled
      },
      child: ChangeNotifierProvider.value(
        value: splitManager,
        child: const SplitView(),
      ),
    );
  }
} 