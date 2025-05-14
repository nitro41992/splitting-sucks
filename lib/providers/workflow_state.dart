import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../widgets/image_state_manager.dart'; // Assuming ImageStateManager is in lib/widgets/
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// If ImageStateManager has been moved to lib/providers/, update path accordingly.
// For now, assuming it's still in lib/widgets/

/// Provider for the workflow state
class WorkflowState extends ChangeNotifier {
  int _currentStep = 0;
  String? _receiptId;
  String _restaurantName;
  final ImageStateManager _imageStateManager; // Renamed to private

  Map<String, dynamic> _parseReceiptResult = {};
  Map<String, dynamic> _transcribeAudioResult = {};
  Map<String, dynamic> _assignPeopleToItemsResult = {};
  double? _tip;
  double? _tax;
  List<String> _people = [];
  bool _isLoading = false;
  String? _errorMessage;

  static const String _transcriptionPrefsKeyPrefix = 'transcription_';

  // Public getter for imageStateManager
  ImageStateManager get imageStateManager => _imageStateManager;

  // List to track GS URIs that might need deletion
  List<String> get pendingDeletionGsUris => _imageStateManager.pendingDeletionGsUris;

  // Load transcription, tip, and tax from SharedPreferences if available
  Future<void> loadTranscriptionFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _transcriptionPrefsKeyPrefix + (_receiptId ?? 'draft');
    final jsonString = prefs.getString(key);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        if (data['text'] != null) {
          _transcribeAudioResult = {'text': data['text']};
        }
        if (data['tip'] != null) {
          _tip = (data['tip'] as num).toDouble();
        }
        if (data['tax'] != null) {
          _tax = (data['tax'] as num).toDouble();
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error decoding transcription/tip/tax from prefs: $e');
      }
    }
  }

  // Save transcription, tip, and tax to SharedPreferences
  Future<void> saveTranscriptionToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _transcriptionPrefsKeyPrefix + (_receiptId ?? 'draft');
    final text = _transcribeAudioResult['text'] as String?;
    final data = <String, dynamic>{};
    if (text != null && text.isNotEmpty) {
      data['text'] = text;
    }
    if (_tip != null) {
      data['tip'] = _tip;
    }
    if (_tax != null) {
      data['tax'] = _tax;
    }
    if (data.isNotEmpty) {
      await prefs.setString(key, jsonEncode(data));
    } else {
      await prefs.remove(key);
    }
  }

  WorkflowState({required String restaurantName, String? receiptId, ImageStateManager? imageStateManager})
      : _restaurantName = restaurantName,
        _receiptId = receiptId,
        _imageStateManager = imageStateManager ?? ImageStateManager() {
    debugPrint('[WorkflowState Constructor] Initial _transcribeAudioResult: [38;5;2m$_transcribeAudioResult[0m');
    if (_receiptId != null) {
      loadTranscriptionFromPrefs();
    }
  }

  // Getters
  int get currentStep => _currentStep;
  String get restaurantName => _restaurantName;
  String? get receiptId => _receiptId;
  File? get imageFile => _imageStateManager.imageFile;
  String? get loadedImageUrl => _imageStateManager.loadedImageUrl;
  String? get actualImageGsUri => _imageStateManager.actualImageGsUri;
  String? get actualThumbnailGsUri => _imageStateManager.actualThumbnailGsUri;
  String? get loadedThumbnailUrl => _imageStateManager.loadedThumbnailUrl;

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
    if (step >= 0 && step < 5) { // Max 5 steps (0-4)
      if (_currentStep != step) { // Only update and notify if the step is different
        _currentStep = step;
        notifyListeners();
      }
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
    _imageStateManager.setNewImageFile(file);
    _parseReceiptResult = {};
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    // Keep these values preserved across image changes
    // _tip = null;
    // _tax = null;
    _people = [];
    notifyListeners();
  }

  void resetImageFile() {
    _imageStateManager.resetImageFile();
    _parseReceiptResult = {};
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    // Keep these values preserved across image changes
    // _tip = null;
    // _tax = null;
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
    saveTranscriptionToPrefs();
    notifyListeners();
  }

  void setAssignPeopleToItemsResult(Map<String, dynamic>? result) {
    _assignPeopleToItemsResult = result ?? {};
    debugPrint('[WorkflowState] setAssignPeopleToItemsResult set to: ${_assignPeopleToItemsResult}');
    // Preserve tip and tax values when setting assignment data
    // _tip = null;
    // _tax = null;
    _people = _extractPeopleFromAssignments();
    notifyListeners();
  }

  void setTip(double? value) {
    if (_tip != value) {
      _tip = value;
      saveTranscriptionToPrefs();
      notifyListeners();
    }
  }

  void setTax(double? value) {
    if (_tax != value) {
      _tax = value;
      saveTranscriptionToPrefs();
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
    _imageStateManager.setUploadedGsUris(imageGsUri, thumbnailGsUri);
    notifyListeners();
  }

  void setLoadedImageUrls(String? imageUrl, String? thumbnailUrl) {
    _imageStateManager.setLoadedImageUrls(imageUrl, thumbnailUrl);
    notifyListeners();
  }

  void setActualGsUrisOnLoad(String? imageGsUri, String? thumbnailGsUri) {
    _imageStateManager.setActualGsUrisOnLoad(imageGsUri, thumbnailGsUri);
    notifyListeners();
  }

  void clearPendingDeletions() {
    _imageStateManager.clearPendingDeletionsList();
    notifyListeners();
  }

  void addUriToPendingDeletions(String? uri) {
    _imageStateManager.addUriToPendingDeletionsList(uri);
    notifyListeners();
  }

  void removeUriFromPendingDeletions(String? uri) {
    _imageStateManager.removeUriFromPendingDeletionsList(uri);
    notifyListeners();
  }
  
  Receipt toReceipt() {
    // Items are primarily managed within parseReceiptResult in WorkflowState
    // and then potentially refined/assigned in assignPeopleToItemsResult.
    // For constructing a Receipt object, we'll use the current state of these maps.

    return Receipt(
      id: _receiptId ?? '', // Ensure ID is present
      restaurantName: _restaurantName,
      imageUri: _imageStateManager.actualImageGsUri,
      thumbnailUri: _imageStateManager.actualThumbnailGsUri,
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

    // Check if 'assignments' is a list before casting
    final dynamic assignmentsDynamic = _assignPeopleToItemsResult['assignments'];
    if (assignmentsDynamic is! List) {
      debugPrint('[WorkflowState _extractPeopleFromAssignments] \'assignments\' is not a List. Found: ${assignmentsDynamic.runtimeType}');
      return [];
    }
    final List<dynamic> assignmentsList = assignmentsDynamic; // Safe cast now, renamed to avoid conflict

    if (assignmentsList.isEmpty) {
      return [];
    }

    final Set<String> peopleSet = {};
    for (var assignmentItem in assignmentsList) { // Use the correctly typed and named list
      if (assignmentItem is Map<String, dynamic> &&
          assignmentItem.containsKey('people')) {
        
        // Check if 'people' is a list before casting
        final dynamic peopleInAssignmentDynamic = assignmentItem['people'];
        if (peopleInAssignmentDynamic is! List) {
          debugPrint('[WorkflowState _extractPeopleFromAssignments] \'people\' in an assignment is not a List. Found: ${peopleInAssignmentDynamic.runtimeType}');
          continue; // Skip this assignment item
        }
        final List<dynamic> peopleInAssignment = peopleInAssignmentDynamic; // Safe cast now

        for (var person in peopleInAssignment) {
          if (person is String && person.isNotEmpty) { // Also check if string is not empty
            peopleSet.add(person);
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
    // Preserve tip and tax values
    // _tip = null; 
    // _tax = null;
    _people = [];
    notifyListeners();
  }

  void clearTranscriptionAndSubsequentData() {
    _transcribeAudioResult = {};
    _assignPeopleToItemsResult = {};
    // Preserve tip and tax values when clearing transcription data
    // _tip = null;
    // _tax = null;
    _people = [];
    notifyListeners();
  }

  void clearAssignmentAndSubsequentData() {
    _assignPeopleToItemsResult = {};
    // Preserve tip and tax values when clearing assignment data
    // _tip = null;
    // _tax = null;
    _people = [];
    notifyListeners();
  }
} 