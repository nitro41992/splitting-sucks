import 'package:flutter/material.dart';
import '../../models/receipt_item.dart'; // Import ReceiptItem model

// Define a return type for the dialog
class EditItemResult {
  final String name;
  final double price;

  EditItemResult(this.name, this.price);
}

Future<EditItemResult?> showEditItemDialog(
  BuildContext context,
  ReceiptItem item,
) async {
  final nameController = TextEditingController(text: item.name);
  final priceController = TextEditingController(text: item.price.toStringAsFixed(2));
  const int maxNameLength = 15;

  final result = await showDialog<EditItemResult?>(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) { // Use setStateDialog for dialog state
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
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Item Name',
                      hintText: 'Enter item name',
                      prefixIcon: const Icon(Icons.fastfood_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '${nameController.text.length}/$maxNameLength',
                    ),
                    maxLength: maxNameLength,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) {
                      // Force dialog rebuild to update counter
                      setStateDialog(() {});
                    },
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
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
                onPressed: () {
                  final newName = nameController.text.trim();
                  final newPrice = double.tryParse(priceController.text);

                  if (newName.isNotEmpty && newName.length <= maxNameLength && newPrice != null && newPrice > 0) {
                    Navigator.pop(context, EditItemResult(newName, newPrice)); // Return the new values
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please enter a valid name (1-$maxNameLength chars) and price (> 0)'),
                        backgroundColor: colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
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
          );
        },
      );
    },
  );

  // Dispose controllers after dialog is closed
  nameController.dispose();
  priceController.dispose();

  return result;
} 