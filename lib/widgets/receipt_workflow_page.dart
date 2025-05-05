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

class _ReceiptWorkflowPageState extends State<ReceiptWorkflowPage> {
  final ReceiptService _receiptService = ReceiptService();
  late File? _imageFile;
  late List<ReceiptItem> _receiptItems;
  Map<String, dynamic>? _assignments;
  String? _savedTranscription;
  
  // Modified PageController to be non-final
  late PageController _pageController;
  
  bool _isLoading = false;
  bool _isUploadComplete = false;
  bool _isReviewComplete = false;
  bool _isAssignmentComplete = false;
  bool _isSplitComplete = false;
  int _currentStep = 0; // Track workflow step
  
  // Add a key to access VoiceAssignmentScreen state without direct reference to private state class
  final GlobalKey _voiceAssignmentKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    
    // Initialize state
    _imageFile = null;
    _receiptItems = [];
    
    // Initialize page controller with current step
    _initializePageController();
    
    // Load saved state if available
    _loadSavedState();
  }
  
  Future<void> _loadSavedState() async {
    try {
      setState(() => _isLoading = true);
      
      // Get receipt data
      final receipt = await _receiptService.getReceiptById(widget.receipt.id!);
      
      if (receipt != null) {
        setState(() {
          // Set image file path
          if (receipt.imageUri != null) {
            _imageFile = File(receipt.imageUri!);
            _isUploadComplete = true;
          }
          
          // Set review items
          if (receipt.parseReceipt != null && 
              receipt.parseReceipt!.containsKey('items')) {
            final items = receipt.parseReceipt!['items'] as List<dynamic>;
            _receiptItems = items
                .map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
                .toList();
            _isReviewComplete = _receiptItems.isNotEmpty;
          }
          
          // Set transcription
          if (receipt.transcribeAudio != null && 
              receipt.transcribeAudio!.containsKey('transcription')) {
            _savedTranscription = receipt.transcribeAudio!['transcription'] as String?;
          }
          
          // Set assignments
          if (receipt.assignPeopleToItems != null) {
            _assignments = receipt.assignPeopleToItems!;
            _isAssignmentComplete = true;
          }
          
          // Set appropriate step based on state
          if (_isAssignmentComplete) {
            _currentStep = 3; // Jump to split screen
          } else if (_isReviewComplete) {
            _currentStep = 2; // Jump to assignment screen
          } else if (_isUploadComplete) {
            _currentStep = 1; // Jump to review screen
          } else {
            _currentStep = 0; // Start at upload screen
          }
          
          // Re-initialize page controller with updated current step
          _initializePageController();
          
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading receipt data: $e');
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
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
            child: _isLoading 
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
          try {
            // We don't need to manually save transcription here anymore
            // as the VoiceAssignmentScreen will call onTranscriptionChanged
            // before processing assignments
            
            // Show saving indicator
            setState(() => _isLoading = true);
            
            // Debug log
            debugPrint('Saving assignments: ${assignments.toString().substring(0, math.min(100, assignments.toString().length))}...');
            
            // Save assignments
            await _receiptService.saveAssignPeopleToItemsResults(
              widget.receipt.id!,
              assignments,
            );
            
            debugPrint('Assignment data saved to Firestore successfully');
            
            // Set state FIRST before navigation attempt
            setState(() {
              _assignments = assignments;
              _isAssignmentComplete = true;
              _isLoading = false;
            });
            
            // Ensure all relevant state is updated correctly before navigation
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Debug log before navigation
            debugPrint('About to navigate from Assign (step 2) to Split (step 3), current step: $_currentStep');
            
            // Use direct method for reliable navigation
            setState(() {
              _currentStep = 3; // Explicitly set to Split step
            });
            
            // Use direct jumpToPage without animation to prevent flashing
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pageController.hasClients) {
                debugPrint('Directly jumping to Split screen (page 3)');
                _pageController.jumpToPage(3);
                
                // Show success toast after navigation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Assignments saved successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            });
          } catch (e) {
            debugPrint('Error saving assignments: $e');
            setState(() => _isLoading = false);
            
            // Show error message
            if (mounted) {
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
      
      // Add people first, ensuring we have valid people
      assignments.forEach((name, _) {
        if (name.isNotEmpty && !splitManager.people.any((p) => p.name == name)) {
          splitManager.addPerson(name);
          debugPrint('Added person: $name');
        }
      });
      
      // Create a mapping of numeric IDs to receipt items for easier lookup
      final Map<String, ReceiptItem> receiptItemsById = {};
      for (final item in _receiptItems) {
        // Extract the numeric ID if possible (handle various ID formats)
        String? numericId;
        if (item.itemId.contains('_')) {
          // Try to extract numeric ID from patterns like "item_123_name"
          final parts = item.itemId.split('_');
          for (final part in parts) {
            if (int.tryParse(part) != null) {
              numericId = part;
              break;
            }
          }
        }
        
        // If no numeric ID found, just use the full ID
        final idKey = numericId ?? item.itemId;
        receiptItemsById[idKey] = item;
        
        // Also store by simple position (1-indexed as used by API)
        final index = _receiptItems.indexOf(item) + 1;
        receiptItemsById[index.toString()] = item;
      }
      
      debugPrint('Created ID mapping with ${receiptItemsById.length} entries:');
      receiptItemsById.forEach((id, item) {
        debugPrint('  ID: $id -> ${item.name} (\$${item.price})');
      });
      
      // Add all receipt items to the manager
      for (final item in _receiptItems) {
        splitManager.addReceiptItem(item);
      }
      
      // Assign items to people - with improved ID matching
      assignments.forEach((name, items) {
        if (name.isEmpty) return;
        
        debugPrint('Processing assignments for person: $name');
        
        final person = splitManager.people.firstWhere(
          (p) => p.name == name,
          orElse: () {
            // Create person if not found
            splitManager.addPerson(name);
            return splitManager.people.firstWhere((p) => p.name == name);
          },
        );
        
        // Process each item in the assignment
        for (final itemData in items as List<dynamic>) {
          try {
            final itemJson = itemData as Map<String, dynamic>;
            // Get the item ID from the API response
            final itemId = itemJson['id'] != null ? itemJson['id'].toString() : null;
            if (itemId == null) {
              debugPrint('Warning: Item ID is null in assignment data: $itemJson');
              continue;
            }
            
            debugPrint('Looking for matching item with ID: $itemId');
            
            // Direct lookup in our ID mapping
            final matchingItem = receiptItemsById[itemId];
            
            if (matchingItem != null) {
              debugPrint('Found exact match for ID $itemId: ${matchingItem.name} (\$${matchingItem.price})');
              splitManager.assignItemToPerson(matchingItem, person);
            } else {
              // Fallback to more flexible matching if direct lookup fails
              final matchingItems = _receiptItems.where((receiptItem) => 
                receiptItem.itemId.endsWith('_$itemId') || // Match by numeric ID suffix
                receiptItem.itemId.contains('_$itemId\_') || // Match by numeric ID in middle 
                receiptItem.itemId == itemId.toString() // Exact string match
              ).toList();
              
              if (matchingItems.isNotEmpty) {
                final item = matchingItems.first;
                debugPrint('Found fuzzy match for ID $itemId: ${item.name} (\$${item.price})');
                splitManager.assignItemToPerson(item, person);
              } else {
                // Last resort - try matching by position in the list (1-indexed)
                if (int.tryParse(itemId) != null) {
                  final index = int.parse(itemId) - 1;
                  if (index >= 0 && index < _receiptItems.length) {
                    final item = _receiptItems[index];
                    debugPrint('Found positional match for ID $itemId: ${item.name} (\$${item.price})');
                    splitManager.assignItemToPerson(item, person);
                  } else {
                    debugPrint('Warning: No matching item found for ID: $itemId (out of range)');
                  }
                } else {
                  debugPrint('Warning: No matching item found for ID: $itemId');
                }
              }
            }
          } catch (e) {
            debugPrint('Error assigning item: $e');
          }
        }
      });
      
      // Use same improved matching for shared items
      for (final itemData in sharedItems) {
        try {
          final itemJson = itemData as Map<String, dynamic>;
          final itemId = itemJson['id'] != null ? itemJson['id'].toString() : null;
          if (itemId == null) {
            debugPrint('Warning: Item ID is null in shared item data: $itemJson');
            continue;
          }
          
          debugPrint('Looking for matching shared item with ID: $itemId');
          
          // Direct lookup in our ID mapping
          final matchingItem = receiptItemsById[itemId];
          
          // Check if this shared item specifies which people are sharing it
          List<String>? peopleNames;
          if (itemJson.containsKey('people') && itemJson['people'] is List) {
            peopleNames = (itemJson['people'] as List).map((p) => p.toString()).toList();
            debugPrint('Found people for shared item: $peopleNames');
          }
          
          // Find the specific people objects if names are provided
          List<Person>? specificPeople;
          if (peopleNames != null && peopleNames.isNotEmpty) {
            specificPeople = splitManager.people
                .where((person) => peopleNames!.contains(person.name))
                .toList();
                
            // Create people if they don't exist yet
            for (final name in peopleNames) {
              if (!splitManager.people.any((p) => p.name == name)) {
                splitManager.addPerson(name);
              }
            }
            
            // Refresh the list after potentially adding people
            if (specificPeople.isEmpty) {
              specificPeople = splitManager.people
                  .where((person) => peopleNames!.contains(person.name))
                  .toList();
            }
            
            debugPrint('Found ${specificPeople.length} people objects for shared item');
          }
          
          if (matchingItem != null) {
            debugPrint('Found exact match for shared ID $itemId: ${matchingItem.name} (\$${matchingItem.price})');
            
            // Use the specific people if available, otherwise share with all people
            if (specificPeople != null && specificPeople.isNotEmpty) {
              splitManager.markAsShared(matchingItem, people: specificPeople);
            } else {
              splitManager.markAsShared(matchingItem);
            }
          } else {
            // Same fallback logic as assignments
            final matchingItems = _receiptItems.where((receiptItem) => 
              receiptItem.itemId.endsWith('_$itemId') || 
              receiptItem.itemId.contains('_$itemId\_') ||
              receiptItem.itemId == itemId.toString()
            ).toList();
            
            if (matchingItems.isNotEmpty) {
              final item = matchingItems.first;
              debugPrint('Found fuzzy match for shared ID $itemId: ${item.name} (\$${item.price})');
              
              // Use the specific people if available, otherwise share with all people
              if (specificPeople != null && specificPeople.isNotEmpty) {
                splitManager.markAsShared(item, people: specificPeople);
              } else {
                splitManager.markAsShared(item);
              }
            } else {
              // Position-based match as last resort
              if (int.tryParse(itemId) != null) {
                final index = int.parse(itemId) - 1;
                if (index >= 0 && index < _receiptItems.length) {
                  final item = _receiptItems[index];
                  debugPrint('Found positional match for shared ID $itemId: ${item.name} (\$${item.price})');
                  
                  // Use the specific people if available, otherwise share with all people
                  if (specificPeople != null && specificPeople.isNotEmpty) {
                    splitManager.markAsShared(item, people: specificPeople);
                  } else {
                    splitManager.markAsShared(item);
                  }
                } else {
                  debugPrint('Warning: No matching shared item found for ID: $itemId (out of range)');
                }
              } else {
                debugPrint('Warning: No matching shared item found for ID: $itemId');
              }
            }
          }
        } catch (e) {
          debugPrint('Error processing shared item: $e');
        }
      }
      
      // And use the same improved logic for unassigned items
      for (final itemData in unassignedItems) {
        try {
          final itemJson = itemData as Map<String, dynamic>;
          final itemId = itemJson['id'] != null ? itemJson['id'].toString() : null;
          if (itemId == null) continue;
          
          // Direct lookup in our ID mapping
          final matchingItem = receiptItemsById[itemId];
          
          if (matchingItem != null) {
            splitManager.markAsUnassigned(matchingItem);
          } else {
            // Same fallback logic as assignments
            final matchingItems = _receiptItems.where((receiptItem) => 
              receiptItem.itemId.endsWith('_$itemId') || 
              receiptItem.itemId.contains('_$itemId\_') ||
              receiptItem.itemId == itemId.toString()
            ).toList();
            
            if (matchingItems.isNotEmpty) {
              splitManager.markAsUnassigned(matchingItems.first);
            } else {
              // Position-based match as last resort
              if (int.tryParse(itemId) != null) {
                final index = int.parse(itemId) - 1;
                if (index >= 0 && index < _receiptItems.length) {
                  splitManager.markAsUnassigned(_receiptItems[index]);
                }
              }
            }
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
  
  void _initializePageController() {
    // Initialize with current step 
    _pageController = PageController(
      initialPage: _currentStep,
      keepPage: true, // Important: keep the page state when switching
    );
    
    // Debug log for initialization
    debugPrint('Initial page set to: $_currentStep');
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