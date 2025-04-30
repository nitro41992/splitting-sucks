import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/split_manager.dart';
import '../models/person.dart';
import '../models/receipt_item.dart';

// Import the extracted widgets
import 'cards/person_card.dart';
import 'cards/shared_item_card.dart';
import 'cards/unassigned_item_card.dart';
import '../theme/app_colors.dart';
import '../receipt_splitter_ui.dart';

// Define a notification class to request navigation
class NavigateToPageNotification extends Notification {
  final int pageIndex;
  
  NavigateToPageNotification(this.pageIndex);
}

class SplitView extends StatefulWidget {
  const SplitView({
    super.key,
  });

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  int _selectedIndex = 0;
  bool _isFabVisible = true;
  bool _isSubtotalCollapsed = true;
  final ScrollController _peopleScrollController = ScrollController();
  final ScrollController _sharedScrollController = ScrollController();
  final ScrollController _unassignedScrollController = ScrollController();

  // Keep PersonCard constants accessible if needed here, or move fully
  static const int personMaxNameLength = PersonCard.maxNameLength;

  @override
  void initState() {
    super.initState();

    // Read initial tab index from SplitManager
    // Use WidgetsBinding.instance.addPostFrameCallback to safely interact with context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final splitManager = context.read<SplitManager>();
      final initialIndex = splitManager.initialSplitViewTabIndex;
      if (initialIndex != null && initialIndex >= 0 && initialIndex <= 2) { // Check bounds (0, 1, 2)
        if (mounted) { // Check if the widget is still in the tree
          setState(() {
            _selectedIndex = initialIndex;
          });
        }
        // Reset the value in SplitManager so it doesn't persist
        splitManager.initialSplitViewTabIndex = null;
      }
    });

    // Add scroll listeners
    _peopleScrollController.addListener(_onScroll);
    _sharedScrollController.addListener(_onScroll);
    _unassignedScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _peopleScrollController.dispose();
    _sharedScrollController.dispose();
    _unassignedScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    ScrollController activeController;
    
    switch (_selectedIndex) {
      case 0:
        activeController = _peopleScrollController;
        break;
      case 1:
        activeController = _sharedScrollController;
        break;
      case 2:
        activeController = _unassignedScrollController;
        break;
      default:
        return;
    }
    
    if (!activeController.hasClients) return;
    
    final isScrollingDown = activeController.position.userScrollDirection == ScrollDirection.reverse;
    if (isScrollingDown != !_isFabVisible) {
      setState(() {
        _isFabVisible = !isScrollingDown;
        // No longer changing _isSubtotalCollapsed based on scroll
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitManager>(
      builder: (context, splitManager, child) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        final TextTheme textTheme = Theme.of(context).textTheme;
        
        // Calculate total values for the header
        final double individualTotal = splitManager.people.fold(0.0, (sum, person) => sum + person.totalAssignedAmount);
        final double sharedTotal = splitManager.sharedItemsTotal;
        final double assignedTotal = individualTotal + sharedTotal;
        final double unassignedTotal = splitManager.unassignedItemsTotal;
        final double subtotal = assignedTotal + unassignedTotal;

        // --- EDIT: Create persistent warning widget logic --- 
        Widget? warningWidget;
        final originalTotal = splitManager.originalReviewTotal;
        final currentTotal = subtotal; // Current total in split view
        final bool totalsMatch = originalTotal == null 
            ? currentTotal < 0.01 // Only consider a match if current is effectively zero
            : (currentTotal - originalTotal).abs() < 0.001;

        // --- EDIT: Add debug print for values being compared ---
        print('DEBUG (SplitView): Checking for total mismatch... Original Review Total: $originalTotal, Current Split Total: $currentTotal, Match: $totalsMatch');
        // --- END EDIT ---

        // Show warning if totals mismatch
        if (!totalsMatch) { 
          // Define puce color (reddish-purple brown)
          final Color puceColor = Color(0xCC8B5A69); // Semi-transparent puce
          
          warningWidget = Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0), 
            child: Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: puceColor.withOpacity(0.5), width: 1),
              ),
              color: puceColor.withOpacity(0.15),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: puceColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.warning_amber_rounded, 
                        color: puceColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'The current total (\$${currentTotal.toStringAsFixed(2)}) differs from the receipt total in the Review tab (\$${originalTotal?.toStringAsFixed(2) ?? 'N/A'}).',
                        style: textTheme.bodyMedium?.copyWith(
                          color: puceColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        return Scaffold(
          body: Column(
            children: [
              // Collapsible totals header at the top
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // We're no longer auto-collapsing based on scroll
                  return false;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _isSubtotalCollapsed ? 60 : 220,
                  decoration: BoxDecoration(
                    color: _isSubtotalCollapsed ? colorScheme.surface.withOpacity(0.9) : Colors.transparent,
                    boxShadow: _isSubtotalCollapsed 
                      ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                  ),
                  child: _isSubtotalCollapsed 
                    // Collapsed view - just the subtotal
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Subtotal: ',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '\$${subtotal.toStringAsFixed(2)}',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            // Toggle button
                            IconButton(
                              icon: Icon(Icons.expand_more, color: colorScheme.primary),
                              onPressed: () => setState(() => _isSubtotalCollapsed = false),
                              tooltip: 'Show details',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 24,
                            ),
                          ],
                        ),
                      )
                    // Expanded view - full totals breakdown
                    : GestureDetector(
                        onVerticalDragEnd: (details) {
                          // If drag ends with upward motion, collapse the totals
                          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                            setState(() => _isSubtotalCollapsed = true);
                          }
                        },
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header with collapse button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.expand_less, color: colorScheme.primary),
                                      onPressed: () => setState(() => _isSubtotalCollapsed = true),
                                      tooltip: 'Hide details',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 24,
                                    ),
                                  ],
                                ),
                                // Individual Items Total
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Individual Items: ',
                                      style: textTheme.titleMedium,
                                    ),
                                    Text(
                                      '\$${individualTotal.toStringAsFixed(2)}',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Shared Items Total
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Shared Items: ',
                                      style: textTheme.titleMedium,
                                    ),
                                    Text(
                                      '\$${sharedTotal.toStringAsFixed(2)}',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Combined Assigned Total
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Assigned Total: ',
                                      style: textTheme.titleMedium,
                                    ),
                                    Text(
                                      '\$${assignedTotal.toStringAsFixed(2)}',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Unassigned: ',
                                      style: textTheme.titleMedium?.copyWith(
                                        color: colorScheme.error,
                                      ),
                                    ),
                                    Text(
                                      '\$${unassignedTotal.toStringAsFixed(2)}',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Subtotal row - always visible and more prominent
                                Divider(height: 1, thickness: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Subtotal: ',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '\$${subtotal.toStringAsFixed(2)}',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ),
              ),
              
              // --- INSERT WARNING BELOW SUBTOTAL ---
              if (warningWidget != null) warningWidget,
              
              // Custom tab selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // People Tab
                      Expanded(
                        child: _buildTabItem(
                          context: context,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          index: 0,
                          label: 'People',
                        ),
                      ),
                      
                      // Shared Tab
                      Expanded(
                        child: _buildTabItem(
                          context: context,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          index: 1,
                          label: 'Shared',
                        ),
                      ),
                      
                      // Unassigned Tab
                      Expanded(
                        child: _buildTabItem(
                          context: context,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          index: 2,
                          label: 'Unassigned',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Content area without totals header
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    // People list
                    _buildList(
                      scrollController: _peopleScrollController,
                      builder: (context) => _buildPeopleList(context, splitManager),
                    ),
                    
                    // Shared items list
                    _buildList(
                      scrollController: _sharedScrollController,
                      builder: (context) => _buildSharedItemsList(context, splitManager),
                    ),
                    
                    // Unassigned items list
                    _buildList(
                      scrollController: _unassignedScrollController,
                      builder: (context) => _buildUnassignedItemsList(context, splitManager),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            offset: _isFabVisible ? Offset.zero : const Offset(0, 2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isFabVisible ? 1.0 : 0.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Add Person button
                  FloatingActionButton(
                    onPressed: () => _showAddPersonDialog(context, splitManager),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    heroTag: 'addPersonBtn',
                    child: const Icon(Icons.person_add),
                  ),
                  const SizedBox(width: 16),
                  // Add Item button 
                  FloatingActionButton(
                    onPressed: () => _showAddItemDialog(context, splitManager),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    heroTag: 'addItemBtn',
                    child: const Icon(Icons.add_shopping_cart),
                  ),
                  const SizedBox(width: 16),
                  // Go to Summary button
                  FloatingActionButton.extended(
                    onPressed: () {
                      // Use notification pattern to request navigation to summary page
                      NavigateToPageNotification(4).dispatch(context);
                    },
                    backgroundColor: colorScheme.secondaryContainer,
                    foregroundColor: colorScheme.onSecondaryContainer,
                    heroTag: 'goToSummaryBtn',
                    label: const Text('Go to Summary'),
                    icon: const Icon(Icons.summarize),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Helper method to build a list with scrolling
  Widget _buildList({
    required ScrollController scrollController,
    required Widget Function(BuildContext) builder,
  }) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), // Increased bottom padding for two FABs
      children: [
        builder(context),
      ],
    );
  }

  Widget _buildPeopleList(BuildContext context, SplitManager splitManager) {
    return Column(
      children: splitManager.people.map((person) => PersonCard(person: person)).toList(),
    );
  }

  Widget _buildSharedItemsList(BuildContext context, SplitManager splitManager) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (splitManager.sharedItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_off_outlined, // Icon indicating no sharing
                size: 60,
                color: colorScheme.secondary, // Use secondary color for distinction
              ),
              const SizedBox(height: 24),
              Text(
                'Nothing Shared Yet!',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.secondary, // Use secondary color
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Assign items to multiple people to share them.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Column(
        children: splitManager.sharedItems.map((item) => SharedItemCard(item: item)).toList(),
      );
    }
  }

  Widget _buildUnassignedItemsList(BuildContext context, SplitManager splitManager) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (splitManager.unassignedItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Icon(
                Icons.celebration_rounded, // Fun icon
                size: 60,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'All Items Assigned!',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Everything\'s assigned, nothing to see here.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Column(
        children: [
          ...splitManager.unassignedItems.reversed.map((item) => UnassignedItemCard(item: item)).toList(),
        ],
      );
    }
  }

  Widget _buildTabItem({
    required BuildContext context,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required int index,
    required String label,
  }) {
    final bool isSelected = _selectedIndex == index;
    
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: textTheme.titleMedium?.copyWith(
            color: isSelected 
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

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
        content: StatefulBuilder( // Use StatefulBuilder for the counter
          builder: (context, setStateDialog) {
            // Wrap the Column in a Container to provide width constraints
            return Container(
              width: double.infinity, // Use available width
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
                      counterText: '', // Remove default counter
                    ),
                    maxLength: personMaxNameLength,
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    onChanged: (value) {
                      // Force rebuild to update counter
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
                splitManager.addPerson(newName);
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
                  // Name field
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
                  
                  // Price field
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
                  
                  // Quantity selector
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
          },
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
              // Validate and parse inputs
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              
              double? price = double.tryParse(priceController.text);
              if (price == null || price <= 0) return;
              
              // Create and add the new item
              final newItem = ReceiptItem(
                name: name,
                price: price,
                quantity: quantity,
              );
              
              splitManager.addUnassignedItem(newItem);
              Navigator.pop(context);
              
              // After adding, switch to the Unassigned tab
              setState(() {
                _selectedIndex = 2; // Index for Unassigned tab
              });
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
} 