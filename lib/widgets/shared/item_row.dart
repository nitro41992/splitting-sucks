import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_item.dart';
import '../../models/split_manager.dart';
import 'editable_price.dart';
import 'quantity_selector.dart';

class ItemRow extends StatelessWidget {
  final ReceiptItem item;

  const ItemRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final splitManager = context.read<SplitManager>(); // Use read if only calling methods
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
              overflow: TextOverflow.ellipsis, // Prevent overflow
            ),
          ),
          const SizedBox(width: 16),
          EditablePrice(
            price: item.price,
            onChanged: (newPrice) => item.updatePrice(newPrice),
          ),
          const SizedBox(width: 16),
          QuantitySelector(
            item: item,
            onChanged: (newQuantity) => splitManager.updateItemQuantity(item, newQuantity),
          ),
        ],
      ),
    );
  }
} 