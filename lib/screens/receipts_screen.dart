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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle at the top
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  
                  // Top row with Close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  
                  // Restaurant Name Edit Section with Completed tag
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                                    padding: const EdgeInsets.only(left: 12.0),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5D737E).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          size: 22,
                                          color: Color(0xFF5D737E),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            isEditingName = true;
                                          });
                                        },
                                        tooltip: 'Edit restaurant name',
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  
                  // Status pill with modern design - now below title
                  const SizedBox(height: 8),
                  if (!receipt.isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759), // Apple's system green for completed
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6), // Spacing between icon and text
                          const Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  
                  // Simplified Receipt details - only show useful information
                  _buildDetailRow('Date', receipt.formattedDate),
                  
                  // People detail with modern circular avatars
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "People",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (receipt.people.isEmpty)
                          Text(
                            "None assigned",
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[600],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: receipt.people.map((person) => 
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Circular avatar with initial
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5D737E), // Slate Blue
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        person.isNotEmpty ? person[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Person name
                                  Text(
                                    person,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ).toList(),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // "Edit Receipt" button - primary action with filled style
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Receipt'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5D737E), // Slate Blue
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(bottomSheetContext);
                        debugPrint('[_ReceiptsScreenState] Attempting to show WorkflowModal for EDIT receipt: ${receipt.id}');
                        
                        if (!screenContext.mounted) {
                          debugPrint('[_ReceiptsScreenState] ReceiptsScreen NOT MOUNTED before showing WorkflowModal for EDIT receipt: ${receipt.id}');
                          return;
                        }
                        
                        final bool? result = await WorkflowModal.show(screenContext, receiptId: receipt.id);
                        if (result == true && screenContext.mounted) {
                          // StreamBuilder will handle data loading
                        }
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Delete button - text style in red
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Delete Receipt', style: TextStyle(color: Colors.red)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(bottomSheetContext);
                        _confirmDeleteReceipt(screenContext, receipt);
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white, // Pure white #FFFFFF
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // Bottom-right shadow (darker)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(4, 4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
            // Top-left highlight (lighter)
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              offset: const Offset(-4, -4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _viewReceiptDetails(receipt),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Thumbnail
                Container(
                  width: 65,
                  height: 85,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE0E0E0), // Light grey border
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D1D1F), // Primary Text - Dark Grey
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Date in mm/dd/yyyy format with improved styling
                      Text(
                        receipt.formattedDate,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF8A8A8E), // Secondary Text - Medium Grey
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Stacked avatars for participants
                      if (hasPeople) 
                        GestureDetector(
                          onTap: () {
                            // Show modal with all participants
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (context) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Participants',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1D1D1F),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ...receipt.people.map((person) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF5D737E), // Slate Blue
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  person.isNotEmpty ? person[0].toUpperCase() : '?',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              person,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Color(0xFF1D1D1F),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )).toList(),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: SizedBox(
                            height: 36,
                            child: Stack(
                              children: [
                                for (int i = 0; i < min(3, receipt.people.length); i++)
                                  Positioned(
                                    left: i * 20.0, // Overlap by 8px
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF5D737E), // Slate Blue
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          receipt.people[i].isNotEmpty ? receipt.people[i][0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Show "+N" indicator if more than 3 people
                                if (receipt.people.length > 3)
                                  Positioned(
                                    left: 60.0, // Position after the 3rd avatar
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF5D737E), // Slate Blue
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          "+${receipt.people.length - 3}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          "No people assigned",
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF8A8A8E), // Secondary Text - Medium Grey
                          ),
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // Status pill with modern design
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: receipt.isDraft 
                              ? const Color(0xFFF5F5F7).withOpacity(0.8) // Light grey for draft
                              : const Color(0xFF34C759), // Apple's system green for completed
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              receipt.isDraft ? Icons.edit_note_outlined : Icons.check_circle,
                              size: 14,
                              color: receipt.isDraft 
                                  ? const Color(0xFF8A8A8E) // Medium grey for draft
                                  : Colors.white,
                            ),
                            const SizedBox(width: 6), // Spacing between icon and text
                            Text(
                              receipt.isDraft ? 'Draft' : 'Completed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: receipt.isDraft 
                                    ? const Color(0xFF8A8A8E) // Medium grey for draft
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
      backgroundColor: const Color(0xFFF5F5F7), // Very light grey background
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
                color: Color(0xFF1D1D1F), // Primary text color
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Smarter bill splitting',
              style: TextStyle(
                color: const Color(0xFF8A8A8E), // Secondary text color
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
        backgroundColor: const Color(0xFF5D737E), // Slate Blue
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.add_rounded, // Rounded plus icon
          color: Colors.white,
          size: 26,
        ),
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