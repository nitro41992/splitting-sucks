import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receipt.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../widgets/workflow_modal.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;
  bool _isLoading = true;
  List<Receipt> _allReceipts = [];
  String? _errorMessage;
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadReceipts();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // Refresh UI when tab changes
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Future<void> _loadReceipts() async {
    try {
      // Check if mounted before calling setState
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final QuerySnapshot snapshot = await _firestoreService.getReceipts();
      
      // Check if mounted before calling setState
      if (mounted) {
        setState(() {
          _allReceipts = snapshot.docs
              .map((doc) => Receipt.fromDocumentSnapshot(doc))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      // Check if mounted before calling setState
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading receipts: $e';
        });
      }
    }
  }

  // Filter receipts based on tab and search query
  List<Receipt> get _filteredReceipts {
    // First filter by tab selection
    List<Receipt> tabFiltered;
    
    switch (_tabController.index) {
      case 1: // Completed
        tabFiltered = _allReceipts.where((receipt) => receipt.isCompleted).toList();
        break;
      case 2: // Drafts
        tabFiltered = _allReceipts.where((receipt) => receipt.isDraft).toList();
        break;
      case 0: // All
      default:
        tabFiltered = _allReceipts;
        break;
    }
    
    // Then apply search filter if query exists
    if (_searchQuery.isEmpty) {
      return tabFiltered;
    }
    
    final query = _searchQuery.toLowerCase();
    return tabFiltered.where((receipt) {
      final restaurantName = receipt.restaurantName?.toLowerCase() ?? '';
      final people = receipt.people.map((p) => p.toLowerCase()).join(' ');
      
      return restaurantName.contains(query) || people.contains(query);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _addNewReceipt() {
    // Show restaurant name dialog
    showRestaurantNameDialog(context).then((restaurantName) {
      if (restaurantName != null) {
        // Pass the obtained restaurantName to WorkflowModal.show
        WorkflowModal.show(context, initialRestaurantName: restaurantName);
      }
    });
  }

  void _viewReceiptDetails(Receipt receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      receipt.restaurantName ?? 'Receipt',
                      style: Theme.of(context).textTheme.headlineSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              
              // Receipt details
              _buildDetailRow('Status', receipt.status),
              _buildDetailRow('Date', receipt.formattedDate),
              _buildDetailRow('Total', receipt.formattedAmount),
              _buildDetailRow('People', receipt.numberOfPeople),
              
              const SizedBox(height: 16),
              
              // Action buttons
              if (receipt.isDraft) ...[
                // Resume draft
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume Draft'),
                    onPressed: () {
                      Navigator.pop(context); // Close the bottom sheet
                      WorkflowModal.show(context, receiptId: receipt.id);
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Edit (for completed receipts)
              if (receipt.isCompleted) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Receipt'),
                    onPressed: () {
                      Navigator.pop(context); // Close the bottom sheet
                      WorkflowModal.show(context, receiptId: receipt.id);
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Delete button (for both draft and completed)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  label: const Text('Delete Receipt'),
                  onPressed: () => _confirmDeleteReceipt(context, receipt),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
  
  Future<void> _confirmDeleteReceipt(BuildContext context, Receipt receipt) async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt?'),
        content: Text(
          'Are you sure you want to delete this receipt${receipt.restaurantName != null ? ' from ${receipt.restaurantName}' : ''}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    
    if (confirmation == true) {
      // User confirmed, delete the receipt
      setState(() {
        _isLoading = true;
      });
      
      try {
        await _firestoreService.deleteReceipt(receipt.id);
        
        // If there was an image, delete that too
        if (receipt.imageUri != null) {
          await _firestoreService.deleteReceiptImage(receipt.imageUri!);
        }
        
        setState(() {
          _isLoading = false;
        });
        
        if (!mounted) return;
        Navigator.of(context).pop(); // Close the bottom sheet
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload receipts
        _loadReceipts();
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error deleting receipt: $e';
        });
        
        if (!mounted) return;
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildReceiptCard(Receipt receipt) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewReceiptDetails(receipt),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Left side: Thumbnail
              Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: receipt.thumbnailUri != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          receipt.thumbnailUri!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.receipt_long,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.receipt_long,
                        size: 32,
                        color: Colors.grey,
                      ),
              ),
              const SizedBox(width: 16),
              
              // Middle: Receipt info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.restaurantName ?? 'Unnamed Receipt',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      receipt.formattedDate,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      receipt.numberOfPeople,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    
                    // Draft badge
                    if (receipt.isDraft)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'DRAFT',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.amber[800],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Right side: Amount and menu
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    receipt.formattedAmount,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      // TODO: Show options menu (edit, delete, etc.)
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _ReceiptSearchDelegate(
                  receipts: _allReceipts,
                  onReceiptTap: _viewReceiptDetails,
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Completed'),
            Tab(text: 'Drafts'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReceipts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _filteredReceipts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _tabController.index == 0
                                ? 'No receipts found'
                                : _tabController.index == 1
                                    ? 'No completed receipts'
                                    : 'No drafts',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text('Tap the + button to add a receipt'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReceipts,
                      child: ListView.builder(
                        itemCount: _filteredReceipts.length,
                        itemBuilder: (context, index) {
                          return _buildReceiptCard(_filteredReceipts[index]);
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewReceipt,
        tooltip: 'Add Receipt',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Search delegate for receipts
class _ReceiptSearchDelegate extends SearchDelegate<String> {
  final List<Receipt> receipts;
  final Function(Receipt) onReceiptTap;

  _ReceiptSearchDelegate({
    required this.receipts,
    required this.onReceiptTap,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(
        child: Text('Enter a restaurant name or person to search'),
      );
    }

    final results = receipts.where((receipt) {
      final restaurantName = receipt.restaurantName?.toLowerCase() ?? '';
      final people = receipt.people.map((p) => p.toLowerCase()).join(' ');
      final searchQuery = query.toLowerCase();
      
      return restaurantName.contains(searchQuery) || 
             people.contains(searchQuery);
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('No results found'),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final receipt = results[index];
        return ListTile(
          leading: const Icon(Icons.receipt_long),
          title: Text(receipt.restaurantName ?? 'Unnamed Receipt'),
          subtitle: Text('${receipt.formattedDate} · ${receipt.numberOfPeople}'),
          trailing: Text(receipt.formattedAmount),
          onTap: () {
            close(context, receipt.id);
            onReceiptTap(receipt);
          },
        );
      },
    );
  }
} 