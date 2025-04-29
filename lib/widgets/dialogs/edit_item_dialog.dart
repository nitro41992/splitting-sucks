import 'package:flutter/material.dart';
import '../../models/receipt_item.dart'; // Import ReceiptItem model

// Define a return type for the dialog
class EditItemResult {
  final String name;
  final double price;

  EditItemResult(this.name, this.price);
}

// --- New StatefulWidget for Dialog Content ---
class _EditItemDialogContent extends StatefulWidget {
  final ReceiptItem initialItem;

  const _EditItemDialogContent({required this.initialItem});

  @override
  _EditItemDialogContentState createState() => _EditItemDialogContentState();
}

class _EditItemDialogContentState extends State<_EditItemDialogContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  static const int maxNameLength = 30;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialItem.name);
    _priceController = TextEditingController(text: widget.initialItem.price.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final newName = _nameController.text.trim();
    final newPrice = double.tryParse(_priceController.text);

    if (newName.isNotEmpty && newName.length <= maxNameLength && newPrice != null && newPrice > 0) {
      Navigator.pop(context, EditItemResult(newName, newPrice)); // Return the new values
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
          Icon(Icons.edit, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Edit Item'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                hintText: 'Enter item name',
                prefixIcon: const Icon(Icons.fastfood_outlined),
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
          onPressed: _saveChanges,
          icon: const Icon(Icons.check),
          label: const Text('Save'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}
// --- End of StatefulWidget ---


Future<EditItemResult?> showEditItemDialog(
  BuildContext context,
  ReceiptItem item,
) async {
  // Remove controller creation and disposal from here
  // final nameController = TextEditingController(text: item.name);
  // final priceController = TextEditingController(text: item.price.toStringAsFixed(2));
  // const int maxNameLength = 15; // Moved to State

  final result = await showDialog<EditItemResult?>(
    context: context,
    // Use the new StatefulWidget as the content
    builder: (BuildContext context) => _EditItemDialogContent(initialItem: item),
  );

  // Remove controller disposal from here
  // nameController.dispose();
  // priceController.dispose();

  return result;
} 