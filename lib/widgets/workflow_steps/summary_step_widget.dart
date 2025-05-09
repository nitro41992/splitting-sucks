import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import '../../models/receipt_item.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../../screens/final_summary_screen.dart';
// import '../../widgets/workflow_modal.dart'; // For NavigateToPageNotification if needed

class SummaryStepWidget extends StatelessWidget {
  final Map<String, dynamic> parseResult;
  final Map<String, dynamic> assignResultMap;
  final double? currentTip;
  final double? currentTax;
  // Add any callbacks if the summary screen can trigger actions, e.g., navigation
  // final Function(int pageIndex) onNavigateToPage; 

  const SummaryStepWidget({
    Key? key,
    required this.parseResult,
    required this.assignResultMap,
    this.currentTip,
    this.currentTax,
    // required this.onNavigateToPage,
  }) : super(key: key);

  // Helper to reconstruct Person list with assigned and shared items for SplitManager
  List<Person> _preparePeopleForSummaryManager(Map<String, dynamic> assignMap) {
    final List<Person> peopleForManager = [];
    final List<ReceiptItem> allSharedItemsForManager = [];

    // First, create all shared item instances
    if (assignMap.containsKey('shared_items') && assignMap['shared_items'] is List) {
      for (var itemData in (assignMap['shared_items'] as List)) {
        if (itemData is Map<String, dynamic>) {
          allSharedItemsForManager.add(ReceiptItem.fromJson(itemData));
        }
      }
    }

    // Then, create people and link their assigned and shared items
    if (assignMap.containsKey('assignments') && assignMap['assignments'] is List) {
      for (var personData in (assignMap['assignments'] as List)) {
        if (personData is Map<String, dynamic>) {
          final personName = personData['person_name'] as String? ?? 'Unknown Person';
          final List<ReceiptItem> personAssignedItems = [];
          if (personData['items'] is List) {
            for (var itemData in (personData['items'] as List)) {
              if (itemData is Map<String, dynamic>) {
                personAssignedItems.add(ReceiptItem.fromJson(itemData));
              }
            }
          }
          final personInstance = Person(name: personName, assignedItems: personAssignedItems);
          
          // Link shared items to this person if specified in their assignment data 
          // (assuming assignMap structure might include person-specific shared item involvement)
          // This part depends on how assignResultMap is structured regarding shared items per person.
          // If shared_items in assignResultMap are global with a 'people' list inside each shared item:
          if (assignMap.containsKey('shared_items') && assignMap['shared_items'] is List) {
            for (var sharedItemMap in (assignMap['shared_items'] as List<dynamic>)) {
                if (sharedItemMap is Map<String, dynamic>) {
                    final List<String> pNamesSharing = (sharedItemMap['people'] as List<dynamic>?)?.cast<String>() ?? [];
                    if (pNamesSharing.contains(personInstance.name)) {
                        final actualSharedItemInstance = allSharedItemsForManager.firstWhereOrNull(
                            (si) => si.name == (sharedItemMap['name'] as String?) && 
                                   si.price == (sharedItemMap['price'] as num?)?.toDouble()
                        );
                        if (actualSharedItemInstance != null && 
                            !personInstance.sharedItems.any((psi) => psi.itemId == actualSharedItemInstance.itemId)) {
                            personInstance.addSharedItem(actualSharedItemInstance);
                        }
                    }
                }
            }
          }
          peopleForManager.add(personInstance);
        }
      }
    }
    return peopleForManager;
  }

  List<ReceiptItem> _extractSharedItemsForSummaryManager(Map<String, dynamic> assignMap) {
    final List<ReceiptItem> sharedItems = [];
     if (assignMap.containsKey('shared_items') && assignMap['shared_items'] is List) {
      for (var itemData in (assignMap['shared_items'] as List)) {
        if (itemData is Map<String, dynamic>) {
          sharedItems.add(ReceiptItem.fromJson(itemData));
        }
      }
    }
    return sharedItems;
  }

  List<ReceiptItem> _extractUnassignedItemsForSummaryManager(Map<String, dynamic> assignMap) {
    final List<ReceiptItem> unassignedItems = [];
    if (assignMap.containsKey('unassigned_items') && assignMap['unassigned_items'] is List) {
      for (var itemData in (assignMap['unassigned_items'] as List)) {
        if (itemData is Map<String, dynamic>) {
          unassignedItems.add(ReceiptItem.fromJson(itemData));
        }
      }
    }
    return unassignedItems;
  }

  @override
  Widget build(BuildContext context) {
    // --- BEGIN DEBUG LOGS for SummaryStepWidget ---
    debugPrint('[SummaryStepWidget] Initializing SplitManager for summary.');
    debugPrint('[SummaryStepWidget] Received parseResult subtotal: ${parseResult['subtotal']}');
    debugPrint('[SummaryStepWidget] Received assignResultMap: $assignResultMap');
    debugPrint('[SummaryStepWidget] Received currentTip: $currentTip, currentTax: $currentTax');
    
    // Calculate sum from assignResultMap for cross-check
    double assignMapItemsSum = 0;
    if (assignResultMap.containsKey('assignments') && assignResultMap['assignments'] is List) {
      for (var personData in (assignResultMap['assignments'] as List)) {
        if (personData is Map<String, dynamic> && personData['items'] is List) {
          for (var itemData in (personData['items'] as List)) {
            if (itemData is Map<String, dynamic>) {
              assignMapItemsSum += (itemData['price'] as num? ?? 0.0).toDouble() * (itemData['quantity'] as num? ?? 0).toInt();
            }
          }
        }
      }
    }
    if (assignResultMap.containsKey('shared_items') && assignResultMap['shared_items'] is List) {
      for (var itemData in (assignResultMap['shared_items'] as List)) {
        if (itemData is Map<String, dynamic>) {
          assignMapItemsSum += (itemData['price'] as num? ?? 0.0).toDouble() * (itemData['quantity'] as num? ?? 0).toInt();
        }
      }
    }
     if (assignResultMap.containsKey('unassigned_items') && assignResultMap['unassigned_items'] is List) {
      for (var itemData in (assignResultMap['unassigned_items'] as List)) {
        if (itemData is Map<String, dynamic>) {
          assignMapItemsSum += (itemData['price'] as num? ?? 0.0).toDouble() * (itemData['quantity'] as num? ?? 0).toInt();
        }
      }
    }
    debugPrint('[SummaryStepWidget] Calculated item sum from received assignResultMap: ${assignMapItemsSum.toStringAsFixed(2)}');
    // --- END DEBUG LOGS ---

    final List<Person> people = _preparePeopleForSummaryManager(assignResultMap);
    final List<ReceiptItem> sharedItems = _extractSharedItemsForSummaryManager(assignResultMap);
    final List<ReceiptItem> unassignedItems = _extractUnassignedItemsForSummaryManager(assignResultMap);

    final summaryManager = SplitManager(
      people: people,
      sharedItems: sharedItems, 
      unassignedItems: unassignedItems,
      tipPercentage: currentTip,
      taxPercentage: currentTax,
      originalReviewTotal: (parseResult['subtotal'] as num?)?.toDouble(),
    );

    // The FinalSummaryScreen is wrapped with a ChangeNotifierProvider for the summaryManager.
    // If FinalSummaryScreen itself could trigger navigation that workflow_modal needs to handle,
    // a NotificationListener would be added here, similar to SplitStepWidget.
    return ChangeNotifierProvider.value(
      value: summaryManager,
      child: const FinalSummaryScreen(),
    );
  }
} 