import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async'; // Add Timer import
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart'; // Add import for Timestamp
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../models/split_manager.dart';
import '../models/person.dart';
import '../services/receipt_service.dart';
import '../services/receipt_parser_service.dart';
import '../services/audio_transcription_service.dart' as audio_service;
import '../screens/receipt_upload_screen.dart';
import '../screens/receipt_review_screen.dart';
import '../screens/voice_assignment_screen.dart';
import '../screens/assignment_review_screen.dart';
import '../screens/final_summary_screen.dart';
import '../models/person.dart' as model show Person;
import '../widgets/split_view.dart'; // Import for NavigateToPageNotification
import '../utils/toast_helper.dart'; // Import ToastHelper

// Create a new notification for split manager updates
class SplitManagerUpdateNotification extends Notification {
  final SplitManager splitManager;
  
  SplitManagerUpdateNotification(this.splitManager);
}

class ReceiptWorkflowPage extends StatefulWidget {
  final Receipt receipt;
  
  const ReceiptWorkflowPage({
    super.key,
    required this.receipt,
  });

  @override
  State<ReceiptWorkflowPage> createState() => _ReceiptWorkflowPageState();
}

class _ReceiptWorkflowPageState extends State<ReceiptWorkflowPage> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // Override keep alive to prevent page disposal
  @override
  bool get wantKeepAlive => true;
  
  final ReceiptService _receiptService = ReceiptService();
  late File? _imageFile;
  late List<ReceiptItem> _receiptItems;
  Map<String, dynamic>? _assignments;
  String? _savedTranscription;
  String? _restaurantName; // Add variable to track restaurant name
  
  // Make PageController final to prevent recreation
  final PageController _pageController = PageController(keepPage: true);
  
  // Timer for batching assignment saves
  Timer? _saveTimer;
  
  bool _isLoading = false;
  bool _isUploadComplete = false;
  bool _isReviewComplete = false;
  bool _isAssignmentComplete = false;
  bool _isSplitComplete = false;
  int _currentStep = 0; // Track workflow step
  
  // Flag to track whether state has been loaded
  bool _stateLoaded = false;
  
  // Add a key to access VoiceAssignmentScreen state without direct reference to private state class
  final GlobalKey _voiceAssignmentKey = GlobalKey();
  
  // Add a flag to prevent multiple concurrent save operations
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    
    // Add observer to detect lifecycle changes (app going to background)
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize state
    _imageFile = null;
    _receiptItems = [];
    
    // Load saved state if available
    _loadSavedState();
  }
  
  @override
  void dispose() {
    // Remove observer when disposed
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel any pending save timer
    _saveTimer?.cancel();
    
    // Save state before disposing
    // Use a try/catch to avoid crashing if the provider is not available
    SplitManager? splitManagerRef;
    
    try {
      // Only try to access the provider if we're mounted
      if (mounted) {
        try {
          splitManagerRef = Provider.of<SplitManager>(context, listen: false);
        } catch (e) {
          debugPrint('Provider not available during dispose: $e');
        }
      }
    } catch (e) {
      debugPrint('Error during dispose: $e');
    }
    
    // Save changes if we got a reference to the SplitManager
    if (splitManagerRef != null && splitManagerRef.assignmentsModified) {
      try {
        // Get the assignment data from the split manager
        final Map<String, dynamic> assignmentData = splitManagerRef.getAssignmentData();
        
        // Reset the modified flag
        splitManagerRef.assignmentsModified = false;
        
        // Fire and forget - don't wait for the save to complete
        _receiptService.saveAssignPeopleToItemsResults(
          widget.receipt.id!,
          assignmentData
        ).then((_) {
          debugPrint('Assignment changes saved during dispose');
        }).catchError((e) {
          debugPrint('Error saving assignments during dispose: $e');
        });
      } catch (e) {
        debugPrint('Error saving during dispose: $e');
      }
    }
    
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app is paused (moved to background), save any pending changes
    if (state == AppLifecycleState.paused) {
      debugPrint('App paused - saving assignments');
      
      // Cancel any pending save timer
      _saveTimer?.cancel();
      _saveTimer = null;
      
      SplitManager? splitManagerRef;
      
      try {
        // Check if context is still valid and mounted
        if (mounted) {
          // Use try/catch to safely attempt to get the provider
          try {
            splitManagerRef = Provider.of<SplitManager>(context, listen: false);
          } catch (providerError) {
            debugPrint('Provider not available for app lifecycle save: $providerError');
          }
        }
      } catch (e) {
        debugPrint('Error saving assignments on app pause: $e');
      }
      
      // Only proceed with saving if we got a valid reference to the SplitManager
      if (splitManagerRef != null && splitManagerRef.assignmentsModified) {
        try {
          // Get the assignment data directly
          final assignmentData = splitManagerRef.getAssignmentData();
          
          // Reset the flag right away
          splitManagerRef.assignmentsModified = false;
          
          // Fire and forget - don't await the result
          _receiptService.saveAssignPeopleToItemsResults(
            widget.receipt.id!,
            assignmentData
          ).then((_) {
            debugPrint('Successfully saved assignments during app pause');
          }).catchError((e) {
            debugPrint('Error during background save: $e');
          });
        } catch (e) {
          debugPrint('Error preparing assignment data: $e');
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      // When app is resumed, we might need to refresh data
      debugPrint('App resumed - checking for data refresh');
    }
  }
  
  Future<void> _loadSavedState() async {
    try {
      setState(() => _isLoading = true);
      
      // Get receipt data
      final receipt = await _receiptService.getReceiptById(widget.receipt.id!);
      
      if (receipt != null) {
        // Prepare data for state update
        File? imageFile;
        List<ReceiptItem> receiptItems = [];
        String? transcription;
        Map<String, dynamic>? assignments;
        String? restaurantName = receipt.metadata.restaurantName; // Load restaurant name
        bool isUploadComplete = false;
        bool isReviewComplete = false;
        bool isAssignmentComplete = false;
        int currentStep = 0;
        
        // Set image file path
        if (receipt.imageUri != null) {
          imageFile = File(receipt.imageUri!);
          isUploadComplete = true;
        }
        
        // Set review items
        if (receipt.parseReceipt != null && 
            receipt.parseReceipt!.containsKey('items')) {
          final items = receipt.parseReceipt!['items'] as List<dynamic>;
          receiptItems = items
              .map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
              .toList();
          isReviewComplete = receiptItems.isNotEmpty;
        }
        
        // Set transcription
        if (receipt.transcribeAudio != null && 
            receipt.transcribeAudio!.containsKey('transcription')) {
          transcription = receipt.transcribeAudio!['transcription'] as String?;
        }
        
        // Set assignments
        if (receipt.assignPeopleToItems != null) {
          assignments = receipt.assignPeopleToItems!;
          isAssignmentComplete = true;
        }
        
        // Set appropriate step based on state
        if (isAssignmentComplete) {
          currentStep = 3; // Jump to split screen
        } else if (isReviewComplete) {
          currentStep = 2; // Jump to assignment screen
        } else if (isUploadComplete) {
          currentStep = 1; // Jump to review screen
        } else {
          currentStep = 0; // Start at upload screen
        }
        
        // Update state in a single setState call
        setState(() {
          _imageFile = imageFile;
          _receiptItems = receiptItems;
          _savedTranscription = transcription;
          _assignments = assignments;
          _restaurantName = restaurantName; // Set restaurant name
          _isUploadComplete = isUploadComplete;
          _isReviewComplete = isReviewComplete;
          _isAssignmentComplete = isAssignmentComplete;
          _currentStep = currentStep;
          _isLoading = false;
          _stateLoaded = true;
        });
        
        // Use jumpToPage after state is updated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(_currentStep);
            debugPrint('Initial page set to: $_currentStep');
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _stateLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading receipt data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _stateLoaded = true;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return ChangeNotifierProvider(
      create: (context) {
        final splitManager = SplitManager();
        
        // Use a post-frame callback to listen for changes in the split manager
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          
          splitManager.addListener(() {
            // Only auto-save when changes are made and the manager is initialized
            if (splitManager.assignmentsModified && splitManager.initialized) {
              // Cancel previous timer if there's one running
              _saveTimer?.cancel();
              
              // Set a new timer to save changes after a short delay (batch changes)
              _saveTimer = Timer(const Duration(milliseconds: 500), () {
                _autoSaveAssignments(splitManager);
              });
            }
          });
        });
        
        return splitManager;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBackNavigation(),
          ),
          title: const Text('Receipt Workflow'),
          actions: [
            // Only show Skip buttons on first three screens
            if (_currentStep < 3)
              TextButton(
                onPressed: () => _navigateToNextStep(),
                child: const Text('SKIP'),
              ),
          ],
        ),
        body: SafeArea(
          child: _isLoading && !_stateLoaded 
            ? const Center(child: CircularProgressIndicator())
            : Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: NotificationListener<NavigateToPageNotification>(
                    onNotification: (notification) {
                      // Auto-save before navigation
                      try {
                        if (mounted) {
                          try {
                            // Try to get the SplitManager, but don't crash if it's not available
                            final splitManager = Provider.of<SplitManager>(context, listen: false);
                            if (splitManager.assignmentsModified) {
                              // Get data and clear modified flag
                              final assignmentData = splitManager.getAssignmentData();
                              splitManager.assignmentsModified = false;
                              
                              // Fire and forget
                              _receiptService.saveAssignPeopleToItemsResults(
                                widget.receipt.id!,
                                assignmentData
                              ).then((_) {
                                debugPrint('Assignment changes saved before notification navigation');
                              }).catchError((e) {
                                debugPrint('Error saving assignments during notification: $e');
                              });
                            }
                          } catch (e) {
                            debugPrint('Provider not available for notification save: $e');
                          }
                        }
                      } catch (e) {
                        debugPrint('Error during notification handling: $e');
                      }
                      
                      // Navigate to the requested page
                      debugPrint('Received NavigateToPageNotification to page: ${notification.pageIndex}');
                      setState(() {
                        _currentStep = notification.pageIndex;
                      });
                      
                      // Use jumpToPage for immediate transition without animation to prevent flashing
                      if (_pageController.hasClients) {
                        _pageController.jumpToPage(_currentStep);
                      } else {
                        debugPrint('ERROR: PageController has no clients when trying to navigate');
                      }
                      
                      // Return true to stop notification propagation
                      return true;
                    },
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(), // Disable swiping between pages
                      onPageChanged: (index) {
                        // Update current step if it's changed via the controller
                        if (index != _currentStep) {
                          setState(() {
                            _currentStep = index;
                          });
                        }
                      },
                      children: [
                        _buildUploadScreen(),
                        _buildReviewScreen(),
                        _buildAssignScreen(),
                        _buildSplitScreen(),
                        _buildSummaryScreen(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
  
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Step indicators in the center
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepDot(0, 'Upload'),
              _buildStepConnector(0),
              _buildStepDot(1, 'Review'),
              _buildStepConnector(1),
              _buildStepDot(2, 'Assign'),
              _buildStepConnector(2),
              _buildStepDot(3, 'Split'),
              _buildStepConnector(3),
              _buildStepDot(4, 'Summary'),
            ],
          ),
          // Close button on the right
          Positioned(
            right: 16.0,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _confirmCancel,
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStepDot(int step, String label) {
    final bool isActive = _currentStep == step;
    final bool isCompleted = _currentStep > step || 
                           (step == 0 && _isUploadComplete) ||
                           (step == 1 && _isReviewComplete) ||
                           (step == 2 && _isAssignmentComplete) ||
                           (step == 3 && _isSplitComplete);
    
    // Allow navigation to any step that is either:
    // 1. The current step or a previous step
    // 2. The next step (only one step ahead)
    // 3. The Summary step if we're on Split step and all items are assigned
    bool canNavigate = false;
    
    // Can always navigate to current or previous steps
    if (step <= _currentStep) {
      canNavigate = true;
    } else if (step == _currentStep + 1) {
      // Can navigate to the next step if we have the necessary data
      switch (step) {
        case 1: // Review step
          canNavigate = _isUploadComplete;
          break;
        case 2: // Assign step
          canNavigate = _isReviewComplete;
          break;
        case 3: // Split step
          canNavigate = _isAssignmentComplete;
          break;
        case 4: // Summary step - special case, always allow if we're on Split
          canNavigate = _currentStep == 3; // Always allow going to Summary from Split
          break;
      }
    }
    
    return MouseRegion(
      cursor: canNavigate ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: canNavigate ? () {
          debugPrint('Navigating to step $step from $_currentStep');
          setState(() {
            _currentStep = step;
          });
          
          // Use jumpToPage for immediate transition without animation
          if (_pageController.hasClients) {
            _pageController.jumpToPage(step);
          }
        } : null,
        child: Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isActive 
                  ? Theme.of(context).primaryColor 
                  : (isCompleted ? Colors.green : Colors.grey[300]),
                shape: BoxShape.circle,
                // Add a subtle shadow for interactive steps
                boxShadow: canNavigate ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ] : null,
              ),
              child: isCompleted 
                ? const Icon(Icons.check, color: Colors.white, size: 16) 
                : Center(
                    child: Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive 
                  ? Theme.of(context).primaryColor 
                  : (isCompleted ? Colors.green : (canNavigate ? Theme.of(context).primaryColor.withOpacity(0.7) : Colors.grey[600])),
                fontSize: 12,
                fontWeight: canNavigate ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStepConnector(int step) {
    final bool isCompleted = _currentStep > step;
    
    return Container(
      width: 20,
      height: 2,
      color: isCompleted ? Colors.green : Colors.grey[300],
    );
  }
  
  void _navigateToPreviousStep() {
    if (_currentStep > 0) {
      // Cancel any pending save timer
      _saveTimer?.cancel();
      _saveTimer = null;
      
      // Try to save changes before navigation
      SplitManager? splitManagerRef;
      
      try {
        if (mounted) {
          try {
            splitManagerRef = Provider.of<SplitManager>(context, listen: false);
          } catch (e) {
            debugPrint('Provider not available during back navigation: $e');
          }
        }
      } catch (e) {
        debugPrint('Error during back navigation: $e');
      }
      
      // Save changes if we got a reference to the SplitManager
      if (splitManagerRef != null && splitManagerRef.assignmentsModified) {
        try {
          // Get data and clear modified flag
          final assignmentData = splitManagerRef.getAssignmentData();
          splitManagerRef.assignmentsModified = false;
          
          // Fire and forget
          _receiptService.saveAssignPeopleToItemsResults(
            widget.receipt.id!,
            assignmentData
          ).then((_) {
            debugPrint('Assignment changes saved before previous step');
          }).catchError((e) {
            debugPrint('Error saving assignments during navigation: $e');
          });
        } catch (e) {
          debugPrint('Error preparing assignment data: $e');
        }
      }
      
      setState(() {
        _currentStep--;
      });
      
      // Wait for the next frame to ensure state update is processed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        // Use jumpToPage for immediate transition without animation to prevent flashing
        if (_pageController.hasClients) {
          debugPrint('Jumping directly to page $_currentStep');
          _pageController.jumpToPage(_currentStep);
        } else {
          debugPrint('WARNING: PageController has no clients, navigation may fail');
        }
      });
    }
  }
  
  void _navigateToNextStep() {
    debugPrint('_navigateToNextStep called - Current step: $_currentStep');
    
    if (_currentStep < 4) {
      // Cancel any pending save timer
      _saveTimer?.cancel();
      _saveTimer = null;
      
      // Try to save changes before navigation
      SplitManager? splitManagerRef;
      
      try {
        if (mounted) {
          try {
            splitManagerRef = Provider.of<SplitManager>(context, listen: false);
          } catch (e) {
            debugPrint('Provider not available during next navigation: $e');
          }
        }
      } catch (e) {
        debugPrint('Error during next navigation: $e');
      }
      
      // Save changes if we got a reference to the SplitManager
      if (splitManagerRef != null && splitManagerRef.assignmentsModified) {
        try {
          // Get data and clear modified flag
          final assignmentData = splitManagerRef.getAssignmentData();
          splitManagerRef.assignmentsModified = false;
          
          // Fire and forget
          _receiptService.saveAssignPeopleToItemsResults(
            widget.receipt.id!,
            assignmentData
          ).then((_) {
            debugPrint('Assignment changes saved before next step');
          }).catchError((e) {
            debugPrint('Error saving assignments during navigation: $e');
          });
        } catch (e) {
          debugPrint('Error preparing assignment data: $e');
        }
      }
      
      final nextStep = _currentStep + 1;
      debugPrint('Advancing to step: $nextStep');
      
      // Update step first before any animation
      setState(() {
        _currentStep = nextStep;
      });
      
      // Wait for the next frame to ensure state update is processed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        // Use jumpToPage for immediate transition without animation to prevent flashing
        if (_pageController.hasClients) {
          debugPrint('Jumping directly to page $_currentStep');
          _pageController.jumpToPage(_currentStep);
        } else {
          debugPrint('WARNING: PageController has no clients, navigation may fail');
        }
      });
    } else {
      // Finish the workflow
      debugPrint('Workflow complete, calling _completeWorkflow()');
      // Try to safely complete the workflow
      try {
        SplitManager? splitManagerRef;
        
        if (mounted) {
          try {
            splitManagerRef = Provider.of<SplitManager>(context, listen: false);
          } catch (e) {
            debugPrint('Provider not available for workflow completion: $e');
          }
        }
        
        if (splitManagerRef != null) {
          _completeWorkflow(splitManagerRef);
        } else {
          // Just go back to the receipts list as fallback
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        debugPrint('Error during workflow completion: $e');
        // Just go back to the receipts list as fallback
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }
  
  void _confirmCancel() {
    // Try to safely save any pending changes first, but don't crash if provider is not available
    SplitManager? splitManagerRef;
    
    try {
      // Cancel any pending save timer
      _saveTimer?.cancel();
      _saveTimer = null;
      
      // Safely try to get the SplitManager and save changes before showing dialog
      if (mounted) {
        try {
          splitManagerRef = Provider.of<SplitManager>(context, listen: false);
        } catch (providerError) {
          debugPrint('Provider not available for cancel dialog: $providerError');
        }
      }
    } catch (e) {
      // Safely ignore other errors
      debugPrint('Error during cancel dialog: $e');
    }
    
    // Save changes if we got a reference to the SplitManager
    if (splitManagerRef != null && splitManagerRef.assignmentsModified) {
      try {
        // Get the assignment data from the split manager
        final Map<String, dynamic> assignmentData = splitManagerRef.getAssignmentData();
        
        // Reset the modified flag since we've saved the changes
        splitManagerRef.assignmentsModified = false;
        
        // Fire and forget - don't wait for the save to complete
        _receiptService.saveAssignPeopleToItemsResults(
          widget.receipt.id!,
          assignmentData
        ).then((_) {
          debugPrint('Assignment changes saved on exit');
        }).catchError((e) {
          debugPrint('Error saving assignments on exit: $e');
        });
      } catch (e) {
        debugPrint('Error saving before exit: $e');
      }
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Receipt'),
          content: const Text('Are you sure you want to cancel? Your progress will be saved as a draft.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CONTINUE EDITING'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // We don't try to access the provider again on exit
                Navigator.of(context).pop(); // Return to previous screen
              },
              child: const Text('EXIT'),
            ),
          ],
        );
      },
    );
  }
  
  void _completeWorkflow(SplitManager splitManager) async {
    try {
      // First save the split manager state
      await _autoSaveSplitManagerState(splitManager);
      
      // Also save assignments
      await _autoSaveAssignments(splitManager);
      
      // Show saving indicator
      setState(() => _isLoading = true);
      
      // Mark receipt as completed
      await _receiptService.updateReceiptStatus(widget.receipt.id!, 'completed');
      
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      
      // Show success message
      ToastHelper.showToast(
        context,
        'Receipt completed successfully!',
        isSuccess: true,
      );
      
      // Return to previous screen
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error completing receipt: $e');
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      
      // Show error message
      ToastHelper.showToast(
        context,
        'Error completing receipt: $e',
        isError: true,
      );
    }
  }
  
  // Screen builders
  Widget _buildUploadScreen() {
    return ReceiptUploadScreen(
      imageFile: _imageFile,
      isLoading: _isLoading,
      restaurantName: _restaurantName, // Pass restaurant name
      onImageSelected: (file) {
        setState(() {
          _imageFile = file;
        });
      },
      onRestaurantNameChanged: (name) {
        // Update restaurant name in state
        setState(() {
          _restaurantName = name;
        });
        
        // If receipt exists, update its metadata
        if (widget.receipt.id != null) {
          // Update through a full receipt update
          final updatedReceipt = widget.receipt.copyWith(
            metadata: widget.receipt.metadata.copyWith(
              restaurantName: name,
              updatedAt: Timestamp.now(),
            ),
          );
          
          _receiptService.updateReceipt(updatedReceipt).then((_) {
            debugPrint('Updated receipt metadata with restaurant name: $name');
          }).catchError((e) {
            debugPrint('Error updating receipt metadata: $e');
          });
        }
      },
      onParseReceipt: () async {
        try {
          // Debug log - starting parse
          debugPrint('Starting receipt parse process...');
          
          // Save image and parse results
          if (_imageFile != null) {
            // Show saving status
            setState(() => _isLoading = true);
            
            // Check if the image file path is a remote URL
            final isRemoteUrl = _imageFile!.path.startsWith('http');
            
            if (isRemoteUrl) {
              debugPrint('Image is already a remote URL, skipping parse: ${_imageFile!.path}');
              
              // If we have the URL but no items, that means we need to retrieve them
              if (_receiptItems.isEmpty && widget.receipt.parseReceipt != null) {
                debugPrint('Loading previously parsed receipt items from Firestore');
                
                // Try to load items from stored parseReceipt data
                if (widget.receipt.parseReceipt!.containsKey('items')) {
                  final items = widget.receipt.parseReceipt!['items'] as List<dynamic>;
                  _receiptItems = items
                      .map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
                      .toList();
                  debugPrint('Loaded ${_receiptItems.length} items from stored data');
                }
              }
              
              setState(() {
                _isUploadComplete = true;
                _isLoading = false;
              });
              
              // Navigate to review screen
              setState(() {
                _currentStep = 1; // Explicitly set to Review step
              });
              
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _pageController.hasClients) {
                  _pageController.jumpToPage(1);
                }
              });
              
              return;
            }
            
            // Upload image and get URLs
            debugPrint('Uploading image to Firebase Storage...');
            final urls = await _receiptService.uploadReceiptImage(
              _imageFile!,
              widget.receipt.id!,
            );
            debugPrint('Image uploaded successfully with URLs: $urls');
            
            // Update receipt with image URLs and restaurant name
            final updatedReceipt = widget.receipt.copyWith(
              imageUri: urls['imageUri'],
              thumbnailUri: urls['thumbnailUri'],
              metadata: widget.receipt.metadata.copyWith(
                restaurantName: _restaurantName,
                updatedAt: Timestamp.now(),
              ),
            );
            
            await _receiptService.updateReceipt(updatedReceipt);
            debugPrint('Receipt updated with image URLs and metadata');
            
            // Use ReceiptParserService to parse the image
            debugPrint('Calling receipt parser service...');
            final parseResult = await ReceiptParserService.parseReceipt(_imageFile!);
            debugPrint('Receipt parsed successfully. ItemCount: ${parseResult.items.length}');
            
            // Get receipt items
            final items = parseResult.getReceiptItems();
            
            // Save parse receipt results
            final parseResults = {
              'items': items.map((item) => item.toJson()).toList(),
            };
            
            await _receiptService.saveParseReceiptResults(
              widget.receipt.id!,
              parseResults,
            );
            debugPrint('Parse results saved to Firestore');
            
            setState(() {
              _receiptItems = items;
              _isUploadComplete = true;
              _isLoading = false;
            });
            debugPrint('State updated, isUploadComplete: $_isUploadComplete');
            
            // Force a delay to ensure state update is processed
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Auto-navigate to next screen after successful upload and parse
            debugPrint('Attempting to navigate from Upload (step 0) to Review (step 1)...');
            
            // Use direct method for reliable navigation
            setState(() {
              _currentStep = 1; // Explicitly set to Review step
            });
            
            // Use direct jumpToPage without animation to prevent flashing
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pageController.hasClients) {
                debugPrint('Directly jumping to Review screen (page 1)');
                _pageController.jumpToPage(1);
                
                // Show success toast after navigation
                ToastHelper.showToast(
                  context,
                  'Receipt uploaded and processed successfully',
                  isSuccess: true,
                );
              }
            });
          }
        } catch (e) {
          debugPrint('Error saving receipt data: $e');
          setState(() => _isLoading = false);
          
          // Show error message
          if (mounted) {
            ToastHelper.showToast(
              context,
              'Error processing receipt: $e',
              isError: true,
            );
          }
        }
      },
      onRetry: () {
        setState(() {
          _imageFile = null;
        });
      },
    );
  }
  
  Widget _buildReviewScreen() {
    return ReceiptReviewScreen(
      initialItems: _receiptItems,
      onReviewComplete: (items, deletedItems) async {
        try {
          // Show saving indicator
          setState(() => _isLoading = true);
          
          // Save updated items
          final parseResults = {
            'items': items.map((item) => item.toJson()).toList(),
          };
          
          await _receiptService.saveParseReceiptResults(
            widget.receipt.id!,
            parseResults,
          );
          
          debugPrint('Review data saved to Firestore successfully');
          
          setState(() {
            _receiptItems = items;
            _isReviewComplete = true;
            _isLoading = false;
          });
          
          // Ensure all relevant state is updated correctly before navigation
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Debug log before navigation
          debugPrint('About to navigate from Review (step 1) to Assign (step 2), current step: $_currentStep');
          
          // Use direct method for reliable navigation
          setState(() {
            _currentStep = 2; // Explicitly set to Assign step
          });
          
          // Use direct jumpToPage without animation to prevent flashing
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              debugPrint('Directly jumping to Assign screen (page 2)');
              _pageController.jumpToPage(2);
              
              // Show success toast after navigation
              ToastHelper.showToast(
                context,
                'Receipt items saved successfully',
                isSuccess: true,
              );
            }
          });
        } catch (e) {
          debugPrint('Error saving receipt items: $e');
          setState(() => _isLoading = false);
          
          // Show error message
          if (mounted) {
            ToastHelper.showToast(
              context,
              'Error saving items: $e',
              isError: true,
            );
          }
        }
      },
      onItemsUpdated: (items) async {
        // Real-time updates when items change
        setState(() {
          _receiptItems = items;
        });
        
        // Save changes to backend without UI blocking
        try {
          final parseResults = {
            'items': items.map((item) => item.toJson()).toList(),
          };
          
          await _receiptService.saveParseReceiptResults(
            widget.receipt.id!,
            parseResults,
          );
        } catch (e) {
          debugPrint('Error auto-saving receipt items: $e');
        }
      },
    );
  }
  
  Widget _buildAssignScreen() {
    return WillPopScope(
      // Save transcription when user attempts to navigate back
      onWillPop: () async {
        try {
          // Reset any stuck loading state first
          if (_isLoading) {
            setState(() => _isLoading = false);
          }
          
          // Trigger save on navigation by calling onTranscriptionChanged with current value
          if (_savedTranscription != null) {
            await _saveTranscription(_savedTranscription!);
          }
        } catch (e) {
          debugPrint('Error saving transcription on pop: $e');
          // Ensure loading is reset regardless of errors
          if (mounted && _isLoading) {
            setState(() => _isLoading = false);
          }
        }
        return true;
      },
      child: VoiceAssignmentScreen(
        key: _voiceAssignmentKey,
        itemsToAssign: _receiptItems,
        initialTranscription: _savedTranscription,
        onTranscriptionChanged: (String? transcription) {
          if (transcription != null) {
            _saveTranscription(transcription);
          }
        },
        onAssignmentProcessed: (assignments) async {
          debugPrint('Assignment processing callback triggered');
          try {
            // Show saving indicator immediately to prevent UI interaction
            if (mounted) {
              setState(() => _isLoading = true);
            }
            
            // Debug log
            debugPrint('Saving assignments: ${assignments.toString().substring(0, math.min(100, assignments.toString().length))}...');
            
            // Save assignments
            await _receiptService.saveAssignPeopleToItemsResults(
              widget.receipt.id!,
              assignments,
            );
            
            debugPrint('Assignment data saved to Firestore successfully');
            
            // Only proceed if still mounted
            if (!mounted) return;
            
            // Cancel any pending save timer if it exists
            _saveTimer?.cancel();
            
            // Update state and immediately request a page change
            // DON'T try to access SplitManager here - it will be created when we navigate
            setState(() {
              _assignments = assignments; // Replace the assignments with the new ones
              _isAssignmentComplete = true;
              _currentStep = 3; // Set to Split step in the same setState call
              _isLoading = false;
            });
            
            // Use direct jumpToPage without animation to prevent flashing
            // Wait for the next frame to ensure state update is processed
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              
              debugPrint('Post-frame callback: Jumping to Split screen (page 3), current step: $_currentStep');
              if (_pageController.hasClients) {
                // Force a jump to the split page
                _pageController.jumpToPage(3);
                
                // Show success toast after navigation
                ToastHelper.showToast(
                  context,
                  'Assignments saved successfully',
                  isSuccess: true,
                );
              } else {
                debugPrint('ERROR: PageController has no clients when trying to navigate');
              }
            });
          } catch (e) {
            debugPrint('Error saving assignments: $e');
            if (mounted) {
              setState(() => _isLoading = false);
              
              // Show error message
              ToastHelper.showToast(
                context,
                'Error saving assignments: $e',
                isError: true,
              );
            }
          }
        },
      ),
    );
  }
  
  Widget _buildSplitScreen() {
    return NotificationListener<SplitManagerUpdateNotification>(
      onNotification: (notification) {
        // Log that we received a notification
        debugPrint('SplitManagerUpdateNotification received in _buildSplitScreen');
        
        // Update receipts items with any changes from the SplitManager
        setState(() {
          // The SplitManager has been updated
          debugPrint('Updating state in response to SplitManagerUpdateNotification');
        });
        
        // Cancel any pending save timer
        _saveTimer?.cancel();
        _saveTimer = null;
        
        // Try to save SplitManager state safely
        try {
          // Save split manager state if we received it in the notification
          if (notification.splitManager != null) {
            // Save the SplitManager state automatically
            final splitManager = notification.splitManager;
            
            try {
              // Get data for saving
              final splitManagerState = <String, dynamic>{
                'people': splitManager.people.map((person) => {
                  'name': person.name,
                  'assignedItems': person.assignedItems.map((item) => item.toJson()).toList(),
                  'sharedItems': person.sharedItems.map((item) => item.toJson()).toList(),
                }).toList(),
                'unassignedItems': splitManager.unassignedItems.map((item) => item.toJson()).toList(),
                'sharedItems': splitManager.sharedItems.map((item) => item.toJson()).toList(),
                'subtotal': splitManager.subtotal,
                'tax': splitManager.tax,
                'tip': splitManager.tip,
                'tipPercentage': splitManager.tipPercentage,
                'restaurantName': _restaurantName ?? splitManager.restaurantName,
              };
              
              // Fire and forget - don't await
              _receiptService.saveSplitManagerState(
                widget.receipt.id!,
                splitManagerState
              ).then((_) {
                debugPrint('Split manager state saved from notification');
              }).catchError((e) {
                debugPrint('Error saving split manager state from notification: $e');
              });
              
              // Also save assignment data
              if (splitManager.assignmentsModified) {
                final assignmentData = splitManager.getAssignmentData();
                
                // Reset flag to prevent duplicate saves
                splitManager.assignmentsModified = false;
                
                // Fire and forget - don't await
                _receiptService.saveAssignPeopleToItemsResults(
                  widget.receipt.id!,
                  assignmentData
                ).then((_) {
                  debugPrint('Assignments saved from notification');
                }).catchError((e) {
                  debugPrint('Error saving assignments from notification: $e');
                });
              }
            } catch (e) {
              debugPrint('Error processing split manager for save: $e');
            }
          }
        } catch (e) {
          debugPrint('Error handling SplitManagerUpdateNotification: $e');
        }
        
        // Return true to stop notification propagation
        return true;
      },
      child: Consumer<SplitManager>(
        builder: (context, splitManager, child) {
          // Debug log to check if assignments data is available
          debugPrint('_buildSplitScreen called, assignments: ${_assignments != null ? 'available' : 'null'}, items: ${_receiptItems.length}, splitManager initialized: ${splitManager.initialized}');
          
          // This is like a useEffect hook in React - runs after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            
            // Check if we need to initialize or re-initialize the manager
            final bool needsInitialization = !splitManager.initialized || 
                                           splitManager.people.isEmpty;
            
            // Only try to initialize if we have the necessary data
            if (needsInitialization && _assignments != null && _receiptItems.isNotEmpty) {
              debugPrint('Initializing SplitManager from _buildSplitScreen');
              _initializeSplitManager(splitManager);
            }
          });
          
          // Return split view screen
          if (splitManager.initialized) {
            return SplitView();
          } else if (_assignments == null || _receiptItems.isEmpty) {
            // Show error state if we don't have necessary data
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _assignments == null 
                        ? 'Assignment data not available' 
                        : 'Receipt items not available',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Try to initialize the manager again
                      setState(() {
                        // This will trigger a rebuild and another initialization attempt
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else {
            // Show loading state while waiting for initialization
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing split view...'),
                ],
              ),
            );
          }
        },
      ),
    );
  }
  
  Widget _buildSummaryScreen() {
    return Consumer<SplitManager>(
      builder: (context, splitManager, _) {
        // Store current assignments reference to detect changes
        final Map<String, dynamic>? currentAssignments = _assignments;
        
        // This is like a useEffect hook in React - runs after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          
          // Check if we need to initialize or re-initialize the manager
          final bool needsInitialization = !splitManager.initialized || 
                                         splitManager.people.isEmpty;
          
          // If we have assignments and need to initialize the manager
          if (currentAssignments != null && needsInitialization) {
            debugPrint('Initializing SplitManager for summary screen');
            
            // Reset the manager first
            splitManager.reset();
            
            // Then initialize with current assignments
            _initializeSplitManager(splitManager);
            
            // Force a rebuild after initialization if needed
            if (mounted) {
              setState(() {
                debugPrint('Triggering rebuild after SplitManager initialization for summary');
              });
            }
          }
        });
        
        // Check if initialization failed - show error screen
        if (currentAssignments != null && !splitManager.initialized) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize split data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Try again
                    setState(() {
                      // Force a rebuild
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        return Stack(
          children: [
            const FinalSummaryScreen(),
            // Complete button removed per user request
          ],
        );
      },
    );
  }
  
  void _initializeSplitManager(SplitManager splitManager) {
    try {
      // Always reset the manager completely before initialization
      // This ensures any old state is cleared when Start Splitting is clicked again
      debugPrint('Completely resetting SplitManager to clear old data before initialization');
      splitManager.reset();
      
      // Check for required data
      if (_assignments == null || _receiptItems.isEmpty) {
        debugPrint('Cannot initialize split manager: Missing assignments or receipt items');
        return;
      }
      
      // Set restaurant name if available
      if (_restaurantName != null) {
        splitManager.restaurantName = _restaurantName;
      }
      
      // Set original review total for validation
      final originalTotal = _receiptItems.fold(
        0.0, 
        (sum, item) => sum + (item.price * item.quantity)
      );
      debugPrint('DEBUG (SplitView): Setting original review total: $originalTotal');
      splitManager.originalReviewTotal = originalTotal;
      splitManager.subtotal = originalTotal;
      
      // Process saved assignments
      final Map<String, dynamic> assignments = _assignments!['assignments'] as Map<String, dynamic>;
      final List<dynamic> sharedItems = _assignments!['shared_items'] as List<dynamic>;
      final List<dynamic> unassignedItems = _assignments!['unassigned_items'] as List<dynamic>? ?? [];
      
      debugPrint('=== INITIALIZATION DATA ===');
      debugPrint('Original review total: $originalTotal');
      debugPrint('People count in assignments: ${assignments.keys.length}');
      debugPrint('Shared items count: ${sharedItems.length}');
      debugPrint('Unassigned items count: ${unassignedItems.length}');
      debugPrint('=========================');
      
      // Create a mapping of names to receipt items for easier lookup
      final Map<String, ReceiptItem> receiptItemsByName = {};
      
      for (int i = 0; i < _receiptItems.length; i++) {
        final item = _receiptItems[i];
        receiptItemsByName[item.name.toLowerCase()] = item;
        
        // Also store by position (1-based) as a fallback
        final oneBasedIndex = i + 1;
        receiptItemsByName['position_$oneBasedIndex'] = item;
      }
      
      // Add debug logging for all receipt items
      debugPrint('=== RECEIPT ITEMS DEBUG ===');
      for (int i = 0; i < _receiptItems.length; i++) {
        final item = _receiptItems[i];
        debugPrint('Receipt item #${i+1}: ${item.name}, ID: ${item.itemId}, Price: \$${item.price}, Quantity: ${item.quantity}');
      }
      
      // Add all receipt items to the manager
      for (final item in _receiptItems) {
        splitManager.addReceiptItem(item);
      }
      
      // Mark as initialized - we'll set this to true before processing assignments
      // This prevents auto-saving during the initialization process
      splitManager.initialized = true;
      
      // Track which items have been processed to avoid duplicate assignments
      final Set<String> processedItemNames = {};
      
      // Assign items to people - with name-based matching
      assignments.forEach((personName, items) {
        if (personName.isEmpty) return;
        
        debugPrint('Processing assignments for person: $personName');
        
        final person = splitManager.people.firstWhere(
          (p) => p.name == personName,
          orElse: () {
            // Create person if not found
            splitManager.addPerson(personName);
            return splitManager.people.firstWhere((p) => p.name == personName);
          },
        );
        
        // Process each item for this person
        for (final itemJson in items as List) {
          try {
            final itemData = itemJson as Map<String, dynamic>;
            final String itemName = itemData['name'] as String;
            final dynamic itemIdData = itemData['id'];
            final int itemId = itemIdData is int 
                ? itemIdData 
                : int.tryParse(itemIdData.toString()) ?? 0;
            final int quantity = (itemData['quantity'] as num).toInt();
            final double price = (itemData['price'] as num).toDouble();
            
            debugPrint('  - Processing item: $itemName (ID: $itemId, Quantity: $quantity, Price: \$${price.toStringAsFixed(2)})');
            
            // First try to find an exact match by name
            ReceiptItem? matchingItem = receiptItemsByName[itemName.toLowerCase()];
            
            // If no exact match, try matching item by position (1-based) if ID is valid
            if (matchingItem == null && itemId > 0 && itemId <= _receiptItems.length) {
              matchingItem = _receiptItems[itemId - 1];
              debugPrint('    No name match, using position match: ${matchingItem.name}');
            }
            
            if (matchingItem != null) {
              // Create a copy with the correct quantity and price
              final itemToAssign = matchingItem.copyWith(
                quantity: quantity,
                price: price,
              );
              
              debugPrint('    Assigning item to ${person.name}: ${itemToAssign.name} (Quantity: ${itemToAssign.quantity})');
              
              // Assign to the person
              splitManager.assignItemToPerson(itemToAssign, person);
              
              // Add to processed list
              processedItemNames.add(itemName.toLowerCase());
            } else {
              debugPrint('    WARNING: Could not find matching item for: $itemName');
            }
          } catch (e) {
            debugPrint('Error processing item assignment: $e');
          }
        }
      });
      
      // Process shared items
      for (final itemJson in sharedItems) {
        try {
          final itemData = itemJson as Map<String, dynamic>;
          final String itemName = itemData['name'] as String;
          final dynamic itemIdData = itemData['id'];
          final int itemId = itemIdData is int 
              ? itemIdData 
              : int.tryParse(itemIdData.toString()) ?? 0;
          final int quantity = (itemData['quantity'] as num).toInt();
          final double price = (itemData['price'] as num).toDouble();
          final List<String> sharingPeople = itemData.containsKey('people')
              ? List<String>.from(itemData['people'] as List)
              : splitManager.people.map((p) => p.name).toList();
          
          debugPrint('  - Processing shared item: $itemName (ID: $itemId, Quantity: $quantity, Price: \$${price.toStringAsFixed(2)})');
          debugPrint('    Shared by: ${sharingPeople.join(', ')}');
          
          // First try to find an exact match by name
          ReceiptItem? matchingItem = receiptItemsByName[itemName.toLowerCase()];
          
          // If no exact match, try matching item by position (1-based) if ID is valid
          if (matchingItem == null && itemId > 0 && itemId <= _receiptItems.length) {
            matchingItem = _receiptItems[itemId - 1];
            debugPrint('    No name match, using position match: ${matchingItem.name}');
          }
          
          if (matchingItem != null) {
            // Create a copy with the correct quantity and price
            final itemToShare = matchingItem.copyWith(
              quantity: quantity,
              price: price,
            );
            
            // Get the list of people who should share this item
            List<Person> peopleToShare = [];
            
            // If specific people were listed, use those
            if (sharingPeople.isNotEmpty) {
              for (final personName in sharingPeople) {
                final matchingPerson = splitManager.people.firstWhere(
                  (p) => p.name == personName,
                  orElse: () => Person(name: personName), // Create if not found
                );
                
                if (matchingPerson.name.isNotEmpty) {
                  peopleToShare.add(matchingPerson);
                  // Ensure the person is added to the split manager if they're new
                  if (!splitManager.people.contains(matchingPerson)) {
                    splitManager.addPerson(matchingPerson.name);
                  }
                }
              }
            } else {
              // If no specific people, share with everyone
              peopleToShare = splitManager.people;
            }
            
            debugPrint('    Adding shared item: ${itemToShare.name} (Quantity: ${itemToShare.quantity})');
            debugPrint('    Shared by ${peopleToShare.length} people');
            
            // Add to shared items
            splitManager.addItemToShared(itemToShare, peopleToShare);
            
            // Add to processed list
            processedItemNames.add(itemName.toLowerCase());
          } else {
            debugPrint('    WARNING: Could not find matching item for shared item: $itemName');
          }
        } catch (e) {
          debugPrint('Error processing shared item: $e');
        }
      }
      
      // Process unassigned items
      for (final itemJson in unassignedItems) {
        try {
          final itemData = itemJson as Map<String, dynamic>;
          final String itemName = itemData['name'] as String;
          final dynamic itemIdData = itemData['id'];
          final int itemId = itemIdData is int 
              ? itemIdData 
              : int.tryParse(itemIdData.toString()) ?? 0;
          final int quantity = (itemData['quantity'] as num).toInt();
          final double price = (itemData['price'] as num).toDouble();
          final dynamic position = itemData['position'];
          
          debugPrint('  - Processing unassigned item: $itemName (ID: $itemId, Quantity: $quantity, Price: \$${price.toStringAsFixed(2)})');
          
          // First try to find an exact match by name
          ReceiptItem? matchingItem = receiptItemsByName[itemName.toLowerCase()];
          
          // If no exact match, try matching item by position (1-based) if ID is valid
          if (matchingItem == null && itemId > 0 && itemId <= _receiptItems.length) {
            matchingItem = _receiptItems[itemId - 1];
            debugPrint('    No name match, using position match: ${matchingItem.name}');
          }
          
          // Try matching by position field if provided 
          if (matchingItem == null && position != null) {
            final int positionInt = position is int 
                ? position 
                : int.tryParse(position.toString()) ?? 0;
                
            if (positionInt > 0 && positionInt <= _receiptItems.length) {
              matchingItem = _receiptItems[positionInt - 1];
              debugPrint('    Using explicit position match: ${matchingItem.name}');
            }
          }
          
          if (matchingItem != null) {
            // Create a copy with the correct quantity and price
            final itemToUnassign = matchingItem.copyWith(
              quantity: quantity,
              price: price,
            );
            
            debugPrint('    Marking as unassigned: ${itemToUnassign.name} (Quantity: ${itemToUnassign.quantity})');
            
            // Mark as unassigned
            splitManager.markAsUnassigned(itemToUnassign);
            
            // Add to processed list
            processedItemNames.add(itemName.toLowerCase());
          } else {
            debugPrint('    WARNING: Could not find matching item for unassigned item: $itemName');
          }
        } catch (e) {
          debugPrint('Error processing unassigned item: $e');
        }
      }
      
      // Debug log people's assigned items for verification
      for (final person in splitManager.people) {
        person.debugLogItems();
      }
      
      // Safely restore calculation values from saved state
      if (widget.receipt.splitManagerState != null) {
        final state = widget.receipt.splitManagerState!;
        
        if (state.containsKey('restaurantName')) {
          splitManager.restaurantName = state['restaurantName'] as String?;
        }
        
        if (state.containsKey('subtotal')) {
          final subtotal = state['subtotal'];
          if (subtotal is double) {
            splitManager.subtotal = subtotal;
          }
        }
        
        if (state.containsKey('tax')) {
          final tax = state['tax'];
          if (tax is double) {
            splitManager.tax = tax;
          }
        }
        
        if (state.containsKey('tip')) {
          final tip = state['tip'];
          if (tip is double) {
            splitManager.tip = tip;
          }
        }
        
        if (state.containsKey('tipPercentage')) {
          final tipPercentage = state['tipPercentage'];
          if (tipPercentage is double) {
            splitManager.tipPercentage = tipPercentage;
          }
        }
      } else {
        // If no saved state, initialize with reasonable defaults
        splitManager.subtotal = originalTotal;
        debugPrint('Setting initial subtotal to original total: $originalTotal');
      }
      
      // Log all items for debugging
      splitManager.logItems();
      
      // Force a notification to update the UI
      splitManager.notifyListeners();
      
      debugPrint('Split manager initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Error initializing split manager: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Mark as initialized to prevent further init attempts in this session
      splitManager.initialized = true;
      
      // Show error notification
      if (mounted) {
        ToastHelper.showToast(
          context,
          'Error preparing split: $e',
          isError: true,
        );
      }
    }
  }
  
  Future<void> _autoSaveSplitManagerState(SplitManager splitManager) async {
    try {
      // First check if the receipt has an ID
      if (widget.receipt.id == null) {
        debugPrint('ERROR: Receipt has no ID, cannot save state');
        return;
      }
      
      // Build data for saving
      final splitManagerState = <String, dynamic>{
        'people': splitManager.people.map((person) => {
          'name': person.name,
          'assignedItems': person.assignedItems.map((item) => item.toJson()).toList(),
          'sharedItems': person.sharedItems.map((item) => item.toJson()).toList(),
        }).toList(),
        'unassignedItems': splitManager.unassignedItems.map((item) => item.toJson()).toList(),
        'sharedItems': splitManager.sharedItems.map((item) => item.toJson()).toList(),
        'subtotal': splitManager.subtotal,
        'tax': splitManager.tax,
        'tip': splitManager.tip,
        'tipPercentage': splitManager.tipPercentage,
        'restaurantName': _restaurantName ?? splitManager.restaurantName, // Save restaurant name
      };
      
      // If we have a restaurant name, update the metadata
      if (_restaurantName != null) {
        // Update the receipt using the service
        final updatedReceipt = widget.receipt.copyWith(
          splitManagerState: splitManagerState,
          metadata: widget.receipt.metadata.copyWith(
            restaurantName: _restaurantName,
            updatedAt: Timestamp.now(),
          ),
        );
        await _receiptService.updateReceipt(updatedReceipt);
      } else {
        // Just update the split manager state
        await _receiptService.saveSplitManagerState(widget.receipt.id!, splitManagerState);
      }
      
    } catch (e) {
      debugPrint('Error auto-saving split manager state: $e');
    }
  }
  
  // Replace the _initializePageController method with a modified version that doesn't recreate the controller
  void _updatePageControllerPage() {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentStep);
      debugPrint('Page controller updated to page: $_currentStep');
    } else {
      debugPrint('PageController has no clients yet, deferring page update');
      // Schedule page update after the controller is attached
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_currentStep);
          debugPrint('Page controller updated to page: $_currentStep (delayed)');
        }
      });
    }
  }
  
  // Add a method to save transcription that can be reused
  Future<void> _saveTranscription(String? transcription) async {
    if (transcription == null) return;
    
    // Safety check - reset loading state if it's been on too long
    bool wasLoading = _isLoading;
    
    try {
      // Don't update loading state for background saves - this prevents UI flickering
      bool showLoadingIndicator = _savedTranscription == null; // Only show loading on first save
      
      if (showLoadingIndicator && !wasLoading) {
        setState(() => _isLoading = true);
      }
      
      // Skip saving if nothing changed
      if (_savedTranscription == transcription) {
        if (showLoadingIndicator) setState(() => _isLoading = false);
        return;
      }
      
      // Prepare data for saving
      final transcriptionResults = {
        'transcription': transcription,
      };
      
      // Save to backend without updating UI
      await _receiptService.saveTranscribeAudioResults(
        widget.receipt.id!,
        transcriptionResults,
      );
      
      // Only update state after save completes, and only if needed
      if (_savedTranscription != transcription || showLoadingIndicator) {
        // Update state variables directly without triggering a rebuild
        _savedTranscription = transcription;
        
        // Only use setState for the loading indicator or if explicitly showing feedback
        if (showLoadingIndicator) {
          if (mounted) setState(() => _isLoading = false);
          
          // Only show indicator for the first save
          if (mounted) {
            ToastHelper.showToast(
              context,
              'Transcription saved',
              isSuccess: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error saving transcription: $e');
      // Always reset loading state on error
      if (mounted) setState(() => _isLoading = false);
      
      // Show error message
      if (mounted) {
        ToastHelper.showToast(
          context,
          'Error saving transcription: $e',
          isError: true,
        );
      }
    }
  }
  
  // Debug utility to help diagnose item matching issues
  void _debugItemMatching() {
    if (_receiptItems.isEmpty || _assignments == null) {
      debugPrint('Cannot debug item matching: No receipt items or assignments');
      return;
    }
    
    debugPrint('\n=== ITEM MATCHING DEBUG ===');
    debugPrint('Receipt items count: ${_receiptItems.length}');
    for (int i = 0; i < _receiptItems.length; i++) {
      final item = _receiptItems[i];
      debugPrint('[$i] ID: ${item.itemId}, Name: ${item.name}, Price: \$${item.price}, Quantity: ${item.quantity}');
    }
    
    // Check API assignment response
    final Map<String, dynamic> assignments = _assignments!['assignments'] as Map<String, dynamic>;
    final List<dynamic> sharedItems = _assignments!['shared_items'] as List<dynamic>;
    
    debugPrint('\nAssignments from API:');
    assignments.forEach((person, items) {
      debugPrint('$person:');
      for (final item in items as List<dynamic>) {
        final itemData = item as Map<String, dynamic>;
        final id = itemData['id'];
        final quantity = itemData['quantity'];
        debugPrint('  - Item ID: $id, Quantity: $quantity');
        
        // Try to find matching items in our receipt items
        final matches = _receiptItems.where((ri) => 
          ri.itemId.endsWith('_$id') || 
          ri.itemId.contains('_${id}_') ||
          ri.itemId == id.toString()
        ).toList();
        
        if (matches.isEmpty) {
          debugPrint('    NO MATCH FOUND!');
          
          // Check if it's a simple position match
          if (id is int && id > 0 && id <= _receiptItems.length) {
            final posItem = _receiptItems[id - 1];
            debugPrint('    Possible position match: ${posItem.name} (\$${posItem.price})');
          }
        } else {
          for (final match in matches) {
            debugPrint('    Matching item: ${match.name} (\$${match.price})');
          }
        }
      }
    });
    
    debugPrint('\nShared items from API:');
    for (final item in sharedItems) {
      final itemData = item as Map<String, dynamic>;
      final id = itemData['id'];
      final quantity = itemData['quantity'];
      debugPrint('  - Item ID: $id, Quantity: $quantity');
      
      // Try to find matching items in our receipt items
      final matches = _receiptItems.where((ri) => 
        ri.itemId.endsWith('_$id') || 
        ri.itemId.contains('_${id}_') ||
        ri.itemId == id.toString()
      ).toList();
      
      if (matches.isEmpty) {
        debugPrint('    NO MATCH FOUND!');
        
        // Check if it's a simple position match
        if (id is int && id > 0 && id <= _receiptItems.length) {
          final posItem = _receiptItems[id - 1];
          debugPrint('    Possible position match: ${posItem.name} (\$${posItem.price})');
        }
      } else {
        for (final match in matches) {
          debugPrint('    Matching item: ${match.name} (\$${match.price})');
        }
      }
    }
    
    debugPrint('=========================\n');
  }
  
  // Add a method to save assignment changes to the database
  Future<void> _autoSaveAssignments(SplitManager splitManager) async {
    // Prevent multiple concurrent save operations
    if (_isSaving) {
      debugPrint('Already saving assignments, skipping duplicate save');
      return;
    }
    
    _isSaving = true;
    
    try {
      // Only save if changes have been made and the manager is initialized
      if (!splitManager.assignmentsModified || !splitManager.initialized) {
        debugPrint('No assignment changes to save or manager not initialized');
        return;
      }
      
      // Check if there are actually people/items to save
      if (splitManager.people.isEmpty && splitManager.sharedItems.isEmpty && splitManager.unassignedItems.isEmpty) {
        debugPrint('No assignment data to save (empty state)');
        return;
      }
      
      // Check if the receipt has an ID
      if (widget.receipt.id == null) {
        debugPrint('ERROR: Receipt has no ID, cannot save assignments');
        return;
      }
      
      // Get the assignment data from the split manager
      final Map<String, dynamic> assignmentData = splitManager.getAssignmentData();
      
      debugPrint('Auto-saving assignment changes to database');
      
      // Save to the database
      await _receiptService.saveAssignPeopleToItemsResults(
        widget.receipt.id!,
        assignmentData
      );
      
      // Reset the modified flag since we've saved the changes
      splitManager.assignmentsModified = false;
      
      debugPrint('Assignment changes saved successfully');
    } catch (e) {
      debugPrint('Error auto-saving assignments: $e');
    } finally {
      _isSaving = false;
    }
  }

  // Handle back button press
  void _handleBackNavigation() {
    // Try to safely save any pending changes first
    SplitManager? splitManagerRef;
    
    try {
      // Cancel any pending save timer
      _saveTimer?.cancel();
      _saveTimer = null;
      
      // Safely try to get the SplitManager and save changes
      if (mounted) {
        try {
          splitManagerRef = Provider.of<SplitManager>(context, listen: false);
        } catch (providerError) {
          debugPrint('Provider not available for back navigation: $providerError');
        }
      }
    } catch (e) {
      debugPrint('Error during back navigation: $e');
    }
    
    // Save changes if we got a reference to the SplitManager
    if (splitManagerRef != null && splitManagerRef.assignmentsModified) {
      try {
        // Get the assignment data from the split manager
        final Map<String, dynamic> assignmentData = splitManagerRef.getAssignmentData();
        
        // Reset the modified flag since we've saved the changes
        splitManagerRef.assignmentsModified = false;
        
        // Fire and forget - don't wait for the save to complete
        _receiptService.saveAssignPeopleToItemsResults(
          widget.receipt.id!,
          assignmentData
        ).then((_) {
          debugPrint('Assignment changes saved on back navigation');
        }).catchError((e) {
          debugPrint('Error saving assignments on back: $e');
        });
      } catch (e) {
        debugPrint('Error saving before back: $e');
      }
    }
    
    // If on the first step, show exit dialog
    if (_currentStep == 0) {
      _confirmCancel();
    } else {
      // Otherwise navigate to previous step
      _navigateToPreviousStep();
    }
  }
} 