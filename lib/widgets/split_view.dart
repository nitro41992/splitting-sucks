import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/split_manager.dart';
import '../models/person.dart';
import '../models/receipt_item.dart';

class SplitView extends StatelessWidget {
  const SplitView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitManager>(
      builder: (context, splitManager, child) {
        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: const Text('Split Bill'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () => _showAddPersonDialog(context, splitManager),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount: \$${splitManager.totalAmount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Shared Items: \$${splitManager.sharedItemsTotal.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final person = splitManager.people[index];
                  return _PersonCard(person: person);
                },
                childCount: splitManager.people.length,
              ),
            ),
            if (splitManager.sharedItems.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Shared Items',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = splitManager.sharedItems[index];
                    return _SharedItemCard(item: item);
                  },
                  childCount: splitManager.sharedItems.length,
                ),
              ),
            ],
          ],
        );
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
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
            ),
            trailing: Text(
              '\$${person.totalAmount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (person.assignedItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned Items',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...person.assignedItems.map((item) => _ItemRow(item: item)),
                ],
              ),
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
                  onChanged: (newQuantity) => item.updateQuantity(newQuantity),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total: \$${item.total.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
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
            onChanged: (newQuantity) => item.updateQuantity(newQuantity),
          ),
        ],
      ),
    );
  }
}

class _EditableText extends StatelessWidget {
  final String text;
  final ValueChanged<String> onChanged;

  const _EditableText({
    required this.text,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showEditDialog(context),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
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