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
import './workflow_steps/upload_step_widget.dart'; // Corrected import path
import './workflow_steps/review_step_widget.dart'; // Import ReviewStepWidget
import './workflow_steps/assign_step_widget.dart'; // Import AssignStepWidget
import './workflow_steps/split_step_widget.dart'; // Import SplitStepWidget
import './workflow_steps/summary_step_widget.dart'; // Import SummaryStepWidget

// --- Moved Typedef to top level --- 
// Callback type for ReceiptReviewScreen to provide its current items
typedef GetCurrentItemsCallback = List<ReceiptItem> Function();

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
  final ImageStateManager imageStateManager; // Add ImageStateManager instance
  
  Map<String, dynamic> _parseReceiptResult = {};
  Map<String, dynamic> _transcribeAudioResult = {};
  Map<String, dynamic> _assignPeopleToItemsResult = {};
  double? _tip;
  double? _tax;
  List<String> _people = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // List to track GS URIs that might need deletion
  List<String> get pendingDeletionGsUris => imageStateManager.pendingDeletionGsUris;
  
  WorkflowState({required String restaurantName, String? receiptId})
      : _restaurantName = restaurantName,
        _receiptId = receiptId,
        imageStateManager = ImageStateManager() { // Initialize ImageStateManager
    debugPrint('[WorkflowState Constructor] Initial _transcribeAudioResult: $_transcribeAudioResult');
    // If ImageStateManager itself calls notifyListeners and WorkflowState needs to propagate that:
    // imageStateManager.addListener(notifyListeners);
    // However, we'll have WorkflowState methods call its own notifyListeners after imageStateManager calls.
  }
  
  // Getters
  int get currentStep => _currentStep;
  String get restaurantName => _restaurantName;
  String? get receiptId => _receiptId;
  File? get imageFile => imageStateManager.imageFile;
  String? get loadedImageUrl => imageStateManager.loadedImageUrl;
  String? get actualImageGsUri => imageStateManager.actualImageGsUri;
  String? get actualThumbnailGsUri => imageStateManager.actualThumbnailGsUri;
  String? get loadedThumbnailUrl => imageStateManager.loadedThumbnailUrl;

  Map<String, dynamic> get parseReceiptResult => _parseReceiptResult;
  Map<String, dynamic> get transcribeAudioResult => _transcribeAudioResult;
  Map<String, dynamic> get assignPeopleToItemsResult => _assignPeopleToItemsResult;
  double? get tip => _tip;
  double? get tax => _tax;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Getter for people
  List<String> get people => _people;
  
  // --- EDIT: Add getters to check for existing data in subsequent steps ---
  bool get hasParseData => _parseReceiptResult.isNotEmpty && 
                          (_parseReceiptResult['items'] as List?)?.isNotEmpty == true;
  
  bool get hasTranscriptionData => _transcribeAudioResult.isNotEmpty && 
                                  (_transcribeAudioResult['text'] as String?)?.isNotEmpty == true;
  
  bool get hasAssignmentData => _assignPeopleToItemsResult.isNotEmpty && 
                               (_assignPeopleToItemsResult['assignments'] as List?)?.isNotEmpty == true;
  // --- END EDIT ---
  
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
    // imageStateManager.setNewImageFile will handle adding old _actualImageGsUri 
    // and _actualThumbnailGsUri from its own state to its pending deletions list.

    imageStateManager.setNewImageFile(file); // Correct delegation

    // When a new image is selected, CLEAR ALL SUBSEQUENT STEP DATA (This logic STAYS in WorkflowState)
    _parseReceiptResult = {}; 
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    _tip = null;
    _tax = null;
    _people = [];
    notifyListeners();
  }
  
  void resetImageFile() {
    // imageStateManager.resetImageFile will handle adding old _actualImageGsUri 
    // and _actualThumbnailGsUri from its own state to its pending deletions list.

    imageStateManager.resetImageFile(); // Correct delegation

    // When image is reset, CLEAR ALL SUBSEQUENT STEP DATA (This logic STAYS in WorkflowState)
    _parseReceiptResult = {}; 
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    _tip = null;
    _tax = null;
    _people = [];
    notifyListeners();
  }
  
  void setParseReceiptResult(Map<String, dynamic> result) {
    // Ensure result map doesn't inadvertently contain old URI fields at root
    result.remove('image_uri');
    result.remove('thumbnail_uri');
    _parseReceiptResult = result;
    
    notifyListeners();
  }
  
  void setTranscribeAudioResult(Map<String, dynamic>? result) {
    debugPrint('[WorkflowState setTranscribeAudioResult] Received result: $result');
    _transcribeAudioResult = result ?? {};
    debugPrint('[WorkflowState setTranscribeAudioResult] _transcribeAudioResult is now: $_transcribeAudioResult');
    notifyListeners();
  }
  
  void setAssignPeopleToItemsResult(Map<String, dynamic>? result) {
    _assignPeopleToItemsResult = result ?? {};
    debugPrint('[WorkflowState] setAssignPeopleToItemsResult set to: ${_assignPeopleToItemsResult}');
    // When assignments change, clear subsequent dependent state
    _tip = null;
    _tax = null;
    _people = _extractPeopleFromAssignments();
    notifyListeners();
  }
  
  void setTip(double? value) {
    if (_tip != value) {
      _tip = value;
      notifyListeners();
    }
  }

  void setTax(double? value) {
    if (_tax != value) {
      _tax = value;
      notifyListeners();
    }
  }
  
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
  
  // These setters will now delegate to ImageStateManager
  void setUploadedGsUris(String? imageGsUri, String? thumbnailGsUri) {
    imageStateManager.setUploadedGsUris(imageGsUri, thumbnailGsUri);
    notifyListeners();
  }

  void setLoadedImageUrls(String? imageUrl, String? thumbnailUrl) {
    imageStateManager.setLoadedImageUrls(imageUrl, thumbnailUrl);
    notifyListeners();
  }

  void setActualGsUrisOnLoad(String? imageGsUri, String? thumbnailGsUri) {
    imageStateManager.setActualGsUrisOnLoad(imageGsUri, thumbnailGsUri);
    notifyListeners();
  }
  
  // Methods to manage the pending deletion list - delegate to ImageStateManager
  void clearPendingDeletions() {
    imageStateManager.clearPendingDeletionsList();
    notifyListeners(); // WorkflowState should notify its own listeners
  }

  void removeUriFromPendingDeletions(String? uri) {
    imageStateManager.removeUriFromPendingDeletionsList(uri);
    notifyListeners(); // WorkflowState should notify its own listeners
  }

  void addUriToPendingDeletions(String? uri) {
    imageStateManager.addUriToPendingDeletionsList(uri);
    notifyListeners(); // WorkflowState should notify its own listeners
  }
  
  // Convert to Receipt model for saving
  Receipt toReceipt() {
    return Receipt(
      id: _receiptId ?? FirebaseFirestore.instance.collection('temp').doc().id,
      restaurantName: _restaurantName,
      // URIs now come from imageStateManager
      imageUri: imageStateManager.actualImageGsUri,
      thumbnailUri: imageStateManager.actualThumbnailGsUri,
      parseReceipt: _parseReceiptResult,
      transcribeAudio: _transcribeAudioResult,
      assignPeopleToItems: _assignPeopleToItemsResult,
      status: 'draft',
      people: _people,
      tip: _tip,
      tax: _tax,
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
          final personName = assignment['person_name'] as String?;
          if (personName != null && personName.isNotEmpty && !people.contains(personName)) {
             people.add(personName); // Ensure non-null, non-empty, unique
          }
        }
      }
    }
    // Also include people mentioned in shared items
    if (_assignPeopleToItemsResult.containsKey('shared_items') &&
        _assignPeopleToItemsResult['shared_items'] is List) {
      final sharedItems = _assignPeopleToItemsResult['shared_items'] as List;
      for (final sharedItem in sharedItems) {
        if (sharedItem is Map && sharedItem.containsKey('people') && sharedItem['people'] is List) {
          final sharedPeople = sharedItem['people'] as List;
          for (final personNameDynamic in sharedPeople) {
            if (personNameDynamic is String) {
              final personName = personNameDynamic;
               if (personName.isNotEmpty && !people.contains(personName)) {
                 people.add(personName);
               }
            }
          }
        }
      }
    }
    
    return people;
  }

  // --- EDIT: Add specific data clearing methods ---
  void clearParseAndSubsequentData() {
    _parseReceiptResult = {};
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    _people = [];
    // Tip and Tax are preserved when re-parsing, as they might have been manually set
    // or are global to the receipt rather than dependent on specific parse data.
    // However, if they WERE dependent on parsed items that are now gone, user should re-verify.
    debugPrint('[WorkflowState] Cleared Parse, Transcription, Assignment, People. Tip/Tax remain.');
    notifyListeners();
  }

  void clearTranscriptionAndSubsequentData() {
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {}; // Also clear assignments
    _people = []; // Also clear people list
    _tip = null; // Also clear tip
    _tax = null; // Also clear tax
    debugPrint('[WorkflowState] Cleared Transcription, Assignments, People, Tip, and Tax.');
    notifyListeners();
  }

  void clearAssignmentAndSubsequentData() {
    _assignPeopleToItemsResult = {};
    _people = []; 
    debugPrint('[WorkflowState] Cleared Assignments and People. Tip/Tax remain.');
    notifyListeners();
  }
  // --- END EDIT ---
}

/// Dialog to prompt for restaurant name
Future<String?> showRestaurantNameDialog(BuildContext context, {String? initialName}) async {
  // Add mounted check before attempting to show a dialog
  if (!context.mounted) {
    debugPrint("[showRestaurantNameDialog] Error: Context is not mounted before showing dialog.");
    return null;
  }
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
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Draft receipt not found."), backgroundColor: Colors.orange));
          }
          return null; // Don't proceed if receipt not found
        }
      } catch (e) {
        debugPrint("[WorkflowModal.show] Error fetching receipt details for modal: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading draft: ${e.toString()}"), backgroundColor: Colors.red));
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
    'Review',
    'Assign',
    'Split',
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
  
  // --- EDIT: Add helper for confirmation dialog ---
  Future<bool> _showConfirmationDialog(String title, String content) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Cancel
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
  // --- END EDIT ---
  
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
        targetStep = 4; // Go to Summary (Step 4) if assignment data exists
      } else if (workflowState.hasTranscriptionData) {
        targetStep = 2; // Go to Assign (Step 2) if transcription data exists (and no assignment)
      } else if (workflowState.hasParseData) {
        targetStep = 1; // Go to Review (Step 1) if only parse data exists
      }
      // Else, targetStep remains 0 (Upload) if no other data exists.
      
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
      // REMOVED: Initial SnackBar for "Saving draft..."
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Saving draft...'),
      //     duration: Duration(seconds: 1),
      //   ),
      // );
      
      await _saveDraft(isBackgroundSave: false); // isBackgroundSave: false ensures SnackBars can be shown by _saveDraft
      
      // REMOVED: SnackBar for "Draft saved" as _saveDraft now handles this.
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text('Draft saved'),
      //       duration: Duration(seconds: 1),
      //     ),
      //   );
      // }
      
      return true; // Allow pop if save is successful
    } catch (e) {
      // If saving fails, show an error and ask what to do
      if (!mounted) return false;
      
      final result = await _showConfirmationDialog('Error Saving Draft', 'There was an error saving your draft: $e\n\n'
            'Do you want to try again or discard changes?');
      
      if (result) {
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
    debugPrint('[_uploadImageAndProcess] Returning URIs - Image: $imageGsUri, Thumbnail: $thumbnailGsUri');
    return {'imageUri': imageGsUri, 'thumbnailUri': thumbnailGsUri};
  }

  // Save the current state as a draft
  Future<void> _saveDraft({bool isBackgroundSave = false}) async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    // Capture ScaffoldMessenger if not a background save and mounted
    final scaffoldMessenger = !isBackgroundSave && mounted ? ScaffoldMessenger.of(context) : null;

    try {
      workflowState.setLoading(true);
      workflowState.setErrorMessage(null);

      // --- Get latest items from ReviewScreen if currently on that step --- 
      if (workflowState.currentStep == 1 && _getCurrentReviewItemsCallback != null) {
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

      // Only show SnackBar if not a background save and context is available (via captured scaffoldMessenger)
      if (scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) { 
      workflowState.setLoading(false);
      final errorMessage = 'Failed to save draft: $e';
      if (workflowState.errorMessage == null) {
         workflowState.setErrorMessage(errorMessage);
      }
      debugPrint('[_saveDraft Error] $errorMessage'); // Always log the error

      // Only show SnackBar if not a background save and context is available (via captured scaffoldMessenger)
      if (scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(workflowState.errorMessage ?? errorMessage), // Show specific error if available
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
    final workflowState = Provider.of<WorkflowState>(context); // Keep for general access
    
    switch (currentStep) {
      case 0: // Upload
        return Consumer<WorkflowState>(
          builder: (context, consumedState, child) {
            final bool isSuccessfullyParsed = consumedState.parseReceiptResult.containsKey('items') &&
                                              (consumedState.parseReceiptResult['items'] as List?)?.isNotEmpty == true;

            // debugPrint('[_buildStepContent Consumer for Upload] consumedState.loadedImageUrl: ${consumedState.loadedImageUrl}, consumedState.loadedThumbnailUrl: ${consumedState.loadedThumbnailUrl}');
                
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
        
      case 1: // Review
        // --- EDIT: Check for parse data before building ---
        if (!workflowState.hasParseData) {
          return _buildPlaceholder('Please upload and parse a receipt first.') as Widget; // Explicit cast
        }
        // --- END EDIT ---
        final List<ReceiptItem> items = _convertToReceiptItems(workflowState.parseReceiptResult);
        
        // debugPrint('[_buildStepContent Consumer for Review] Building ReceiptReviewScreen with ${items.length} items.');

        return ReviewStepWidget(
          key: const ValueKey('ReviewStepWidget'), 
          initialItems: items,
          onReviewComplete: _handleReviewCompleteForReviewStep,
          onItemsUpdated: _handleItemsUpdatedForReviewStep,
          registerCurrentItemsGetter: _handleRegisterCurrentItemsGetterForReviewStep,
        );
        
      case 2: // Assign people to items (Voice Assignment)
        return Consumer<WorkflowState>(
          builder: (context, workflowState, child) {
            final List<ReceiptItem> itemsToAssign = _convertToReceiptItems(workflowState.parseReceiptResult);

            if (itemsToAssign.isEmpty) {
               return _buildPlaceholder('Please complete the review step first. No items to assign.');
            }
            return AssignStepWidget(
              key: ValueKey('AssignStepWidget_${itemsToAssign.length}_${(workflowState.transcribeAudioResult['text'] as String?)?.hashCode ?? 0}'),
              itemsToAssign: itemsToAssign, 
              initialTranscription: workflowState.transcribeAudioResult['text'] as String?,
              onAssignmentProcessed: _handleAssignmentProcessedForAssignStep,
              onTranscriptionChanged: _handleTranscriptionChangedForAssignStep,
              onReTranscribeRequested: _handleReTranscribeRequestedForAssignStep,
              onConfirmProcessAssignments: _handleConfirmProcessAssignmentsForAssignStep,
            );
          },
        );
        
      case 3: // Split
        return Consumer<WorkflowState>(
          builder: (context, workflowState, child) {
            if (!workflowState.hasAssignmentData) {
              return _buildPlaceholder('Please complete the voice assignment first, or ensure people/items were assigned.');
            }
            return SplitStepWidget(
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
            );
          }
        );
        
      case 4: // Summary
        return Consumer<WorkflowState>(
          builder: (context, workflowState, child) {
        if (!workflowState.hasAssignmentData) {
           return _buildPlaceholder('Please complete the Split step first, ensuring items are assigned.');
        }
            // All data preparation for FinalSummaryScreen's SplitManager is now within SummaryStepWidget.
            return SummaryStepWidget(
              key: const ValueKey('SummaryStepWidget'), // Add a key
              parseResult: workflowState.parseReceiptResult,
              assignResultMap: workflowState.assignPeopleToItemsResult,
              currentTip: workflowState.tip,
              currentTax: workflowState.tax,
              // onNavigateToPage: _handleNavigateToPageForSummaryStep, // If summary needs to navigate
            );
          }
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
                else if (currentStep == 2 && !localWorkflowState.hasAssignmentData) {
                   isNextEnabled = false;
                }
                else if (currentStep == 3 && !localWorkflowState.hasAssignmentData) {
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
    // Capture the navigator and scaffold messenger state BEFORE any awaits
    // Check mounted before accessing context for these.
    if (!mounted) return;
    final navigator = Navigator.of(context); 
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // --- Start Operation ---
      // Update state ONLY IF mounted
      if (!mounted) return; 
      workflowState.setLoading(true); 
      workflowState.setErrorMessage(null);
      
      final receipt = workflowState.toReceipt();
      
      // --- First Await --- 
      // Use receipt.id which is guaranteed to be non-null by toReceipt()
      final String definitiveReceiptId = await _firestoreService.completeReceipt( 
        receiptId: receipt.id, 
        data: receipt.toMap(),
      );
      
      // --- Check Mounted After First Await --- 
      if (!mounted) return; 
      
      // --- State Updates (No Context Use) --- 
      // Update the workflowState with the definitive receiptId
      workflowState.setReceiptId(definitiveReceiptId);
      workflowState.removeUriFromPendingDeletions(workflowState.actualImageGsUri);
      workflowState.removeUriFromPendingDeletions(workflowState.actualThumbnailGsUri);

      // --- Second Await --- 
      await _processPendingDeletions(isSaving: true); 

      // --- Check Mounted After Second Await --- 
      if (!mounted) return; 
      
      // --- Final State Updates & UI Feedback (using captured references) --- 
      workflowState.setLoading(false); 
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Receipt completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // --- Navigate LAST --- 
      navigator.pop(true); 
      
    } catch (e) {
      // --- Check Mounted in Catch Block --- 
      if (!mounted) return; 
      
      // --- State Updates & UI Feedback (using captured references) --- 
      workflowState.setLoading(false); 
      workflowState.setErrorMessage('Failed to complete receipt: $e');
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to complete receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
      // Do NOT pop here on error, let the user decide or stay in modal
    }
  }

  @override
  Widget build(BuildContext context) {
    final workflowState = Provider.of<WorkflowState>(context);
    final colorScheme = Theme.of(context).colorScheme;

    // Show loading indicator if draft is being loaded initially, 
    // or if workflowState itself indicates loading for a receiptId (e.g. during _loadReceiptData).
    if (_isDraftLoading || (workflowState.receiptId != null && workflowState.isLoading && workflowState.currentStep == 0)) {
        // The condition `workflowState.currentStep == 0` helps ensure this full-screen loader 
        // only shows during the very initial load before any step navigation has occurred via _loadReceiptData.
        // Once _loadReceiptData completes, `isLoading` will be false, or `currentStep` will be non-zero.
      return Scaffold(
        appBar: AppBar(
          title: Text(workflowState.receiptId != null ? 'Loading Draft...' : 'New Receipt'),
          automaticallyImplyLeading: false, // No back button during this loading phase
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
            // _buildStepIndicator(workflowState.currentStep), // REMOVED direct call
            
            // Allow tapping on step indicators with confirmation
            GestureDetector(
              onTapUp: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localOffset = box.globalToLocal(details.globalPosition);
                final screenWidth = MediaQuery.of(context).size.width;
                // Ensure _stepTitles is not empty to prevent division by zero if titles are somehow not ready
                final stepWidth = _stepTitles.isNotEmpty ? screenWidth / _stepTitles.length : screenWidth;
                final tappedStep = stepWidth > 0 ? (localOffset.dx / stepWidth).floor() : 0;
                final currentStep = workflowState.currentStep;

                if (tappedStep >= 0 && tappedStep < _stepTitles.length && tappedStep != currentStep) {
                  bool canNavigate = true;
                  String blockingReason = 'Please complete previous steps first.';

                  if (tappedStep > currentStep) {
                    // Check data prerequisites for all steps from currentStep up to tappedStep - 1
                    for (int stepToValidate = currentStep; stepToValidate < tappedStep; stepToValidate++) {
                      if (stepToValidate == 0 && !workflowState.hasParseData) {
                        canNavigate = false;
                        blockingReason = 'Receipt must be parsed before proceeding from Upload step.';
                        debugPrint('[WorkflowModal] StepIndicator: Blocked tap from $currentStep to $tappedStep. Reason: missing parse data for step 1.');
                        break;
                      }
                      // No specific data check for leaving Review (step 1) to Assign (step 2)
                      if (stepToValidate == 2 && !workflowState.hasAssignmentData) {
                        canNavigate = false;
                        blockingReason = 'Items must be assigned before proceeding from Assign step.';
                        debugPrint('[WorkflowModal] StepIndicator: Blocked tap from $currentStep to $tappedStep. Reason: missing assignment data for step 3.');
                        break;
                      }
                      if (stepToValidate == 3 && !workflowState.hasAssignmentData) {
                        // This covers navigating from Split to Summary. The prerequisite is having assignment data.
                        canNavigate = false;
                        blockingReason = 'Splitting process must be based on assigned items before proceeding to Summary.';
                        debugPrint('[WorkflowModal] StepIndicator: Blocked tap from $currentStep to $tappedStep. Reason: missing assignment data for step 4.');
                        break;
                      }
                    }
                  }

                  if (canNavigate) {
                    workflowState.goToStep(tappedStep);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(blockingReason),
                          duration: const Duration(seconds: 3),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                }
              },
              child: _buildStepIndicator(workflowState.currentStep),
            ),
            
            Expanded(
              child: _buildStepContent(workflowState.currentStep),
            ),
            
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

  // --- START OF NEW HELPER METHODS FOR UPLOAD STEP CALLBACKS ---
  Future<void> _handleImageSelectedForUploadStep(File? file) async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    if (workflowState.hasParseData) {
      final confirmed = await _showConfirmationDialog(
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
      final confirmed = await _showConfirmationDialog(
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
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Please select an image first.'), backgroundColor: Colors.red),
          );
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
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to process/parse receipt: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleRetryForUploadStep() {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    workflowState.resetImageFile();
    workflowState.setErrorMessage(null);
  }
  // --- END OF NEW HELPER METHODS FOR UPLOAD STEP ---

  // --- START OF NEW HELPER METHODS FOR REVIEW STEP CALLBACKS ---
  void _handleReviewCompleteForReviewStep(List<ReceiptItem> updatedItems, List<ReceiptItem> deletedItems) {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    // Calculate the new subtotal from the updated items
    double newSubtotal = 0.0;
    for (var item in updatedItems) {
      newSubtotal += item.price * item.quantity;
    }
    newSubtotal = double.parse(newSubtotal.toStringAsFixed(2)); // Mitigate floating point issues for storage/comparison

    // Update workflowState's parseReceiptResult to reflect the reviewed items AND the new subtotal
    Map<String, dynamic> currentParseResult = Map.from(workflowState.parseReceiptResult);
    currentParseResult['items'] = updatedItems.map((item) => item.toJson()).toList();
    currentParseResult['subtotal'] = newSubtotal; // Store the recalculated subtotal
    
    workflowState.setParseReceiptResult(currentParseResult);

    debugPrint('[_WorkflowModalBodyState._handleReviewCompleteForReviewStep] Review complete. Subtotal: $newSubtotal. workflowState.parseReceiptResult updated. Updated items: ${updatedItems.length}, Deleted: ${deletedItems.length}');
    
    workflowState.clearTranscriptionAndSubsequentData();
    workflowState.nextStep();
  }

  void _handleItemsUpdatedForReviewStep(List<ReceiptItem> currentItems) {
    // Optional: Could use this to update a temporary state if needed.
    // For now, we rely on onReviewComplete and the getter for _saveDraft.
    // This method is extracted for consistency if logic is added later.
    debugPrint('[_WorkflowModalBodyState._handleItemsUpdatedForReviewStep] Items updated in review screen. Count: ${currentItems.length}');
  }

  void _handleRegisterCurrentItemsGetterForReviewStep(GetCurrentItemsCallback getter) {
    // This assigns the callback provided by ReceiptReviewScreen to the _WorkflowModalBodyState variable.
    // This allows _saveDraft to fetch the latest items from ReceiptReviewScreen if it's the current step.
    _getCurrentReviewItemsCallback = getter;
    debugPrint('[_WorkflowModalBodyState._handleRegisterCurrentItemsGetterForReviewStep] Registered getCurrentItems callback from ReceiptReviewScreen.');
  }
  // --- END OF NEW HELPER METHODS FOR REVIEW STEP ---

  // --- START OF NEW HELPER METHODS FOR ASSIGN STEP CALLBACKS ---
  void _handleAssignmentProcessedForAssignStep(Map<String, dynamic> assignmentResultData) {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    debugPrint('[_WorkflowModalBodyState._handleAssignmentProcessedForAssignStep] Received data type: ${assignmentResultData.runtimeType}');
    debugPrint('[_WorkflowModalBodyState._handleAssignmentProcessedForAssignStep] Data content: $assignmentResultData');
    workflowState.setAssignPeopleToItemsResult(assignmentResultData);
    workflowState.nextStep();
  }

  // Method to handle when new transcription is available from VoiceAssignmentScreen
  void _handleTranscriptionChangedForAssignStep(String? newTranscription) {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    Map<String, dynamic> newResult = Map.from(workflowState.transcribeAudioResult);
    if (newTranscription == null || newTranscription.isEmpty) {
      newResult.remove('text'); 
    } else {
      newResult['text'] = newTranscription;
    }
    workflowState.setTranscribeAudioResult(newResult);
    debugPrint('[WorkflowModal] Transcription updated by AssignStep: $newTranscription');
  }

  // Method to handle re-transcription request from VoiceAssignmentScreen
  Future<bool> _handleReTranscribeRequestedForAssignStep() async {
      final confirmed = await _showConfirmationDialog(
      // Positional arguments for title and content
      'Re-record Audio',
      'Are you sure you want to re-record the audio? The current transcription will be discarded.',
      );
    if (confirmed) { // _showConfirmationDialog returns bool, not bool?
      final workflowState = Provider.of<WorkflowState>(context, listen: false);
      workflowState.clearTranscriptionAndSubsequentData();
      debugPrint('[WorkflowModal] Re-transcription confirmed. Data cleared.');
    }
    return confirmed;
  }

  // Method to handle confirmation before processing assignments in VoiceAssignmentScreen
  Future<bool> _handleConfirmProcessAssignmentsForAssignStep() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    // Access transcription via transcribeAudioResult map
    final transcription = workflowState.transcribeAudioResult['text'] as String?;

    if (transcription == null || transcription.isEmpty) {
      // Use ScaffoldMessenger directly for error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please record or ensure transcription is available before processing.'),
            backgroundColor: Theme.of(context).colorScheme.error, 
          ),
        );
      }
      return false; 
    }

      final confirmed = await _showConfirmationDialog(
      // Positional arguments for title and content
      'Process Assignments',
      'Are you sure you want to process the assignments with the current transcription?',
    );
    if (confirmed) { // _showConfirmationDialog returns bool, not bool?
      debugPrint('[WorkflowModal] Assignment processing confirmed by user.');
    }
    return confirmed;
  }
  // --- END OF NEW HELPER METHODS FOR ASSIGN STEP ---

  // --- START OF NEW HELPER METHODS FOR SPLIT STEP CALLBACKS ---
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
      if (pageIndex == 4) { // Tapped "Go to Summary" (index 4) from Split (index 3)
        if (!workflowState.hasAssignmentData) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Cannot proceed to Summary: Assignment data is missing.'),
                duration: const Duration(seconds: 3),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          return; // Block navigation
        }
      }
      workflowState.goToStep(pageIndex);
    }
  }
  // --- END OF NEW HELPER METHODS FOR SPLIT STEP ---
}