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

// Import neumorphic widgets
import 'neumorphic/neumorphic_container.dart';
import 'neumorphic/neumorphic_text_field.dart';

/// Utility class for Neumorphic styling
class NeumorphicStyles {
  // Colors
  static const Color pageBackground = Color(0xFFF5F5F7);
  static const Color cardBackground = Colors.white;
  static const Color slateBlue = Color(0xFF5D737E);
  static const Color mutedCoral = Color(0xFFFFB59E);
  static const Color darkGrey = Color(0xFF1D1D1F);
  static const Color mediumGrey = Color(0xFF8A8A8E);
  static const Color mutedRed = Color(0xFFE57373);
  
  // Text styles
  static TextStyle primaryText({
    double size = 16.0,
    FontWeight weight = FontWeight.normal,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: darkGrey,
    );
  }
  
  static TextStyle secondaryText({
    double size = 14.0,
    FontWeight weight = FontWeight.normal,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: mediumGrey,
    );
  }
  
  static TextStyle onAccentText({
    double size = 14.0,
    FontWeight weight = FontWeight.normal,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: Colors.white,
    );
  }
}

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
          final Color warningColor = AppColors.error.withOpacity(0.85);
          
          // Format values to match exactly what's shown in the UI
          final String currentTotalFormatted = currentTotal.toStringAsFixed(2);
          final String originalTotalFormatted = originalTotal?.toStringAsFixed(2) ?? 'N/A';
          
          warningWidget = Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0), 
            child: NeumorphicContainer(
              type: NeumorphicType.raised,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: warningColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.warning_amber_rounded, 
                      color: warningColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Warning: Current item sum in split (\$$currentTotalFormatted) doesn\'t match reviewed subtotal (\$$originalTotalFormatted).',
                      style: NeumorphicStyles.primaryText(
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
          backgroundColor: NeumorphicStyles.pageBackground,
          body: Stack(
            children: [
              Column(
                children: [
                  // Header with subtotal
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Subtotal: ',
                          style: NeumorphicStyles.primaryText(
                            size: 18.0,
                            weight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '\$${subtotal.toStringAsFixed(2)}',
                          style: NeumorphicStyles.primaryText(
                            size: 18.0, 
                            weight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isSubtotalCollapsed ? Icons.expand_more : Icons.expand_less, 
                            color: AppColors.slateBlue,
                          ),
                          onPressed: () => setState(() => _isSubtotalCollapsed = !_isSubtotalCollapsed),
                          tooltip: _isSubtotalCollapsed ? 'Show details' : 'Hide details',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 24,
                        ),
                      ],
                    ),
                  ),
                  
                  // Expanded subtotal section (conditionally shown)
                  if (!_isSubtotalCollapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: NeumorphicContainer(
                        type: NeumorphicType.raised,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Individual Items Total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Individual Items: ',
                                  style: NeumorphicStyles.primaryText(),
                                ),
                                Text(
                                  '\$${individualTotal.toStringAsFixed(2)}',
                                  style: NeumorphicStyles.primaryText(
                                    weight: FontWeight.bold,
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
                                  style: NeumorphicStyles.primaryText(),
                                ),
                                Text(
                                  '\$${sharedTotal.toStringAsFixed(2)}',
                                  style: NeumorphicStyles.primaryText(
                                    weight: FontWeight.bold,
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
                                  style: NeumorphicStyles.primaryText(),
                                ),
                                Text(
                                  '\$${assignedTotal.toStringAsFixed(2)}',
                                  style: NeumorphicStyles.primaryText(
                                    weight: FontWeight.bold,
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
                                  style: NeumorphicStyles.primaryText(),
                                ),
                                Text(
                                  '\$${unassignedTotal.toStringAsFixed(2)}',
                                  style: NeumorphicStyles.primaryText(
                                    weight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Subtotal row - always visible and more prominent
                            Divider(height: 1, thickness: 1, color: NeumorphicStyles.mediumGrey.withOpacity(0.3)),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Subtotal: ',
                                    style: NeumorphicStyles.primaryText(
                                      size: 16,
                                      weight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\$${subtotal.toStringAsFixed(2)}',
                                    style: NeumorphicStyles.primaryText(
                                      size: 16,
                                      weight: FontWeight.bold,
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
                  
                  // Tabs
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: NeumorphicStyles.pageBackground,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            offset: const Offset(-2, -2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabItem(
                                index: 0,
                                label: 'People',
                              ),
                            ),
                            Expanded(
                              child: _buildTabItem(
                                index: 1,
                                label: 'Shared',
                              ),
                            ),
                            Expanded(
                              child: _buildTabItem(
                                index: 2,
                                label: 'Unassigned',
                              ),
                            ),
                          ],
                        ),
                      ),
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
              
              // Add Person / Add Item floating action buttons
              if (_isFabVisible)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      NeumorphicIconButton(
                        icon: Icons.person_add,
                        backgroundColor: AppColors.slateBlue,
                        iconColor: Colors.white,
                        size: 56,
                        radius: 28,
                        onPressed: () => _showAddPersonDialog(context, splitManager),
                      ),
                      const SizedBox(width: 16),
                      NeumorphicIconButton(
                        icon: Icons.add_shopping_cart,
                        backgroundColor: AppColors.slateBlue,
                        iconColor: Colors.white,
                        size: 56,
                        radius: 28,
                        onPressed: () => _showAddItemDialog(context, splitManager),
                      ),
                      const SizedBox(width: 16),
                      NeumorphicIconButton(
                        icon: Icons.check,
                        backgroundColor: AppColors.slateBlue,
                        iconColor: Colors.white,
                        size: 56,
                        radius: 28,
                        onPressed: () {
                          widget.onClose?.call();
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), // Extra bottom padding for FAB
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
                color: NeumorphicStyles.mediumGrey,
              ),
              const SizedBox(height: 16),
              Text(
                emptyText,
                style: NeumorphicStyles.secondaryText(size: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
  }
  
  // Building a tab item with neumorphic design
  Widget _buildTabItem({
    required int index,
    required String label,
  }) {
    final bool isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        _checkScrollability();
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.slateBlue : NeumorphicStyles.pageBackground,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected 
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.7),
                  offset: const Offset(-2, -2),
                  blurRadius: 4,
                ),
              ]
            : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: isSelected
            ? NeumorphicStyles.onAccentText(
                weight: FontWeight.w500,
              )
            : NeumorphicStyles.primaryText(
                weight: FontWeight.w500,
              ),
        ),
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
                    color: NeumorphicStyles.slateBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Person', 
                    style: NeumorphicStyles.primaryText(
                      size: 18, 
                      weight: FontWeight.w600
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              NeumorphicTextField(
                controller: controller,
                labelText: 'Name',
                hintText: 'Enter person\'s name',
                prefixIcon: Icon(
                  Icons.person_outline, 
                  color: NeumorphicStyles.slateBlue,
                  size: 18,
                ),
                maxLength: personMaxNameLength,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: NeumorphicStyles.mutedRed,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  NeumorphicButton(
                    color: NeumorphicStyles.slateBlue,
                    radius: 8,
                    onPressed: () {
                      final newName = controller.text.trim();
                      if (newName.isNotEmpty && newName.length <= personMaxNameLength) {
                        splitManager.addPerson(newName);
                        Navigator.pop(context);
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check, 
                          color: Colors.white, 
                          size: 18
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add',
                          style: NeumorphicStyles.onAccentText(
                            size: 15, 
                            weight: FontWeight.w500
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Show add item dialog
  void _showAddItemDialog(BuildContext context, SplitManager splitManager) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    int quantity = 1;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateDialog) {
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
                        color: NeumorphicStyles.slateBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Add Item', 
                        style: NeumorphicStyles.primaryText(
                          size: 18, 
                          weight: FontWeight.w600
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Item Name field
                  NeumorphicTextField(
                    controller: nameController,
                    labelText: 'Item Name',
                    hintText: 'Enter item name',
                    textCapitalization: TextCapitalization.sentences,
                    autofocus: true,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Price field
                  NeumorphicTextField(
                    controller: priceController,
                    labelText: 'Price',
                    hintText: 'Enter price',
                    prefixText: '\$',
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
                      Text(
                        'Quantity:', 
                        style: NeumorphicStyles.primaryText(
                          weight: FontWeight.w500
                        )
                      ),
                      Row(
                        children: [
                          NeumorphicIconButton(
                            icon: Icons.remove,
                            type: NeumorphicType.inset,
                            size: 36,
                            radius: 18,
                            iconSize: 18,
                            iconColor: quantity > 1 
                              ? NeumorphicStyles.slateBlue 
                              : NeumorphicStyles.mediumGrey.withOpacity(0.5),
                            onPressed: quantity > 1 
                              ? () => setStateDialog(() => quantity--) 
                              : null,
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              quantity.toString(),
                              style: NeumorphicStyles.primaryText(
                                weight: FontWeight.bold,
                              ),
                            ),
                          ),
                          NeumorphicIconButton(
                            icon: Icons.add,
                            type: NeumorphicType.inset,
                            size: 36,
                            radius: 18,
                            iconSize: 18,
                            iconColor: NeumorphicStyles.slateBlue,
                            onPressed: () => setStateDialog(() => quantity++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: NeumorphicStyles.mutedRed,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      NeumorphicButton(
                        color: NeumorphicStyles.slateBlue,
                        radius: 8,
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check, 
                              color: Colors.white, 
                              size: 18
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add',
                              style: NeumorphicStyles.onAccentText(
                                size: 15, 
                                weight: FontWeight.w500
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  // Show edit person name dialog
  void _showEditPersonNameDialog(BuildContext context, SplitManager splitManager, Person person) {
    final controller = TextEditingController(text: person.name);
    
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
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
                    color: AppColors.slateBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Name', 
                    style: NeumorphicStyles.primaryText(
                      size: 18, 
                      weight: FontWeight.w600
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              NeumorphicTextField(
                controller: controller,
                labelText: 'Name',
                hintText: 'Enter name',
                prefixIcon: Icon(
                  Icons.person_outline, 
                  color: AppColors.slateBlue,
                  size: 18,
                ),
                maxLength: personMaxNameLength,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.slateBlue),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      final newName = controller.text.trim();
                      if (newName.isNotEmpty) {
                        splitManager.updatePersonName(person, newName);
                      }
                      Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slateBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Show edit shared item dialog
  void _showEditSharedItemDialog(BuildContext context, ReceiptItem item, SplitManager splitManager) {
    // Implementation omitted for brevity
  }
  
  // Show edit unassigned item dialog
  void _showEditUnassignedItemDialog(BuildContext context, ReceiptItem item, SplitManager splitManager) {
    // Implementation omitted for brevity
  }
} 