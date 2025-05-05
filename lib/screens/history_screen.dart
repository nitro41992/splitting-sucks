import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/receipt_history.dart';
import '../services/receipt_history_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/cards/receipt_history_card.dart';
import '../utils/env_checker.dart';
import 'receipt_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ReceiptHistoryProvider _historyProvider = ReceiptHistoryProvider();
  List<ReceiptHistory> _receipts = [];
  List<ReceiptHistory> _filteredReceipts = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showScrollToTop = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Log environment status for this screen
    EnvironmentChecker.logStatus('HistoryScreen');
    _loadReceipts();
    
    // Add scroll listener to show/hide scroll-to-top button
    _scrollController.addListener(() {
      setState(() {
        _showScrollToTop = _scrollController.offset > 300;
      });
    });
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final receipts = await _historyProvider.getAllReceipts();
      
      if (mounted) {
        setState(() {
          _receipts = receipts;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading receipts: $e");
      
      // Handle the error gracefully
      if (mounted) {
        setState(() {
          // Set empty receipts in case of error
          _receipts = [];
          _filteredReceipts = [];
          _isLoading = false;
        });
        
        // Show error message
        _showErrorMessage('Error loading receipts. Using empty data.');
      }
    }
  }

  void _applyFilters() {
    try {
      // Create a modifiable copy of receipts
      List<ReceiptHistory> filtered = [];
      
      if (_filterStatus == 'all') {
        filtered = List<ReceiptHistory>.from(_receipts);
      } else {
        filtered = _receipts
            .where((receipt) => receipt.status == _filterStatus)
            .toList();
      }

      if (_searchQuery.isNotEmpty) {
        final lowerQuery = _searchQuery.toLowerCase();
        filtered = filtered
            .where((receipt) =>
                receipt.restaurantName.toLowerCase().contains(lowerQuery))
            .toList();
      }

      // Sort by date (newest first)
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      setState(() {
        _filteredReceipts = filtered;
      });
    } catch (e) {
      debugPrint('Error applying filters: $e');
      // Fallback to avoid UI issues
      setState(() {
        _filteredReceipts = [];
      });
      _showErrorMessage('Error filtering receipts: Using empty list');
    }
  }

  void _onFilterChanged(String status) {
    setState(() {
      _filterStatus = status;
      _applyFilters();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _viewReceiptDetails(ReceiptHistory receipt) async {
    // Show platform-specific navigation transition
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    final result = await Navigator.push<bool>(
      context,
      isIOS
          ? CupertinoPageRoute(
              builder: (context) => ReceiptDetailScreen(receipt: receipt),
            )
          : MaterialPageRoute(
              builder: (context) => ReceiptDetailScreen(receipt: receipt),
            ),
    );
    
    // If result is true, it means the receipt was deleted in the detail screen
    if (result == true) {
      _loadReceipts();
    }
  }

  Future<void> _deleteReceipt(ReceiptHistory receipt) async {
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    bool shouldDelete = false;
    
    if (isIOS) {
      // iOS-style confirmation
      await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Delete Receipt?'),
          content: const Text(
            'Are you sure you want to delete this receipt and all its data? This action cannot be undone.',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ).then((value) => shouldDelete = value ?? false);
    } else {
      // Android-style confirmation
      await showDialog<bool>(
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
      ).then((value) => shouldDelete = value ?? false);
    }

    if (shouldDelete) {
      try {
        await _historyProvider.deleteReceipt(receipt.id);
        // Add haptic feedback on successful delete
        if (isIOS) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.vibrate();
        }
        _showSuccessMessage('Receipt deleted successfully');
        _loadReceipts();
      } catch (e) {
        _showErrorMessage('Error deleting receipt: ${e.toString()}');
      }
    }
  }

  void _showSuccessMessage(String message) {
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    if (isIOS) {
      // iOS-style success message
      showCupertinoSnackBar(message);
    } else {
      // Android-style success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
  
  void _showErrorMessage(String message) {
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    if (isIOS) {
      // iOS-style error message
      showCupertinoSnackBar(
        message,
        backgroundColor: Colors.red.shade700,
      );
    } else {
      // Android-style error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Helper method for showing iOS-style snackbar
  void showCupertinoSnackBar(
    String message, {
    Color backgroundColor = Colors.black87,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 20.0,
        left: 20.0,
        right: 20.0,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              color: backgroundColor,
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }

  Widget _buildFilterChips() {
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: isIOS
          ? CupertinoSegmentedControl<String>(
              children: const {
                'all': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('All'),
                ),
                'completed': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Completed'),
                ),
                'draft': Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Drafts'),
                ),
              },
              groupValue: _filterStatus,
              onValueChanged: _onFilterChanged,
            )
          : Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterStatus == 'all',
                  onSelected: (selected) {
                    if (selected) _onFilterChanged('all');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Completed'),
                  selected: _filterStatus == 'completed',
                  onSelected: (selected) {
                    if (selected) _onFilterChanged('completed');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Drafts'),
                  selected: _filterStatus == 'draft',
                  onSelected: (selected) {
                    if (selected) _onFilterChanged('draft');
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSearchField() {
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: isIOS
          ? CupertinoSearchTextField(
              controller: _searchController,
              placeholder: 'Search by restaurant name',
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchChanged,
              onSuffixTap: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            )
          : TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by restaurant name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
    );
  }

  Widget _buildEmptyState() {
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final icon = isIOS ? CupertinoIcons.doc_text : Icons.receipt_long;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No receipts found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _filterStatus == 'all'
                ? 'You haven\'t saved any receipts yet'
                : _filterStatus == 'completed'
                    ? 'You don\'t have any completed receipts'
                    : 'You don\'t have any drafts',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    // Return platform-specific scaffold
    if (isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('History'),
        ),
        child: _buildBody(),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('History'),
        ),
        body: _buildBody(),
        // Floating action button for Android to scroll to top
        floatingActionButton: _showScrollToTop
            ? FloatingActionButton(
                mini: true,
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  );
                },
                child: const Icon(Icons.arrow_upward),
              )
            : null,
      );
    }
  }
  
  Widget _buildBody() {
    // Show loading indicator
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // History screen doesn't need environment warnings
    // The core functionality works without special environment variables
    
    return Column(
      children: [
        _buildSearchField(),
        _buildFilterChips(),
        const SizedBox(height: 8),
        Expanded(
          child: _filteredReceipts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _filteredReceipts.length,
                  itemBuilder: (context, index) {
                    final receipt = _filteredReceipts[index];
                    return ReceiptHistoryCard(
                      receipt: receipt,
                      onTap: () => _viewReceiptDetails(receipt),
                      onDelete: () => _deleteReceipt(receipt),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 