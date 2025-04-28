import 'package:flutter/material.dart';

class EditablePrice extends StatelessWidget {
  final double price;
  final ValueChanged<double> onChanged;

  const EditablePrice({
    super.key,
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