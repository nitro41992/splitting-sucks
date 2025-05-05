import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:math' as math;
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

class _ReceiptWorkflowPageState extends State<ReceiptWorkflowPage> with AutomaticKeepAliveClientMixin {
  // Override keep alive to prevent page disposal
  @override
  bool get wantKeepAlive => true;
  
  final ReceiptService _receiptService = ReceiptService();
  late File? _imageFile;
  late List<ReceiptItem> _receiptItems;
  Map<String, dynamic>? _assignments;
  String? _savedTranscription;
  
  // Make PageController final to prevent recreation
  final PageController _pageController = PageController(keepPage: true);
  
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
  
  @override
  void initState() {
    super.initState();
    
    // Initialize state
    _imageFile = null;
    _receiptItems = [];
    
    // Load saved state if available
    _loadSavedState();
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
    
    return WillPopScope(
      // Prevent backing out of workflow - show confirmation dialog instead
      onWillPop: () async {
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Receipt Workflow?'),
            content: const Text('Progress will be saved, but you will need to restart from the beginning if you exit now.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        
        return shouldPop ?? false;
      },
      child: ChangeNotifierProvider(
        create: (_) => SplitManager(),
        child: Scaffold(
          body: SafeArea(
            child: _isLoading && !_stateLoaded 
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildStepIndicator(),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(), // Disable swipe navigation
                      onPageChanged: (index) {
                        // Update current step when page changes
                        setState(() {
                          _currentStep = index;
                        });
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
                ],
              ),
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
    
    // Determine if we can navigate to this step based on completed data
    bool canNavigate = false;
    
    // Can always navigate to current or previous steps
    if (step <= _currentStep) {
      canNavigate = true;
    } else {
      // For future steps, check if we have the necessary data
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
        case 4: // Summary step
          canNavigate = _isSplitComplete;
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
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void _navigateToNextStep() {
    debugPrint('_navigateToNextStep called - Current step: $_currentStep');
    
    if (_currentStep < 4) {
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
      _completeWorkflow();
    }
  }
  
  void _confirmCancel() {
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
                Navigator.of(context).pop(); // Return to previous screen
              },
              child: const Text('EXIT'),
            ),
          ],
        );
      },
    );
  }
  
  void _completeWorkflow() async {
    try {
      // Show saving indicator
      setState(() => _isLoading = true);
      
      // Mark receipt as completed
      await _receiptService.updateReceiptStatus(widget.receipt.id!, 'completed');
      
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt completed successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Return to previous screen
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error completing receipt: $e');
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Screen builders
  Widget _buildUploadScreen() {
    return ReceiptUploadScreen(
      imageFile: _imageFile,
      isLoading: _isLoading,
      onImageSelected: (file) {
        setState(() {
          _imageFile = file;
        });
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
            
            // Update receipt with image URLs
            final updatedReceipt = widget.receipt.copyWith(
              imageUri: urls['imageUri'],
              thumbnailUri: urls['thumbnailUri'],
            );
            
            await _receiptService.updateReceipt(updatedReceipt);
            debugPrint('Receipt updated with image URLs');
            
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Receipt uploaded and processed successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
          }
        } catch (e) {
          debugPrint('Error saving receipt data: $e');
          setState(() => _isLoading = false);
          
          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error processing receipt: $e'),
                backgroundColor: Colors.red,
              ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt items saved successfully'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        } catch (e) {
          debugPrint('Error saving receipt items: $e');
          setState(() => _isLoading = false);
          
          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving items: $e'),
                backgroundColor: Colors.red,
              ),
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
            
            // Update state and immediately request a page change
            setState(() {
              _assignments = assignments;
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Assignments saved successfully'),
                    duration: Duration(seconds: 2),
                  ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving assignments: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }
  
  Widget _buildSplitScreen() {
    // The split screen is the AssignmentReviewScreen which wraps a SplitView
    return Consumer<SplitManager>(
      builder: (context, splitManager, _) {
        // Initialize split manager with saved state if available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_assignments != null && !splitManager.initialized) {
            // Run debug utility before initialization
            _debugItemMatching();
            
            // Now initialize the split manager
            _initializeSplitManager(splitManager);
          }
        });
        
        // Create a wrapper around AssignmentReviewScreen with a complete button
        return Stack(
          children: [
            const AssignmentReviewScreen(),
            
            // Add a Complete button to move to summary
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () {
                  // Auto-save the current state
                  _autoSaveSplitManagerState();
                  
                  // Ensure state is updated correctly before navigation
                  setState(() {
                    _isSplitComplete = true;
                    _currentStep = 4; // Explicitly set to Summary step
                  });
                  
                  // Use direct jumpToPage without animation to prevent flashing
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _pageController.hasClients) {
                      debugPrint('Directly jumping to Summary screen (page 4)');
                      _pageController.jumpToPage(4);
                    }
                  });
                },
                heroTag: 'split_complete_button',
                label: const Text('Complete'),
                icon: const Icon(Icons.check),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildSummaryScreen() {
    return Consumer<SplitManager>(
      builder: (context, splitManager, _) {
        // Initialize split manager with saved state if available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_assignments != null && !splitManager.initialized) {
            _initializeSplitManager(splitManager);
          }
        });
        
        return Stack(
          children: [
            const FinalSummaryScreen(),
            // Add a Done button to complete workflow
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: _completeWorkflow,
                heroTag: 'summary_complete_button',
                label: const Text('Complete'),
                icon: const Icon(Icons.done_all),
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        );
      },
    );
  }
  
  void _initializeSplitManager(SplitManager splitManager) {
    try {
      // Prevent repeated calls if already initialized
      if (splitManager.initialized) {
        debugPrint('SplitManager already initialized, skipping initialization');
        return;
      }
      
      // Check for required data
      if (_assignments == null || _receiptItems.isEmpty) {
        debugPrint('Cannot initialize split manager: Missing assignments or receipt items');
        return;
      }
      
      // Reset the manager
      splitManager.reset();
      
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
        
        // Process each item in the assignment
        for (final itemData in items as List<dynamic>) {
          try {
            final itemJson = itemData as Map<String, dynamic>;
            
            // Get the item name or id from the API response
            final itemName = itemJson.containsKey('name') ? itemJson['name'] as String? : null;
            final itemId = itemJson.containsKey('id') ? itemJson['id']?.toString() : null;
            final position = itemJson.containsKey('position') ? itemJson['position']?.toString() : null;
            
            if (itemName == null && itemId == null && position == null) {
              debugPrint('Warning: Item has no identifiers in assignment data: $itemJson');
              continue;
            }
            
            ReceiptItem? matchingItem;
            
            // Try matching by name first (preferred)
            if (itemName != null) {
              matchingItem = receiptItemsByName[itemName.toLowerCase()];
              if (matchingItem != null) {
                debugPrint('Found name match: "$itemName" for person: ${person.name}');
                splitManager.assignItemToPerson(matchingItem, person);
                // Mark this item as processed by this person
                processedItemNames.add('${personName}:${matchingItem.name.toLowerCase()}');
                continue;
              }
            }
            
            // Try matching by id if provided (legacy support)
            if (itemId != null) {
              // Legacy position-based matching 
              if (int.tryParse(itemId) != null) {
                final index = int.parse(itemId) - 1; // Convert from 1-indexed to 0-indexed
                if (index >= 0 && index < _receiptItems.length) {
                  matchingItem = _receiptItems[index];
                  debugPrint('Found position match using id field: $itemId: ${matchingItem.name} for person: ${person.name}');
                  splitManager.assignItemToPerson(matchingItem, person);
                  // Mark this item as processed by this person
                  processedItemNames.add('${personName}:${matchingItem.name.toLowerCase()}');
                  continue;
                }
              }
            }
            
            // Try matching by position field if provided 
            if (position != null) {
              matchingItem = receiptItemsByName['position_$position'];
              if (matchingItem != null) {
                debugPrint('Found position match: $position: ${matchingItem.name} for person: ${person.name}');
                splitManager.assignItemToPerson(matchingItem, person);
                // Mark this item as processed by this person
                processedItemNames.add('${personName}:${matchingItem.name.toLowerCase()}');
                continue;
              }
            }
            
            // If we got here, no match was found
            debugPrint('Warning: No matching item found for assignment: $itemJson');
            
          } catch (e) {
            debugPrint('Error assigning item: $e');
          }
        }
      });

      // Track which items have been processed as shared to avoid duplicate shared item processing
      final Set<String> processedSharedItemNames = {};
      
      // Use name-based matching for shared items
      for (final itemData in sharedItems) {
        try {
          final itemJson = itemData as Map<String, dynamic>;
            
          // Get the item name or id from the API response
          final itemName = itemJson.containsKey('name') ? itemJson['name'] as String? : null;
          final itemId = itemJson.containsKey('id') ? itemJson['id']?.toString() : null;
          final position = itemJson.containsKey('position') ? itemJson['position']?.toString() : null;
          
          if (itemName == null && itemId == null && position == null) {
            debugPrint('Warning: Shared item has no identifiers: $itemJson');
            continue;
          }
          
          // Skip items that have already been processed as shared
          if (itemName != null && processedSharedItemNames.contains(itemName.toLowerCase())) {
            debugPrint('Skipping already processed shared item: $itemName');
            continue;
          }
          
          ReceiptItem? matchingItem;
          
          // Try matching by name first (preferred)
          if (itemName != null) {
            matchingItem = receiptItemsByName[itemName.toLowerCase()];
            if (matchingItem != null) {
              debugPrint('Found name match for shared item: "$itemName"');
            }
          }
          
          // Try matching by id if provided (legacy support)
          if (matchingItem == null && itemId != null) {
            // Legacy position-based matching 
            if (int.tryParse(itemId) != null) {
              final index = int.parse(itemId) - 1; // Convert from 1-indexed to 0-indexed
              if (index >= 0 && index < _receiptItems.length) {
                matchingItem = _receiptItems[index];
                debugPrint('Found position match using id field for shared item: $itemId: ${matchingItem.name}');
              }
            }
          }
          
          // Try matching by position field if provided 
          if (matchingItem == null && position != null) {
            matchingItem = receiptItemsByName['position_$position'];
            if (matchingItem != null) {
              debugPrint('Found position match for shared item: $position: ${matchingItem.name}');
            }
          }
          
          if (matchingItem == null) {
            debugPrint('Warning: No matching item found for shared item: $itemJson');
            continue;
          }
          
          // Get the list of people who are sharing this item
          List<String> peopleNames = [];
          if (itemJson.containsKey('people') && itemJson['people'] is List) {
            peopleNames = (itemJson['people'] as List).map((p) => p.toString()).toList();
            debugPrint('Found people for shared item ${matchingItem.name}: $peopleNames');
          } else {
            // If no people specified, default to all people sharing (legacy behavior)
            peopleNames = splitManager.people.map((p) => p.name).toList();
            debugPrint('No people specified in shared item ${matchingItem.name}, defaulting to all people: $peopleNames');
          }
          
          // Check if any of these people have already been individually assigned this exact item
          bool isAlreadyAssigned = false;
          for (final personName in peopleNames) {
            if (processedItemNames.contains('${personName}:${matchingItem.name.toLowerCase()}')) {
              debugPrint('WARNING: Item ${matchingItem.name} was already assigned to $personName individually, ' +
                         'but also appears in shared items. Skipping to avoid duplication.');
              isAlreadyAssigned = true;
              break;
            }
          }
          
          // Skip shared item processing if it was already individually assigned
          if (isAlreadyAssigned) {
            continue;
          }
          
          // Mark this item as processed for shared
          if (itemName != null) {
            processedSharedItemNames.add(itemName.toLowerCase());
          }
          
          // Find the specific Person objects for these people names
          List<Person> specificPeople = [];
          for (final name in peopleNames) {
            // Find or create person if needed
            Person? person = splitManager.people.firstWhere(
              (p) => p.name == name,
              orElse: () {
                debugPrint('Creating missing person "$name" for shared item');
                splitManager.addPerson(name);
                return splitManager.people.firstWhere((p) => p.name == name);
              }
            );
            specificPeople.add(person);
          }
          
          debugPrint('Marking ${matchingItem.name} as shared among ${specificPeople.length} people: ${specificPeople.map((p) => p.name).join(", ")}');
          
          if (specificPeople.isNotEmpty) {
            splitManager.markAsShared(matchingItem, people: specificPeople);
          } else {
            debugPrint('WARNING: No people found to share item with, using default behavior');
            splitManager.markAsShared(matchingItem);
          }
          
        } catch (e) {
          debugPrint('Error processing shared item: $e');
        }
      }
      
      // Use the same name-based matching for unassigned items
      for (final itemData in unassignedItems) {
        try {
          final itemJson = itemData as Map<String, dynamic>;
            
          // Get the item name or id from the API response
          final itemName = itemJson.containsKey('name') ? itemJson['name'] as String? : null;
          final itemId = itemJson.containsKey('id') ? itemJson['id']?.toString() : null;
          final position = itemJson.containsKey('position') ? itemJson['position']?.toString() : null;
          
          if (itemName == null && itemId == null && position == null) {
            debugPrint('Warning: Unassigned item has no identifiers: $itemJson');
            continue;
          }
          
          ReceiptItem? matchingItem;
          
          // Try matching by name first (preferred)
          if (itemName != null) {
            matchingItem = receiptItemsByName[itemName.toLowerCase()];
            if (matchingItem != null) {
              debugPrint('Found name match for unassigned item: "$itemName"');
              splitManager.markAsUnassigned(matchingItem);
              continue;
            }
          }
          
          // Try matching by id if provided (legacy support)
          if (itemId != null) {
            // Legacy position-based matching 
            if (int.tryParse(itemId) != null) {
              final index = int.parse(itemId) - 1; // Convert from 1-indexed to 0-indexed
              if (index >= 0 && index < _receiptItems.length) {
                matchingItem = _receiptItems[index];
                debugPrint('Found position match using id field for unassigned item: $itemId: ${matchingItem.name}');
                splitManager.markAsUnassigned(matchingItem);
                continue;
              }
            }
          }
          
          // Try matching by position field if provided 
          if (position != null) {
            matchingItem = receiptItemsByName['position_$position'];
            if (matchingItem != null) {
              debugPrint('Found position match for unassigned item: $position: ${matchingItem.name}');
              splitManager.markAsUnassigned(matchingItem);
              continue;
            }
          }
          
          // If we got here, no match was found
          debugPrint('Warning: No matching item found for unassigned item: $itemJson');
          
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
      
      // Mark as initialized only after successful completion
      splitManager.initialized = true;
      
      // Log all items for debugging
      splitManager.logItems();
      
      // Force a notification to update the UI
      splitManager.notifyListeners();
      
      debugPrint('Split manager initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Error initializing split manager: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Don't set initialized to false to prevent further init attempts in this session
      splitManager.initialized = true;
      
      // Show error notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing split: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  Future<void> _autoSaveSplitManagerState() async {
    try {
      // Create a basic map with the required information
      final Map<String, dynamic> splitManagerState = {};
      
      // Get the SplitManager
      final splitManager = Provider.of<SplitManager>(context, listen: false);
      
      // Add key data we want to preserve
      splitManagerState['people'] = splitManager.people.map((person) => {
        'name': person.name,
        // Add other person properties as needed
      }).toList();
      
      // Add other properties as needed
      
      // Save to Firestore
      await _receiptService.saveSplitManagerState(
        widget.receipt.id!,
        splitManagerState,
      );
      
      // Update state
      setState(() {
        _isSplitComplete = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved split calculations'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving split manager state: $e');
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving split calculations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transcription saved'),
                duration: Duration(seconds: 1),
              ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transcription: $e'),
            backgroundColor: Colors.red,
          ),
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
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
} 