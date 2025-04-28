import 'package:flutter/material.dart';
import '../models/receipt_item.dart';
import '../widgets/receipt_review/subtotal_header.dart'; // Import the header
import '../widgets/receipt_review/receipt_item_card.dart'; // Import the new card
import '../widgets/dialogs/add_item_dialog.dart'; // Import Add dialog
import '../widgets/dialogs/edit_item_dialog.dart'; // Import Edit dialog

class ReceiptReviewScreen extends StatefulWidget {
  final List<ReceiptItem> initialItems;
  final Function(List<ReceiptItem> updatedItems, List<ReceiptItem> deletedItems) onReviewComplete;
  // Optional: Callback for immediate updates if needed later
  // final Function(List<ReceiptItem> currentItems) onItemsUpdated;

  const ReceiptReviewScreen({
    super.key,
    required this.initialItems,
    required this.onReviewComplete,
    // this.onItemsUpdated,
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
  }

  void _addItem() async {
    final newItem = await showAddItemDialog(context);
    if (newItem != null) {
      setState(() {
        _editableItems.add(newItem);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${newItem.name} to the receipt'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          showCloseIcon: true,
        ),
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
    }
  }

  void _removeItem(int index) {
    final itemToRemove = _editableItems[index];
    setState(() {
      _deletedItems.add(itemToRemove);
      _editableItems.removeAt(index);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${itemToRemove.name} moved to deleted items'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            setState(() {
              _editableItems.insert(index, itemToRemove);
              _deletedItems.remove(itemToRemove);
            });
          },
        ),
      ),
    );
  }

  void _restoreItem(int deletedIndex) {
     final itemToRestore = _deletedItems[deletedIndex];
     setState(() {
       _editableItems.add(itemToRestore);
       _deletedItems.removeAt(deletedIndex);
     });
   }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        CustomScrollView(
          controller: _itemsScrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: SubtotalHeaderDelegate( // Use the extracted delegate
                minHeight: 60,
                maxHeight: 120,
                isCollapsed: _isSubtotalCollapsed,
                subtotal: _calculateSubtotal(),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Text(
                    'Items (${_editableItems.length})',
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
                  ),
                ),
              ),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _editableItems[index];
                  return ReceiptItemCard(
                    key: ValueKey(item.hashCode), // Use a unique key for animations
                    item: item,
                    index: index,
                    onEdit: _editItem,
                    onDelete: _removeItem,
                    onQuantityChanged: _updateItemQuantity, // Pass the new handler
                  );
                },
                childCount: _editableItems.length,
              ),
            ),

            if (_deletedItems.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_outlined, color: colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Deleted Items (${_deletedItems.length})',
                          style: textTheme.titleMedium?.copyWith(color: colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _deletedItems[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        title: Text(
                          item.name,
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          '${item.quantity}x \$${item.price.toStringAsFixed(2)} each',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                             decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        trailing: TextButton.icon(
                          icon: const Icon(Icons.restore_from_trash, size: 18),
                          label: const Text('Restore'),
                          onPressed: () => _restoreItem(index),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _deletedItems.length,
                ),
              ),
            ],

            // Bottom padding to ensure last items are fully visible below buttons
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        // Bottom buttons
        Positioned(
          left: 16,
          right: 16,
          bottom: 16, // Adjust position if needed
          child: Row(
            children: [
              // FAB for adding items
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isFabVisible ? 1.0 : 0.0,
                child: FloatingActionButton(
                  onPressed: _isFabVisible ? _addItem : null, // Use the extracted add dialog
                  heroTag: 'addItemFab', // Add unique hero tag
                  child: const Icon(Icons.playlist_add),
                  tooltip: 'Add Item',
                ),
              ),
              const SizedBox(width: 16),
              // Confirmation button
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isContinueButtonVisible ? 1.0 : 0.0,
                  child: SizedBox(
                    height: 56.0,
                    child: ElevatedButton.icon(
                      onPressed: _isContinueButtonVisible
                          ? () => widget.onReviewComplete(_editableItems, _deletedItems)
                          : null,
                      icon: Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: colorScheme.onPrimary,
                      ),
                      label: Text(
                        'Confirm Items & Continue',
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 