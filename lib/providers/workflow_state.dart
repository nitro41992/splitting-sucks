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
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _transcriptionPrefsKeyPrefix + (_receiptId ?? 'draft');
      final jsonString = prefs.getString(key);
      
      if (jsonString != null && jsonString.isNotEmpty) {
        try {
          final data = jsonDecode(jsonString) as Map<String, dynamic>;
          bool changed = false;
          
          if (data.containsKey('text')) {
            final transcriptionMap = {'text': data['text']};
            if (_transcribeAudioResult != transcriptionMap) {
              _transcribeAudioResult = transcriptionMap;
              changed = true;
            }
          }
          
          if (data.containsKey('tip')) {
            final tipValue = data['tip'] as double?;
            if (_tip != tipValue) {
              _tip = tipValue;
              changed = true;
            }
          }
          
          if (data.containsKey('tax')) {
            final taxValue = data['tax'] as double?;
            if (_tax != taxValue) {
              _tax = taxValue;
              changed = true;
            }
          }
          
          if (changed) {
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Error parsing transcription JSON from SharedPreferences: $e');
          // Don't crash if JSON is malformed
        }
      }
    } catch (e) {
      debugPrint('Error loading transcription from SharedPreferences: $e');
    }
  }

  // Save transcription text, tip, and tax to SharedPreferences
  Future<void> saveTranscriptionToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _transcriptionPrefsKeyPrefix + (_receiptId ?? 'draft');
      
      // Prepare data to save
      final Map<String, dynamic> dataToSave = {};
      
      // Add text from transcribeAudioResult if available
      if (_transcribeAudioResult.containsKey('text')) {
        dataToSave['text'] = _transcribeAudioResult['text'];
      }
      
      // Add tip and tax if they have values
      if (_tip != null) {
        dataToSave['tip'] = _tip;
      }
      
      if (_tax != null) {
        dataToSave['tax'] = _tax;
      }
      
      // Only save if we have at least one value to save
      if (dataToSave.isNotEmpty) {
        await prefs.setString(key, jsonEncode(dataToSave));
      } else {
        // If no data, remove the key to clean up
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('Error saving transcription to SharedPreferences: $e');
    }
  }

  WorkflowState({required String restaurantName, String? receiptId, ImageStateManager? imageStateManager})
      : _restaurantName = restaurantName,
        _receiptId = receiptId,
        _imageStateManager = imageStateManager ?? ImageStateManager() {
    debugPrint('[WorkflowState Constructor] Initial _transcribeAudioResult: $_transcribeAudioResult');
    
    // Always try to load data, whether for a specific receipt or for drafts
    loadTranscriptionFromPrefs();
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
    if (result == null) {
      if (_transcribeAudioResult.isNotEmpty) {
        _transcribeAudioResult = {};
        saveTranscriptionToPrefs();
        notifyListeners();
      }
    } else {
      debugPrint('[WorkflowState setTranscribeAudioResult] Received result: $result');
      _transcribeAudioResult = Map<String, dynamic>.from(result);
      debugPrint('[WorkflowState setTranscribeAudioResult] _transcribeAudioResult is now: $_transcribeAudioResult');
      saveTranscriptionToPrefs();
      notifyListeners();
    }
  }

  void setAssignPeopleToItemsResult(Map<String, dynamic>? result) {
    if (result == null || result.isEmpty) {
      // Reset assignment data, but preserve tip/tax
      _assignPeopleToItemsResult = {};
      _people = [];
    } else {
      debugPrint('[WorkflowState] setAssignPeopleToItemsResult set to: $result');
      _assignPeopleToItemsResult = Map<String, dynamic>.from(result);
      // Extract people
      _people = _extractPeopleFromAssignments();
    }
    notifyListeners();
  }

  void setTip(double? value) {
    // Always update and notify in the current implementation
    _tip = value;
    saveTranscriptionToPrefs();
    notifyListeners();
  }

  void setTax(double? value) {
    // Always update and notify in the current implementation
    _tax = value;
    saveTranscriptionToPrefs();
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

    // Use existing ID or generate a temporary ID. 
    // This temporary ID won't matter since Firestore will generate a new one
    // when receiptId parameter is null in saveDraft/saveReceipt.
    final String receiptId = _receiptId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    
    // Get URIs safely handling potential nulls
    final imageUri = _imageStateManager.actualImageGsUri;
    final thumbnailUri = _imageStateManager.actualThumbnailGsUri;
    
    return Receipt(
      id: receiptId, // Use temporary ID when _receiptId is null
      restaurantName: _restaurantName,
      imageUri: imageUri,
      thumbnailUri: thumbnailUri,
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

  // Extract people from assignments result
  List<String> _extractPeopleFromAssignments() {
    return _extractPeopleFromAssignmentsMap(_assignPeopleToItemsResult);
  }
  
  // Extract people from a provided assignments map
  List<String> _extractPeopleFromAssignmentsMap(Map<String, dynamic> assignments) {
    if (assignments.isEmpty ||
        !assignments.containsKey('assignments')) {
      return [];
    }

    // Check if 'assignments' is a list before casting
    final dynamic assignmentsDynamic = assignments['assignments'];
    if (assignmentsDynamic is! List) {
      debugPrint('[WorkflowState _extractPeopleFromAssignments] \'assignments\' is not a List. Found: ${assignmentsDynamic.runtimeType}');
      return [];
    }

    final List<dynamic> assignmentsList = assignmentsDynamic;
    final Set<String> peopleNames = {}; // Use a Set to avoid duplicates

    for (var assignment in assignmentsList) {
      if (assignment is! Map) {
        continue; // Skip non-map assignments
      }

      final Map<dynamic, dynamic> assignmentMap = assignment;
      final dynamic peopleListDynamic = assignmentMap['people'];
      if (peopleListDynamic is! List) {
        if (peopleListDynamic != null) {
          debugPrint('[WorkflowState _extractPeopleFromAssignments] \'people\' in an assignment is not a List. Found: ${peopleListDynamic.runtimeType}');
        }
        continue; // Skip when people isn't a list
      }

      final List<dynamic> peopleList = peopleListDynamic;
      for (var person in peopleList) {
        if (person != null) {
          // Try to ensure we get a string representation no matter what
          peopleNames.add(person.toString());
        }
      }
    }

    return peopleNames.toList();
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