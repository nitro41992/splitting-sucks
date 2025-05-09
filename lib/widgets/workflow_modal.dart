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
  double? _tip;
  double? _tax;
  List<String> _people = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // List to track GS URIs that might need deletion
  final List<String> _pendingDeletionGsUris = [];
  
  WorkflowState({required String restaurantName, String? receiptId})
      : _restaurantName = restaurantName,
        _receiptId = receiptId {
    debugPrint('[WorkflowState Constructor] Initial _transcribeAudioResult: $_transcribeAudioResult');
  }
  
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
  double? get tip => _tip;
  double? get tax => _tax;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Getter for the loaded thumbnail URL
  String? get loadedThumbnailUrl => _loadedThumbnailUrl;
  
  // Getter for the pending deletion list (read-only view)
  List<String> get pendingDeletionGsUris => List.unmodifiable(_pendingDeletionGsUris);
  
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
    // If there was a previous image URI, mark it for potential deletion
    if (_actualImageGsUri != null && _actualImageGsUri!.isNotEmpty) {
      _pendingDeletionGsUris.add(_actualImageGsUri!);
    }
    if (_actualThumbnailGsUri != null && _actualThumbnailGsUri!.isNotEmpty) {
      _pendingDeletionGsUris.add(_actualThumbnailGsUri!);
    }

    _imageFile = file;
    _loadedImageUrl = null; 
    _loadedThumbnailUrl = null; 
    _actualImageGsUri = null; 
    _actualThumbnailGsUri = null; 
    // When a new image is selected, CLEAR ALL SUBSEQUENT STEP DATA
    _parseReceiptResult = {}; 
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    _tip = null;
    _tax = null;
    _people = [];
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
    _loadedThumbnailUrl = null; 
    _actualImageGsUri = null;
    _actualThumbnailGsUri = null;
    // When image is reset, CLEAR ALL SUBSEQUENT STEP DATA
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
    
    // DO NOT CLEAR _transcribeAudioResult, _assignPeopleToItemsResult, _splitManagerState here.
    // These should be cleared more intentionally, for example when a new image is set
    // or when moving from review back to upload.
    // If items are re-parsed from the *same* image, subsequent steps might still be valid
    // or need specific invalidation logic.
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

  void setLoadedImageAndThumbnailUrls(String? imageUrl, String? thumbnailUrl) {
    _loadedImageUrl = imageUrl;
    _loadedThumbnailUrl = thumbnailUrl;
    notifyListeners(); // Notify once after both are set
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
        debugPrint('[WorkflowState] Added to pending deletions: $uri. Current list: $_pendingDeletionGsUris');
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
      status: 'draft',
      people: _people,
      tip: _tip,
      tax: _tax,
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
    
    // Sort for consistency? Optional.
    // people.sort(); 
    return people;
  }

  // Added setter for people list
  void setPeople(List<String> newPeople) {
    // Use ListEquality to check if lists are deeply equal to avoid unnecessary notifications
    if (!const DeepCollectionEquality().equals(_people, newPeople)) {
       _people = newPeople;
       notifyListeners();
    }
  }

  // --- EDIT: Add specific data clearing methods ---
  void clearParseAndSubsequentData() {
    _parseReceiptResult = {};
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    // _tip = null; // Keep Tip
    // _tax = null; // Keep Tax
    _people = [];
    debugPrint('[WorkflowState] Cleared Parse, Transcription, Assignment, People. Tip/Tax remain.');
    notifyListeners();
  }

  void clearTranscriptionAndSubsequentData() {
    _transcribeAudioResult = {};
    // _assignPeopleToItemsResult = {}; // Keep Assignments
    // _tip = null; // Keep Tip
    // _tax = null; // Keep Tax
    // _people = []; // Keep People (derived from assignments)
    debugPrint('[WorkflowState] Cleared ONLY Transcription. Assignments, People, Tip/Tax remain.');
    notifyListeners();
  }

  void clearAssignmentAndSubsequentData() {
    _assignPeopleToItemsResult = {};
    // _tip = null; // Keep Tip
    // _tax = null; // Keep Tax
    _people = []; // People list depends on assignments, so clear it.
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

class _WorkflowModalBodyState extends State<_WorkflowModalBody> {
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
      workflowState.setLoadedImageUrl(null);
      workflowState.setActualImageGsUri(null); 
      workflowState.setActualThumbnailGsUri(null);
      
      final snapshot = await _firestoreService.getReceipt(receiptId);
      
      if (!snapshot.exists) {
        throw Exception('Receipt not found');
      }
      
      final receipt = Receipt.fromDocumentSnapshot(snapshot);
      
      if (receipt.restaurantName != null) {
        workflowState.setRestaurantName(receipt.restaurantName!); 
      }
      if (receipt.imageUri != null) {
        workflowState.setActualImageGsUri(receipt.imageUri);
      }
      if (receipt.thumbnailUri != null) {
        workflowState.setActualThumbnailGsUri(receipt.thumbnailUri);
      }
      debugPrint('[_loadReceiptData] Loaded from Firestore. WorkflowState updated - ActualImageGsUri: ${workflowState.actualImageGsUri}, ActualThumbnailGsUri: ${workflowState.actualThumbnailGsUri}');

      // Load sub-document data, defaulting to empty maps if null from Firestore
      // This ensures WorkflowState always has valid, non-null maps for these.
      Map<String, dynamic> parseResultFromDraft = receipt.parseReceipt ?? {};
      parseResultFromDraft.remove('image_uri'); // Clean old fields
      parseResultFromDraft.remove('thumbnail_uri');
      workflowState.setParseReceiptResult(parseResultFromDraft);
      
      debugPrint('[_loadReceiptData] Data from Firestore for receipt.transcribeAudio: ${receipt.transcribeAudio}');
      workflowState.setTranscribeAudioResult(receipt.transcribeAudio); 
      workflowState.setAssignPeopleToItemsResult(receipt.assignPeopleToItems); 
      workflowState.setTip(receipt.tip);
      workflowState.setTax(receipt.tax);
      workflowState.setPeople(receipt.people ?? []);
      
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
      workflowState.setLoadedImageAndThumbnailUrls(loadedImageUrl, loadedThumbnailUrl);
      debugPrint('[LoadData Timer] WorkflowState updated with URLs via setLoadedImageAndThumbnailUrls.');
      
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
  Future<void> _saveDraft() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);

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
        // Keep workflowState from Provider.of for callbacks for now

        // Wrap the part that needs the latest URLs in a Consumer
        return Consumer<WorkflowState>(
          builder: (context, consumedState, child) {
            
            // Use consumedState for values needed for the build
            final bool isSuccessfullyParsed = consumedState.parseReceiptResult.containsKey('items') &&
                                              (consumedState.parseReceiptResult['items'] as List?)?.isNotEmpty == true;

            // **** Use consumedState in the debug print ****
            debugPrint('[_buildStepContent Consumer for Upload] consumedState.loadedImageUrl: ${consumedState.loadedImageUrl}, consumedState.loadedThumbnailUrl: ${consumedState.loadedThumbnailUrl}');
                
            return ReceiptUploadScreen(
              imageFile: consumedState.imageFile, // Use consumed state
              imageUrl: consumedState.loadedImageUrl, // Use consumed state
              loadedThumbnailUrl: consumedState.loadedThumbnailUrl, // Use consumed state
              isLoading: consumedState.isLoading, // Use consumed state
              isSuccessfullyParsed: isSuccessfullyParsed, // Use calculated value
              
              // Callbacks still use the workflowState obtained via Provider.of outside the Consumer
              onImageSelected: (file) async {
                // --- EDIT: Add confirmation if parse data exists ---
                if (workflowState.hasParseData) {
                  final confirmed = await _showConfirmationDialog(
                    'Confirm Action',
                    'Selecting a new image will clear all currently reviewed items, assigned people, and split details. Do you want to continue?'
                  );
                  if (!confirmed) return; // User cancelled
                  workflowState.clearParseAndSubsequentData();
                }
                // --- END EDIT ---

                if (file != null) {
                  workflowState.setImageFile(file); // This already clears subsequent data internally
                  workflowState.setErrorMessage(null);
                  // Store the file reference used for this specific upload attempt
                  final File imageFileForThisUpload = file; 

                  _uploadImageAndProcess(imageFileForThisUpload).then((uris) {
                    // Check if the widget is still mounted AND if the current imageFile in state is still the one we started this upload for.
                    if (mounted && workflowState.imageFile == imageFileForThisUpload) { 
                      workflowState.setActualImageGsUri(uris['imageUri']); 
                      workflowState.setActualThumbnailGsUri(uris['thumbnailUri']);
                      debugPrint('[WorkflowModal onImageSelected] Background upload complete. WorkflowState updated - ActualImageGsUri: ${workflowState.actualImageGsUri}, ActualThumbnailGsUri: ${workflowState.actualThumbnailGsUri}');
                    } else {
                      debugPrint('[WorkflowModal onImageSelected] Background upload complete, but context changed or image no longer matches. URIs not set or will be overwritten. Orphaned URIs might be ${uris['imageUri']}, ${uris['thumbnailUri']}');
                      // If URIs were generated but not set, they are now orphans. Add them to pending deletion.
                      if (uris['imageUri'] != null) workflowState.addUriToPendingDeletions(uris['imageUri']);
                      if (uris['thumbnailUri'] != null) workflowState.addUriToPendingDeletions(uris['thumbnailUri']);
                    }
                  }).catchError((error) {
                     // Check if the widget is still mounted AND if the current imageFile in state is still the one we started this upload for.
                     if (mounted && workflowState.imageFile == imageFileForThisUpload) { 
                        debugPrint('[WorkflowModal onImageSelected] Background upload failed for current image: $error');
                        workflowState.setErrorMessage('Background image upload failed. Please try parsing again or reselect.');
                        // Explicitly clear URIs in state as the upload for the current imageFile failed
                        workflowState.setActualImageGsUri(null);
                        workflowState.setActualThumbnailGsUri(null);
                      } else {
                        debugPrint('[WorkflowModal onImageSelected] Background upload failed for an outdated image selection: $error');
                        // The URIs that might have been generated for this outdated attempt are unknown here,
                        // but _uploadImageAndProcess should not return URIs if it hard-fails.
                        // If it somehow did, they'd be handled by the 'else' in the 'then' block if a new image was selected quickly.
                      }
                  });
                } else {
                  workflowState.resetImageFile(); 
                  workflowState.setErrorMessage(null);
                }
              },
              onParseReceipt: () async {
                // --- EDIT: Add confirmation dialog ---
                if (workflowState.hasParseData) {
                  final confirmed = await _showConfirmationDialog(
                    'Confirm Re-Parse',
                    'Parsing again will clear all currently reviewed items, voice assignments, and split details. Tip and Tax will be preserved. Do you want to continue?'
                  );
                  if (!confirmed) return;
                  workflowState.clearParseAndSubsequentData(); // Clears relevant data, preserves tip/tax
                }
                // --- END EDIT ---

                workflowState.setLoading(true); 
                workflowState.setErrorMessage(null);
                String? gsUriForParsing;
                try {
                  if (workflowState.actualImageGsUri != null && workflowState.actualImageGsUri!.isNotEmpty) { // Use original ref
                      gsUriForParsing = workflowState.actualImageGsUri;
                      debugPrint('[WorkflowModal onParseReceipt] Using pre-existing actualImageGsUri: $gsUriForParsing');
                  } else if (workflowState.imageFile != null) { // Use original ref
                      debugPrint('[WorkflowModal onParseReceipt] Local file detected, no GS URI yet. Uploading synchronously...');
                      final uris = await _uploadImageAndProcess(workflowState.imageFile!);
                      workflowState.setActualImageGsUri(uris['imageUri']); // Use original ref
                      workflowState.setActualThumbnailGsUri(uris['thumbnailUri']); // Use original ref
                      gsUriForParsing = uris['imageUri'];
                      debugPrint('[WorkflowModal onParseReceipt] Synchronous upload complete. WorkflowState updated - ActualImageGsUri: ${workflowState.actualImageGsUri}, ActualThumbnailGsUri: ${workflowState.actualThumbnailGsUri}. Using: $gsUriForParsing for parsing.');
                  } else if (workflowState.loadedImageUrl != null) { // Use original ref
                    debugPrint('[WorkflowModal onParseReceipt] CRITICAL: loadedImageUrl is present, but actualImageGsUri is missing...');
                    throw Exception('Image loaded from draft, but its GS URI is missing in state.');
                  } else {
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

                  if (gsUriForParsing == null || gsUriForParsing.isEmpty) {
                    debugPrint('[WorkflowModal onParseReceipt] CRITICAL: gsUriForParsing is null or empty...');
                    throw Exception('Image URI could not be determined for parsing.');
                  }
                  
                  Map<String, dynamic> newParseResult = {}; 
                  bool isNewImageJustUploaded = workflowState.imageFile != null; // Use original ref
                  bool shouldParse = isNewImageJustUploaded || 
                                    (!workflowState.parseReceiptResult.containsKey('items')) || // Use original ref
                                    ((workflowState.parseReceiptResult['items'] as List?)?.isEmpty ?? true);

                  if (shouldParse) {
                    debugPrint('[WorkflowModal onParseReceipt] Parsing needed...');
                    final ReceiptData parsedData = await ReceiptParserService.parseReceipt(gsUriForParsing);
                    newParseResult['items'] = parsedData.items;
                    newParseResult['subtotal'] = parsedData.subtotal;
                    workflowState.setParseReceiptResult(newParseResult); // Use original ref
                    debugPrint('[WorkflowModal onParseReceipt] Receipt parsed successfully...');
                  } else {
                    debugPrint('[WorkflowModal onParseReceipt] Parsing not needed...');
                  }

                  workflowState.setLoading(false); // Use original ref
                  workflowState.nextStep(); // Use original ref
                } catch (e) { 
                  debugPrint('[WorkflowModal onParseReceipt] Error: $e');
                  workflowState.setLoading(false); // Use original ref
                  workflowState.setErrorMessage('Failed to process/parse receipt: ${e.toString()}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to process/parse receipt: ${e.toString()}'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              onRetry: () { 
                workflowState.resetImageFile(); // Use original ref
                workflowState.setErrorMessage(null); // Use original ref
              },
            );
          },
        );
        
      case 1: // Review
        // Convert receipt data to ReceiptItem objects for review
        // --- EDIT: Check for parse data before building ---
        if (!workflowState.hasParseData) {
          return _buildPlaceholder('Please upload and parse a receipt first.');
        }
        // --- END EDIT ---
        final List<ReceiptItem> items = _convertToReceiptItems(workflowState.parseReceiptResult);
        
        debugPrint('[_buildStepContent Consumer for Review] Building ReceiptReviewScreen with ${items.length} items.');

        return ReceiptReviewScreen(
          initialItems: items,
          onReviewComplete: (updatedItems, deletedItems) {
            workflowState.setParseReceiptResult({
              ...workflowState.parseReceiptResult,
              'items': updatedItems.map((item) => item.toJson()).toList(),
            });
            debugPrint('Review complete. Updated items: ${updatedItems.length}, Deleted: ${deletedItems.length}');
            workflowState.nextStep();
          },
          onItemsUpdated: (currentItems) {
            // Optional: Could use this to update a temporary state if needed
            // For now, we rely on onReviewComplete and the getter for _saveDraft
          },
          registerCurrentItemsGetter: (getter) {
            _getCurrentReviewItemsCallback = getter;
            debugPrint('[_buildStepContent] Registered getCurrentItems callback from ReceiptReviewScreen.');
          }
        );
        
      case 2: // Assign
        return Consumer<WorkflowState>(
          builder: (context, consumedState, child) {
            // --- EDIT: Check for parse data before building ---
            if (!consumedState.hasParseData) {
              return _buildPlaceholder('Please complete the Review step first.');
            }
            // --- END EDIT ---
            final List<ReceiptItem> items = _convertToReceiptItems(consumedState.parseReceiptResult);
            
            debugPrint('[_buildStepContent Assign] consumedState._transcribeAudioResult: ${consumedState._transcribeAudioResult}');
            final String? initialTranscriptionFromState = consumedState.transcribeAudioResult['text'] as String?;
            debugPrint('[_buildStepContent Assign] initialTranscription from state for VoiceScreen: $initialTranscriptionFromState');

            return VoiceAssignmentScreen(
              itemsToAssign: items, 
              initialTranscription: initialTranscriptionFromState ?? '',
              onAssignmentProcessed: (assignmentResultData) {
                debugPrint('[WorkflowModal Assign CB] onAssignmentProcessed received data type: ${assignmentResultData.runtimeType}');
                debugPrint('[WorkflowModal Assign CB] onAssignmentProcessed data content: $assignmentResultData');
                workflowState.setAssignPeopleToItemsResult(assignmentResultData);
                workflowState.nextStep();
              },
              onTranscriptionChanged: (newTranscription) {
                final currentTranscribeResult = Map<String, dynamic>.from(workflowState.transcribeAudioResult);
                currentTranscribeResult['text'] = newTranscription;
                workflowState.setTranscribeAudioResult(currentTranscribeResult);
                debugPrint('[WorkflowModal] Transcription updated in WorkflowState using key \'text\': $newTranscription');
              },
              onReTranscribeRequested: () async {
                if (workflowState.hasTranscriptionData) {
                  final confirmed = await _showConfirmationDialog(
                    'Confirm Re-transcribe',
                    'Starting a new recording will clear the current transcription text. Assignments and split details will be preserved unless you re-process assignments later. Continue?'
                  );
                  if (!confirmed) return false;
                  workflowState.clearTranscriptionAndSubsequentData();
                  debugPrint('[WorkflowModal] Re-transcribe confirmed. Transcription cleared.');
                  return true;
                }
                return true;
              },
              onConfirmProcessAssignments: () async {
                if (workflowState.hasAssignmentData) {
                  final confirmed = await _showConfirmationDialog(
                    'Confirm Process Assignments',
                    'This will re-process assignments based on the current transcription and overwrite any existing assignment data. Tip and tax will be preserved. Continue?'
                  );
                  if (!confirmed) return false;
                  workflowState.clearAssignmentAndSubsequentData();
                  debugPrint('[WorkflowModal] Process assignments confirmed. Previous assignments cleared.');
                  return true;
                }
                return true;
              },
            );
          }
        );
        
      case 3: // Split
        return Consumer<WorkflowState>(
          builder: (context, workflowState, child) {
            // --- EDIT: Check for assignment data before building ---
            if (!workflowState.hasAssignmentData) {
              return _buildPlaceholder('Please complete the voice assignment first, or ensure people/items were assigned.');
            }
            // --- END EDIT ---
            final parseResult = workflowState.parseReceiptResult;
            final assignResultMap = workflowState.assignPeopleToItemsResult;
            debugPrint('[_buildStepContent SplitProvider] assignResultMap runtimeType: ${assignResultMap.runtimeType}');
            debugPrint('[_buildStepContent SplitProvider] assignResultMap content: $assignResultMap');

            // Always initialize SplitManager from the current workflowState's
            // parseReceiptResult and assignPeopleToItemsResult.
            debugPrint('[_buildStepContent SplitProvider] Creating/Recreating SplitManager for Split view.');

            final List<Map<String, dynamic>> assignments = 
                (assignResultMap['assignments'] as List<dynamic>?)
                    ?.map((e) => e as Map<String, dynamic>)
                    .toList() ?? [];
            
            final List<Map<String, dynamic>> sharedItemsFromAssign = 
                (assignResultMap['shared_items'] as List<dynamic>?)
                    ?.map((e) => e as Map<String, dynamic>)
                    .toList() ?? [];

            final List<Map<String, dynamic>> unassignedItemsFromAssign = 
                (assignResultMap['unassigned_items'] as List<dynamic>?)
                    ?.map((e) => e as Map<String, dynamic>)
                    .toList() ?? [];

            final List<Person> people = assignments.map((assignment) {
              final personName = assignment['person_name'] as String;
              final itemsForPerson = (assignment['items'] as List<dynamic>).map((itemMap) {
                final itemDetail = itemMap as Map<String, dynamic>;
                // Here, we need to create ReceiptItem instances.
                // We need a source for itemId if it exists, otherwise it's a new item.
                // For now, let's assume items parsed here might not have a persistent itemId yet,
                // or we can generate one if needed. This part might need refinement based on how
                // items are initially created and identified before explicit splitting.
                return ReceiptItem(
                  name: itemDetail['name'] as String,
                  quantity: (itemDetail['quantity'] as num).toInt(),
                  price: (itemDetail['price'] as num).toDouble(),
                  // itemId: if it comes from a parsed source, use it, else it's new.
                );
              }).toList();
              return Person(name: personName, assignedItems: itemsForPerson);
            }).toList();

            final List<ReceiptItem> sharedItems = sharedItemsFromAssign.map((itemMap) {
              // Similar to above, how do we get itemId if these are pre-existing items?
              return ReceiptItem(
                name: itemMap['name'] as String,
                quantity: (itemMap['quantity'] as num).toInt(),
                price: (itemMap['price'] as num).toDouble(),
                // people: (itemMap['people'] as List<dynamic>).cast<String>(), // This was for AssignmentResult.SharedItemDetail
              );
            }).toList();
            
            // Populate shared items for each person based on the 'people' field in sharedItemsFromAssign
            for (final sharedItemMap in sharedItemsFromAssign) {
                final itemName = sharedItemMap['name'] as String;
                final itemPrice = (sharedItemMap['price'] as num).toDouble();
                final sharedItemInstance = sharedItems.firstWhereOrNull(
                    (ri) => ri.name == itemName && ri.price == itemPrice
                );
                if (sharedItemInstance != null) {
                    final List<String> personNamesSharingThisItem = (sharedItemMap['people'] as List<dynamic>).cast<String>();
                    for (final personName in personNamesSharingThisItem) {
                        final person = people.firstWhereOrNull((p) => p.name == personName);
                        if (person != null && !person.sharedItems.any((si) => si.itemId == sharedItemInstance.itemId)) { // Ensure itemId is unique if used
                            person.addSharedItem(sharedItemInstance);
                        }
                    }
                }
            }


            final List<ReceiptItem> unassignedItemsFromAssignResult = unassignedItemsFromAssign.map((itemMap) {
              return ReceiptItem(
                name: itemMap['name'] as String,
                quantity: (itemMap['quantity'] as num).toInt(),
                price: (itemMap['price'] as num).toDouble(),
              );
            }).toList();
            
            // Extract initial items list from parseResult to get original quantities
            final initialItemsFromParse = (parseResult['items'] as List<dynamic>?)
              ?.map((itemMap) => ReceiptItem.fromJson(itemMap as Map<String, dynamic>))
              .toList() ?? [];

            final manager = SplitManager(
              people: people,
              sharedItems: sharedItems, // These are template shared items, not assigned yet. SplitManager handles distribution.
              unassignedItems: unassignedItemsFromAssignResult, 
              tipPercentage: workflowState.tip ?? (parseResult['tip'] as num?)?.toDouble(), // Prioritize workflowState tip
              taxPercentage: workflowState.tax ?? (parseResult['tax'] as num?)?.toDouble(), // Prioritize workflowState tax
              originalReviewTotal: (parseResult['subtotal'] as num?)?.toDouble(),
            );
            
            // Set original quantities in the manager
            for (var item in initialItemsFromParse) {
              manager.setOriginalQuantity(item, item.quantity);
            }
            // Also for items that might have come from assign_people_to_items but were not in original parse
            // (e.g. manually added items in a previous session that were saved in assign_people_to_items)
            final allKnownItemsForQuantities = [
              ...people.expand((p) => p.assignedItems),
              ...sharedItems, // these are distinct instances
              ...unassignedItemsFromAssignResult,
            ];
            for (var item in allKnownItemsForQuantities) {
                if (manager.getOriginalQuantity(item) == 0 && item.quantity > 0) { // only if not already set by parseResult
                    manager.setOriginalQuantity(item, item.quantity);
                }
            }
            
            manager.initialSplitViewTabIndex = _initialSplitViewTabIndex;

            // The SplitManager instance (manager) is created fresh.
            // Attach the listener directly here for this new instance.
            manager.addListener(() {
              if (mounted && Provider.of<WorkflowState>(context, listen: false) == workflowState) {
                if (workflowState.tip != manager.tipPercentage) {
                  workflowState.setTip(manager.tipPercentage);
                }
                if (workflowState.tax != manager.taxPercentage) {
                  workflowState.setTax(manager.taxPercentage);
                }
                final newAssignmentMap = manager.generateAssignmentMap();
                workflowState.setAssignPeopleToItemsResult(newAssignmentMap);
                final newPeopleList = manager.currentPeopleNames;
                workflowState.setPeople(newPeopleList);
              }
            });

            // Wrap SplitView with NotificationListener
            return NotificationListener<NavigateToPageNotification>(
              onNotification: (notification) {
                if (notification.pageIndex >= 0 && notification.pageIndex < _stepTitles.length) {
                  if (notification.pageIndex == 4) { // Tapped "Go to Summary" (index 4) from Split (index 3)
                    if (!workflowState.hasAssignmentData) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Cannot proceed to Summary: Assignment data is missing.'),
                          duration: const Duration(seconds: 3),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                      return true; // Notification handled, block navigation
                    }
                  }
                  workflowState.goToStep(notification.pageIndex);
                }
                return true; // Notification handled
              },
              child: ChangeNotifierProvider.value(
                value: manager,
                child: const SplitView(), 
              ),
            );
          }
        );
        
      case 4: // Summary
        // --- EDIT: Check for assignment data before building ---
        if (!workflowState.hasAssignmentData) {
           return _buildPlaceholder('Please complete the Split step first, ensuring items are assigned.');
        }
        // --- END EDIT ---
        return ChangeNotifierProvider(
          create: (context) {
            final assignResultMap = workflowState.assignPeopleToItemsResult;
            final parseResult = workflowState.parseReceiptResult;
            
            debugPrint('[_buildStepContent SummaryProvider] Creating SplitManager for Summary.');
            debugPrint('[_buildStepContent SummaryProvider] assignResultMap: $assignResultMap');

            final List<Person> peopleForManager = [];
            final List<ReceiptItem> sharedItemsForManager = [];
            final List<ReceiptItem> unassignedItemsForManager = [];

            // Populate directly from assignResultMap
            if (assignResultMap.containsKey('assignments') && assignResultMap['assignments'] is List) {
              for (var personData in (assignResultMap['assignments'] as List)) {
                if (personData is Map<String, dynamic>) {
                  final personName = personData['person_name'] as String? ?? 'Unknown Person';
                  final List<ReceiptItem> personItems = [];
                  if (personData['items'] is List) {
                    for (var itemData in (personData['items'] as List)) {
                      if (itemData is Map<String, dynamic>) {
                        personItems.add(ReceiptItem.fromJson(itemData));
                      }
                    }
                  }
                  // Create Person and add its shared items if they exist in personData (from assignResultMap)
                  // For now, assuming 'shared_items' for a person might not be directly in personData here
                  // as generateAssignmentMap() for person only serializes 'items' (assignedItems)
                  final personInstance = Person(name: personName, assignedItems: personItems);

                  // If assignResultMap's 'shared_items' list contains references to which people share them,
                  // we could iterate through sharedItemsForManager later and add to personInstance.sharedItems.
                  // Or, if personData itself contained 'shared_items_participation' like in earlier commented code
                  // in generateAssignmentMap, it could be used here.
                  // For now, this person only has assigned items.
                  peopleForManager.add(personInstance);
                }
              }
            }

            if (assignResultMap.containsKey('shared_items') && assignResultMap['shared_items'] is List) {
              for (var itemData in (assignResultMap['shared_items'] as List)) {
                if (itemData is Map<String, dynamic>) {
                  final sharedItem = ReceiptItem.fromJson(itemData);
                  sharedItemsForManager.add(sharedItem);
                  
                  // Post-process: Link shared items to people if assignResultMap indicates who shares them.
                  // This logic might be complex if 'itemData' (from assignResultMap['shared_items'])
                  // contains a list of person names/IDs that share this item.
                  // The SplitManager itself, when constructed with a list of people and a list of shared items,
                  // might internally establish these links or expect Person objects to already have their shared items populated.
                  // The original code (that was problematic) did try to populate Person.sharedItems.
                  // Let's assume for now that SplitManager.getPeopleForSharedItem() works by checking
                  // which people in its _people list have this sharedItem in their _sharedItems list.
                  // So, we need to populate Person._sharedItems based on `assignResultMap['shared_items']` if it has person linkage.
                  // The current `SplitManager.generateAssignmentMap` does NOT put a 'people' list inside each shared_item map.
                  // It just lists global shared items. The Person objects only have their 'assignedItems' serialized.
                  // So, the `Person` objects in `peopleForManager` won't have their `sharedItems` list populated from this map directly
                  // unless `SplitManager` constructor or other methods handle it.
                  // This might be a separate area to ensure consistency if `PersonCard` relies on `person.sharedItems`.
                  // For `summaryManager.totalAmount`, this direct population of `sharedItemsForManager` is correct.
                  // --- START ADDED LOGIC TO LINK SHARED ITEMS TO PEOPLE ---
                  if (itemData.containsKey('people') && itemData['people'] is List) {
                    final List<String> personNamesSharingThisItem = (itemData['people'] as List).cast<String>();
                    for (final personName in personNamesSharingThisItem) {
                      final person = peopleForManager.firstWhereOrNull((p) => p.name == personName);
                      if (person != null) {
                        // Ensure the person doesn't already have this exact item instance in their shared list
                        // This check might need to be more robust based on ReceiptItem's equality
                        if (!person.sharedItems.any((si) => si.name == sharedItem.name && si.price == sharedItem.price && si.quantity == sharedItem.quantity)) {
                           person.addSharedItem(sharedItem); // Use the instance from sharedItemsForManager if appropriate, or a new one.
                                                           // For now, assuming ReceiptItem.fromJson creates a suitable instance.
                        }
                      }
                    }
                  }
                  // --- END ADDED LOGIC ---
                }
              }
            }

            if (assignResultMap.containsKey('unassigned_items') && assignResultMap['unassigned_items'] is List) {
              for (var itemData in (assignResultMap['unassigned_items'] as List)) {
                if (itemData is Map<String, dynamic>) {
                  unassignedItemsForManager.add(ReceiptItem.fromJson(itemData));
                }
              }
            }
            
            // After populating peopleForManager and sharedItemsForManager,
            // we might need to iterate through sharedItemsForManager and assign them to the
            // respective Person objects in peopleForManager if the data model requires Person.sharedItems to be populated
            // and if assignResultMap['shared_items'] implies which person shares what.
            // However, `SplitManager.generateAssignmentMap()` current structure:
            // 'assignments': [{'person_name': ..., 'items': [assigned_item_jsons]}]
            // 'shared_items': [shared_item_jsons]  <-- No direct link to people here
            // 'unassigned_items': [unassigned_item_jsons]
            // So, Person objects created above will only have their `assignedItems`. `sharedItemsForManager` will be the global list.
            // This is consistent with how `SplitManager.totalAmount` works.

            final summaryManager = SplitManager(
              people: peopleForManager,
              sharedItems: sharedItemsForManager,
              unassignedItems: unassignedItemsForManager,
              tipPercentage: workflowState.tip,
              taxPercentage: workflowState.tax,
              originalReviewTotal: (parseResult['subtotal'] as num?)?.toDouble(),
            );
            
            return summaryManager;
          },
          // REMOVE the listener from here if SplitView is the only source
          // child: Column(
          //   children: [
          //     const Expanded(
          //       child: FinalSummaryScreen(),
          //     ),
          //     NotificationListener<NavigateToPageNotification>(
          //       onNotification: (notification) {
          //         if (notification.pageIndex < 5) { 
          //           workflowState.goToStep(notification.pageIndex);
          //         }
          //         return true; 
          //       },
          //       child: const SizedBox.shrink(), 
          //     ),
          //   ],
          // ),
          // Replace with direct child if listener is removed
          child: const FinalSummaryScreen(),
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
                    await _saveDraft();
                    if (mounted) {
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
                        // REMOVE the confirmation logic from here
                        // bool proceedAfterConfirm = true;
                        // if (currentStep == 2 /* && localWorkflowState.hasAssignmentData - implied by isNextEnabled */) { 
                        //   proceedAfterConfirm = await _showConfirmationDialog(
                        //     'Start Splitting',
                        //     'This will use the current assignments to start the split. Any existing split details (people modifications, item assignments in split, tip/tax) will be based on this. If you re-assign later, you may need to re-split. Continue?'
                        //   );
                        // }
                        // 
                        // if (proceedAfterConfirm) {
                        //     localWorkflowState.nextStep();
                        // }
                        
                        // Simply navigate if enabled
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
      final receiptId = await _firestoreService.completeReceipt( 
        receiptId: workflowState.receiptId!, 
        data: receipt.toMap(),
      );
      
      // --- Check Mounted After First Await --- 
      if (!mounted) return; 
      
      // --- State Updates (No Context Use) --- 
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
} 