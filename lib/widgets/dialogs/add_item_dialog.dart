import 'package:flutter/material.dart';
import '../../models/receipt_item.dart'; // Import ReceiptItem model

// --- New StatefulWidget for Dialog Content ---
class _AddItemDialogContent extends StatefulWidget {
  const _AddItemDialogContent();

  @override
  _AddItemDialogContentState createState() => _AddItemDialogContentState();
}

class _AddItemDialogContentState extends State<_AddItemDialogContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  int _quantity = 1;
  static const int maxNameLength = 15;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _priceController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text);

    if (name.isNotEmpty && name.length <= maxNameLength && price != null && price > 0) {
      final newItem = ReceiptItem(
        name: name,
        price: price,
        quantity: _quantity,
      );
      Navigator.pop(context, newItem); // Return the new item
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid name (1-$maxNameLength chars) and price (> 0)'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Icon(Icons.add_shopping_cart, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Add New Item'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item name field with character counter
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                hintText: 'Enter item name',
                prefixIcon: const Icon(Icons.shopping_bag_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '${_nameController.text.length}/$maxNameLength',
              ),
              maxLength: maxNameLength,
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                // Use standard setState to update counter
                setState(() {});
              },
              autofocus: true,
            ),
            const SizedBox(height: 16),
            // Price field
            TextField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Price',
                prefixText: '\$ ',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            // Quantity selector
            Row(
              children: [
                Text(
                  'Quantity:',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(), // Push controls to the right
                IconButton(
                  onPressed: () {
                    if (_quantity > 1) {
                      setState(() => _quantity--);
                    }
                  },
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  style: IconButton.styleFrom(padding: const EdgeInsets.all(4)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _quantity.toString(),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _quantity++);
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  style: IconButton.styleFrom(padding: const EdgeInsets.all(4)),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null), // Return null on cancel
          child: Text(
            'Cancel',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
        FilledButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Add Item'),
        ),
      ],
    );
  }
}
// --- End of StatefulWidget ---


Future<ReceiptItem?> showAddItemDialog(BuildContext context) async {
  // Remove controller and state creation/disposal from here
  // final nameController = TextEditingController();
  // final priceController = TextEditingController();
  // int quantity = 1;
  // const int maxNameLength = 15; // Moved to State

  final result = await showDialog<ReceiptItem?>(
    context: context,
    builder: (BuildContext context) {
      // Use the new StatefulWidget as the content
      return const _AddItemDialogContent();
    },
  );

  // Remove controller disposal from here
  // nameController.dispose();
  // priceController.dispose();

  return result;
} 