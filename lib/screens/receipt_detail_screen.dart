import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/receipt_history.dart';
import '../models/receipt_item.dart';
import '../services/receipt_history_provider.dart';
import 'create_workflow_screen.dart';

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
              } else if (value == 'rename') {
                _showRenameDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_note, size: 18),
                    SizedBox(width: 8),
                    Text('Rename'),
                  ],
                ),
              ),
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
                  
                  // Receipt image with cached_network_image for better performance
                  if (widget.receipt.imageUri.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<String>(
                          future: _historyProvider.getDownloadURL(widget.receipt.imageUri),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Container(
                                height: 200,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
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
                            } else {
                              return CachedNetworkImage(
                                imageUrl: snapshot.data!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                // Better size caching for improved performance
                                memCacheHeight: 400, // 2x display size
                                // Fade in animation for smoother appearance
                                fadeInDuration: const Duration(milliseconds: 200),
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.receipt,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }
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
    // Navigate to the Create workflow with this receipt's data
    // We're using pushReplacement to prevent navigation back to this screen
    // This avoids the jarring reload when navigating back
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => CreateWorkflowScreen(
          existingReceipt: widget.receipt,
        ),
      ),
    );
    // Note: Since we're using pushReplacement, we don't need a .then handler
    // The user will go directly to the main screen when pressing back in the CreateWorkflowScreen
  }
  
  // This method is no longer needed with the new navigation approach
  // We're keeping it for now in case we need it for other functionality
  Future<void> _refreshReceiptData() async {
    try {
      final updatedReceipt = await _historyProvider.getReceiptById(widget.receipt.id);
      if (updatedReceipt != null && mounted) {
        // If the receipt was modified, replace it
        // But we're using a much smoother transition
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
              ReceiptDetailScreen(receipt: updatedReceipt),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Use a fade transition instead of the default slide
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing receipt: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showRenameDialog() {
    final formKey = GlobalKey<FormState>();
    String newName = widget.receipt.restaurantName;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Receipt'),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: newName,
            decoration: const InputDecoration(
              labelText: 'Restaurant Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
            onChanged: (value) {
              newName = value;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop();
                _renameReceipt(newName);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _renameReceipt(String newName) async {
    if (newName == widget.receipt.restaurantName) {
      return; // No change
    }
    
    setState(() {
      _isDeleting = true; // Reuse loading indicator
    });
    
    try {
      final updatedReceipt = widget.receipt.copyWith(restaurantName: newName);
      await _historyProvider.updateReceipt(updatedReceipt);
      
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        _refreshReceiptData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt renamed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error renaming receipt: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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