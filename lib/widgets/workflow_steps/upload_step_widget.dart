import 'dart:io';
import 'package:flutter/material.dart';
import '../../screens/receipt_upload_screen.dart';
import '../../screens/receipt_review_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/workflow_state.dart';
import '../../models/receipt_item.dart';
import '../../widgets/workflow_modal.dart' show GetCurrentItemsCallback;

class UploadStepWidget extends StatefulWidget {
  final File? imageFile;
  final String? imageUrl;
  final String? loadedThumbnailUrl;
  final bool isLoading;
  final bool isUploading;
  final bool isSuccessfullyParsed;
  final Function(File?) onImageSelected;
  final VoidCallback onParseReceipt;
  final VoidCallback onRetry;

  const UploadStepWidget({
    Key? key,
    required this.imageFile,
    this.imageUrl,
    this.loadedThumbnailUrl,
    required this.isLoading,
    required this.isSuccessfullyParsed,
    required this.onImageSelected,
    required this.onParseReceipt,
    required this.onRetry,
    this.isUploading = false,
  }) : super(key: key);

  @override
  State<UploadStepWidget> createState() => _UploadStepWidgetState();
}

class _UploadStepWidgetState extends State<UploadStepWidget> {
  List<ReceiptItem>? _currentItems;
  GetCurrentItemsCallback? _getCurrentItems;
  
  @override
  void initState() {
    super.initState();
    // Setup auto-caching
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    if (workflowState.hasParseData) {
      _currentItems = _parseItemsFromResult(workflowState.parseReceiptResult);
    }
  }
  
  // Method to register the callback for getting current items
  void _registerCurrentItemsGetter(GetCurrentItemsCallback callback) {
    _getCurrentItems = callback;
    debugPrint('[UploadStepWidget] Registered getCurrentItems callback.');
  }
  
  // Method to handle item updates from review
  void _handleItemsUpdated(List<ReceiptItem> items) {
    _currentItems = items;
    
    // Update workflow state
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    final currentParseResult = Map<String, dynamic>.from(workflowState.parseReceiptResult);
    currentParseResult['items'] = items.map((item) => {
      'name': item.name, 'price': item.price, 'quantity': item.quantity,
    }).toList();
    
    workflowState.setParseReceiptResult(currentParseResult);
    debugPrint('[UploadStepWidget] Updated parse result with ${items.length} items.');
  }
  
  // Method to show review overlay
  void _showReviewOverlay() {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ReceiptReviewScreen(
          initialItems: _currentItems ?? _parseItemsFromResult(workflowState.parseReceiptResult),
          onReviewComplete: (updatedItems, deletedItems) {
            _handleItemsUpdated(updatedItems);
            Navigator.pop(context);
          },
          onItemsUpdated: _handleItemsUpdated,
          registerCurrentItemsGetter: _registerCurrentItemsGetter,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ReceiptUploadScreen(
            imageFile: widget.imageFile,
            imageUrl: widget.imageUrl,
            loadedThumbnailUrl: widget.loadedThumbnailUrl,
            isLoading: widget.isLoading || widget.isUploading,
            isSuccessfullyParsed: widget.isSuccessfullyParsed,
            onImageSelected: widget.onImageSelected,
            onParseReceipt: widget.onParseReceipt,
            onRetry: widget.onRetry,
          ),
        ),
        
        // // Show "Review Items" button after successful parsing
        // if (widget.isSuccessfullyParsed && !widget.isLoading)
        //   Padding(
        //     padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        //     child: ElevatedButton.icon(
        //       onPressed: _showReviewOverlay,
        //       icon: const Icon(Icons.edit_note),
        //       label: const Text('Review Items'),
        //       style: ElevatedButton.styleFrom(
        //         padding: const EdgeInsets.symmetric(vertical: 12),
        //       ),
        //     ),
        //   ),
      ],
    );
  }
  
  // Parse items from workflow state result
  List<ReceiptItem> _parseItemsFromResult(Map<String, dynamic> parseResult) {
    if (parseResult.containsKey('items') && parseResult['items'] is List) {
      final items = (parseResult['items'] as List).map((item) {
        if (item is Map<String, dynamic>) {
          return ReceiptItem(
            name: item['name'] as String? ?? 'Unknown',
            price: (item['price'] as num?)?.toDouble() ?? 0.0,
            quantity: (item['quantity'] as num?)?.toInt() ?? 1,
          );
        }
        return ReceiptItem(name: 'Unknown', price: 0.0, quantity: 1);
      }).toList();
      return items;
    }
    return [];
  }
} 