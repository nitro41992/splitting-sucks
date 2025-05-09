import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receipt.dart';
import '../services/firestore_service.dart';
import '../widgets/workflow_modal.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/dialog_helpers.dart';
import '../utils/toast_utils.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> 
    with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();
  // String? _errorMessage; // StreamBuilder will handle error display
  Stream<List<Receipt>>? _processedReceiptsStream; // ADDED: New stream for processed receipts
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // --- State Variables for holding receipts from stream --- 
  List<Receipt> _receipts = []; // Will be populated by StreamBuilder data
  bool _isProcessingStream = false; // To manage async processing of stream data
  // --- End Stream Data Variables ---

  // REMOVE Pagination state variables:
  // DocumentSnapshot? _lastDocument;
  // bool _isLoadingInitial = true;
  // bool _isLoadingMore = false;
  // bool _hasMoreData = true;
  // final ScrollController _scrollController = ScrollController();
  // final int _pageSize = 15;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _processedReceiptsStream = _firestoreService.getReceiptsStream().asyncMap((snapshot) async {
      if (!mounted) return <Receipt>[]; 
      try {
        return await _processReceiptsWithThumbnails(snapshot.docs);
      } catch (e) {
        debugPrint("Error processing stream data for UI: $e");
        return <Receipt>[]; // Return empty list on error to prevent breaking UI
      }
    });
    // _fetchInitialReceipts(); // REMOVE - StreamBuilder will handle data loading
    // _scrollController.addListener(_onScroll); // REMOVE
  }

  @override
  void dispose() {
    debugPrint('[_ReceiptsScreenState] dispose() called.');
    _searchController.dispose();
    // _scrollController.removeListener(_onScroll); // REMOVE
    // _scrollController.dispose(); // REMOVE
    super.dispose();
  }

  // REMOVE _fetchInitialReceipts, _fetchMoreReceipts, _onScroll methods
  // Future<void> _fetchInitialReceipts() async { ... }
  // void _onScroll() { ... }
  // Future<void> _fetchMoreReceipts() async { ... }

  // Helper method to process snapshots and fetch thumbnail URLs
  Future<List<Receipt>> _processReceiptsWithThumbnails(List<QueryDocumentSnapshot> docs) async {
    // Create initial list from snapshots
    final List<Receipt> initialReceipts = docs
        .map((doc) => Receipt.fromDocumentSnapshot(doc))
        .toList();

    // List to hold futures for fetching URLs
    final List<Future<Receipt>> fetchUrlFutures = [];

    for (final receipt in initialReceipts) {
      // Check if a valid gs:// thumbnail URI exists
      if (receipt.thumbnailUri != null && receipt.thumbnailUri!.startsWith('gs://')) {
        // Add a future that gets the URL and returns a new Receipt object
        fetchUrlFutures.add(
          FirebaseStorage.instance
              .refFromURL(receipt.thumbnailUri!)
              .getDownloadURL()
              .then((downloadUrl) {
                // Use ValueGetter syntax for copyWith
                return receipt.copyWith(thumbnailUrlForDisplay: () => downloadUrl);
              })
              .catchError((error) {
                debugPrint('Error getting download URL for thumbnail ${receipt.thumbnailUri}: $error');
                return receipt; // Return original receipt if URL fetch fails
              }),
        );
      } else {
        // If no valid thumbnail URI, add the original receipt wrapped in a Future
        fetchUrlFutures.add(Future.value(receipt));
      }
    }

    // Wait for all futures to complete (fetching URLs or returning original)
    return await Future.wait(fetchUrlFutures);
  }

  // Filter receipts based on tab and search query
  List<Receipt> _getFilteredReceipts(List<Receipt> receiptsToFilter, String searchQuery) {
    List<Receipt> currentlyDisplayedReceipts = receiptsToFilter;
    
    // Apply search filter if query exists
    if (searchQuery.isEmpty) {
      return currentlyDisplayedReceipts;
    }
    
    final query = searchQuery.toLowerCase();
    return currentlyDisplayedReceipts.where((receipt) {
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

  void _addNewReceipt() async {
    // Show restaurant name dialog
    String? restaurantName = await showRestaurantNameDialog(context);

    if (!mounted) return;

    if (restaurantName != null) {
      final bool? result = await WorkflowModal.show(context, initialRestaurantName: restaurantName);
      if (result == true && mounted) {
        // _fetchInitialReceipts(); // REMOVE - StreamBuilder will handle data loading
      }
    }
  }

  void _viewReceiptDetails(Receipt receipt) {
    // Capture the ReceiptsScreen's context BEFORE showing the bottom sheet.
    // This context should remain valid even after the bottom sheet is popped.
    final BuildContext screenContext = context; // IMPORTANT CHANGE HERE

    showModalBottomSheet(
      context: screenContext, // Use the captured screenContext to show the sheet
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) { // This is the bottom sheet's own context
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
                    onPressed: () => Navigator.pop(bottomSheetContext), // Use bottomSheetContext to pop itself
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
                    onPressed: () async {
                      Navigator.pop(bottomSheetContext); // Pop the bottom sheet using ITS context
                      debugPrint('[_ReceiptsScreenState] Attempting to show WorkflowModal for RESUME draft: ${receipt.id}');
                      
                      // Use the CAPTURED screenContext from ReceiptsScreen for WorkflowModal.show
                      if (!screenContext.mounted) { 
                        debugPrint('[_ReceiptsScreenState] ReceiptsScreen NOT MOUNTED before showing WorkflowModal for RESUME draft: ${receipt.id}');
                        return;
                      }
                      final bool? result = await WorkflowModal.show(screenContext, receiptId: receipt.id);
                      if (result == true && screenContext.mounted) {
                        // _fetchInitialReceipts(); // REMOVE - StreamBuilder will handle data loading
                      }
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
                    onPressed: () async {
                      Navigator.pop(bottomSheetContext); // Pop the bottom sheet using ITS context
                      debugPrint('[_ReceiptsScreenState] Attempting to show WorkflowModal for EDIT receipt: ${receipt.id}');
                      
                      // Use the CAPTURED screenContext from ReceiptsScreen for WorkflowModal.show
                      if (!screenContext.mounted) {
                        debugPrint('[_ReceiptsScreenState] ReceiptsScreen NOT MOUNTED before showing WorkflowModal for EDIT receipt: ${receipt.id}');
                        return;
                      }
                      final bool? result = await WorkflowModal.show(screenContext, receiptId: receipt.id);
                      if (result == true && screenContext.mounted) {
                        // _fetchInitialReceipts(); // REMOVE - StreamBuilder will handle data loading
                      }
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
                  // Pass screenContext to _confirmDeleteReceipt if it also needs to show dialogs/modals
                  onPressed: () async {
                    // Pop the details bottom sheet FIRST.
                    Navigator.pop(bottomSheetContext); 
                    
                    // Yield to the event loop to allow the pop to be processed.
                    await Future.microtask(() {}); 

                    // Ensure the screenContext is still mounted before showing the dialog.
                    if (screenContext.mounted) {
                      // Then show the confirmation dialog
                      // IMPORTANT: Use screenContext for showing the dialog,
                      // as bottomSheetContext is no longer valid after the pop.
                      await _confirmDeleteReceipt(screenContext, receipt); 
                    }
                  },
                ),
              ),
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
  
  // Helper for confirmation dialog before deleting a receipt
  Future<void> _confirmDeleteReceipt(BuildContext context, Receipt receipt) async {
    // Show the confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context, // Use the passed context (screenContext) to display the dialog over
      barrierDismissible: false, // PREVENT dismissal by tapping outside or system back for now
      builder: (alertDialogContext) { // This context is specific to the AlertDialog
        return AlertDialog(
          title: const Text('Delete Receipt?'),
          content: Text('Are you sure you want to delete "${receipt.restaurantName ?? 'this receipt'}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(alertDialogContext).pop(false); // Dismiss dialog with false
              },
            ),
            FilledButton(
              child: const Text('DELETE'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(alertDialogContext).pop(true); // Dismiss dialog with true
              },
            ),
          ],
        );
      },
    );

    // If the user confirmed
    if (confirmed == true) {
      if (!context.mounted) return; // Check if the original context (screenContext) is still mounted

      try {
        // Attempt to delete associated images from Firebase Storage
        if (receipt.imageUri != null && receipt.imageUri!.startsWith('gs://')) {
          try {
            await _firestoreService.deleteImage(receipt.imageUri!);
            debugPrint('Deleted main image from Storage: ${receipt.imageUri}');
          } catch (e) {
            debugPrint('Error deleting main image ${receipt.imageUri}: $e');
            // Optionally, show a specific error for image deletion failure but continue to delete receipt
          }
        }
        if (receipt.thumbnailUri != null && receipt.thumbnailUri!.startsWith('gs://')) {
          try {
            await _firestoreService.deleteImage(receipt.thumbnailUri!);
            debugPrint('Deleted thumbnail from Storage: ${receipt.thumbnailUri}');
          } catch (e) {
            debugPrint('Error deleting thumbnail ${receipt.thumbnailUri}: $e');
            // Optionally, show a specific error for image deletion failure but continue to delete receipt
          }
        }

        // Delete the receipt document from Firestore
        await _firestoreService.deleteReceipt(receipt.id);

        if (context.mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('"${receipt.restaurantName ?? 'Receipt'}" deleted successfully')),
          // );
          showAppToast(context, '"${receipt.restaurantName ?? 'Receipt'}" deleted successfully', AppToastType.success);
        }
      } catch (e) {
        debugPrint('Error during deletion process: $e');
        if (context.mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(content: Text('Error deleting receipt: $e'), backgroundColor: Colors.red),
          // );
          showAppToast(context, "Error deleting receipt: $e", AppToastType.error);
        }
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
                child: receipt.thumbnailUrlForDisplay != null 
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: receipt.thumbnailUrlForDisplay!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
                          errorWidget: (context, url, error) => const Icon(
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
    super.build(context);
    debugPrint('[_ReceiptsScreenState] build() called.');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'logo.png', // Changed path
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Billfie',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Smarter bill splitting',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _ReceiptSearchDelegate(
                  receipts: _receipts, // Use the locally held _receipts list
                  onReceiptTap: _viewReceiptDetails,
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Receipt>>( // MODIFIED: StreamBuilder now expects List<Receipt>
        stream: _processedReceiptsStream, // MODIFIED: Use the new processed stream
        builder: (BuildContext context, AsyncSnapshot<List<Receipt>> snapshot) { // MODIFIED: Snapshot type
          debugPrint('[_ReceiptsScreenState StreamBuilder] builder called. ConnectionState: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, HasError: ${snapshot.hasError}'); // ADDED
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading receipts: ${snapshot.error}', style: const TextStyle(color: Colors.red)), // MODIFIED: More generic error
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Retry logic: re-initialize the stream
                      if (mounted) {
                        setState(() {
                           _processedReceiptsStream = _firestoreService.getReceiptsStream().asyncMap((snapshot) async {
                            if (!mounted) return <Receipt>[];
                            try {
                              return await _processReceiptsWithThumbnails(snapshot.docs);
                            } catch (e) {
                              debugPrint("Error processing stream data for UI (Retry): $e");
                              return <Receipt>[];
                            }
                          });
                        });
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // if (snapshot.connectionState == ConnectionState.waiting || _isProcessingStream) { // REMOVED _isProcessingStream
          if (snapshot.connectionState == ConnectionState.waiting) { // MODIFIED: Only check waiting
            return const Center(child: CircularProgressIndicator());
          }

          // if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { // MODIFIED: Check snapshot.data (List<Receipt>)
          final List<Receipt> receiptsFromStream = snapshot.data ?? <Receipt>[];
          _receipts = receiptsFromStream; // Update local _receipts for search delegate

          if (receiptsFromStream.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No receipts yet.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap the + button to add a receipt'),
                ],
              ),
            );
          }

          // REMOVE WidgetsBinding.instance.addPostFrameCallback block
          // The processing is now part of the stream pipeline.
          
          final List<Receipt> displayReceipts = _getFilteredReceipts(receiptsFromStream, _searchQuery);

          // if (_receipts.isEmpty && snapshot.data!.docs.isNotEmpty) { // REMOVED: Old loading logic
          // return const Center(child: CircularProgressIndicator());
          // }
          
          if (displayReceipts.isEmpty && _searchQuery.isNotEmpty) {
            return const Center(child: Text("No receipts match your search."));
          // } else if (_filteredReceipts.isEmpty) { // MODIFIED: Use displayReceipts
          } else if (displayReceipts.isEmpty) { 
             // This case covers when receiptsFromStream is empty OR all items are filtered out by search
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty ? 'No receipts match your search.' : 'No receipts available.', // MODIFIED: Message based on search
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_searchQuery.isEmpty)
                    const Text('Tap the + button to add a receipt'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              if (mounted) {
                  setState(() {
                    // Re-initialize the stream to fetch and process fresh data
                    _processedReceiptsStream = _firestoreService.getReceiptsStream().asyncMap((snapshot) async {
                      if (!mounted) return <Receipt>[];
                      try {
                        return await _processReceiptsWithThumbnails(snapshot.docs);
                      } catch (e) {
                        debugPrint("Error processing stream data for UI (onRefresh): $e");
                        return <Receipt>[];
                      }
                    });
                  });
              }
            },
            child: ListView.builder(
              itemCount: displayReceipts.length, // MODIFIED: Use displayReceipts
              itemBuilder: (context, index) {
                 return _buildReceiptCard(displayReceipts[index]); // MODIFIED: Use displayReceipts
              },
            ),
          );
        },
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