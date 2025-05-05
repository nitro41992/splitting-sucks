import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/receipt_history.dart';
import '../models/receipt_item.dart';
import '../services/receipt_history_provider.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final ReceiptHistory receipt;

  const ReceiptDetailScreen({
    Key? key,
    required this.receipt,
  }) : super(key: key);

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  final ReceiptHistoryProvider _historyProvider = ReceiptHistoryProvider();
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM/dd/yyyy');
    final formattedDate = dateFormat.format(widget.receipt.createdAt.toDate());
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    
    // Extract receipt data for display
    final receiptItems = _getReceiptItems();
    final personTotals = widget.receipt.personTotals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _continueEditing,
            tooltip: 'Continue Editing',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _deleteReceipt();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isDeleting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting receipt...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant name and date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.receipt.restaurantName,
                          style: theme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  
                  // Status badge
                  if (widget.receipt.status == 'draft')
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DRAFT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  
                  // Receipt image
                  if (widget.receipt.imageUri.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.receipt.imageUri,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.receipt,
                                size: 64,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Total amount
                  Row(
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        currencyFormat.format(widget.receipt.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 32),
                  
                  // People section
                  Text(
                    'People',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Display person totals
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: personTotals.length,
                    itemBuilder: (context, index) {
                      final person = personTotals[index];
                      final name = person['name'] as String;
                      final total = (person['total'] as num).toDouble();
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Text(name),
                            const Spacer(),
                            Text(currencyFormat.format(total)),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const Divider(height: 32),
                  
                  // Receipt items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Receipt Items',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${receiptItems.length} items',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Display items
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: receiptItems.length,
                    itemBuilder: (context, index) {
                      final item = receiptItems[index];
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            if (item['quantity'] > 1)
                              Text('${item['quantity']}x '),
                            Expanded(
                              child: Text(
                                item['item'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(currencyFormat.format(item['price'])),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Edit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _continueEditing,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Continue Editing'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Map<String, dynamic>> _getReceiptItems() {
    final receiptData = widget.receipt.receiptData;
    if (receiptData.containsKey('items')) {
      return List<Map<String, dynamic>>.from(receiptData['items']);
    }
    return [];
  }

  void _continueEditing() {
    // This will be implemented to navigate back to the Create workflow
    // with this receipt's data loaded
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Edit functionality will be implemented in a future update',
        ),
      ),
    );
  }

  Future<void> _deleteReceipt() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt?'),
        content: const Text(
          'Are you sure you want to delete this receipt and all its data?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      setState(() {
        _isDeleting = true;
      });
      
      try {
        await _historyProvider.deleteReceipt(widget.receipt.id);
        if (mounted) {
          Navigator.of(context).pop(true); // Pop with 'true' to indicate deletion
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting receipt: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
} 