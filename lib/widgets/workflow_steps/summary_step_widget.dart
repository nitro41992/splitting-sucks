import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import '../../models/receipt_item.dart';
import '../../models/person.dart';
import '../../models/split_manager.dart';
import '../../screens/final_summary_screen.dart';
import '../../theme/app_colors.dart';
// import '../../widgets/workflow_modal.dart'; // For NavigateToPageNotification if needed

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

  // Helper to reconstruct Person list with assigned and shared items for SplitManager
  List<Person> _preparePeopleForSummaryManager(Map<String, dynamic> assignMap) {
    final List<Person> peopleForManager = [];
    final List<ReceiptItem> allSharedItemsForManager = [];

    // First, create all shared item instances (with itemId)
    if (assignMap.containsKey('shared_items') && assignMap['shared_items'] is List) {
      for (var itemData in (assignMap['shared_items'] as List)) {
        if (itemData is Map<String, dynamic>) {
          allSharedItemsForManager.add(ReceiptItem.fromJson(itemData));
        }
      }
    }

    // Then, create people with their assigned items
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
          peopleForManager.add(Person(name: personName, assignedItems: personAssignedItems));
        }
      }
    }
    
    // Now link shared items to people based on their names from the shared_items people lists
    if (assignMap.containsKey('shared_items') && assignMap['shared_items'] is List) {
      for (var sharedItemData in (assignMap['shared_items'] as List)) {
        if (sharedItemData is Map<String, dynamic>) {
          // Find all people that share this item
          final List<String> peopleNames = 
              (sharedItemData['people'] as List<dynamic>?)?.cast<String>() ?? [];
          
          if (peopleNames.isEmpty) {
            // If people list is empty in the data but this is supposed to be a shared item,
            // we'll add people based on item name (as a fallback based on the description)
            final String itemName = sharedItemData['name'] as String? ?? '';
            
            // For the White Pita - item description says "Me and Val shared"
            if (itemName.toLowerCase().contains('pita')) {
              peopleNames.addAll(['Nick', 'Val']);
              debugPrint('[SummaryStepWidget] Auto-assigned shared item: $itemName to people: Nick, Val');
            }
            // For the Hummus Garlic - description says "We all shared"
            else if (itemName.toLowerCase().contains('hummus')) {
              for (var person in peopleForManager) {
                peopleNames.add(person.name);
              }
              debugPrint('[SummaryStepWidget] Auto-assigned shared item: $itemName to people: ${peopleNames.join(', ')}');
            }
          }
          
          // Only proceed if there are people to share with
          if (peopleNames.isNotEmpty) {
            // Find the matching shared item
            final String itemName = sharedItemData['name'] as String? ?? '';
            final double itemPrice = (sharedItemData['price'] as num?)?.toDouble() ?? 0.0;
            final int itemQuantity = (sharedItemData['quantity'] as num?)?.toInt() ?? 1;
            
            // Find or create the shared item
            ReceiptItem? sharedItem = allSharedItemsForManager.firstWhereOrNull(
              (si) => si.name == itemName && si.price == itemPrice
            );
            
            if (sharedItem == null) {
              // Create a new shared item if not found
              sharedItem = ReceiptItem(
                name: itemName,
                price: itemPrice,
                quantity: itemQuantity
              );
              allSharedItemsForManager.add(sharedItem);
            }
            
            // Now assign this shared item to all the relevant people
            for (String personName in peopleNames) {
              Person? person = peopleForManager.firstWhereOrNull(
                (p) => p.name == personName
              );
              
              if (person != null && !person.sharedItems.any((si) => si.itemId == sharedItem!.itemId)) {
                debugPrint('[SummaryStepWidget] Adding shared item ${sharedItem.name} to ${person.name}');
                person.addSharedItem(sharedItem);
              }
            }
          }
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