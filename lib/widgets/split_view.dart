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
import '../theme/neumorphic_theme.dart';

// Import neumorphic widgets
import 'neumorphic/neumorphic_container.dart';
import 'neumorphic/neumorphic_text_field.dart';
import 'neumorphic/neumorphic_tabs.dart';

// Define a notification class to request navigation
class NavigateToPageNotification extends Notification {
  final int pageIndex;
  
  NavigateToPageNotification(this.pageIndex);
}

class SplitView extends StatefulWidget {
  final VoidCallback? onClose;

  const SplitView({
    super.key,
    this.onClose,
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
          // Check scrollability after setting the initial tab
          _checkScrollability();
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

  // Add method to check if current tab has scrollable content
  void _checkScrollability() {
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
    
    // Wait for the next frame to ensure controller is attached and has correct metrics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (activeController.hasClients) {
        final bool canScroll = activeController.position.maxScrollExtent > 0;
        
        // If can't scroll, always show FAB
        if (!canScroll && !_isFabVisible) {
          setState(() {
            _isFabVisible = true;
          });
        }
      }
    });
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
    
    // Only hide buttons if content is actually scrollable
    if (activeController.position.maxScrollExtent > 0) {
      final isScrollingDown = activeController.position.userScrollDirection == ScrollDirection.reverse;
      if (isScrollingDown != !_isFabVisible) {
        setState(() {
          _isFabVisible = !isScrollingDown;
        });
      }
    } else if (!_isFabVisible) {
      // If content is not scrollable, buttons should always be visible
      setState(() {
        _isFabVisible = true;
      });
    }
  }

  // Build the bottom fixed footer
  Widget _buildFixedFooter(SplitManager splitManager) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          NeumorphicIconButton(
            icon: Icons.person_add,
            backgroundColor: Colors.white,
            iconColor: NeumorphicTheme.slateBlue,
            size: 48,
            radius: 24,
            type: NeumorphicType.inset,
            onPressed: () => _showAddPersonDialog(context, splitManager),
          ),
          NeumorphicIconButton(
            icon: Icons.add_shopping_cart,
            backgroundColor: Colors.white,
            iconColor: NeumorphicTheme.slateBlue,
            size: 48,
            radius: 24,
            type: NeumorphicType.inset,
            onPressed: () => _showAddItemDialog(context, splitManager),
          ),
          NeumorphicIconButton(
            icon: Icons.check,
            backgroundColor: Colors.white,
            iconColor: NeumorphicTheme.slateBlue,
            size: 48,
            radius: 24,
            type: NeumorphicType.inset,
            onPressed: () {
              widget.onClose?.call();
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitManager>(
      builder: (context, splitManager, child) {
        // Calculate total values for the header
        final double individualTotal = splitManager.people.fold(0.0, (sum, person) => sum + person.totalAssignedAmount);
        final double sharedTotal = splitManager.sharedItemsTotal;
        final double assignedTotal = individualTotal + sharedTotal;
        final double unassignedTotal = splitManager.unassignedItemsTotal;
        final double subtotal = assignedTotal + unassignedTotal;

        // --- Warning widget logic --- 
        Widget? warningWidget;
        final originalTotal = splitManager.originalReviewTotal;
        final currentTotal = subtotal; // Current total in split view
        
        // Use higher precision comparison to account for floating point rounding differences
        final bool totalsMatch = originalTotal == null 
            ? currentTotal < 0.01 // Only consider a match if current is effectively zero
            : (currentTotal - originalTotal).abs() < 0.02; // Increased precision threshold to 0.02

        // Show warning if totals mismatch
        if (!totalsMatch) { 
          final Color warningColor = NeumorphicTheme.error.withOpacity(0.85);
          
          // Format values to match exactly what's shown in the UI
          final String currentTotalFormatted = currentTotal.toStringAsFixed(2);
          final String originalTotalFormatted = originalTotal?.toStringAsFixed(2) ?? 'N/A';
          
          warningWidget = Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0), 
            child: NeumorphicContainer(
              type: NeumorphicType.raised,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: warningColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.warning_amber_rounded, 
                      color: warningColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current sum (\$$currentTotalFormatted) ≠ subtotal (\$$originalTotalFormatted)',
                      style: NeumorphicTheme.secondaryText(
                        size: 13,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return Scaffold(
          backgroundColor: NeumorphicTheme.pageBackground,
          body: Stack(
            children: [
              Column(
                children: [
                  // Header with subtotal - Updated to match specs
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Subtotal: ',
                            style: NeumorphicTheme.primaryText(
                              size: 18.0,
                              weight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '\$${subtotal.toStringAsFixed(2)}',
                            style: NeumorphicTheme.primaryText(
                              size: 18.0, 
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _isSubtotalCollapsed = !_isSubtotalCollapsed),
                            child: Icon(
                              _isSubtotalCollapsed ? Icons.expand_more : Icons.expand_less,
                              color: NeumorphicTheme.slateBlue,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Dropdown overlay when expanded
                  if (!_isSubtotalCollapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: NeumorphicContainer(
                        type: NeumorphicType.raised,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Individual Items Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Individual Items: ',
                                  style: NeumorphicTheme.primaryText(size: 14),
                                ),
                                Text(
                                  '\$${individualTotal.toStringAsFixed(2)}',
                                  style: NeumorphicTheme.primaryText(
                                    size: 14,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Shared Items Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Shared Items: ',
                                  style: NeumorphicTheme.primaryText(size: 14),
                                ),
                                Text(
                                  '\$${sharedTotal.toStringAsFixed(2)}',
                                  style: NeumorphicTheme.primaryText(
                                    size: 14,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Unassigned Items Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Unassigned Items: ',
                                  style: NeumorphicTheme.primaryText(size: 14),
                                ),
                                Text(
                                  '\$${unassignedTotal.toStringAsFixed(2)}',
                                  style: NeumorphicTheme.primaryText(
                                    size: 14,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Subtotal row - with divider
                            Divider(height: 1, thickness: 1, color: NeumorphicTheme.mediumGrey.withOpacity(0.2)),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Assigned Total: ',
                                    style: NeumorphicTheme.primaryText(
                                      size: 14,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '\$${subtotal.toStringAsFixed(2)}',
                                    style: NeumorphicTheme.primaryText(
                                      size: 14,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Warning widget (if needed)
                  if (warningWidget != null) warningWidget,
                  
                  // Tabs with updated Neumorphic style
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                    child: NeumorphicTabs(
                      tabs: [
                        NeumorphicTabItem(label: 'People'),
                        NeumorphicTabItem(label: 'Shared'),
                        NeumorphicTabItem(label: 'Unassigned'),
                      ],
                      selectedIndex: _selectedIndex,
                      onTabSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                        _checkScrollability();
                      },
                      trackColor: const Color(0xFFE9ECEF),
                      selectedColor: NeumorphicTheme.slateBlue,
                      selectedTextColor: Colors.white,
                      unselectedTextColor: NeumorphicTheme.slateBlue,
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        // People tab
                        _buildScrollableList(
                          controller: _peopleScrollController,
                          itemCount: splitManager.people.length,
                          emptyText: 'No people added yet',
                          itemBuilder: (context, index) {
                            final person = splitManager.people[index];
                            return PersonCard(
                              key: ValueKey('person_card_${person.name}'),
                              person: person,
                            );
                          },
                        ),
                        
                        // Shared tab
                        _buildScrollableList(
                          controller: _sharedScrollController,
                          itemCount: splitManager.sharedItems.length,
                          emptyText: 'No shared items yet',
                          itemBuilder: (context, index) {
                            final item = splitManager.sharedItems[index];
                            return SharedItemCard(
                              key: ValueKey('shared_item_card_${item.itemId}'),
                              item: item,
                            );
                          },
                        ),
                        
                        // Unassigned tab
                        _buildScrollableList(
                          controller: _unassignedScrollController,
                          itemCount: splitManager.unassignedItems.length,
                          emptyText: 'No unassigned items',
                          itemBuilder: (context, index) {
                            final item = splitManager.unassignedItems[index];
                            return UnassignedItemCard(
                              key: ValueKey('unassigned_item_card_${item.itemId}'),
                              item: item,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Replace floating action buttons with fixed footer
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildFixedFooter(splitManager),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Helper method to build a list with scrolling
  Widget _buildScrollableList({
    required ScrollController controller,
    required int itemCount,
    required String emptyText,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    return itemCount > 0
      ? ListView.builder(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Extra bottom padding for fixed footer
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        )
      : Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline,
                size: 48,
                color: NeumorphicTheme.mediumGrey,
              ),
              const SizedBox(height: 16),
              Text(
                emptyText,
                style: NeumorphicTheme.secondaryText(size: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
  }
  
  // Show add person dialog
  void _showAddPersonDialog(BuildContext context, SplitManager splitManager) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: NeumorphicContainer(
          type: NeumorphicType.raised,
          radius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_add, 
                    color: NeumorphicTheme.slateBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Person', 
                    style: NeumorphicTheme.primaryText(
                      size: 18, 
                      weight: FontWeight.w600
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              NeumorphicTextField(
                controller: controller,
                labelText: 'Name',
                maxLength: personMaxNameLength,
                prefixIcon: Icon(
                  Icons.person_outline, 
                  color: NeumorphicTheme.slateBlue,
                  size: 18,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: NeumorphicTheme.mutedRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  NeumorphicContainer(
                    type: NeumorphicType.raised,
                    color: NeumorphicTheme.slateBlue,
                    radius: 8,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    onTap: () {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        splitManager.addPerson(name);
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      'Add',
                      style: NeumorphicTheme.onAccentText(weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) => controller.dispose());
  }
  
  // Show add item dialog
  void _showAddItemDialog(BuildContext context, SplitManager splitManager) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: NeumorphicContainer(
                type: NeumorphicType.raised,
                radius: 16,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.add_shopping_cart, 
                          color: NeumorphicTheme.slateBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Add Item', 
                          style: NeumorphicTheme.primaryText(
                            size: 18, 
                            weight: FontWeight.w600
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Name field
                    NeumorphicTextField(
                      controller: nameController,
                      labelText: 'Item Name',
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    
                    // Price field
                    NeumorphicTextField(
                      controller: priceController,
                      labelText: 'Price',
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      prefixText: '\$',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Quantity selector
                    Text(
                      'Quantity:',
                      style: NeumorphicTheme.primaryText(size: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        NeumorphicIconButton(
                          icon: Icons.remove,
                          backgroundColor: Colors.white,
                          size: 36,
                          radius: 18,
                          iconSize: 18,
                          iconColor: quantity > 1 
                            ? NeumorphicTheme.slateBlue 
                            : NeumorphicTheme.mediumGrey.withOpacity(0.5),
                          onPressed: quantity > 1 
                            ? () => setStateDialog(() => quantity--) 
                            : () {},
                        ),
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: Text(
                            '$quantity',
                            style: NeumorphicTheme.primaryText(
                              size: 18,
                              weight: FontWeight.bold,
                            ),
                          ),
                        ),
                        NeumorphicIconButton(
                          icon: Icons.add,
                          backgroundColor: Colors.white,
                          size: 36,
                          radius: 18,
                          iconSize: 18,
                          iconColor: NeumorphicTheme.slateBlue,
                          onPressed: () => setStateDialog(() => quantity++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: NeumorphicTheme.mutedRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        NeumorphicContainer(
                          type: NeumorphicType.raised,
                          color: NeumorphicTheme.slateBlue,
                          radius: 8,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          onTap: () {
                            // Validate and parse inputs
                            final itemName = nameController.text.trim();
                            if (itemName.isEmpty) return;
                            
                            double? price = double.tryParse(priceController.text);
                            if (price == null || price <= 0) return;
                            
                            // Create and add the new item
                            final newItem = ReceiptItem(
                              name: itemName,
                              price: price,
                              quantity: quantity,
                            );
                            splitManager.addUnassignedItem(newItem);
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Add',
                            style: NeumorphicTheme.onAccentText(weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      nameController.dispose();
      priceController.dispose();
    });
  }
  
  // Show edit person dialog
  void _showEditPersonDialog(BuildContext context, SplitManager splitManager, Person person) {
    final controller = TextEditingController(text: person.name);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: NeumorphicContainer(
          type: NeumorphicType.raised,
          radius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit, 
                    color: NeumorphicTheme.slateBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Person', 
                    style: NeumorphicTheme.primaryText(
                      size: 18, 
                      weight: FontWeight.w600
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              NeumorphicTextField(
                controller: controller,
                labelText: 'Name',
                maxLength: personMaxNameLength,
                prefixIcon: Icon(
                  Icons.person_outline, 
                  color: NeumorphicTheme.slateBlue,
                  size: 18,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: NeumorphicTheme.mutedRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  NeumorphicContainer(
                    type: NeumorphicType.raised,
                    color: NeumorphicTheme.slateBlue,
                    radius: 8,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    onTap: () {
                      final newName = controller.text.trim();
                      if (newName.isNotEmpty && newName != person.name) {
                        splitManager.updatePersonName(person, newName);
                        Navigator.of(context).pop();
                      } else if (newName.isEmpty) {
                        // Show error or handle empty name case
                      } else {
                        // Name unchanged, just close dialog
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      'Save',
                      style: NeumorphicTheme.onAccentText(weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) => controller.dispose());
  }
} 