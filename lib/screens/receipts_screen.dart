import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import '../services/receipt_service.dart';

class ReceiptsScreen extends StatefulWidget {
  final Function(Receipt) onReceiptTap;
  final Function() onAddReceiptTap;
  
  const ReceiptsScreen({
    super.key,
    required this.onReceiptTap,
    required this.onAddReceiptTap,
  });

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final ReceiptService _receiptService = ReceiptService();
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'completed', 'drafts'
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration(
            hintText: 'Search receipts...',
            prefixIcon: const Icon(Icons.search),
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<List<Receipt>>(
              stream: _receiptService.getReceipts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                
                final receipts = snapshot.data ?? [];
                
                // Apply filters
                final filteredReceipts = receipts.where((receipt) {
                  // Filter by status
                  if (_filterType == 'completed' && receipt.metadata.status != 'completed') {
                    return false;
                  }
                  
                  if (_filterType == 'drafts' && receipt.metadata.status != 'draft') {
                    return false;
                  }
                  
                  // Search query
                  if (_searchQuery.isNotEmpty) {
                    // Search by restaurant name
                    final restaurantName = receipt.metadata.restaurantName?.toLowerCase() ?? '';
                    if (restaurantName.contains(_searchQuery)) {
                      return true;
                    }
                    
                    // Search by people
                    final peopleMatch = receipt.metadata.people.any(
                      (person) => person.toLowerCase().contains(_searchQuery)
                    );
                    
                    return peopleMatch;
                  }
                  
                  return true;
                }).toList();
                
                if (filteredReceipts.isEmpty) {
                  return const Center(
                    child: Text(
                      'No receipts found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }
                
                return ListView.builder(
                  itemCount: filteredReceipts.length,
                  itemBuilder: (context, index) {
                    final receipt = filteredReceipts[index];
                    return _buildReceiptCard(receipt);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onAddReceiptTap,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Text('Filters:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Completed', 'completed'),
          const SizedBox(width: 8),
          _buildFilterChip('Drafts', 'drafts'),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String filterValue) {
    final isSelected = _filterType == filterValue;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = selected ? filterValue : 'all';
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }
  
  Widget _buildReceiptCard(Receipt receipt) {
    final dateFormat = DateFormat('MM/dd/yy');
    final date = dateFormat.format(receipt.metadata.createdAt.toDate());
    final restaurantName = receipt.metadata.restaurantName ?? 'Unnamed Receipt';
    final people = receipt.metadata.people;
    final peopleCount = people.isEmpty ? 0 : people.length;

    // Calculate total if available in splitManagerState
    String totalText = '';
    if (receipt.assignPeopleToItems != null &&
        receipt.assignPeopleToItems!.containsKey('subtotal')) {
      // Try to get subtotal from assignments
      final totalAmount = receipt.assignPeopleToItems!['subtotal'];
      if (totalAmount is num) {
        totalText = '\$${totalAmount.toStringAsFixed(2)}';
      }
    } else if (receipt.parseReceipt != null && 
        receipt.parseReceipt!.containsKey('subtotal')) {
      // Fall back to parsed receipt data
      final subtotalStr = receipt.parseReceipt!['subtotal'] as String?;
      if (subtotalStr != null) {
        final totalAmount = double.tryParse(subtotalStr);
        if (totalAmount != null) {
          totalText = '\$${totalAmount.toStringAsFixed(2)}';
        }
      }
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => widget.onReceiptTap(receipt),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (receipt.thumbnailUri != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: CachedNetworkImage(
                      imageUrl: receipt.thumbnailUri!,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.receipt, color: Colors.grey),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error, color: Colors.red),
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt, color: Colors.grey),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$peopleCount ${peopleCount == 1 ? 'person' : 'people'}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (totalText.isNotEmpty)
                    Text(
                      totalText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Status indicator or menu button
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showReceiptOptions(receipt),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showReceiptOptions(Receipt receipt) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Receipt'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onReceiptTap(receipt);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Receipt', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteReceipt(receipt);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _confirmDeleteReceipt(Receipt receipt) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Receipt'),
          content: const Text('Are you sure you want to delete this receipt? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _receiptService.deleteReceipt(receipt.id!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt deleted successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting receipt: $e')),
                    );
                  }
                }
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
} 