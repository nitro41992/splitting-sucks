import 'package:flutter/material.dart';
import '../models/receipt_item.dart';
import '../widgets/receipt_review/subtotal_header.dart'; // Import the header
import '../widgets/receipt_review/receipt_item_card.dart'; // Import the new card
import '../widgets/dialogs/add_item_dialog.dart'; // Import Add dialog
import '../widgets/dialogs/edit_item_dialog.dart'; // Import Edit dialog
import '../utils/platform_config.dart'; // Import platform config
import '../utils/toast_helper.dart'; // Import toast helper
import '../widgets/workflow_modal.dart' show GetCurrentItemsCallback; 

class ReceiptReviewScreen extends StatefulWidget {
  final List<ReceiptItem> initialItems;
  final Function(List<ReceiptItem> updatedItems, List<ReceiptItem> deletedItems) onReviewComplete;
  // Callback for immediate updates when items change
  final Function(List<ReceiptItem> currentItems)? onItemsUpdated;
  final Function(GetCurrentItemsCallback)? registerCurrentItemsGetter;
  final VoidCallback? onClose;

  const ReceiptReviewScreen({
    super.key,
    required this.initialItems,
    required this.onReviewComplete,
    this.onItemsUpdated,
    this.registerCurrentItemsGetter,
    this.onClose,
  });

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late List<ReceiptItem> _editableItems;
  late List<ReceiptItem> _deletedItems;
  // Price controllers are managed internally by the items now, not needed here
  late ScrollController _itemsScrollController;

  bool _isFabVisible = true;
  bool _isContinueButtonVisible = true;
  double _lastScrollPosition = 0;
  bool _isSubtotalCollapsed = false; // Start expanded

  @override
  void initState() {
    super.initState();
    // Create deep copies to avoid modifying the original list directly
    _editableItems = widget.initialItems.map((item) => ReceiptItem.clone(item)).toList();
    _deletedItems = [];
    _itemsScrollController = ScrollController();
    _itemsScrollController.addListener(_onScroll);

    // --- Register the getter function with the parent --- 
    if (widget.registerCurrentItemsGetter != null) {
      widget.registerCurrentItemsGetter!(() => _editableItems); 
      debugPrint('[ReceiptReviewScreen] Registered getCurrentItems callback.');
    }
    // -----------------------------------------------------
  }

  @override
  void dispose() {
    _itemsScrollController.removeListener(_onScroll);
    _itemsScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_itemsScrollController.hasClients) return;
    final currentPosition = _itemsScrollController.position.pixels;
    final isScrollingDown = currentPosition > _lastScrollPosition;

    // Update subtotal collapse state based on scroll position
    final shouldCollapse = currentPosition > 50;
    if (shouldCollapse != _isSubtotalCollapsed) {
      setState(() {
        _isSubtotalCollapsed = shouldCollapse;
      });
    }

    // Update button visibility based on scroll direction
    final scrollThreshold = 5.0;
    if ((currentPosition - _lastScrollPosition).abs() > scrollThreshold) {
      setState(() {
        _isFabVisible = !isScrollingDown;
        _isContinueButtonVisible = !isScrollingDown;
      });
    }

    _lastScrollPosition = currentPosition;
  }

  double _calculateSubtotal() {
    double total = 0.0;
    for (var item in _editableItems) {
      total += item.price * item.quantity;
    }
    return total;
  }

  void _updateItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) return; // Prevent quantity from going below 1
    setState(() {
      _editableItems[index].updateQuantity(newQuantity);
    });
    
    // Notify parent if callback is provided
    if (widget.onItemsUpdated != null) {
      widget.onItemsUpdated!(_editableItems);
    }
  }

  void _addItem() async {
    final newItem = await showAddItemDialog(context);
    if (newItem != null) {
      setState(() {
        _editableItems.add(newItem);
      });
      
      // Notify parent if callback is provided
      if (widget.onItemsUpdated != null) {
        widget.onItemsUpdated!(_editableItems);
      }
      
      ToastHelper.showToast(
        context,
        'Added ${newItem.name} to the receipt',
        isSuccess: true
      );
    }
  }

  void _editItem(ReceiptItem item, int index) async {
    final result = await showEditItemDialog(context, item);
    if (result != null) {
      setState(() {
        _editableItems[index].updateName(result.name);
        _editableItems[index].updatePrice(result.price);
        // Quantity is handled separately by the card now
      });
      
      // Notify parent if callback is provided
      if (widget.onItemsUpdated != null) {
        widget.onItemsUpdated!(_editableItems);
      }
    }
  }

  void _removeItem(int index) {
    final itemToRemove = _editableItems[index];
    setState(() {
      _deletedItems.add(itemToRemove);
      _editableItems.removeAt(index);
    });
    
    // Notify parent if callback is provided
    if (widget.onItemsUpdated != null) {
      widget.onItemsUpdated!(_editableItems);
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ToastHelper.showToast(
      context,
      '${itemToRemove.name} moved to deleted items',
      isSuccess: false
    );
    
    // Show the undo action as a separate button-focused toast
    final undoOverlay = Overlay.of(context);
    final mediaQuery = MediaQuery.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    
    late final OverlayEntry undoEntry;
    
    undoEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 16,
        right: 16,
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.primaryContainer,
          child: InkWell(
            onTap: () {
              setState(() {
                _editableItems.insert(index, itemToRemove);
                _deletedItems.remove(itemToRemove);
              });
              
              // Notify parent on undo if callback is provided
              if (widget.onItemsUpdated != null) {
                widget.onItemsUpdated!(_editableItems);
              }
              
              undoEntry.remove();
              
              ToastHelper.showToast(
                context,
                'Item restored',
                isSuccess: true
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Icon(Icons.undo, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text(
                    'UNDO',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    undoOverlay.insert(undoEntry);
    Future.delayed(const Duration(seconds: 4), () {
      if (undoEntry.mounted) {
        undoEntry.remove();
      }
    });
  }

  void _restoreItem(int deletedIndex) {
     final itemToRestore = _deletedItems[deletedIndex];
     setState(() {
       _editableItems.add(itemToRestore);
       _deletedItems.removeAt(deletedIndex);
     });
     
     // Notify parent if callback is provided
     if (widget.onItemsUpdated != null) {
       widget.onItemsUpdated!(_editableItems);
     }
   }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Light grey background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7), // Match page background
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(2, 2),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 8,
                offset: const Offset(-2, -2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF5D737E)),
            onPressed: widget.onClose,
          ),
        ),
        title: Text(
          'Edit Receipt Items',
          style: const TextStyle(
            color: Color(0xFF1D1D1F),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _itemsScrollController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: SubtotalHeaderDelegate(
                  minHeight: 60,
                  maxHeight: 100,
                  isCollapsed: _isSubtotalCollapsed,
                  subtotal: _calculateSubtotal(),
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  // Pass the neumorphic design details
                  useNeumorphicStyle: true,
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFF1D1D1F),
                  accentColor: const Color(0xFF5D737E),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(
                        Icons.list, 
                        size: 20, 
                        color: const Color(0xFF5D737E),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Items (${_editableItems.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5D737E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _editableItems[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Item name with edit icon
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _editItem(item, index),
                                      child: Row(
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontSize: 16, 
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1D1D1F),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: Color(0xFF5D737E),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Delete icon
                                  IconButton(
                                    onPressed: () => _removeItem(index),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // Price and quantity controls row
                              Row(
                                children: [
                                  // Price text
                                  Text(
                                    '\$${item.price.toStringAsFixed(2)} each',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF8A8A8E),
                                    ),
                                  ),
                                  const Spacer(),
                                  
                                  // Quantity controls
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Minus button
                                        InkWell(
                                          onTap: item.quantity > 1 
                                            ? () => _updateItemQuantity(index, item.quantity - 1) 
                                            : null,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.remove,
                                              size: 16,
                                              color: item.quantity > 1
                                                ? const Color(0xFF5D737E)
                                                : const Color(0xFF8A8A8E).withOpacity(0.5),
                                            ),
                                          ),
                                        ),
                                        
                                        // Quantity display
                                        Container(
                                          width: 40,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1D1D1F),
                                            ),
                                          ),
                                        ),
                                        
                                        // Plus button
                                        InkWell(
                                          onTap: () => _updateItemQuantity(index, item.quantity + 1),
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(
                                              Icons.add,
                                              size: 16,
                                              color: Color(0xFF5D737E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 12),
                                  
                                  // Total price pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5D737E),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _editableItems.length,
                ),
              ),

              if (_deletedItems.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_outlined, color: Colors.red.shade400, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Deleted Items (${_deletedItems.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _deletedItems[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF8A8A8E),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            subtitle: Text(
                              '${item.quantity}x \$${item.price.toStringAsFixed(2)} each',
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(0xFF8A8A8E).withOpacity(0.7),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: TextButton.icon(
                                icon: const Icon(Icons.restore_from_trash, size: 16),
                                label: const Text('Restore'),
                                onPressed: () => _restoreItem(index),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF5D737E),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _deletedItems.length,
                  ),
                ),
              ],

              // Bottom padding to ensure last items are fully visible
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          
          // Bottom action bar with neumorphic styling
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  // Add Item button
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.9),
                            blurRadius: 6,
                            offset: const Offset(-2, -2),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _addItem,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_circle_outline,
                                  color: Color(0xFF5D737E),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add Item',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF5D737E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Done button
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF5D737E),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _editableItems.isNotEmpty
                            ? () => widget.onReviewComplete(_editableItems, _deletedItems)
                            : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
} 