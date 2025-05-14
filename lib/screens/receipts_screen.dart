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
import 'dart:math'; // Add import for min function

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

    // Auto-fix any drafts with summary data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFixDraftReceipts();
    });
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
    
    // Controller for editing restaurant name
    final TextEditingController restaurantNameController = TextEditingController(
      text: receipt.restaurantName ?? 'Unnamed Receipt'
    );
    
    // State variables for the modal
    bool isEditingName = false;
    bool hasSaved = false;

    showModalBottomSheet(
      context: screenContext, // Use the captured screenContext to show the sheet
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) { // This is the bottom sheet's own context
        return StatefulBuilder(
          builder: (context, setState) {
            // Function to update restaurant name with feedback
            Future<void> updateRestaurantName(String updatedName) async {
              if (updatedName.isEmpty) {
                updatedName = 'Unnamed Receipt';
                restaurantNameController.text = updatedName;
              }
                                             
              // Only update if name changed
              if (updatedName != (receipt.restaurantName ?? 'Unnamed Receipt')) {
                try {
                  // Update receipt in Firestore
                  await _firestoreService.saveReceipt(
                    receiptId: receipt.id, 
                    data: {
                      'metadata': {
                        'restaurant_name': updatedName
                      }
                    }
                  );
                  
                  // Show feedback
                  if (context.mounted) {
                    showAppToast(context, 'Restaurant name updated', AppToastType.success);
                  }
                  
                  setState(() {
                    hasSaved = true;
                  });
                } catch (e) {
                  debugPrint('Error updating restaurant name: $e');
                  if (context.mounted) {
                    showAppToast(context, 'Error updating name: $e', AppToastType.error);
                  }
                }
              }
            }
            
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row with Status and Close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status pill with consistent style
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: receipt.isDraft 
                              ? Colors.amber.shade100 
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          receipt.isDraft ? 'Draft' : 'Completed',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: receipt.isDraft 
                                ? Colors.amber.shade800 
                                : Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Restaurant Name Edit Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: isEditingName
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: restaurantNameController,
                                    autofocus: true,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Restaurant Name',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                                      ),
                                    ),
                                    onFieldSubmitted: (value) async {
                                      await updateRestaurantName(value.trim());
                                      setState(() {
                                        isEditingName = false;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            restaurantNameController.text = receipt.restaurantName ?? 'Unnamed Receipt';
                                            isEditingName = false;
                                          });
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () async {
                                          await updateRestaurantName(restaurantNameController.text.trim());
                                          setState(() {
                                            isEditingName = false;
                                          });
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      restaurantNameController.text,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          isEditingName = true;
                                        });
                                      },
                                      tooltip: 'Edit restaurant name',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  
                  // Simplified Receipt details - only show useful information
                  _buildDetailRow('Date', receipt.formattedDate),
                  
                  if (receipt.formattedAmount.isNotEmpty)
                    _buildDetailRow('Total', receipt.formattedAmount),
                    
                  // People detail with custom formatting to always show attendees
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "People",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (receipt.people.isEmpty)
                          Text(
                            "None assigned",
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                            ),
                          )
                        else
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                children: receipt.people.map((person) => 
                                  Chip(
                                    avatar: CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      radius: 12,
                                      child: Text(
                                        person.isNotEmpty ? person[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    label: Text(person),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                  )
                                ).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  if (receipt.isDraft) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Continue Editing'),
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
                  ] else ...[
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
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Delete Receipt', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () async {
                        Navigator.pop(bottomSheetContext);
                        _confirmDeleteReceipt(screenContext, receipt);
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                ],
              ),
            );
          }
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
    // Check if receipt has people data from assignments
    final bool hasPeople = receipt.people.isNotEmpty;
    
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    // Restaurant name (bold, clear, minimal)
                    Text(
                      receipt.restaurantName ?? 'Unnamed Receipt',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Date in mm/dd/yyyy format
                    Text(
                      receipt.formattedDate,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Attendees row - always show them if they exist in data
                    // Or display a placeholder if no people are assigned
                    if (hasPeople) 
                      SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            // Show max 3 avatars + overflow indicator
                            for (int i = 0; i < min(3, receipt.people.length); i++)
                              Padding(
                                padding: EdgeInsets.only(right: i < min(3, receipt.people.length) - 1 ? 4 : 0),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Text(
                                    receipt.people[i].isNotEmpty ? receipt.people[i][0].toUpperCase() : '?',
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            
                            // Show overflow indicator if more than 3 people
                            if (receipt.people.length > 3)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '+${receipt.people.length - 3}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else
                      Text(
                        "No people assigned",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Status pill with consistent style
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: receipt.isDraft 
                            ? Colors.amber.shade100 
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        receipt.isDraft ? 'Draft' : 'Completed',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: receipt.isDraft 
                              ? Colors.amber.shade800 
                              : Colors.green.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Right side: Amount (only if meaningful)
              if (receipt.formattedAmount.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                  child: Text(
                    receipt.formattedAmount,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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

  // Scan for drafts with assignment data and auto-complete them
  Future<void> _checkAndFixDraftReceipts() async {
    try {
      final draftReceiptDocs = await _firestoreService.getDraftReceipts(); // Assuming this returns List<Receipt>
      int fixedCount = 0;
      
      for (final receipt in draftReceiptDocs) {
        // Use peopleFromAssignments to get the authoritative list of people
        final List<String> actualPeople = receipt.peopleFromAssignments;
        bool hasMeaningfulData = false;

        // Check if this receipt has assignment data that should make it completed
        if (receipt.assignPeopleToItems != null) {
          final assignmentsData = receipt.assignPeopleToItems!;

          // Check for assignments with items assigned to people
          bool hasAssignments = false;
          if (assignmentsData.containsKey('assignments')) {
            final assignmentsList = assignmentsData['assignments'];
            if (assignmentsList is List && assignmentsList.isNotEmpty) {
              for (var assignmentEntry in assignmentsList) {
                if (assignmentEntry is Map<String, dynamic> && 
                    assignmentEntry.containsKey('items') &&
                    assignmentEntry['items'] is List &&
                    (assignmentEntry['items'] as List).isNotEmpty) {
                  hasAssignments = true;
                  break;
                }
              }
            }
          }
          
          // Also check for shared items - if any exist, it's a valid split
          bool hasSharedItems = false;
          if (assignmentsData.containsKey('shared_items')) {
            final sharedItems = assignmentsData['shared_items'];
            if (sharedItems is List && sharedItems.isNotEmpty) {
              hasSharedItems = true;
            }
          }
          
          hasMeaningfulData = hasAssignments || hasSharedItems;
        }
            
        // If it has meaningful data and actual people, complete it
        if (hasMeaningfulData && actualPeople.isNotEmpty) {
          debugPrint('[_ReceiptsScreenState._checkAndFixDraftReceipts] Completing draft with ID: ${receipt.id} as it has ${actualPeople.length} people and assignment data.');
          
          // Create a new Receipt object with the correct people list and completed status
          Receipt receiptToSave = receipt.copyWith(
            people: actualPeople, // Ensure the 'people' field is updated with the list from assignments
            status: 'completed',  // Explicitly set status to completed
          );
          
          // Convert to map for Firestore. toMap() should use the updated people and status.
          final Map<String, dynamic> receiptData = receiptToSave.toMap();
          
          // Save the receipt as completed using completeReceipt
          await _firestoreService.completeReceipt(
            receiptId: receipt.id,
            data: receiptData,
          );
          
          fixedCount++;
        } 
        // Even if not completing, update the people list if it's different
        else if (actualPeople.isNotEmpty && !_areListsEqual(receipt.people, actualPeople)) {
          debugPrint('[_ReceiptsScreenState._checkAndFixDraftReceipts] Updating people list for draft ID: ${receipt.id} from ${receipt.people.length} to ${actualPeople.length} people.');
          
          // Create new receipt with updated people list but same status
          Receipt receiptToUpdate = receipt.copyWith(
            people: actualPeople, // Update people list without changing status
          );
          
          // Save the updated receipt
          await _firestoreService.saveReceipt(
            receiptId: receipt.id,
            data: receiptToUpdate.toMap(),
          );
          
          fixedCount++;
        }
      }
      
      if (fixedCount > 0) {
        debugPrint('[_ReceiptsScreenState._checkAndFixDraftReceipts] Fixed and completed $fixedCount draft receipts.');
        if (mounted) {
          showAppToast(context, "$fixedCount receipt(s) were automatically updated.", AppToastType.success);
        }
      }
    } catch (e) {
      debugPrint('[_ReceiptsScreenState._checkAndFixDraftReceipts] Error fixing drafts: $e');
      // Don't show error to user as this is a background task
    }
  }
  
  // Helper method to compare two lists
  bool _areListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    
    // Convert to sets and compare for content equality (ignoring order)
    final set1 = Set<String>.from(list1);
    final set2 = Set<String>.from(list2);
    return set1.difference(set2).isEmpty;
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