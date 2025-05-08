import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../models/person.dart';
import '../services/firestore_service.dart';
import '../models/split_manager.dart';
import '../screens/receipt_upload_screen.dart';
import '../screens/receipt_review_screen.dart';
import '../screens/voice_assignment_screen.dart';
import '../screens/final_summary_screen.dart';
import 'split_view.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/receipt_parser_service.dart';

/// Define NavigateToPageNotification class here to match the one in split_view.dart
/// This avoids having to expose that class in a separate file while maintaining compatibility
class NavigateToPageNotification extends Notification {
  final int pageIndex;
  
  NavigateToPageNotification(this.pageIndex);
}

/// Provider for the workflow state
class WorkflowState extends ChangeNotifier {
  int _currentStep = 0;
  String? _receiptId;
  String _restaurantName;
  File? _imageFile;
  String? _loadedImageUrl; // For displaying an image from a URL (e.g., loaded draft)
  
  // Authoritative GS URIs for the current workflow
  String? _actualImageGsUri;
  String? _actualThumbnailGsUri;

  // URL for displaying thumbnail from loaded draft
  String? _loadedThumbnailUrl; 

  Map<String, dynamic> _parseReceiptResult = {};
  Map<String, dynamic> _transcribeAudioResult = {};
  Map<String, dynamic> _assignPeopleToItemsResult = {};
  Map<String, dynamic> _splitManagerState = {};
  bool _isLoading = false;
  String? _errorMessage;
  
  // List to track GS URIs that might need deletion
  final List<String> _pendingDeletionGsUris = [];
  
  WorkflowState({required String restaurantName, String? receiptId})
      : _restaurantName = restaurantName,
        _receiptId = receiptId;
  
  // Getters
  int get currentStep => _currentStep;
  String get restaurantName => _restaurantName;
  String? get receiptId => _receiptId;
  File? get imageFile => _imageFile;
  String? get loadedImageUrl => _loadedImageUrl;
  String? get actualImageGsUri => _actualImageGsUri;
  String? get actualThumbnailGsUri => _actualThumbnailGsUri;

  Map<String, dynamic> get parseReceiptResult => _parseReceiptResult;
  Map<String, dynamic> get transcribeAudioResult => _transcribeAudioResult;
  Map<String, dynamic> get assignPeopleToItemsResult => _assignPeopleToItemsResult;
  Map<String, dynamic> get splitManagerState => _splitManagerState;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Getter for the loaded thumbnail URL
  String? get loadedThumbnailUrl => _loadedThumbnailUrl;
  
  // Getter for the pending deletion list (read-only view)
  List<String> get pendingDeletionGsUris => List.unmodifiable(_pendingDeletionGsUris);
  
  // Step navigation
  void goToStep(int step) {
    if (step >= 0 && step < 5) {
      _currentStep = step;
      notifyListeners();
    }
  }
  
  void nextStep() {
    if (_currentStep < 4) {
      _currentStep++;
      notifyListeners();
    }
  }
  
  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }
  
  // Data setters
  void setRestaurantName(String name) {
    _restaurantName = name;
    notifyListeners();
  }
  
  void setReceiptId(String id) {
    _receiptId = id;
    notifyListeners();
  }
  
  void setImageFile(File file) {
    // If there was a previous image URI, mark it for potential deletion
    if (_actualImageGsUri != null && _actualImageGsUri!.isNotEmpty) {
      _pendingDeletionGsUris.add(_actualImageGsUri!);
    }
    if (_actualThumbnailGsUri != null && _actualThumbnailGsUri!.isNotEmpty) {
      _pendingDeletionGsUris.add(_actualThumbnailGsUri!);
    }

    _imageFile = file;
    _loadedImageUrl = null; 
    _loadedThumbnailUrl = null; // Clear loaded thumbnail URL
    _actualImageGsUri = null; 
    _actualThumbnailGsUri = null; 
    _parseReceiptResult = {}; 
    notifyListeners();
  }
  
  void resetImageFile() {
    // If there was a previous image URI, mark it for potential deletion
    if (_actualImageGsUri != null && _actualImageGsUri!.isNotEmpty) {
      _pendingDeletionGsUris.add(_actualImageGsUri!);
    }
    if (_actualThumbnailGsUri != null && _actualThumbnailGsUri!.isNotEmpty) {
      _pendingDeletionGsUris.add(_actualThumbnailGsUri!);
    }

    _imageFile = null;
    _loadedImageUrl = null;
    _loadedThumbnailUrl = null; // Clear loaded thumbnail URL
    _actualImageGsUri = null;
    _actualThumbnailGsUri = null;
    _parseReceiptResult = {}; 
    notifyListeners();
  }
  
  void setParseReceiptResult(Map<String, dynamic> result) {
    // Ensure result map doesn't inadvertently contain old URI fields at root
    result.remove('image_uri');
    result.remove('thumbnail_uri');
    _parseReceiptResult = result;
    notifyListeners();
  }
  
  void setTranscribeAudioResult(Map<String, dynamic> result) {
    _transcribeAudioResult = result;
    notifyListeners();
  }
  
  void setAssignPeopleToItemsResult(Map<String, dynamic> result) {
    _assignPeopleToItemsResult = result;
    notifyListeners();
  }
  
  void setSplitManagerState(Map<String, dynamic> state) {
    _splitManagerState = state;
    notifyListeners();
  }
  
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
  
  void setLoadedImageUrl(String? url) {
    _loadedImageUrl = url;
    // If we are setting a loaded image URL, it implies there's no local file for now
    // _imageFile = null; // This might be too aggressive if just previewing
    notifyListeners();
  }
  
  void setActualImageGsUri(String? uri) {
    _actualImageGsUri = uri;
    notifyListeners();
  }

  void setActualThumbnailGsUri(String? uri) {
    _actualThumbnailGsUri = uri;
    notifyListeners();
  }

  void setLoadedThumbnailUrl(String? url) {
    _loadedThumbnailUrl = url;
    notifyListeners();
  }
  
  // Methods to manage the pending deletion list
  void clearPendingDeletions() {
    _pendingDeletionGsUris.clear();
    // No need to notify listeners, this is internal state management
  }

  void removeUriFromPendingDeletions(String? uri) {
    if (uri != null && uri.isNotEmpty) {
      _pendingDeletionGsUris.remove(uri);
      // No need to notify listeners
    }
  }

  void addUriToPendingDeletions(String? uri) {
    if (uri != null && uri.isNotEmpty && !_pendingDeletionGsUris.contains(uri)) {
        _pendingDeletionGsUris.add(uri);
    }
     // No need to notify listeners
  }
  
  // Convert to Receipt model for saving
  Receipt toReceipt() {
    return Receipt(
      id: _receiptId ?? FirebaseFirestore.instance.collection('temp').doc().id,
      restaurantName: _restaurantName,
      // URIs now come from the dedicated fields in WorkflowState for metadata
      imageUri: _actualImageGsUri,
      thumbnailUri: _actualThumbnailGsUri,
      // These sub-documents should not contain URIs if functions are updated
      parseReceipt: _parseReceiptResult,
      transcribeAudio: _transcribeAudioResult,
      assignPeopleToItems: _assignPeopleToItemsResult,
      splitManagerState: _splitManagerState,
      status: 'draft',
      people: _extractPeopleFromAssignments(),
      // TODO: Add tip/tax from splitManagerState if available for drafts too? Or only on complete?
      // For now, using defaults or values from _splitManagerState for tip/tax might be good
      // Or ensure these are set in metadata directly by the workflow state if needed for drafts.
    );
  }
  
  // Extract people from assignments for metadata
  List<String> _extractPeopleFromAssignments() {
    final List<String> people = [];
    
    if (_assignPeopleToItemsResult.containsKey('assignments') && 
        _assignPeopleToItemsResult['assignments'] is List) {
      final assignments = _assignPeopleToItemsResult['assignments'] as List;
      for (final assignment in assignments) {
        if (assignment is Map && assignment.containsKey('person_name')) {
          people.add(assignment['person_name'] as String);
        }
      }
    }
    
    return people;
  }
}

/// Dialog to prompt for restaurant name
Future<String?> showRestaurantNameDialog(BuildContext context, {String? initialName}) async {
  final TextEditingController controller = TextEditingController(text: initialName);
  
  return showDialog<String>(
    context: context,
    barrierDismissible: false, // User must respond to dialog
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Restaurant Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the name of the restaurant or store:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Restaurant Name',
                hintText: 'e.g., Joe\'s Diner',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null), // Cancel
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                // Show error if empty
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Restaurant name is required'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                Navigator.of(context).pop(name);
              }
            },
            child: const Text('CONTINUE'),
          ),
        ],
      );
    },
  );
}

/// Main workflow modal widget
class WorkflowModal extends StatelessWidget {
  final String? receiptId; // If null, this is a new receipt
  
  const WorkflowModal({Key? key, this.receiptId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WorkflowState(
        restaurantName: 'Unknown', // Will be updated in dialog
        receiptId: receiptId,
      ),
      child: const _WorkflowModalBody(),
    );
  }
  
  /// Static method to show the workflow modal with restaurant name dialog
  static Future<bool?> show(BuildContext context, {String? receiptId, String? initialRestaurantName}) async {
    String? finalRestaurantName = initialRestaurantName;

    // If a receiptId is provided, try to load the receipt and get its name
    if (receiptId != null && finalRestaurantName == null) {
      // Temporarily show a loading indicator or handle this state appropriately
      // For simplicity, we'll try to fetch it. In a real app, manage loading state.
      try {
        final firestoreService = FirestoreService();
        final snapshot = await firestoreService.getReceipt(receiptId);
        if (snapshot.exists) {
          final receipt = Receipt.fromDocumentSnapshot(snapshot);
          finalRestaurantName = receipt.restaurantName;
        }
      } catch (e) {
        // Log error or handle, for now, we'll proceed without pre-filled name
        debugPrint("Error fetching receipt name for modal: $e");
      }
    }

    // If restaurantName is still null, show the dialog to get it
    if (finalRestaurantName == null) {
      finalRestaurantName = await showRestaurantNameDialog(context);
    }
    
    // If the user cancels the dialog or name is still null, don't show the modal
    if (finalRestaurantName == null) {
      return null;
    }
    
    // Then show the workflow modal
    return await Navigator.of(context).push<bool?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ChangeNotifierProvider(
          create: (context) => WorkflowState(
            restaurantName: finalRestaurantName!, // finalRestaurantName is guaranteed non-null here
            receiptId: receiptId,
          ),
          child: const _WorkflowModalBody(),
        ),
      ),
    );
  }
}

class _WorkflowModalBody extends StatefulWidget {
  const _WorkflowModalBody({Key? key}) : super(key: key);

  @override
  State<_WorkflowModalBody> createState() => _WorkflowModalBodyState();
}

class _WorkflowModalBodyState extends State<_WorkflowModalBody> {
  final FirestoreService _firestoreService = FirestoreService();
  final List<String> _stepTitles = [
    'Upload',
    'Review',
    'Assign',
    'Split',
    'Summary',
  ];
  
  @override
  void initState() {
    super.initState();
    
    // Load the receipt data if we have a receipt ID
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final workflowState = Provider.of<WorkflowState>(context, listen: false);
      if (workflowState.receiptId != null) {
        _loadReceiptData(workflowState.receiptId!);
      }
    });
  }
  
  // Load receipt data from Firestore
  Future<void> _loadReceiptData(String receiptId) async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    try {
      workflowState.setLoading(true);
      workflowState.setErrorMessage(null);
      workflowState.setLoadedImageUrl(null);
      workflowState.setActualImageGsUri(null); // Reset before loading
      workflowState.setActualThumbnailGsUri(null); // Reset before loading
      
      final snapshot = await _firestoreService.getReceipt(receiptId);
      
      if (!snapshot.exists) {
        throw Exception('Receipt not found');
      }
      
      final receipt = Receipt.fromDocumentSnapshot(snapshot); // Receipt model now handles URI from metadata
      
      // --- Populate WorkflowState --- 
      if (receipt.restaurantName != null) {
        workflowState.setRestaurantName(receipt.restaurantName!); 
      }
      // Set authoritative GS URIs from the loaded receipt (which got them from metadata)
      if (receipt.imageUri != null) {
        workflowState.setActualImageGsUri(receipt.imageUri);
      }
      if (receipt.thumbnailUri != null) {
        workflowState.setActualThumbnailGsUri(receipt.thumbnailUri);
      }

      // Populate other results, ensuring they don't carry redundant URIs
      if (receipt.parseReceipt != null) {
        // Create a new map to avoid modifying the one from the Receipt model directly if it's cached
        Map<String, dynamic> cleanParseResult = Map.from(receipt.parseReceipt!);
        cleanParseResult.remove('image_uri'); // Ensure no old root URI
        cleanParseResult.remove('thumbnail_uri'); // Ensure no old root URI
        workflowState.setParseReceiptResult(cleanParseResult); 
      }
      if (receipt.transcribeAudio != null) {
        workflowState.setTranscribeAudioResult(receipt.transcribeAudio!); 
      }
       if (receipt.assignPeopleToItems != null) {
        workflowState.setAssignPeopleToItemsResult(receipt.assignPeopleToItems!); 
      }
      if (receipt.splitManagerState != null) {
        workflowState.setSplitManagerState(receipt.splitManagerState!); 
      }

      // --- Get Download URL for Main Image if actualImageGsUri exists --- 
      if (workflowState.actualImageGsUri != null && workflowState.actualImageGsUri!.startsWith('gs://')) {
        try {
          debugPrint('Attempting to get download URL for main image: ${workflowState.actualImageGsUri}');
          final ref = FirebaseStorage.instance.refFromURL(workflowState.actualImageGsUri!);
          final downloadUrl = await ref.getDownloadURL();
          debugPrint('Got main image download URL: $downloadUrl');
          workflowState.setLoadedImageUrl(downloadUrl); // For display
        } catch (e) {
          debugPrint('Error getting download URL for main image ${workflowState.actualImageGsUri}: $e');
          workflowState.setErrorMessage('Could not load saved image preview.');
          // Proceed without main image URL if thumbnail fails too
        }
      } else {
        debugPrint('No valid gs:// actualImageGsUri found in loaded receipt state for main image.');
      }

      // --- Get Download URL for Thumbnail if actualThumbnailGsUri exists --- 
      if (workflowState.actualThumbnailGsUri != null && workflowState.actualThumbnailGsUri!.startsWith('gs://')) {
        try {
          debugPrint('Attempting to get download URL for thumbnail: ${workflowState.actualThumbnailGsUri}');
          final ref = FirebaseStorage.instance.refFromURL(workflowState.actualThumbnailGsUri!);
          final thumbnailUrl = await ref.getDownloadURL();
          debugPrint('Got thumbnail download URL: $thumbnailUrl');
          workflowState.setLoadedThumbnailUrl(thumbnailUrl); // For faster preview
        } catch (e) {
          // Log error but don't necessarily block UI, main image might still load
          debugPrint('Error getting download URL for thumbnail ${workflowState.actualThumbnailGsUri}: $e');
          // Optionally set an error message specifically for thumbnail?
        }
      } else {
        debugPrint('No valid gs:// actualThumbnailGsUri found in loaded receipt state.');
      }

      // Determine target step (existing logic)
      int targetStep = 0;
      if (receipt.parseReceipt != null && 
          receipt.parseReceipt!.containsKey('items') && 
          receipt.parseReceipt!['items'] is List && 
          (receipt.parseReceipt!['items'] as List).isNotEmpty) {
        targetStep = 1;
      }
      if (receipt.assignPeopleToItems != null && 
          receipt.assignPeopleToItems!.containsKey('assignments') && 
          receipt.assignPeopleToItems!['assignments'] is List && 
          (receipt.assignPeopleToItems!['assignments'] as List).isNotEmpty) {
        workflowState.setAssignPeopleToItemsResult(receipt.assignPeopleToItems!);
        targetStep = 3; // Go to split view
      }
      if (receipt.splitManagerState != null && 
          receipt.splitManagerState!.isNotEmpty) {
        workflowState.setSplitManagerState(receipt.splitManagerState!);
        targetStep = 4; // Go to summary
      }
      
      // Navigate to the appropriate step
      workflowState.goToStep(targetStep);
      
      workflowState.setLoading(false);
      
    } catch (e) {
      workflowState.setLoading(false);
      workflowState.setErrorMessage('Failed to load receipt: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Show dialog when back button is pressed or Save & Exit is tapped
  Future<bool> _onWillPop() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    // If we're on the first step and nothing has been uploaded yet, just exit
    if (workflowState.currentStep == 0 && workflowState.imageFile == null) {
      return true;
    }
    
    // Auto-save as draft without confirmation
    try {
      // Show a saving indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saving draft...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      await _saveDraft();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      return true;
    } catch (e) {
      // If saving fails, show an error and ask what to do
      if (!mounted) return false;
      
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error Saving Draft'),
          content: Text(
            'There was an error saving your draft: $e\n\n'
            'Do you want to try again or discard changes?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Don't save, just exit
              child: const Text('DISCARD'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true), // Try again
              child: const Text('TRY AGAIN'),
            ),
          ],
        ),
      );
      
      if (result == true) {
        // Try again
        return _onWillPop();
      }
      
      // Discard and exit
      // Process deletions before exiting if changes are discarded
      await _processPendingDeletions(isSaving: false); 
      return true;
    }
  }
  
  // Helper function to delete orphaned images
  Future<void> _processPendingDeletions({required bool isSaving}) async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    // Create a copy to avoid concurrent modification issues if the list is somehow changed elsewhere
    final List<String> urisToDelete = List.from(workflowState.pendingDeletionGsUris);

    if (!isSaving) {
      // If not saving, also add the *current* URIs to the deletion list,
      // as they represent an unsaved background upload or loaded draft being discarded.
      if (workflowState.actualImageGsUri != null && workflowState.actualImageGsUri!.isNotEmpty && !urisToDelete.contains(workflowState.actualImageGsUri!)) {
          urisToDelete.add(workflowState.actualImageGsUri!);
      }
      if (workflowState.actualThumbnailGsUri != null && workflowState.actualThumbnailGsUri!.isNotEmpty && !urisToDelete.contains(workflowState.actualThumbnailGsUri!)) {
          urisToDelete.add(workflowState.actualThumbnailGsUri!);
      }
    }
    // If isSaving == true, we assume the calling method (_saveDraft/_completeReceipt) 
    // already removed the *saved* URIs from the state's pending list before calling this.

    if (urisToDelete.isEmpty) {
      debugPrint('[Cleanup] No pending URIs to delete.');
      return;
    }

    debugPrint('[Cleanup] Attempting to delete ${urisToDelete.length} orphaned URIs: $urisToDelete');

    // Use FirestoreService (add deleteImage method there)
    List<Future<void>> deleteFutures = [];
    for (final uri in urisToDelete) {
      deleteFutures.add(
        _firestoreService.deleteImage(uri).then((_) {
          debugPrint('[Cleanup] Successfully deleted: $uri');
        }).catchError((e) {
          // Log deletion errors but don't block the user flow
          debugPrint('[Cleanup] Error deleting URI $uri: $e');
          // Optionally, report this error more formally (e.g., to crash reporting)
        })
      );
    }

    // Wait for all deletions to attempt completion
    await Future.wait(deleteFutures);

    // Clear the list in the state after attempting all deletions
    // It's important this happens AFTER the await, even if some deletions failed.
    workflowState.clearPendingDeletions();
    debugPrint('[Cleanup] Processed all pending deletions.');
  }

  // Helper to upload image and generate thumbnail
  Future<Map<String, String?>> _uploadImageAndProcess(File imageFile) async {
    // This helper's responsibility is to upload and generate thumbnail, returning GS URIs.
    // It does NOT set WorkflowState directly.
    String? imageGsUri;
    String? thumbnailGsUri;

    // final workflowState = Provider.of<WorkflowState>(context, listen: false); // Not needed here

    try {
      debugPrint('_uploadImageAndProcess: Uploading image...');
      imageGsUri = await _firestoreService.uploadReceiptImage(imageFile);
      debugPrint('_uploadImageAndProcess: Image uploaded to: $imageGsUri');

      if (imageGsUri != null) {
        try {
          debugPrint('_uploadImageAndProcess: Generating thumbnail...');
          thumbnailGsUri = await _firestoreService.generateThumbnail(imageGsUri);
          debugPrint('_uploadImageAndProcess: Thumbnail generated: $thumbnailGsUri');
        } catch (thumbError) {
          debugPrint('_uploadImageAndProcess: Error generating thumbnail (proceeding without it): $thumbError');
        }
      } else {
         debugPrint('_uploadImageAndProcess: Skipping thumbnail generation because imageGsUri is null.');
      }
    } catch (uploadError) {
       debugPrint('_uploadImageAndProcess: Error during image upload: $uploadError');
       rethrow;
    }
    return {'imageUri': imageGsUri, 'thumbnailUri': thumbnailGsUri};
  }

  // Save the current state as a draft
  Future<void> _saveDraft() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);

    try {
      workflowState.setLoading(true);
      workflowState.setErrorMessage(null);

      // --- Conditional Upload --- 
      // Upload only if a local file exists AND the GS URI hasn't been set yet 
      // (e.g., background upload didn't finish or wasn't triggered).
      if (workflowState.imageFile != null && workflowState.actualImageGsUri == null) 
      {
        debugPrint('_saveDraft: Local image present without actual GS URI. Uploading synchronously before saving...');
        try {
          final uris = await _uploadImageAndProcess(workflowState.imageFile!);
          workflowState.setActualImageGsUri(uris['imageUri']);
          workflowState.setActualThumbnailGsUri(uris['thumbnailUri']);
          debugPrint('_saveDraft: Synchronous image upload complete. Actual GS URIs set in WorkflowState.');
        } catch (e) {
           debugPrint('_saveDraft: Error uploading image during save: $e');
           workflowState.setLoading(false); 
           workflowState.setErrorMessage('Failed to upload image while saving draft: ${e.toString()}');
           rethrow; // Prevent saving draft if upload fails
        }
      }
      // If imageFile is null but loadedImageUrl/actualImageGsUri is present, we don't need to upload again.

      final receipt = workflowState.toReceipt(); // Gets URIs from actualImageGsUri/ThumbnailGsUri

      final String definitiveReceiptId = await _firestoreService.saveDraft(
        receiptId: receipt.id, 
        data: receipt.toMap(), // toMap() places URIs in metadata
      );

      workflowState.setReceiptId(definitiveReceiptId);
      workflowState.setLoading(false);

      // Remove successfully saved URIs from the pending deletion list
      workflowState.removeUriFromPendingDeletions(workflowState.actualImageGsUri);
      workflowState.removeUriFromPendingDeletions(workflowState.actualThumbnailGsUri);
      
      // Process any remaining deletions (e.g., from rapid re-selection before save)
      // Pass isSaving: true so it only deletes what's left in the list.
      await _processPendingDeletions(isSaving: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) { 
      workflowState.setLoading(false);
      if (workflowState.errorMessage == null) {
         workflowState.setErrorMessage('Failed to save draft: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(workflowState.errorMessage ?? 'Failed to save draft: $e'), // Show specific error if available
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }
  
  // Build the step indicator
  Widget _buildStepIndicator(int currentStep) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step indicator dots and lines
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _stepTitles.length * 2 - 1,
              (index) {
                // If index is even, show a dot
                if (index % 2 == 0) {
                  final stepIndex = index ~/ 2;
                  final isActive = stepIndex == currentStep;
                  final isCompleted = stepIndex < currentStep;
                  
                  return Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : isCompleted
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceVariant,
                      border: Border.all(
                        color: isActive || isCompleted
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    child: isCompleted
                        ? Icon(
                            Icons.check,
                            size: 12,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          )
                        : null,
                  );
                } else {
                  // If index is odd, show a line
                  final lineIndex = index ~/ 2;
                  final isCompleted = lineIndex < currentStep;
                  
                  return Container(
                    width: 24,
                    height: 2,
                    color: isCompleted
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          
          // Step titles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _stepTitles.length,
              (index) => Container(
                width: 72,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _stepTitles[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: index == currentStep ? FontWeight.bold : FontWeight.normal,
                    color: index == currentStep
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build the content for the current step
  Widget _buildStepContent(int currentStep) {
    final workflowState = Provider.of<WorkflowState>(context);
    
    switch (currentStep) {
      case 0: // Upload
        // Extract potential imageUrl from the state
        final bool isSuccessfullyParsed = workflowState.parseReceiptResult.containsKey('items') &&
                                          (workflowState.parseReceiptResult['items'] as List?)?.isNotEmpty == true;
            
        return ReceiptUploadScreen(
          imageFile: workflowState.imageFile, // Local file if selected
          imageUrl: workflowState.loadedImageUrl, // Pass the fetched download URL
          isLoading: workflowState.isLoading,
          isSuccessfullyParsed: isSuccessfullyParsed, // Pass the new flag
          onImageSelected: (file) async {
            if (file != null) {
              workflowState.setImageFile(file);
              workflowState.setErrorMessage(null);

              // Start optimistic background upload
              debugPrint('[WorkflowModal onImageSelected] New file selected. Starting background upload...');
              // No global loading indicator here, let UI handle if needed. Upload is in background.
              _uploadImageAndProcess(file).then((uris) {
                // Critical: Check if the context is still valid and the imageFile in state 
                // is still the one we initiated this upload for.
                if (mounted && workflowState.imageFile == file) {
                  workflowState.setActualImageGsUri(uris['imageUri']);
                  workflowState.setActualThumbnailGsUri(uris['thumbnailUri']);
                  debugPrint('[WorkflowModal onImageSelected] Background upload complete. Actual GS URIs set for ${uris['imageUri']}.');
                } else {
                  debugPrint('[WorkflowModal onImageSelected] Background upload complete, but context changed or image no longer matches. URIs not set or will be overwritten.');
                  // TODO: If uris['imageUri'] is not null, this image is now orphaned. Add to a cleanup list (Phase 3 cleanup).
                  // For now, we are not implementing immediate deletion here to avoid complexity if the user quickly reselects.
                }
              }).catchError((error) {
                if (mounted && workflowState.imageFile == file) { // Error for the current file
                  debugPrint('[WorkflowModal onImageSelected] Background upload failed: $error');
                  workflowState.setErrorMessage('Background image upload failed. Please try parsing again or reselect.');
                  // Do not clear actualImageGsUri here, as it might be from a previously successful load.
                  // The user will have to explicitly retry or re-select.
                } else {
                  debugPrint('[WorkflowModal onImageSelected] Background upload failed for an outdated image selection: $error');
                }
              });

            } else {
              // Clearing selection
              // String? gsUriToPotentiallyDelete = workflowState.actualImageGsUri;
              workflowState.resetImageFile(); // This clears imageFile, loadedImageUrl, actualImageGsUri, actualThumbnailGsUri, and parseResult
              workflowState.setErrorMessage(null);
              // TODO: If gsUriToPotentiallyDelete was not null, it's now orphaned. Add to cleanup list (Phase 3 cleanup).
            }
          },
          onParseReceipt: () async {
            workflowState.setLoading(true); // Global loading for this explicit action
            workflowState.setErrorMessage(null);
            
            String? gsUriForParsing;

            try {
              // Determine the GS URI for parsing
              if (workflowState.actualImageGsUri != null && workflowState.actualImageGsUri!.isNotEmpty) {
                // URI already available (e.g., from background upload or loaded draft)
                gsUriForParsing = workflowState.actualImageGsUri;
                debugPrint('[WorkflowModal onParseReceipt] Using pre-existing actualImageGsUri: $gsUriForParsing');
              } else if (workflowState.imageFile != null) {
                // Local file exists, but no GS URI yet. Upload it now.
                debugPrint('[WorkflowModal onParseReceipt] Local file detected, no GS URI yet. Uploading synchronously...');
                final uris = await _uploadImageAndProcess(workflowState.imageFile!);
                workflowState.setActualImageGsUri(uris['imageUri']);
                workflowState.setActualThumbnailGsUri(uris['thumbnailUri']);
                gsUriForParsing = uris['imageUri'];
                debugPrint('[WorkflowModal onParseReceipt] Synchronous upload complete. Actual GS URIs set. Using: $gsUriForParsing');
              } else if (workflowState.loadedImageUrl != null) {
                // This case implies a draft was loaded, and actualImageGsUri should have been set during _loadReceiptData.
                // If actualImageGsUri is null here, it indicates an issue with draft loading or state.
                debugPrint('[WorkflowModal onParseReceipt] CRITICAL: loadedImageUrl is present, but actualImageGsUri is missing. This should not happen if draft loaded correctly.');
                throw Exception('Image loaded from draft, but its GS URI is missing in state.');
              } else {
                // No image available at all
                debugPrint('[WorkflowModal onParseReceipt] No image selected or available for parsing.');
                workflowState.setLoading(false);
                workflowState.setErrorMessage('Please select an image first.');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select an image first.'), backgroundColor: Colors.red),
                  );
                }
                return;
              }

              // Final check for GS URI before parsing
              if (gsUriForParsing == null || gsUriForParsing.isEmpty) {
                debugPrint('[WorkflowModal onParseReceipt] CRITICAL: gsUriForParsing is null or empty before parsing attempt after all checks.');
                throw Exception('Image URI could not be determined for parsing.');
              }

              // Parsing logic (shouldParse, call ReceiptParserService, etc.)
              Map<String, dynamic> newParseResult = {}; 

              // Determine if parsing is needed. 
              // If actualImageGsUri was just set by a new upload (workflowState.imageFile was not null path), always parse.
              // If actualImageGsUri was from a loaded draft, parse only if items are missing.
              bool isNewImageJustUploaded = workflowState.imageFile != null; // Heuristic: if local file was source of URI path

              bool shouldParse = isNewImageJustUploaded || 
                                 (!workflowState.parseReceiptResult.containsKey('items')) || 
                                 ((workflowState.parseReceiptResult['items'] as List?)?.isEmpty ?? true);

              if (shouldParse) {
                debugPrint('[WorkflowModal onParseReceipt] Parsing needed. Calling ReceiptParserService.parseReceipt with GsUri: $gsUriForParsing');
                final ReceiptData parsedData = await ReceiptParserService.parseReceipt(gsUriForParsing);
                
                newParseResult['items'] = parsedData.items;
                newParseResult['subtotal'] = parsedData.subtotal;
                workflowState.setParseReceiptResult(newParseResult); // This now only sets items and subtotal
                debugPrint('[WorkflowModal onParseReceipt] Receipt parsed successfully. Items count: ${parsedData.items.length}');
              } else {
                debugPrint('[WorkflowModal onParseReceipt] Parsing not needed. Using existing items from parseReceiptResult.');
              }

              workflowState.setLoading(false);
              workflowState.nextStep();

            } catch (e) { 
              debugPrint('[WorkflowModal onParseReceipt] Error: $e');
              workflowState.setLoading(false);
              workflowState.setErrorMessage('Failed to process/parse receipt: ${e.toString()}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to process/parse receipt: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            }
          },
          onRetry: () { 
            workflowState.resetImageFile();
            workflowState.setErrorMessage(null); 
          },
        );
        
      case 1: // Review
        // Convert receipt data to ReceiptItem objects for review
        final List<ReceiptItem> items = _convertToReceiptItems(workflowState.parseReceiptResult);
        
        return ReceiptReviewScreen(
          initialItems: items,
          onReviewComplete: (updatedItems, deletedItems) {
            // Update the parse receipt result with the updated items
            final parseResult = Map<String, dynamic>.from(workflowState.parseReceiptResult);
            
            // Convert updated items back to the expected format
            final updatedItemsList = updatedItems.map((item) => {
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
            }).toList();
            
            parseResult['items'] = updatedItemsList;
            
            // Update the state
            workflowState.setParseReceiptResult(parseResult);
            
            // Advance to the next step
            workflowState.nextStep();
          },
        );
        
      case 2: // Assign
        // Convert receipt data to ReceiptItem objects for assignment
        final List<ReceiptItem> items = _convertToReceiptItems(workflowState.parseReceiptResult);
        
        return VoiceAssignmentScreen(
          itemsToAssign: items,
          onAssignmentProcessed: (assignmentData) {
            // Save the assignment data
            workflowState.setAssignPeopleToItemsResult(assignmentData);
            
            // Go to next step
            workflowState.nextStep();
          },
          initialTranscription: workflowState.transcribeAudioResult.containsKey('text') 
              ? workflowState.transcribeAudioResult['text'] as String?
              : null,
          onTranscriptionChanged: (transcription) {
            if (transcription != null) {
              // Save the transcription
              final transcribeResult = Map<String, dynamic>.from(workflowState.transcribeAudioResult);
              transcribeResult['text'] = transcription;
              workflowState.setTranscribeAudioResult(transcribeResult);
            }
          },
        );
        
      case 3: // Split
        return ChangeNotifierProvider(
          create: (context) {
            // Convert assignPeopleToItems to SplitManager
            final splitManager = SplitManager();
            
            // Extract assignments data
            final splitData = workflowState.assignPeopleToItemsResult;
            
            if (splitData.containsKey('assignments') && splitData['assignments'] is List) {
              final assignments = splitData['assignments'] as List;
              
              // First, create all people
              for (final personData in assignments) {
                if (personData is Map && personData.containsKey('person_name')) {
                  final personName = personData['person_name'] as String;
                  splitManager.addPerson(personName);
                }
              }
              
              // Then add all items to the appropriate person
              for (final personData in assignments) {
                if (personData is Map && 
                    personData.containsKey('person_name') && 
                    personData.containsKey('items')) {
                  final personName = personData['person_name'] as String;
                  final items = personData['items'] as List;
                  
                  // Find the person object
                  final person = splitManager.people.firstWhere(
                    (p) => p.name == personName,
                    orElse: () => throw Exception('Person not found: $personName'),
                  );
                  
                  // Add each item to this person
                  for (final itemData in items) {
                    if (itemData is Map) {
                      try {
                        final receiptItem = ReceiptItem(
                          name: itemData['name'] as String,
                          price: (itemData['price'] as num).toDouble(),
                          quantity: itemData['quantity'] as int,
                        );
                        splitManager.assignItemToPerson(receiptItem, person);
                      } catch (e) {
                        print('Error processing assigned item: $e');
                      }
                    }
                  }
                  
                  // Add shared items (will be properly connected later)
                  if (personData.containsKey('shared_items') && personData['shared_items'] is List) {
                    final sharedItems = personData['shared_items'] as List;
                    for (final itemData in sharedItems) {
                      if (itemData is Map) {
                        try {
                          final receiptItem = ReceiptItem(
                            name: itemData['name'] as String,
                            price: (itemData['price'] as num).toDouble(),
                            quantity: itemData['quantity'] as int,
                          );
                          
                          // Check if this item is already in the shared items list
                          final existingItem = splitManager.sharedItems.firstWhere(
                            (item) => item.name == receiptItem.name && item.price == receiptItem.price,
                            orElse: () => receiptItem, // Use the new item if not found
                          );
                          
                          if (!splitManager.sharedItems.contains(existingItem)) {
                            splitManager.addItemToShared(existingItem, [person]);
                          } else {
                            splitManager.addPersonToSharedItem(existingItem, person);
                          }
                        } catch (e) {
                          print('Error processing shared item: $e');
                        }
                      }
                    }
                  }
                }
              }
            }
            
            // Add unassigned items if any
            if (splitData.containsKey('unassigned_items') && splitData['unassigned_items'] is List) {
              final unassignedItems = splitData['unassigned_items'] as List;
              for (final itemData in unassignedItems) {
                if (itemData is Map) {
                  try {
                    final receiptItem = ReceiptItem(
                      name: itemData['name'] as String,
                      price: (itemData['price'] as num).toDouble(),
                      quantity: itemData['quantity'] as int,
                    );
                    splitManager.addUnassignedItem(receiptItem);
                  } catch (e) {
                    print('Error processing unassigned item: $e');
                  }
                }
              }
            }
            
            // Update split manager with any state from previous sessions
            if (workflowState.splitManagerState.isNotEmpty) {
              if (workflowState.splitManagerState.containsKey('tipPercentage')) {
                splitManager.tipPercentage = (workflowState.splitManagerState['tipPercentage'] as num).toDouble();
              }
              
              if (workflowState.splitManagerState.containsKey('taxPercentage')) {
                splitManager.taxPercentage = (workflowState.splitManagerState['taxPercentage'] as num).toDouble();
              }
            }
            
            return splitManager;
          },
          child: NotificationListener<NavigateToPageNotification>(
            onNotification: (notification) {
              // If requested, navigate to specified page
              if (notification.pageIndex < 5) {
                workflowState.goToStep(notification.pageIndex);
              }
              return true;
            },
            child: const SplitView(),
          ),
        );
        
      case 4: // Summary
        return ChangeNotifierProvider(
          create: (context) {
            // Convert assignPeopleToItems to SplitManager
            final splitManager = SplitManager();
            
            // Extract assignments data
            final splitData = workflowState.assignPeopleToItemsResult;
            
            if (splitData.containsKey('assignments') && splitData['assignments'] is List) {
              final assignments = splitData['assignments'] as List;
              
              // First, create all people
              for (final personData in assignments) {
                if (personData is Map && personData.containsKey('person_name')) {
                  final personName = personData['person_name'] as String;
                  splitManager.addPerson(personName);
                }
              }
              
              // Then add all items to the appropriate person
              for (final personData in assignments) {
                if (personData is Map && 
                    personData.containsKey('person_name') && 
                    personData.containsKey('items')) {
                  final personName = personData['person_name'] as String;
                  final items = personData['items'] as List;
                  
                  // Find the person object
                  final person = splitManager.people.firstWhere(
                    (p) => p.name == personName,
                    orElse: () => throw Exception('Person not found: $personName'),
                  );
                  
                  // Add each item to this person
                  for (final itemData in items) {
                    if (itemData is Map) {
                      try {
                        final receiptItem = ReceiptItem(
                          name: itemData['name'] as String,
                          price: (itemData['price'] as num).toDouble(),
                          quantity: itemData['quantity'] as int,
                        );
                        splitManager.assignItemToPerson(receiptItem, person);
                      } catch (e) {
                        print('Error processing assigned item: $e');
                      }
                    }
                  }
                  
                  // Add shared items (will be properly connected later)
                  if (personData.containsKey('shared_items') && personData['shared_items'] is List) {
                    final sharedItems = personData['shared_items'] as List;
                    for (final itemData in sharedItems) {
                      if (itemData is Map) {
                        try {
                          final receiptItem = ReceiptItem(
                            name: itemData['name'] as String,
                            price: (itemData['price'] as num).toDouble(),
                            quantity: itemData['quantity'] as int,
                          );
                          
                          // Check if this item is already in the shared items list
                          final existingItem = splitManager.sharedItems.firstWhere(
                            (item) => item.name == receiptItem.name && item.price == receiptItem.price,
                            orElse: () => receiptItem, // Use the new item if not found
                          );
                          
                          if (!splitManager.sharedItems.contains(existingItem)) {
                            splitManager.addItemToShared(existingItem, [person]);
                          } else {
                            splitManager.addPersonToSharedItem(existingItem, person);
                          }
                        } catch (e) {
                          print('Error processing shared item: $e');
                        }
                      }
                    }
                  }
                }
              }
            }
            
            // Add unassigned items if any
            if (splitData.containsKey('unassigned_items') && splitData['unassigned_items'] is List) {
              final unassignedItems = splitData['unassigned_items'] as List;
              for (final itemData in unassignedItems) {
                if (itemData is Map) {
                  try {
                    final receiptItem = ReceiptItem(
                      name: itemData['name'] as String,
                      price: (itemData['price'] as num).toDouble(),
                      quantity: itemData['quantity'] as int,
                    );
                    splitManager.addUnassignedItem(receiptItem);
                  } catch (e) {
                    print('Error processing unassigned item: $e');
                  }
                }
              }
            }
            
            // Update split manager with state from previous sessions
            if (workflowState.splitManagerState.isNotEmpty) {
              if (workflowState.splitManagerState.containsKey('tipPercentage')) {
                splitManager.tipPercentage = (workflowState.splitManagerState['tipPercentage'] as num).toDouble();
              }
              
              if (workflowState.splitManagerState.containsKey('taxPercentage')) {
                splitManager.taxPercentage = (workflowState.splitManagerState['taxPercentage'] as num).toDouble();
              }
            }
            
            return splitManager;
          },
          child: Column(
            children: [
              const Expanded(
                child: FinalSummaryScreen(),
              ),
              // Listen for navigation requests from Summary screen to go back to Split
              NotificationListener<NavigateToPageNotification>(
                onNotification: (notification) {
                  // If requested, navigate to specified page
                  if (notification.pageIndex < 5) {
                    workflowState.goToStep(notification.pageIndex);
                  }
                  return true;
                },
                child: const SizedBox.shrink(), // Empty container as we're just listening
              ),
            ],
          ),
        );
        
      default:
        return const Center(child: Text('Unknown Step'));
    }
  }
  
  // Build the navigation buttons
  Widget _buildNavigation(int currentStep) {
    final workflowState = Provider.of<WorkflowState>(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button (hidden on first step)
          TextButton.icon(
            onPressed: currentStep > 0
                ? () => workflowState.previousStep()
                : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          ),
          
          // Middle button - Exit for steps 0-3, Save Draft for step 4
          currentStep < 4 
              ? OutlinedButton(
                  onPressed: () async {
                    // _onWillPop handles saving. If it allows pop (returns true), pop with true.
                    final bool canPop = await _onWillPop(); 
                    if (canPop && mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Exit'),
                )
              : OutlinedButton(
                  onPressed: () async {
                    await _saveDraft(); // Assumes _saveDraft shows its own errors/success
                    if (mounted) {
                      Navigator.of(context).pop(true); // Pop true after saving draft
                    }
                  },
                  child: const Text('Save Draft'),
                ),
          
          // Next/Complete button
          currentStep < 4
              ? FilledButton.icon(
                  onPressed: () => workflowState.nextStep(),
                  label: const Text('Next'),
                  icon: const Icon(Icons.arrow_forward),
                )
              : FilledButton.icon(
                  onPressed: () => _completeReceipt(),
                  label: const Text('Complete'),
                  icon: const Icon(Icons.check),
                ),
        ],
      ),
    );
  }

  // Mark the current receipt as completed
  Future<void> _completeReceipt() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    try {
      // Show loading indicator
      workflowState.setLoading(true);
      workflowState.setErrorMessage(null);
      
      // Get tip and tax values from Split manager
      final splitManagerState = workflowState.splitManagerState;
      double? tip;
      double? tax;
      
      if (splitManagerState.containsKey('tipPercentage')) {
        tip = (splitManagerState['tipPercentage'] as num).toDouble();
      }
      
      if (splitManagerState.containsKey('taxPercentage')) {
        tax = (splitManagerState['taxPercentage'] as num).toDouble();
      }
      
      // Convert state to Receipt model
      final receipt = workflowState.toReceipt();
      
      // Save to Firestore as completed
      final receiptId = await _firestoreService.completeReceipt(
        receiptId: workflowState.receiptId!,
        data: receipt.toMap(),
        restaurantName: workflowState.restaurantName,
        tip: tip,
        tax: tax,
      );
      
      // Done
      workflowState.setLoading(false);
      
      // Remove successfully completed URIs from the pending deletion list
      workflowState.removeUriFromPendingDeletions(workflowState.actualImageGsUri);
      workflowState.removeUriFromPendingDeletions(workflowState.actualThumbnailGsUri);

      // Process any remaining deletions
      // Pass isSaving: true so it only deletes what's left in the list.
      await _processPendingDeletions(isSaving: true);

      if (mounted) {
        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return to receipts screen
        Navigator.of(context).pop(true); // Pop true after completing receipt
      }
    } catch (e) {
      // Show error
      workflowState.setLoading(false);
      workflowState.setErrorMessage('Failed to complete receipt: $e');
      
      if (mounted) {
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workflowState = Provider.of<WorkflowState>(context);
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(workflowState.restaurantName),
          // Don't show automatic back button
          automaticallyImplyLeading: false,
          // Override the back button to show our confirmation dialog
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final bool canPop = await _onWillPop(); // Handles confirmation/saving/deletion on discard
              if (canPop && mounted) {
                // _onWillPop already handles calling _processPendingDeletions if discarding.
                // If saving occurred within _onWillPop, deletions were also handled there.
                Navigator.of(context).pop(true); // Pop with true indicating a potential change
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Step indicator
            _buildStepIndicator(workflowState.currentStep),
            
            // Current step content
            Expanded(
              child: _buildStepContent(workflowState.currentStep),
            ),
            
            // Navigation
            _buildNavigation(workflowState.currentStep),
          ],
        ),
      ),
    );
  }

  // Helper method to convert parse receipt result to ReceiptItem objects
  List<ReceiptItem> _convertToReceiptItems(Map<String, dynamic> parseReceiptResult) {
    final List<ReceiptItem> items = [];
    
    if (parseReceiptResult.containsKey('items') && parseReceiptResult['items'] is List) {
      final rawItems = parseReceiptResult['items'] as List;
      for (final rawItem in rawItems) {
        if (rawItem is Map) {
          try {
            // Defensive parsing for each field
            final String itemName = rawItem['item'] as String? ?? 'Unknown Item'; // Default if name is null
            
            final num? itemPriceNum = rawItem['price'] as num?;
            final double itemPrice = itemPriceNum?.toDouble() ?? 0.0; // Default if price is null or not a number
            
            final num? itemQuantityNum = rawItem['quantity'] as num?;
            final int itemQuantity = itemQuantityNum?.toInt() ?? 1; // Default if quantity is null or not a number

            items.add(ReceiptItem(
              name: itemName,
              price: itemPrice,
              quantity: itemQuantity,
            ));
          } catch (e) {
            // Log more specific details about the problematic item if possible
            print('Error parsing item: $e. Raw item data: $rawItem');
          }
        }
      }
    }
    
    return items;
  }
} 