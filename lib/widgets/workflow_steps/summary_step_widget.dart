import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import '../../models/receipt_item.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../../screens/final_summary_screen.dart';
import '../../theme/app_colors.dart';
// import '../../widgets/workflow_modal.dart'; // For NavigateToPageNotification if needed

// Helper record for the return type
class ExtractedSharedItemsResult {
  final List<ReceiptItem> itemsMappedToOriginalOrder; // Corresponds 1-to-1 with input items
  final List<ReceiptItem> uniqueCanonicalItems;       // De-duplicated list of items for SplitManager

  ExtractedSharedItemsResult(this.itemsMappedToOriginalOrder, this.uniqueCanonicalItems);
}

class SummaryStepWidget extends StatelessWidget {
  final Map<String, dynamic> parseResult;
  final Map<String, dynamic> assignResultMap;
  final double? currentTip;
  final double? currentTax;
  final VoidCallback? onEditAssignments;
  // Add any callbacks if the summary screen can trigger actions, e.g., navigation
  // final Function(int pageIndex) onNavigateToPage; 

  const SummaryStepWidget({
    Key? key,
    required this.parseResult,
    required this.assignResultMap,
    this.currentTip,
    this.currentTax,
    this.onEditAssignments,
    // required this.onNavigateToPage,
  }) : super(key: key);

  ExtractedSharedItemsResult _extractSharedItemsHelper(Map<String, dynamic> assignResultMap) {
    final List<ReceiptItem> mappedItems = [];
    // Use a Map to ensure unique items by their final itemId for the SplitManager
    final Map<String, ReceiptItem> uniqueItemsByFinalId = {}; 

    // This map tracks canonical items created for sourceItemIds found in assignResultMap
    final Map<String, ReceiptItem> canonicalItemsBySourceId = {}; 

    if (assignResultMap.containsKey('shared_items') && assignResultMap['shared_items'] is List) {
      for (var sharedItemDataUntyped in (assignResultMap['shared_items'] as List)) {
        // Ensure we're working with a mutable copy for fromJson if it modifies its input, though it shouldn't.
        final sharedItemMap = Map<String, dynamic>.from(sharedItemDataUntyped as Map<String, dynamic>);
        final String? sourceItemId = sharedItemMap['itemId'] as String?;
        ReceiptItem currentCanonicalItem;

        if (sourceItemId != null) {
          // This entry from assignResultMap has a specific itemId.
          if (canonicalItemsBySourceId.containsKey(sourceItemId)) {
            // We've already created/designated a canonical ReceiptItem for this sourceItemId. Use it.
            currentCanonicalItem = canonicalItemsBySourceId[sourceItemId]!;
          } else {
            // First time seeing this sourceItemId. Create a ReceiptItem (fromJson will use sourceItemId).
            // This becomes the canonical instance for this sourceItemId.
            currentCanonicalItem = ReceiptItem.fromJson(sharedItemMap);
            canonicalItemsBySourceId[sourceItemId] = currentCanonicalItem;
          }
        } else {
          // No sourceItemId in this assignResultMap entry (e.g., old data).
          // This entry represents a distinct shared item.
          // ReceiptItem.fromJson will generate a new, unique itemId for it.
          currentCanonicalItem = ReceiptItem.fromJson(sharedItemMap);
        }
        // Add the (potentially shared, potentially new) canonical item to the list that mirrors original order.
        mappedItems.add(currentCanonicalItem);
        // Also, ensure this item (identified by its final, possibly generated, itemId) is in the unique list.
        uniqueItemsByFinalId[currentCanonicalItem.itemId] = currentCanonicalItem;
      }
    }
    return ExtractedSharedItemsResult(mappedItems, uniqueItemsByFinalId.values.toList());
  }

  List<Person> _preparePeopleForSummaryManager(
    Map<String, dynamic> assignMap,
    List<ReceiptItem> itemsMappedToOriginalShared // This is from ExtractedSharedItemsResult.itemsMappedToOriginalOrder
  ) {
    final List<Person> peopleForManager = _extractPeopleFromAssignResult(assignMap);

    if (assignMap.containsKey('shared_items') && assignMap['shared_items'] is List) {
      final List<dynamic> sharedEntriesFromMap = assignMap['shared_items'] as List<dynamic>;

      if (sharedEntriesFromMap.length != itemsMappedToOriginalShared.length) {
        String msg = "[SummaryStepWidget._preparePeople] Error: Mismatch in length between shared item entries from assignMap (";
        msg += "${sharedEntriesFromMap.length}) and the mapped canonical items (${itemsMappedToOriginalShared.length}). ";
        msg += "Aborting shared item processing for people.";
        debugPrint(msg);
        return peopleForManager; 
      }

      for (int i = 0; i < sharedEntriesFromMap.length; i++) {
        final sharedEntryMap = sharedEntriesFromMap[i] as Map<String, dynamic>;
        // This is the specific canonical ReceiptItem instance corresponding to the i-th entry 
        // in assignMap['shared_items']. It will have a unique itemId.
        final ReceiptItem canonicalItemForThisEntry = itemsMappedToOriginalShared[i]; 

        final List<dynamic> peopleNamesInvolved = sharedEntryMap['people'] as List<dynamic>? ?? [];
        for (final personNameDynamic in peopleNamesInvolved) {
          final String personName = personNameDynamic as String;
          final int personIndex = peopleForManager.indexWhere((p) => p.name == personName);

          if (personIndex != -1) {
            final Person currentPerson = peopleForManager[personIndex];
            // Add the canonical item to the person's shared list if not already there (by its unique itemId).
            // A person can share multiple distinct items.
            // If multiple entries in assignMap['shared_items'] resolved to the *same* canonicalItemForThisEntry
            // (because they shared a sourceItemId), this addSharedItem will only add it once.
            if (!currentPerson.sharedItems.any((si) => si.itemId == canonicalItemForThisEntry.itemId)) {
              currentPerson.addSharedItem(canonicalItemForThisEntry);
               // debugPrint('[SummaryStepWidget._preparePeople] Added shared item ${canonicalItemForThisEntry.name} (ID: ${canonicalItemForThisEntry.itemId}) to ${currentPerson.name}');
            }
          } else {
            // Corrected debugPrint statement for person not found
            debugPrint('[SummaryStepWidget._preparePeople] Warning: Person $personName listed in shared item \'${sharedEntryMap['name']}\' (entry $i) not found in peopleForManager list.');
          }
        }
      }
    }
    return peopleForManager;
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

  List<Person> _extractPeopleFromAssignResult(Map<String, dynamic> assignResult) {
    final List<Person> people = [];
    if (assignResult.containsKey('assignments') && assignResult['assignments'] is List) {
      for (var personData in (assignResult['assignments'] as List)) {
        if (personData is Map<String, dynamic>) {
          final String personName = personData['person_name'] as String? ?? 'Unknown Person';
          final List<ReceiptItem> assignedItems = [];
          if (personData['items'] is List) {
            for (var itemMapUntyped in (personData['items'] as List)) {
              final itemMap = itemMapUntyped as Map<String, dynamic>;
              // Ensure assigned items also get their itemIds correctly (fromJson should handle this)
              assignedItems.add(ReceiptItem.fromJson(itemMap));
            }
          }
          people.add(Person(name: personName, assignedItems: assignedItems));
        }
      }
    }
    return people;
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

    // Order of operations:
    // 1. Extract shared items: get a list mapped to original input order AND a unique list for the manager.
    final ExtractedSharedItemsResult sharedExtractionResult = _extractSharedItemsHelper(assignResultMap);
    final List<ReceiptItem> itemsToLinkToPeople = sharedExtractionResult.itemsMappedToOriginalOrder;
    final List<ReceiptItem> uniqueSharedItemsForManager = sharedExtractionResult.uniqueCanonicalItems;
    
    // 2. Prepare people: extract their assigned items and then link them to the canonical shared items 
    //    using the mapped list that preserves original shared item entry context.
    final List<Person> people = _preparePeopleForSummaryManager(assignResultMap, itemsToLinkToPeople);
    
    // 3. Extract unassigned items.
    final List<ReceiptItem> unassignedItems = _extractUnassignedItemsForSummaryManager(assignResultMap);

    final summaryManager = SplitManager(
      people: people,
      sharedItems: uniqueSharedItemsForManager, // Use the de-duplicated unique list for the manager
      unassignedItems: unassignedItems,
      tipPercentage: currentTip,
      taxPercentage: currentTax,
      originalReviewTotal: (parseResult['subtotal'] as num?)?.toDouble(),
    );

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // The FinalSummaryScreen is wrapped with a ChangeNotifierProvider for the summaryManager.
    // If FinalSummaryScreen itself could trigger navigation that workflow_modal needs to handle,
    // a NotificationListener would be added here, similar to SplitStepWidget.
    return ChangeNotifierProvider.value(
      value: summaryManager,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Icon(Icons.summarize, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Split Summary',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                if (onEditAssignments != null)
                  GestureDetector(
                    onTap: onEditAssignments,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.puce,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.puce.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Edit Split',
                            style: textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FinalSummaryScreen(),
          ),
        ],
      ),
    );
  }
} 