import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../models/split_manager.dart';
import '../models/person.dart';
import '../models/receipt_item.dart';

class SplitView extends StatefulWidget {
  const SplitView({super.key});

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  int _selectedIndex = 0;
  bool _isFabVisible = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isScrollingDown = _scrollController.position.userScrollDirection == ScrollDirection.reverse;
    if (isScrollingDown != !_isFabVisible) {
      setState(() {
        _isFabVisible = !isScrollingDown;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitManager>(
      builder: (context, splitManager, child) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        final TextTheme textTheme = Theme.of(context).textTheme;
        
        return Scaffold(
          body: Column(
            children: [
              // Integrated tab bar with totals
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Total amount display
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Total: ',
                            style: textTheme.headlineSmall,
                          ),
                          Text(
                            '\$${splitManager.totalAmount.toStringAsFixed(2)}',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Custom tab selector
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  ],
                ),
              ),
              
              // Content area
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    // People list
                    _buildPeopleList(context, splitManager),
                    
                    // Shared items list
                    _buildSharedItemsList(context, splitManager),
                    
                    // Unassigned items list
                    _buildUnassignedItemsList(context, splitManager),
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

  Widget _buildPeopleList(BuildContext context, SplitManager splitManager) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
      itemCount: splitManager.people.length,
      itemBuilder: (context, index) {
        final person = splitManager.people[index];
        return _PersonCard(person: person);
      },
    );
  }

  Widget _buildSharedItemsList(BuildContext context, SplitManager splitManager) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
      itemCount: splitManager.sharedItems.length,
      itemBuilder: (context, index) {
        final item = splitManager.sharedItems[index];
        return _SharedItemCard(item: item);
      },
    );
  }

  Widget _buildUnassignedItemsList(BuildContext context, SplitManager splitManager) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
      itemCount: splitManager.unassignedItems.length,
      itemBuilder: (context, index) {
        final item = splitManager.unassignedItems[index];
        return _UnassignedItemCard(item: item);
      },
    );
  }

  void _showAddPersonDialog(BuildContext context, SplitManager splitManager) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Person'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter person\'s name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                splitManager.addPerson(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final Person person;

  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(person.name[0]),
            ),
            title: _EditableText(
              text: person.name,
              onChanged: (newName) {
                context.read<SplitManager>().updatePersonName(person, newName);
              },
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Text(
              '\$${person.totalAmount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (person.assignedItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: person.assignedItems.map((item) => _ItemRow(item: item)).toList(),
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
    final people = splitManager.people;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _EditableText(
                    text: item.name,
                    onChanged: (newName) => item.updateName(newName),
                  ),
                ),
                const SizedBox(width: 16),
                _EditablePrice(
                  price: item.price,
                  onChanged: (newPrice) => item.updatePrice(newPrice),
                ),
                const SizedBox(width: 16),
                _QuantitySelector(
                  quantity: item.quantity,
                  onChanged: (newQuantity) => splitManager.updateItemQuantity(item, newQuantity),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: \$${item.total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Assign'),
                  onPressed: () => _showAssignDialog(context, splitManager, item),
                ),
              ],
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign to Person'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: splitManager.people.length,
            itemBuilder: (context, index) {
              final person = splitManager.people[index];
              return ListTile(
                leading: CircleAvatar(child: Text(person.name[0])),
                title: Text(person.name),
                onTap: () {
                  splitManager.removeUnassignedItem(item);
                  splitManager.assignItemToPerson(item, person);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context, SplitManager splitManager, ReceiptItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select people to share with:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: splitManager.people.map((person) {
                return FilterChip(
                  label: Text(person.name),
                  selected: false,
                  onSelected: (selected) {
                    if (selected) {
                      splitManager.removeUnassignedItem(item);
                      splitManager.addItemToShared(item, [person]);
                      Navigator.pop(context);
                    }
                  },
                );
              }).toList(),
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
}

class _SharedItemCard extends StatelessWidget {
  final ReceiptItem item;

  const _SharedItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.watch<SplitManager>();
    final people = splitManager.people;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _EditableText(
                    text: item.name,
                    onChanged: (newName) => item.updateName(newName),
                  ),
                ),
                const SizedBox(width: 16),
                _EditablePrice(
                  price: item.price,
                  onChanged: (newPrice) => item.updatePrice(newPrice),
                ),
                const SizedBox(width: 16),
                _QuantitySelector(
                  quantity: item.quantity,
                  onChanged: (newQuantity) => splitManager.updateItemQuantity(item, newQuantity),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: \$${item.total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: people.map((person) {
                final isSelected = person.sharedItems.contains(item);
                final colorScheme = Theme.of(context).colorScheme;

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: _EditableText(
              text: item.name,
              onChanged: (newName) => item.updateName(newName),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
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
            quantity: item.quantity,
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
    return InkWell(
      onTap: () => _showEditDialog(context),
      child: Text(
        text,
        style: style ?? Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onChanged(controller.text);
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
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantitySelector({
    required this.quantity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
        ),
        Text(
          quantity.toString(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
} 