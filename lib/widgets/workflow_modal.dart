import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../models/person.dart';
import '../services/firestore_service.dart';
import '../models/split_manager.dart';
import '../screens/receipt_upload_screen.dart';
import '../screens/receipt_review_screen.dart';
import '../screens/voice_assignment_screen.dart';
import '../screens/final_summary_screen.dart';
import '../widgets/split_view.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/receipt_parser_service.dart';
import '../services/audio_transcription_service.dart' hide Person;
import 'dart:async';
import 'package:flutter/foundation.dart';
import './image_state_manager.dart'; // Import the new manager
import '../providers/workflow_state.dart'; // ADDED: Import for moved WorkflowState
import './workflow_steps/upload_step_widget.dart'; // Corrected import path
import './workflow_steps/review_step_widget.dart'; // Import ReviewStepWidget
import './workflow_steps/assign_step_widget.dart'; // Import AssignStepWidget
import './workflow_steps/split_step_widget.dart'; // Import SplitStepWidget
import './workflow_steps/summary_step_widget.dart'; // Import SummaryStepWidget
import '../utils/dialog_helpers.dart'; // Added import
import './workflow_steps/workflow_step_indicator.dart'; // Import new widget
import './workflow_steps/workflow_navigation_controls.dart'; // Import new widget
import '../utils/toast_utils.dart'; // Import the new toast utility

// --- Moved Typedef to top level --- 
// Callback type for ReceiptReviewScreen to provide its current items
typedef GetCurrentItemsCallback = List<ReceiptItem> Function();

/// Define NavigateToPageNotification class here to match the one in split_view.dart
/// This avoids having to expose that class in a separate file while maintaining compatibility
class NavigateToPageNotification extends Notification {
  final int pageIndex;
  
  NavigateToPageNotification(this.pageIndex);
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
    final firestoreService = FirestoreService(); // Instance it once

    // If a receiptId is provided, try to load the receipt and get its name
    if (receiptId != null && finalRestaurantName == null) {
      try {
        // Check context before the first await if this block is entered
        if (!context.mounted) {
          debugPrint("[WorkflowModal.show] Context unmounted before fetching receipt details for ID: $receiptId");
          return null;
        }
        final snapshot = await firestoreService.getReceipt(receiptId);

        // Check context immediately after await
        if (!context.mounted) {
          // THIS IS THE SOURCE OF YOUR LOG MESSAGE
          debugPrint("[WorkflowModal.show] Calling context for receiptId '$receiptId' unmounted after 'firestoreService.getReceipt()' await."); // MODIFIED: Clarified log message
          return null;
        }

        if (snapshot.exists) {
          final receipt = Receipt.fromDocumentSnapshot(snapshot);
          finalRestaurantName = receipt.restaurantName;
        } else {
          debugPrint("[WorkflowModal.show] Receipt with ID $receiptId not found.");
          if (context.mounted) {
             showAppToast(context, "Draft receipt not found.", AppToastType.warning);
          }
          return null; // Don't proceed if receipt not found
        }
      } catch (e) {
        debugPrint("[WorkflowModal.show] Error fetching receipt details for modal: $e");
        if (context.mounted) {
          showAppToast(context, "Error loading draft: ${e.toString()}", AppToastType.error);
        }
        return null; // Don't proceed on error
      }
    }

    // If restaurantName is still null (e.g. new receipt, or above fetch failed to set it), show the dialog
    if (finalRestaurantName == null) {
      // Check context before this await as well
      if (!context.mounted) {
        debugPrint("[WorkflowModal.show] Context unmounted before showing restaurant name dialog.");
        return null;
      }
      finalRestaurantName = await showRestaurantNameDialog(context); // showRestaurantNameDialog now has its own internal mounted check
      
      // Check context again after this await
      if (!context.mounted) {
        debugPrint("[WorkflowModal.show] Context unmounted after showing restaurant name dialog.");
        return null;
      }
    }
    
    // If the user cancels the dialog or name is still null, don't show the modal
    if (finalRestaurantName == null) {
      return null;
    }

    // Final safety check before navigation (this was the one logging your error)
    if (!context.mounted) {
       debugPrint("[WorkflowModal.show] Error: Context is not mounted before navigation.");
       return null; 
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) {
       debugPrint("[WorkflowModal.show] Error: Could not find a Navigator ancestor for the provided context.");
       return null; 
    }
    
    // Then show the workflow modal using the safe navigator reference
    return await navigator.push<bool?>(
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

class _WorkflowModalBodyState extends State<_WorkflowModalBody> with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  final List<String> _stepTitles = [
    'Upload',
    'Assign',
    'Summary',
  ];
  int _initialSplitViewTabIndex = 0;
  bool _isDraftLoading = false; // Added for initial draft load
  
  // Variable to hold the function provided by ReceiptReviewScreen
  GetCurrentItemsCallback? _getCurrentReviewItemsCallback;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Load the receipt data if we have a receipt ID
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final workflowState = Provider.of<WorkflowState>(context, listen: false);
      if (workflowState.receiptId != null) {
        if (mounted) { // Check mounted before initial setState
          setState(() { 
            _isDraftLoading = true; 
          });
        }
        _loadReceiptData(workflowState.receiptId!).then((_) {
          if (mounted) { 
             setState(() { 
               _isDraftLoading = false;
             });
          }
        }).catchError((error) {
             if (mounted) {
                setState(() {
                    _isDraftLoading = false; 
                });
             }
             debugPrint("Error in _loadReceiptData during initState: $error");
             // Optionally, show a persistent error message if draft loading fails critically
             // workflowState.setErrorMessage("Failed to load draft. Please try again.");
        });
      }
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Only attempt to save if there's potentially something to save.
      // This mirrors part of the logic in _onWillPop.
      final workflowState = Provider.of<WorkflowState>(context, listen: false);
      if (workflowState.imageFile != null || workflowState.receiptId != null || workflowState.hasParseData) {
        debugPrint("[WorkflowModal] App paused, attempting to save draft...");
        _saveDraft(isBackgroundSave: true).catchError((e) {
          // Log error from background save, as no SnackBar will be shown by _saveDraft.
          debugPrint("[WorkflowModal] Error during background save draft: $e");
        });
      }
    }
  }
  
  // Load receipt data from Firestore
  Future<void> _loadReceiptData(String receiptId) async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    try {
      workflowState.setLoading(true);
      workflowState.setErrorMessage(null);
      workflowState.setLoadedImageUrls(null, null); // Clears both loaded URLs
      workflowState.setActualGsUrisOnLoad(null, null); // Clears both actual GS URIs
      
      final snapshot = await _firestoreService.getReceipt(receiptId);
      
      if (!snapshot.exists) {
        throw Exception('Receipt not found');
      }
      
      final receipt = Receipt.fromDocumentSnapshot(snapshot);
      
      if (receipt.restaurantName != null) {
        workflowState.setRestaurantName(receipt.restaurantName!); 
      }
      // Set both actual URIs from the loaded receipt data
      workflowState.setActualGsUrisOnLoad(receipt.imageUri, receipt.thumbnailUri);
      debugPrint('[_loadReceiptData] Loaded from Firestore. WorkflowState updated - ActualImageGsUri: ${workflowState.actualImageGsUri}, ActualThumbnailGsUri: ${workflowState.actualThumbnailGsUri}');

      // Load sub-document data, defaulting to empty maps if null from Firestore
      // This ensures WorkflowState always has valid, non-null maps for these.
      Map<String, dynamic> parseResultFromDraft = receipt.parseReceipt ?? {};
      parseResultFromDraft.remove('image_uri'); // Clean old fields
      parseResultFromDraft.remove('thumbnail_uri');
      workflowState.setParseReceiptResult(parseResultFromDraft);
      
      debugPrint('[_loadReceiptData] Data from Firestore for receipt.transcribeAudio: ${receipt.transcribeAudio}');
      workflowState.setTranscribeAudioResult(receipt.transcribeAudio); 
      workflowState.setAssignPeopleToItemsResult(receipt.assignPeopleToItems); // This will call _extractPeopleFromAssignments and update _people
      workflowState.setTip(receipt.tip);
      workflowState.setTax(receipt.tax);
      // workflowState.setPeople(receipt.people ?? []); // REMOVED: _people is now derived from assignPeopleToItemsResult
      
      // --- Concurrently get Download URLs for Main Image and Thumbnail ---
      String? loadedImageUrl;
      String? loadedThumbnailUrl;

      Future<String?> getMainImageUrl() async {
        if (workflowState.actualImageGsUri != null && workflowState.actualImageGsUri!.startsWith('gs://')) {
          final stopwatch = Stopwatch()..start(); // Start timer
          try {
            debugPrint('[LoadData Timer] Getting download URL for main image: ${workflowState.actualImageGsUri}');
            final ref = FirebaseStorage.instance.refFromURL(workflowState.actualImageGsUri!);
            final url = await ref.getDownloadURL();
            stopwatch.stop(); // Stop timer
            debugPrint('[LoadData Timer] Got main image download URL in ${stopwatch.elapsedMilliseconds}ms: $url');
            return url;
          } catch (e) {
            stopwatch.stop(); // Stop timer on error too
            debugPrint('[LoadData Timer] Error getting download URL for main image ${workflowState.actualImageGsUri} after ${stopwatch.elapsedMilliseconds}ms: $e');
            return null; 
          }
        } else {
           debugPrint('[LoadData Timer] No valid gs:// actualImageGsUri found for main image.');
           return null;
        }
      }

      Future<String?> getThumbnailImageUrl() async {
         if (workflowState.actualThumbnailGsUri != null && workflowState.actualThumbnailGsUri!.startsWith('gs://')) {
          final stopwatch = Stopwatch()..start(); // Start timer
          try {
            debugPrint('[LoadData Timer] Getting download URL for thumbnail: ${workflowState.actualThumbnailGsUri}');
            final ref = FirebaseStorage.instance.refFromURL(workflowState.actualThumbnailGsUri!);
            final url = await ref.getDownloadURL();
            stopwatch.stop(); // Stop timer
            debugPrint('[LoadData Timer] Got thumbnail download URL in ${stopwatch.elapsedMilliseconds}ms: $url');
            return url;
          } catch (e) {
            stopwatch.stop(); // Stop timer on error too
            debugPrint('[LoadData Timer] Error getting download URL for thumbnail ${workflowState.actualThumbnailGsUri} after ${stopwatch.elapsedMilliseconds}ms: $e');
            return null;
          }
        } else {
           debugPrint('[LoadData Timer] No valid gs:// actualThumbnailGsUri found.');
           return null;
        }
      }

      // Run URL fetches concurrently
      try {
        final results = await Future.wait([
          getMainImageUrl(),
          getThumbnailImageUrl(),
        ]);
        loadedImageUrl = results[0];
        loadedThumbnailUrl = results[1];
      } catch (e) {
        // Should not happen if individual futures catch errors, but as a fallback:
        debugPrint('[LoadData] Error during Future.wait for URLs: $e');
        workflowState.setErrorMessage('Failed to load image URLs.');
      }
      
      // Update state with results from concurrent fetch
      workflowState.setLoadedImageUrls(loadedImageUrl, loadedThumbnailUrl);
      debugPrint('[LoadData Timer] WorkflowState updated with URLs via setLoadedImageUrls.');
      
      // Set error message if main image URL failed but thumbnail might have succeeded
      if (loadedImageUrl == null && workflowState.actualImageGsUri != null) {
           workflowState.setErrorMessage('Could not load saved image preview.');
      }

      // Determine target step
      int targetStep = 0; // Default to Upload (Step 0)
      if (workflowState.hasAssignmentData) {
        targetStep = 2; // Go to Summary (Step 2) if assignment data exists
      } else if (workflowState.hasTranscriptionData) {
        targetStep = 1; // Go to Assign (Step 1) if transcription data exists (and no assignment)
      } else if (workflowState.hasParseData) {
        targetStep = 0; // Go to Upload (Step 0) if only parse data exists
      }
      // Else, targetStep remains 0 (Upload) if no other data exists.
      
      workflowState.goToStep(targetStep);
      
      workflowState.setLoading(false);
      
    } catch (e) {
      workflowState.setLoading(false);
      workflowState.setErrorMessage('Failed to load receipt: $e');
      
      if (mounted) {
        showAppToast(context, "Failed to load receipt: $e", AppToastType.error);
      }
    }
  }
  
  // Show dialog when back button is pressed or Save & Exit is tapped
  Future<bool> _onWillPop({BuildContext? dialogContext}) async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    // If we're on the first step and nothing has been uploaded or parsed, just exit
    // Adjusted condition to be more robust: if no image file, no existing receiptId, and no parse data.
    if (workflowState.currentStep == 0 && 
        workflowState.imageFile == null && 
        workflowState.receiptId == null && 
        !workflowState.hasParseData) {
      // Before exiting, process any pending deletions that might have accumulated from UI interactions
      // without resulting in a savable state.
      await _processPendingDeletions(isSaving: false); 
      return true;
    }
    
    // Auto-save as draft without confirmation
    try {
      // Pass the current context (or dialogContext if available from a retry) for potential toasts
      await _saveDraft(isBackgroundSave: false, toastContext: dialogContext ?? (mounted ? context : null)); 
      
      return true; // Allow pop if save is successful
    } catch (e) {
      // If saving fails, show an error and ask what to do
      if (!mounted) return false;
      
      // IMPORTANT: Use a new context for the dialog, which will be `dialogContext` in recursive calls.
      final bool result = await showConfirmationDialog(context, 'Error Saving Draft', 'There was an error saving your draft: $e\n\n'
            'Do you want to try again or discard changes?');
      
      if (result) {
        // Try again, passing the context from *this* level of the dialog/error handling
        return _onWillPop(dialogContext: context); 
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
    debugPrint('[_uploadImageAndProcess] Returning URIs - Image: $imageGsUri, Thumbnail: $thumbnailGsUri');
    return {'imageUri': imageGsUri, 'thumbnailUri': thumbnailGsUri};
  }

  // Save the current state as a draft
  Future<void> _saveDraft({bool isBackgroundSave = false, BuildContext? toastContext}) async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    // Use the provided toastContext if available and valid, otherwise try the state's context.
    BuildContext? effectiveToastContext;
    if (toastContext != null && toastContext.mounted) {
      effectiveToastContext = toastContext;
    } else if (mounted && !isBackgroundSave) {
      effectiveToastContext = context; // Fallback to the state's context
    }

    try {
      workflowState.setLoading(true);
      workflowState.setErrorMessage(null);

      // --- Get latest items from ReviewScreen if currently on that step --- 
      if (workflowState.currentStep == 0 && _getCurrentReviewItemsCallback != null) {
        try {
          final currentReviewItems = _getCurrentReviewItemsCallback!(); 
          final currentParseResult = Map<String, dynamic>.from(workflowState.parseReceiptResult);
          final currentItemsList = currentReviewItems.map((item) => {
              'name': item.name, 'price': item.price, 'quantity': item.quantity,
          }).toList();
          currentParseResult['items'] = currentItemsList;
          
          // --- Update the state just before creating the Receipt object for saving --- 
          // Directly modify the _parseReceiptResult in the state object. 
          // Avoid calling setParseReceiptResult if it unnecessarily notifies listeners.
          // We need to access the internal state or add a silent update method.
          // FOR NOW: Let's assume setParseReceiptResult is okay, but this might need refinement
          // if it causes unwanted rebuilds during the save process.
          workflowState.setParseReceiptResult(currentParseResult); 
          debugPrint('[_saveDraft] Updated parseReceiptResult via callback from ReviewScreen state just before saving. Item count: ${currentItemsList.length}');
        } catch (e) {
            debugPrint('[_saveDraft] Error getting current items from ReviewScreen via callback: $e');
            // Decide if we should proceed with potentially stale data or throw?
            // For now, we proceed, but log the error.
        }
      }
      // ---------------------------------------------------------------------

      // --- Conditional Upload --- 
      // Upload only if a local file exists AND the GS URI hasn't been set yet 
      // (e.g., background upload didn't finish or wasn't triggered).
      if (workflowState.imageFile != null && workflowState.actualImageGsUri == null) 
      {
        debugPrint('_saveDraft: Local image present without actual GS URI. Uploading synchronously before saving...');
        try {
          final uris = await _uploadImageAndProcess(workflowState.imageFile!);
          workflowState.setUploadedGsUris(uris['imageUri'], uris['thumbnailUri']);
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
      debugPrint('[_saveDraft] Preparing to save. Receipt object created with ImageURI: ${receipt.imageUri}, ThumbnailURI: ${receipt.thumbnailUri}');
      
      // **** ADD DEBUG PRINT HERE ****
      debugPrint('[_saveDraft] Saving draft. workflowState.parseReceiptResult: ${workflowState.parseReceiptResult}');
      // ***************************

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

      // Only show SnackBar if not a background save and context is available
      if (!isBackgroundSave && effectiveToastContext != null && effectiveToastContext.mounted) {
        showAppToast(effectiveToastContext, "Draft saved successfully", AppToastType.success);
      }
    } catch (e) { 
      workflowState.setLoading(false);
      final errorMessage = 'Failed to save draft: $e';
      if (workflowState.errorMessage == null) {
         workflowState.setErrorMessage(errorMessage);
      }
      debugPrint('[_saveDraft Error] $errorMessage'); // Always log the error

      // Only show SnackBar if not a background save and context is available
      if (!isBackgroundSave && effectiveToastContext != null && effectiveToastContext.mounted) {
        showAppToast(effectiveToastContext, workflowState.errorMessage ?? errorMessage, AppToastType.error);
      }
      rethrow;
    }
  }
  
  // Build the content for the current step
  Widget _buildStepContent(int currentStep) {
    final workflowState = Provider.of<WorkflowState>(context); // Keep for general access
    switch (currentStep) {
      case 0: // Upload
        return Consumer<WorkflowState>(
          builder: (context, consumedState, child) {
            final bool isSuccessfullyParsed = consumedState.parseReceiptResult.containsKey('items') &&
                                              (consumedState.parseReceiptResult['items'] as List?)?.isNotEmpty == true;
            return UploadStepWidget(
              imageFile: consumedState.imageFile,
              imageUrl: consumedState.loadedImageUrl,
              loadedThumbnailUrl: consumedState.loadedThumbnailUrl,
              isLoading: consumedState.isLoading,
              isSuccessfullyParsed: isSuccessfullyParsed,
              onImageSelected: _handleImageSelectedForUploadStep, // Use new handler
              onParseReceipt: _handleParseReceiptForUploadStep,    // Use new handler
              onRetry: _handleRetryForUploadStep,                // Use new handler
            ) as Widget; // Explicit cast
          },
        );
      case 1: // Assign (shows parsed items and assignments, with pencil icon for Review)
        return Consumer<WorkflowState>(
          builder: (context, workflowState, child) {
            final List<ReceiptItem> itemsToAssign = _convertToReceiptItems(workflowState.parseReceiptResult);
            return AssignStepWidget(
              key: ValueKey('AssignStepWidget_${itemsToAssign.length}_${(workflowState.transcribeAudioResult['text'] as String?)?.hashCode ?? 0}'),
              itemsToAssign: itemsToAssign, 
              initialTranscription: workflowState.transcribeAudioResult['text'] as String?,
              onAssignmentProcessed: _handleAssignmentProcessedForAssignStep,
              onTranscriptionChanged: _handleTranscriptionChangedForAssignStep,
              onReTranscribeRequested: _handleReTranscribeRequestedForAssignStep,
              onConfirmProcessAssignments: _handleConfirmProcessAssignmentsForAssignStep,
              onEditItems: _showReviewOverlay, // New: pencil icon triggers this
            );
          },
        );
      case 2: // Summary (shows assignments, with pencil icon for Split)
        return Consumer<WorkflowState>(
          builder: (context, workflowState, child) {
            return SummaryStepWidget(
              key: const ValueKey('SummaryStepWidget'),
              parseResult: workflowState.parseReceiptResult,
              assignResultMap: workflowState.assignPeopleToItemsResult,
              currentTip: workflowState.tip,
              currentTax: workflowState.tax,
              onEditAssignments: _showSplitOverlay, // New: pencil icon triggers this
            );
          },
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
                    final bool canPop = await _onWillPop(); 
                    if (canPop && mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Exit'),
                )
              : OutlinedButton(
                  onPressed: () async {
                    bool saveSuccess = false;
                    try {
                      await _saveDraft();
                      saveSuccess = true;
                    } catch (e) {
                      // _saveDraft already handles logging and showing a SnackBar
                      // for the error.
                      saveSuccess = false;
                    }
                    if (saveSuccess && mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Save Draft'),
                ),
          
          // Next/Complete button
          if (currentStep < 4) ...[ // Only show Next button if not on last step
            Builder( // Use Builder to get latest workflowState for enable check
              builder: (context) {
                final localWorkflowState = Provider.of<WorkflowState>(context);
                bool isNextEnabled = true;
                if (currentStep == 0 && !localWorkflowState.hasParseData) {
                   isNextEnabled = false;
                }
                else if (currentStep == 1 && !localWorkflowState.hasAssignmentData) {
                   isNextEnabled = false;
                }

                return FilledButton.icon(
                  onPressed: isNextEnabled 
                    ? () async { // Enabled logic
                        localWorkflowState.nextStep();
                      }
                    : null, // Disabled
                  label: const Text('Next'),
                  icon: const Icon(Icons.arrow_forward),
                );
              }
            ),
          ] else ...[ // Show Complete button on last step
             FilledButton.icon(
                  onPressed: () => _completeReceipt(),
                  label: const Text('Complete'),
                  icon: const Icon(Icons.check),
                ),
          ],
        ],
      ),
    );
  }

  // Mark the current receipt as completed
  Future<void> _completeReceipt() async {
    // Get workflow state ONCE at the beginning.
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    // Capture the navigator before any awaits
    if (!mounted) return;
    final navigator = Navigator.of(context); 

    try {
      // --- Start Operation ---
      if (!mounted) return; 
      workflowState.setLoading(true); 
      workflowState.setErrorMessage(null);
      
      // Create the receipt object and explicitly set status to 'completed'
      final receipt = workflowState.toReceipt();
      final Map<String, dynamic> receiptData = receipt.toMap();
      receiptData['metadata']['status'] = 'completed'; // Ensure status is explicitly set to 'completed'
      
      // --- First Await --- 
      final String definitiveReceiptId = await _firestoreService.completeReceipt( 
        receiptId: receipt.id, 
        data: receiptData,
      );
      
      // --- Check Mounted After First Await --- 
      if (!mounted) return; 
      
      // --- State Updates (No Context Use) --- 
      workflowState.setReceiptId(definitiveReceiptId);
      workflowState.removeUriFromPendingDeletions(workflowState.actualImageGsUri);
      workflowState.removeUriFromPendingDeletions(workflowState.actualThumbnailGsUri);

      // --- Second Await --- 
      await _processPendingDeletions(isSaving: true); 

      // --- Check Mounted After Second Await --- 
      if (!mounted) return; 
      
      // --- Final State Updates & UI Feedback --- 
      workflowState.setLoading(false); 
      
      // Show toast before navigation if context is still valid
      if (mounted) {
        showAppToast(context, "Receipt completed successfully", AppToastType.success);
      }
      
      // Short delay to allow toast to be shown before navigation
      await Future.delayed(const Duration(milliseconds: 300));
      
      // --- Navigate LAST --- 
      // Final check before navigation
      if (mounted) {
        // Pop with result value true to indicate successful completion
        navigator.pop(true);
      }
      
    } catch (e) {
      // --- Check Mounted in Catch Block --- 
      if (!mounted) return; 
      
      // --- State Updates & UI Feedback --- 
      workflowState.setLoading(false); 
      workflowState.setErrorMessage('Failed to complete receipt: $e');
      
      // Show error toast with current context
      showAppToast(context, "Failed to complete receipt: $e", AppToastType.error);
      // Do NOT pop here on error, let the user decide or stay in modal
    }
  }

  // --- START: New handlers for WorkflowNavigationControls callbacks ---
  Future<void> _handleNavigationExitAction() async {
    final bool canPop = await _onWillPop(); 
    if (canPop && mounted) {
      Navigator.of(context).pop(true); // true indicates a deliberate exit/save
    }
  }

  Future<void> _handleNavigationSaveDraftAction() async {
    bool saveSuccess = false;
    try {
      // For UI-triggered save, use the current widget's context for toasts
      await _saveDraft(isBackgroundSave: false, toastContext: mounted ? context : null);
      saveSuccess = true;
    } catch (e) {
      // _saveDraft already handles logging and showing a SnackBar
      // for the error.
      saveSuccess = false;
    }
    if (saveSuccess && mounted) {
      Navigator.of(context).pop(true); // true indicates a deliberate exit/save
    }
  }

  Future<void> _handleNavigationCompleteAction() async {
    await _completeReceipt();
  }
  // --- END: New handlers for WorkflowNavigationControls callbacks ---

  @override
  Widget build(BuildContext context) {
    final workflowState = Provider.of<WorkflowState>(context);
    final colorScheme = Theme.of(context).colorScheme;
    if (_isDraftLoading || (workflowState.receiptId != null && workflowState.isLoading && workflowState.currentStep == 0)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(workflowState.receiptId != null ? 'Loading Draft...' : 'New Receipt'),
          automaticallyImplyLeading: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(workflowState.restaurantName),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            WorkflowStepIndicator(currentStep: workflowState.currentStep, stepTitles: _stepTitles),
            Expanded(
              child: _buildStepContent(workflowState.currentStep),
            ),
            WorkflowNavigationControls(
              onExitAction: _handleNavigationExitAction,
              onSaveDraftAction: _handleNavigationSaveDraftAction,
              onCompleteAction: _handleNavigationCompleteAction,
            ),
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
            final String itemName = rawItem.containsKey('name') 
                                    ? (rawItem['name'] as String? ?? 'Unknown Item') 
                                    : (rawItem['item'] as String? ?? 'Unknown Item');
            
            final num? itemPriceNum = rawItem['price'] as num?;
            final double itemPrice = itemPriceNum?.toDouble() ?? 0.0;
            
            final num? itemQuantityNum = rawItem['quantity'] as num?;
            final int itemQuantity = itemQuantityNum?.toInt() ?? 1;

            items.add(ReceiptItem(
              name: itemName,
              price: itemPrice,
              quantity: itemQuantity,
            ));
          } catch (e) {
            print('Error parsing item: $e. Raw item data: $rawItem');
          }
        }
      }
    }
    
    return items;
  }

  // --- EDIT: Add standard placeholder widget ---
  Widget _buildPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
  // --- END EDIT ---

  // --- START OF NEW HELPER METHODS FOR UPLOAD STEP ---
  Future<void> _handleImageSelectedForUploadStep(File? file) async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    if (workflowState.hasParseData) {
      final confirmed = await showConfirmationDialog(
        context,
        'Confirm Action',
        'Selecting a new image will clear all currently reviewed items, assigned people, and split details. Do you want to continue?'
      );
      if (!confirmed) return; // User cancelled
      workflowState.clearParseAndSubsequentData();
    }

    if (file != null) {
      workflowState.setImageFile(file); // This already clears subsequent data internally
      workflowState.setErrorMessage(null);
      final File imageFileForThisUpload = file; 

      _uploadImageAndProcess(imageFileForThisUpload).then((uris) {
        if (mounted && workflowState.imageFile == imageFileForThisUpload) { 
          workflowState.setUploadedGsUris(uris['imageUri'], uris['thumbnailUri']);
          debugPrint('[_WorkflowModalBodyState._handleImageSelectedForUploadStep] Background upload complete. WorkflowState updated.');
        } else {
          debugPrint('[_WorkflowModalBodyState._handleImageSelectedForUploadStep] Background upload complete, but context changed or image no longer matches. URIs not set. Orphaned URIs might be ${uris['imageUri']}, ${uris['thumbnailUri']}');
          if (uris['imageUri'] != null) workflowState.addUriToPendingDeletions(uris['imageUri']);
          if (uris['thumbnailUri'] != null) workflowState.addUriToPendingDeletions(uris['thumbnailUri']);
        }
      }).catchError((error) {
         if (mounted && workflowState.imageFile == imageFileForThisUpload) { 
            debugPrint('[_WorkflowModalBodyState._handleImageSelectedForUploadStep] Background upload failed for current image: $error');
            workflowState.setErrorMessage('Background image upload failed. Please try parsing again or reselect.');
            workflowState.setUploadedGsUris(null, null);
          } else {
            debugPrint('[_WorkflowModalBodyState._handleImageSelectedForUploadStep] Background upload failed for an outdated image selection: $error');
          }
      });
    } else {
      workflowState.resetImageFile(); 
      workflowState.setErrorMessage(null);
    }
  }

  Future<void> _handleParseReceiptForUploadStep() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Capture before async

    if (workflowState.hasParseData) {
      final confirmed = await showConfirmationDialog(
        context,
        'Confirm Re-Parse',
        'Parsing again will clear all currently reviewed items, voice assignments, and split details. Tip and Tax will be preserved. Do you want to continue?'
      );
      if (!confirmed) return;
      workflowState.clearParseAndSubsequentData();
    }

    workflowState.setLoading(true); 
    workflowState.setErrorMessage(null);
    String? gsUriForParsing;
    try {
      if (workflowState.actualImageGsUri != null && workflowState.actualImageGsUri!.isNotEmpty) {
          gsUriForParsing = workflowState.actualImageGsUri;
          debugPrint('[_WorkflowModalBodyState._handleParseReceiptForUploadStep] Using pre-existing actualImageGsUri: $gsUriForParsing');
      } else if (workflowState.imageFile != null) {
          debugPrint('[_WorkflowModalBodyState._handleParseReceiptForUploadStep] Local file detected, no GS URI yet. Uploading synchronously...');
          final uris = await _uploadImageAndProcess(workflowState.imageFile!);
          workflowState.setUploadedGsUris(uris['imageUri'], uris['thumbnailUri']);
          gsUriForParsing = uris['imageUri'];
          debugPrint('[_WorkflowModalBodyState._handleParseReceiptForUploadStep] Synchronous upload complete. Using: $gsUriForParsing for parsing.');
      } else if (workflowState.loadedImageUrl != null) {
        debugPrint('[_WorkflowModalBodyState._handleParseReceiptForUploadStep] CRITICAL: loadedImageUrl is present, but actualImageGsUri is missing...');
        throw Exception('Image loaded from draft, but its GS URI is missing in state.');
      } else {
        debugPrint('[_WorkflowModalBodyState._handleParseReceiptForUploadStep] No image selected or available for parsing.');
        workflowState.setLoading(false);
        workflowState.setErrorMessage('Please select an image first.');
        if (mounted) {
          showAppToast(scaffoldMessenger.context, "Please select an image first.", AppToastType.error);
        }
        return;
      }

      if (gsUriForParsing == null || gsUriForParsing.isEmpty) {
        debugPrint('[_WorkflowModalBodyState._handleParseReceiptForUploadStep] CRITICAL: gsUriForParsing is null or empty...');
        throw Exception('Image URI could not be determined for parsing.');
      }
      
      Map<String, dynamic> newParseResult = {}; 
      debugPrint('[_WorkflowModalBodyState._handleParseReceiptForUploadStep] Parsing receipt with URI: $gsUriForParsing');
      final ReceiptData parsedData = await ReceiptParserService.parseReceipt(gsUriForParsing);
      newParseResult['items'] = parsedData.items;
      newParseResult['subtotal'] = parsedData.subtotal;
      workflowState.setParseReceiptResult(newParseResult);
      debugPrint('[_WorkflowModalBodyState._handleParseReceiptForUploadStep] Receipt parsed successfully.');

      workflowState.setLoading(false);
      workflowState.nextStep();
    } catch (e) { 
      debugPrint('[_WorkflowModalBodyState._handleParseReceiptForUploadStep] Error: $e');
      workflowState.setLoading(false);
      workflowState.setErrorMessage('Failed to process/parse receipt: ${e.toString()}');
      if (mounted) {
        showAppToast(scaffoldMessenger.context, "Failed to process/parse receipt: ${e.toString()}", AppToastType.error);
      }
    }
  }

  void _handleRetryForUploadStep() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    // Show confirmation dialog before clearing data
    final confirm = await showConfirmationDialog( 
      context,
      "Confirm Retry",
      "Retrying will clear any existing parsed receipt data. Are you sure you want to continue?",
    );

    if (confirm) {
      workflowState.resetImageFile();
      workflowState.setErrorMessage(null);
    }
  }
  // --- END OF NEW HELPER METHODS FOR UPLOAD STEP ---

  // --- START OF NEW HELPER METHODS FOR REVIEW STEP ---
  void _handleReviewCompleteForReviewStep(List<ReceiptItem> updatedItems, List<ReceiptItem> deletedItems) { 
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    // The updatedItems are used to ensure the parseReceiptResult is current before proceeding.
    // This is important if _saveDraft hasn't been called or if items changed since last save.
    final newParseResult = Map<String, dynamic>.from(workflowState.parseReceiptResult);
    newParseResult['items'] = updatedItems.map((item) => 
      {'name': item.name, 'price': item.price, 'quantity': item.quantity}
    ).toList();
    // Potentially update subtotal or other derived data if necessary here
    workflowState.setParseReceiptResult(newParseResult);
    debugPrint('[_WorkflowModalBodyState._handleReviewCompleteForReviewStep] Review complete. Items processed: ${updatedItems.length}. Deleted: ${deletedItems.length}');

    workflowState.nextStep(); 
  }

  // Signature: void Function(List<ReceiptItem> updatedItems)
  void _handleItemsUpdatedForReviewStep(List<ReceiptItem> updatedItems) {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    final newParseResult = Map<String, dynamic>.from(workflowState.parseReceiptResult);
    newParseResult['items'] = updatedItems.map((item) => 
      {'name': item.name, 'price': item.price, 'quantity': item.quantity}
    ).toList();
    workflowState.setParseReceiptResult(newParseResult);
    debugPrint('[_WorkflowModalBodyState._handleItemsUpdatedForReviewStep] Items updated. Count: ${updatedItems.length}');
  }

  // Signature: void Function(GetCurrentItemsCallback getter)
  void _handleRegisterCurrentItemsGetterForReviewStep(GetCurrentItemsCallback getter) {
    _getCurrentReviewItemsCallback = getter;
    debugPrint('[_WorkflowModalBodyState._handleRegisterCurrentItemsGetterForReviewStep] Registered getCurrentItems callback.');
  }
  // --- END OF NEW HELPER METHODS FOR REVIEW STEP ---

  // --- START OF NEW HELPER METHODS FOR ASSIGN STEP ---
  // Signature: void Function(Map<String, dynamic> assignmentResultData)
  void _handleAssignmentProcessedForAssignStep(Map<String, dynamic> assignmentResultData) {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    workflowState.setAssignPeopleToItemsResult(assignmentResultData);
    debugPrint('[WorkflowModal] Assignment processed, new state: ${workflowState.assignPeopleToItemsResult}');
    // workflowState.nextStep(); // Decision: nextStep is usually called by the "Next" button in navigation after data is ready.
  }

  // Signature: void Function(String? newTranscription)
  void _handleTranscriptionChangedForAssignStep(String? newTranscription) {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    final currentTranscriptionResult = Map<String, dynamic>.from(workflowState.transcribeAudioResult);
    if (newTranscription == null || newTranscription.isEmpty) {
      currentTranscriptionResult.remove('text');
    } else {
      currentTranscriptionResult['text'] = newTranscription;
    }
    workflowState.setTranscribeAudioResult(currentTranscriptionResult);
    debugPrint('[WorkflowModal] Transcription updated by AssignStep: $newTranscription');
  }

  // Signature: Future<bool> Function() // async
  Future<bool> _handleReTranscribeRequestedForAssignStep() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    final confirm = await showConfirmationDialog(
        context,
        "Confirm Re-transcribe",
        "This will clear your current transcription and any subsequent assignments, tip, and tax. Are you sure you want to re-transcribe?");
    if (confirm) {
      workflowState.clearTranscriptionAndSubsequentData();
    }
    return confirm;
  }

  // Corrected Signature: Future<bool> Function() // async
  // This method is called by AssignStepWidget's onConfirmProcessAssignments to confirm with the user.
  // It does NOT process the data itself; that's done by _handleAssignmentProcessedForAssignStep.
  Future<bool> _handleConfirmProcessAssignmentsForAssignStep() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    // final transcription = workflowState.transcribeAudioResult['text'] as String? ?? '';
    
    // Always confirm before processing assignments, as it's a significant step.
    // The previous logic to bypass confirmation for empty transcription/assignments might be too implicit.
    // VoiceAssignmentScreen will provide the actual assignment map to _handleAssignmentProcessedForAssignStep.

    final confirmed = await showConfirmationDialog(
      context, 
      'Process Assignments', 
      'Are you sure you want to process these assignments? This will overwrite any previous assignments.'
    );

    // This handler's role is only to return the confirmation status.
    // The actual data processing happens in _handleAssignmentProcessedForAssignStep.
    return confirmed;
  }
  // --- END OF NEW HELPER METHODS FOR ASSIGN STEP ---

  // --- START OF NEW HELPER METHODS FOR SPLIT STEP ---
  void _handleTipChangedForSplitStep(double? newTip) {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    if (workflowState.tip != newTip) {
      workflowState.setTip(newTip);
      debugPrint('[_WorkflowModalBodyState._handleTipChangedForSplitStep] Tip updated from SplitStep: $newTip');
    }
  }

  void _handleTaxChangedForSplitStep(double? newTax) {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    if (workflowState.tax != newTax) {
      workflowState.setTax(newTax);
      debugPrint('[_WorkflowModalBodyState._handleTaxChangedForSplitStep] Tax updated from SplitStep: $newTax');
    }
  }

  void _handleAssignmentsUpdatedBySplitStep(Map<String, dynamic> newAssignments) {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    workflowState.setAssignPeopleToItemsResult(newAssignments);
    debugPrint('[_WorkflowModalBodyState._handleAssignmentsUpdatedBySplitStep] Assignments updated from SplitStep.');
  }

  void _handleNavigateToPageForSplitStep(int pageIndex) {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    if (pageIndex >= 0 && pageIndex < _stepTitles.length) {
      if (pageIndex == 2) { // Tapped "Go to Summary" (index 2) from Split (index 1)
        if (!workflowState.hasAssignmentData) {
          if (mounted) {
            showAppToast(context, "Cannot proceed to Summary: Assignment data is missing.", AppToastType.error);
          }
          return; // Block navigation
        }
      }
      workflowState.goToStep(pageIndex);
    }
  }
  // --- END OF NEW HELPER METHODS FOR SPLIT STEP ---

  // Overlay state and handlers
  Future<void> _showReviewOverlay() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ChangeNotifierProvider<WorkflowState>.value(
          value: workflowState,
          child: ReviewStepWidget(
            key: const ValueKey('ReviewStepWidget'),
            initialItems: _convertToReceiptItems(workflowState.parseReceiptResult),
            onReviewComplete: (updatedItems, deletedItems) {
              final newParseResult = Map<String, dynamic>.from(workflowState.parseReceiptResult);
              newParseResult['items'] = updatedItems.map((item) =>
                {'name': item.name, 'price': item.price, 'quantity': item.quantity}
              ).toList();
              workflowState.setParseReceiptResult(newParseResult);
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            onItemsUpdated: _handleItemsUpdatedForReviewStep,
            registerCurrentItemsGetter: _handleRegisterCurrentItemsGetterForReviewStep,
            onClose: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }

  Future<void> _showSplitOverlay() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => SplitStepWidget(
          key: const ValueKey('SplitStepWidget'),
          parseResult: workflowState.parseReceiptResult,
          assignResultMap: workflowState.assignPeopleToItemsResult,
          currentTip: workflowState.tip,
          currentTax: workflowState.tax,
          initialSplitViewTabIndex: _initialSplitViewTabIndex,
          onTipChanged: _handleTipChangedForSplitStep,
          onTaxChanged: _handleTaxChangedForSplitStep,
          onAssignmentsUpdatedBySplit: _handleAssignmentsUpdatedBySplitStep,
          onNavigateToPage: _handleNavigateToPageForSplitStep,
        ),
      ),
    );
  }
}