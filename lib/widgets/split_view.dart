import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../models/split_manager.dart';
import '../models/person.dart';
import '../models/receipt_item.dart';

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

  @override
  void initState() {
    super.initState();
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
              child: FloatingActionButton(
                onPressed: () => _showAddPersonDialog(context, splitManager),
                child: const Icon(Icons.person_add),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
      children: [
        builder(context),
      ],
    );
  }

  Widget _buildPeopleList(BuildContext context, SplitManager splitManager) {
    return Column(
      children: splitManager.people.map((person) => _PersonCard(person: person)).toList(),
    );
  }

  Widget _buildSharedItemsList(BuildContext context, SplitManager splitManager) {
    return Column(
      children: splitManager.sharedItems.map((item) => _SharedItemCard(item: item)).toList(),
    );
  }

  Widget _buildUnassignedItemsList(BuildContext context, SplitManager splitManager) {
    return Column(
      children: splitManager.unassignedItems.map((item) => _UnassignedItemCard(item: item)).toList(),
    );
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
        content: Column(
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
                counterText: '${controller.text.length}/${_PersonCard.maxNameLength}',
              ),
              maxLength: _PersonCard.maxNameLength,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              onChanged: (value) {
                // Force rebuild to update counter
                (context as Element).markNeedsBuild();
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Maximum ${_PersonCard.maxNameLength} characters',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
              if (newName.isNotEmpty && newName.length <= _PersonCard.maxNameLength) {
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
}

class _PersonCard extends StatelessWidget {
  final Person person;
  static const int maxNameLength = 9;

  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Text(
                    person.name[0],
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              person.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showEditNameDialog(context, person),
                            icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
                              padding: const EdgeInsets.all(8),
                              visualDensity: VisualDensity.compact,
                            ),
                            tooltip: 'Edit name',
                          ),
                        ],
                      ),
                      if (person.assignedItems.isNotEmpty)
                        Text(
                          '${person.assignedItems.length} items',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '\$${person.totalAssignedAmount.toStringAsFixed(2)}',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (person.assignedItems.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: person.assignedItems.map((item) => _ItemRow(item: item)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, Person person) {
    final controller = TextEditingController(text: person.name);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Edit Name'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Enter name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '${controller.text.length}/$maxNameLength',
              ),
              style: textTheme.bodyLarge,
              textCapitalization: TextCapitalization.words,
              maxLength: maxNameLength,
              autofocus: true,
              onChanged: (value) {
                // Force rebuild to update counter
                (context as Element).markNeedsBuild();
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Maximum $maxNameLength characters',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
              if (newName.isNotEmpty && newName.length <= maxNameLength) {
                context.read<SplitManager>().updatePersonName(person, newName);
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Save'),
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

class _UnassignedItemCard extends StatelessWidget {
  final ReceiptItem item;

  const _UnassignedItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.watch<SplitManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: ${item.quantity}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _EditablePrice(
                      price: item.price,
                      onChanged: (newPrice) => item.updatePrice(newPrice),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: \$${item.total.toStringAsFixed(2)}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _showAssignDialog(context, splitManager, item),
              icon: const Icon(Icons.person_add),
              label: const Text('Assign Item'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose how to assign this item:'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('To Person'),
                  onPressed: () {
                    Navigator.pop(context);
                    _showAssignToPersonDialog(context, splitManager, item);
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.group),
                  label: const Text('Share'),
                  onPressed: () {
                    Navigator.pop(context);
                    _showShareDialog(context, splitManager, item);
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAssignToPersonDialog(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    // Create a stateful value to track the quantity
    int selectedQuantity = item.quantity;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Assign to Person'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quantity selector that matches the app's design
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Quantity: '),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle),
                        onPressed: selectedQuantity > 0 ? () {
                          setState(() {
                            selectedQuantity--;
                          });
                        } : null,
                      ),
                      SizedBox(
                        width: 24,
                        child: Text(
                          selectedQuantity.toString(),
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: selectedQuantity < item.quantity ? () {
                          setState(() {
                            selectedQuantity++;
                          });
                        } : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: splitManager.people.length,
                      itemBuilder: (context, index) {
                        final person = splitManager.people[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text(person.name[0])),
                          title: Text(person.name),
                          onTap: () {
                            if (selectedQuantity <= 0 || selectedQuantity > item.quantity) return;
                            
                            // Create a new item with the specified quantity
                            final newItem = ReceiptItem(
                              name: item.name,
                              price: item.price,
                              quantity: selectedQuantity,
                            );
                            
                            // First assign the new item
                            splitManager.assignItemToPerson(newItem, person);
                            
                            // Then handle the source item's quantity reduction
                            if (selectedQuantity >= item.quantity) {
                              splitManager.removeUnassignedItem(item);
                            } else {
                              item.updateQuantity(item.quantity - selectedQuantity);
                            }
                            
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showShareDialog(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    // Create a stateful value to track the quantity
    int selectedQuantity = item.quantity;
    final List<Person> selectedPeople = [];
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Share Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quantity selector that matches the app's design
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Quantity: '),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle),
                          onPressed: selectedQuantity > 0 ? () {
                            setState(() {
                              selectedQuantity--;
                            });
                          } : null,
                        ),
                        SizedBox(
                          width: 24,
                          child: Text(
                            selectedQuantity.toString(),
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: selectedQuantity < item.quantity ? () {
                            setState(() {
                              selectedQuantity++;
                            });
                          } : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Select people to share with:'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      width: double.maxFinite,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: splitManager.people.map((person) {
                          final isSelected = selectedPeople.contains(person);
                          return FilterChip(
                            label: Text(person.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  selectedPeople.add(person);
                                } else {
                                  selectedPeople.remove(person);
                                }
                              });
                            },
                            selectedColor: Theme.of(context).colorScheme.primaryContainer,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedPeople.isEmpty ? null : () {
                    if (selectedQuantity <= 0 || selectedQuantity > item.quantity) return;
                    
                    // Create a new item with the specified quantity
                    final newItem = ReceiptItem(
                      name: item.name,
                      price: item.price,
                      quantity: selectedQuantity,
                    );
                    
                    // First add the item to shared section
                    splitManager.addItemToShared(newItem, selectedPeople);
                    
                    // Then handle the source item's quantity reduction
                    if (selectedQuantity >= item.quantity) {
                      splitManager.removeUnassignedItem(item);
                    } else {
                      item.updateQuantity(item.quantity - selectedQuantity);
                    }
                    
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Share'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SharedItemCard extends StatelessWidget {
  final ReceiptItem item;

  const _SharedItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.watch<SplitManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final people = splitManager.people;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Qty: ${item.quantity}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _QuantitySelector(
                            item: item,
                            onChanged: (newQuantity) => splitManager.updateItemQuantity(item, newQuantity),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _EditablePrice(
                      price: item.price,
                      onChanged: (newPrice) => item.updatePrice(newPrice),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: \$${item.total.toStringAsFixed(2)}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Shared with:',
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: people.map((person) {
                final isSelected = person.sharedItems.contains(item);

                return FilterChip(
                  label: Text(person.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      splitManager.addPersonToSharedItem(item, person);
                    } else {
                      splitManager.removePersonFromSharedItem(item, person);

                      final remainingSharers = splitManager.people
                          .where((p) => p.sharedItems.contains(item))
                          .toList();

                      if (remainingSharers.isEmpty) {
                        splitManager.removeItemFromShared(item);
                        splitManager.addUnassignedItem(item);
                      }
                    }
                  },
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.outlineVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ReceiptItem item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.watch<SplitManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _EditablePrice(
            price: item.price,
            onChanged: (newPrice) => item.updatePrice(newPrice),
          ),
          const SizedBox(width: 16),
          _QuantitySelector(
            item: item,
            onChanged: (newQuantity) => splitManager.updateItemQuantity(item, newQuantity),
          ),
        ],
      ),
    );
  }
}

class _EditableText extends StatelessWidget {
  final String text;
  final ValueChanged<String> onChanged;
  final TextStyle? style;

  const _EditableText({
    required this.text,
    required this.onChanged,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: () => _showEditDialog(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: style ?? Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Icon(
            Icons.edit_outlined,
            size: 16,
            color: colorScheme.primary.withOpacity(0.8),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: text);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Edit Name'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: 'Enter name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          style: textTheme.bodyLarge,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
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
              if (controller.text.trim().isNotEmpty) {
                onChanged(controller.text.trim());
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Save'),
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

class _EditablePrice extends StatelessWidget {
  final double price;
  final ValueChanged<double> onChanged;

  const _EditablePrice({
    required this.price,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showEditDialog(context),
      child: Text(
        '\$${price.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: price.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Price'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Price',
            prefixText: '\$ ',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null && newPrice >= 0) {
                onChanged(newPrice);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final ReceiptItem item;
  final Function(int) onChanged;

  const _QuantitySelector({
    required this.item,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final splitManager = context.watch<SplitManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Tooltip(
      message: 'Reduce quantity',
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decrease button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item.quantity > 0 ? () => onChanged(item.quantity - 1) : null,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.quantity > 0 
                      ? colorScheme.primaryContainer
                      : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                  ),
                  child: Icon(
                    Icons.remove_circle_outline,
                    size: 22,
                    color: item.quantity > 0 
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant.withOpacity(0.38),
                  ),
                ),
              ),
            ),
            // Quantity display
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Text(
                item.quantity.toString(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final bool isCollapsed;
  final double individualTotal;
  final double sharedTotal;
  final double assignedTotal;
  final double unassignedTotal;
  final double subtotal;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  _TotalsHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.isCollapsed,
    required this.individualTotal,
    required this.sharedTotal,
    required this.assignedTotal,
    required this.unassignedTotal,
    required this.subtotal,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  double get minExtent => minHeight;
  
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Calculate the percentage of shrinking (0.0 to 1.0)
    final double shrinkPercentage = shrinkOffset / (maxExtent - minExtent);
    final bool shouldCollapse = shrinkPercentage > 0.5 || isCollapsed;
    
    // Calculate the current height based on shrink percentage
    // Ensure it's never less than minHeight
    final double currentHeight = (maxHeight - (shrinkOffset)).clamp(minHeight, maxHeight);
    
    return SizedBox(
      height: currentHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: currentHeight,
        decoration: BoxDecoration(
          color: shouldCollapse ? colorScheme.surface.withOpacity(0.9) : Colors.transparent,
          boxShadow: shouldCollapse 
            ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
            : null,
        ),
        child: shouldCollapse 
          // Collapsed view - just the subtotal
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            )
          // Expanded view - full totals breakdown
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
    );
  }

  @override
  bool shouldRebuild(covariant _TotalsHeaderDelegate oldDelegate) {
    return isCollapsed != oldDelegate.isCollapsed || 
           subtotal != oldDelegate.subtotal ||
           individualTotal != oldDelegate.individualTotal ||
           sharedTotal != oldDelegate.sharedTotal ||
           assignedTotal != oldDelegate.assignedTotal ||
           unassignedTotal != oldDelegate.unassignedTotal ||
           maxHeight != oldDelegate.maxHeight ||
           minHeight != oldDelegate.minHeight;
  }
} 