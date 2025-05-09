import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../widgets/image_state_manager.dart'; // Assuming ImageStateManager is in lib/widgets/

// If ImageStateManager has been moved to lib/providers/, update path accordingly.
// For now, assuming it's still in lib/widgets/

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

  List<String> get people => _people;

  bool get hasParseData => _parseReceiptResult.isNotEmpty &&
                          (_parseReceiptResult['items'] as List?)?.isNotEmpty == true;

  bool get hasTranscriptionData => _transcribeAudioResult.isNotEmpty &&
                                  (_transcribeAudioResult['text'] as String?)?.isNotEmpty == true;

  bool get hasAssignmentData => _assignPeopleToItemsResult.isNotEmpty &&
                               (_assignPeopleToItemsResult['assignments'] as List?)?.isNotEmpty == true;

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
    imageStateManager.setNewImageFile(file);
    _parseReceiptResult = {};
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    _tip = null;
    _tax = null;
    _people = [];
    notifyListeners();
  }

  void resetImageFile() {
    imageStateManager.resetImageFile();
    _parseReceiptResult = {};
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    _tip = null;
    _tax = null;
    _people = [];
    notifyListeners();
  }

  void setParseReceiptResult(Map<String, dynamic> result) {
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

  void clearPendingDeletions() {
    imageStateManager.clearPendingDeletionsList();
    notifyListeners();
  }

  void addUriToPendingDeletions(String? uri) {
    imageStateManager.addUriToPendingDeletionsList(uri);
    notifyListeners();
  }

  void removeUriFromPendingDeletions(String? uri) {
    imageStateManager.removeUriFromPendingDeletionsList(uri);
    notifyListeners();
  }
  
  Receipt toReceipt() {
    // Items are primarily managed within parseReceiptResult in WorkflowState
    // and then potentially refined/assigned in assignPeopleToItemsResult.
    // For constructing a Receipt object, we'll use the current state of these maps.

    return Receipt(
      id: _receiptId ?? '', // Ensure ID is present
      restaurantName: _restaurantName,
      imageUri: imageStateManager.actualImageGsUri,
      thumbnailUri: imageStateManager.actualThumbnailGsUri,
      parseReceipt: _parseReceiptResult, // This map contains the items list
      transcribeAudio: _transcribeAudioResult,
      assignPeopleToItems: _assignPeopleToItemsResult, // This map contains assignments
      status: 'draft', // Default to 'draft', can be changed before final save if completing
      people: _people, // This is derived from _assignPeopleToItemsResult
      tip: _tip,
      tax: _tax,
      // Let FirestoreService handle Timestamp creation for new receipts if id is empty,
      // or preserve existing timestamps when loading/updating a draft.
      // For now, to satisfy the constructor if these were required for a *new* object:
      createdAt: null, // Handled by FirestoreService or loaded from existing draft
      updatedAt: null, // Handled by FirestoreService or updated upon save
    );
  }

  List<String> _extractPeopleFromAssignments() {
    if (_assignPeopleToItemsResult.isEmpty ||
        !_assignPeopleToItemsResult.containsKey('assignments')) {
      return [];
    }
    final assignments = _assignPeopleToItemsResult['assignments'] as List<dynamic>?;
    if (assignments == null || assignments.isEmpty) {
      return [];
    }

    final Set<String> peopleSet = {};
    for (var assignment in assignments) {
      if (assignment is Map<String, dynamic> &&
          assignment.containsKey('people')) {
        final peopleInAssignment = assignment['people'] as List<dynamic>?;
        if (peopleInAssignment != null) {
          for (var person in peopleInAssignment) {
            if (person is String) {
              peopleSet.add(person);
            }
          }
        }
      }
    }
    return peopleSet.toList();
  }

  // Methods for clearing data for subsequent steps
  void clearParseAndSubsequentData() {
    _parseReceiptResult = {};
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    _tip = null; 
    _tax = null;
    _people = [];
    notifyListeners();
  }

  void clearTranscriptionAndSubsequentData() {
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    _tip = null;
    _tax = null;
    _people = [];
    notifyListeners();
  }

  void clearAssignmentAndSubsequentData() {
    _assignPeopleToItemsResult = {};
    _tip = null; // Keep tip/tax if desired, or clear them too.
    _tax = null;
    _people = [];
    notifyListeners();
  }
} 