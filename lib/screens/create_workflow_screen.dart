import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/receipt_history.dart';
import '../models/receipt_item.dart';
import '../models/split_manager.dart';
import '../services/receipt_history_service.dart';
import 'receipt_upload_screen.dart';
import 'receipt_review_screen.dart';
import 'voice_assignment_screen.dart';
import 'assignment_review_screen.dart';
import 'final_summary_screen.dart';
import 'package:provider/provider.dart';
import '../services/receipt_parser_service.dart';

class CreateWorkflowScreen extends StatefulWidget {
  final ReceiptHistory? existingReceipt;

  const CreateWorkflowScreen({
    Key? key, 
    this.existingReceipt,
  }) : super(key: key);

  @override
  State<CreateWorkflowScreen> createState() => _CreateWorkflowScreenState();
}

class _CreateWorkflowScreenState extends State<CreateWorkflowScreen> with WidgetsBindingObserver {
  int _currentStep = 0;
  File? _imageFile;
  bool _isLoading = false;
  bool _isAutoSaving = false;
  String _loadingMessage = 'Loading...';
  bool _hasUnsavedChanges = false;
  
  // State management
  final SplitManager _splitManager = SplitManager();
  List<ReceiptItem> _receiptItems = [];
  double _subtotal = 0.0;
  String? _imageUri;
  String? _transcription;
  String _restaurantName = '';
  
  // Receipt history service for saving
  final ReceiptHistoryService _historyService = ReceiptHistoryService();
  
  // Define the steps in the workflow
  final List<String> _steps = [
    'Upload',
    'Review',
    'Assign',
    'Split',
    'Summary',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // If editing an existing receipt, load its data
    if (widget.existingReceipt != null) {
      _loadExistingReceipt();
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Auto-save when app goes to background
      _autoSaveDraft();
    }
  }
  
  void _loadExistingReceipt() {
    final receipt = widget.existingReceipt!;
    
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Loading receipt data...';
    });
    
    try {
      // Determine which step to start at based on receipt status and available data
      int startStep = 0;
      
      if (receipt.status == 'draft') {
        // For draft receipts, determine the furthest step completed
        if (receipt.splitManagerState != null && receipt.splitManagerState!.isNotEmpty) {
          // If split manager state exists, go to summary
          startStep = 4;
          
          // Load split manager state
          _splitManager.loadFromMap(receipt.splitManagerState!);
          
          // Extract other data from split manager
          _subtotal = _splitManager.subtotal;
          _receiptItems = _splitManager.getAllItems();
        } else if (receipt.receiptData.containsKey('items')) {
          // If receipt items exist, go to review screen
          startStep = 1;
          
          // Extract receipt items
          final items = receipt.receiptData['items'] as List<dynamic>;
          _receiptItems = items.map((item) => ReceiptItem.fromMap(Map<String, dynamic>.from(item))).toList();
          
          if (receipt.transcription != null && receipt.transcription!.isNotEmpty) {
            // If there's transcription, move to assign step
            startStep = 2;
            _transcription = receipt.transcription;
          }
        }
      } else {
        // For completed receipts, go to summary
        startStep = 4;
        
        // Load split manager state
        if (receipt.splitManagerState != null) {
          _splitManager.loadFromMap(receipt.splitManagerState!);
          _subtotal = _splitManager.subtotal;
          _receiptItems = _splitManager.getAllItems();
        }
      }
      
      // Set common data
      _imageUri = receipt.imageUri;
      _restaurantName = receipt.restaurantName;
      
      // Update the current step
      _currentStep = startStep;
      
    } catch (e) {
      _showErrorSnackbar('Error loading receipt: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _autoSaveDraft() async {
    // Only auto-save if there are unsaved changes and we have necessary data
    if (!_hasUnsavedChanges || _imageUri == null || _currentStep == 0) {
      return;
    }
    
    setState(() {
      _isAutoSaving = true;
    });
    
    try {
      await _historyService.saveDraftReceipt(
        splitManager: _splitManager,
        imageUri: _imageUri!,
        restaurantName: _restaurantName.isNotEmpty ? _restaurantName : 'Draft Receipt',
        transcription: _transcription,
      );
      
      setState(() {
        _hasUnsavedChanges = false;
      });
      
      // Show subtle indicator that auto-save was successful
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress auto-saved'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Auto-save error: ${e.toString()}');
      // Don't show error to user during auto-save to avoid disruption
    } finally {
      setState(() {
        _isAutoSaving = false;
      });
    }
  }
  
  Future<void> _saveCompletedReceipt(String restaurantName) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Saving receipt...';
    });
    
    try {
      await _historyService.saveReceipt(
        splitManager: _splitManager,
        imageUri: _imageUri!,
        restaurantName: restaurantName,
        status: 'completed',
        transcription: _transcription,
      );
      
      setState(() {
        _hasUnsavedChanges = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Return to first step and reset state for a new receipt
        setState(() {
          _currentStep = 0;
          _imageFile = null;
          _imageUri = null;
          _transcription = null;
          _receiptItems = [];
          _splitManager.reset();
          _subtotal = 0.0;
          _restaurantName = '';
        });
      }
    } catch (e) {
      _showErrorSnackbar('Error saving receipt: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        String name = _restaurantName;
        
        return AlertDialog(
          title: const Text('Save Receipt'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter restaurant or store name:'),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Pizza Place',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    name = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop();
                  _saveCompletedReceipt(name);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
  
  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _onStepTapped(int step) {
    // Don't allow skipping ahead unless previous steps are complete
    if (step > _currentStep) {
      // Check if step can be accessed based on data availability
      bool canAccess = false;
      
      switch (step) {
        case 1: // Review step
          canAccess = _imageUri != null;
          break;
        case 2: // Assign step
          canAccess = _receiptItems.isNotEmpty;
          break;
        case 3: // Split step
          canAccess = _transcription != null && _transcription!.isNotEmpty;
          break;
        case 4: // Summary step
          canAccess = _splitManager.people.isNotEmpty && _splitManager.areAllItemsAssigned();
          break;
        default:
          canAccess = false;
      }
      
      if (!canAccess) {
        _showErrorSnackbar('Please complete the current step first');
        return;
      }
    }
    
    // Auto-save when moving between steps
    if (_currentStep > 0 && _imageUri != null) {
      _autoSaveDraft();
    }
    
    setState(() {
      _currentStep = step;
    });
  }
  
  void _moveToNextStep() {
    if (_currentStep < _steps.length - 1) {
      _onStepTapped(_currentStep + 1);
    }
  }
  
  void _moveToPreviousStep() {
    if (_currentStep > 0) {
      _onStepTapped(_currentStep - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If on first step or loading, allow going back
        if (_currentStep == 0 || _isLoading) {
          return true;
        }
        
        // Otherwise, go to previous step and prevent back navigation
        _moveToPreviousStep();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Receipt'),
          leading: _currentStep > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _moveToPreviousStep,
                )
              : null,
          actions: [
            if (_isAutoSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_loadingMessage),
                  ],
                ),
              )
            : Column(
                children: [
                  // Step indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: SizedBox(
                      height: 50,
                      child: Center(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          shrinkWrap: true,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_steps.length, (index) {
                                final isActive = index == _currentStep;
                                final isCompleted = index < _currentStep;
                                
                                return GestureDetector(
                                  onTap: () => _onStepTapped(index),
                                  child: Row(
                                    children: [
                                      // Step circle
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isActive
                                              ? Theme.of(context).primaryColor
                                              : isCompleted
                                                  ? Colors.green
                                                  : Colors.grey.shade300,
                                        ),
                                        child: Center(
                                          child: isCompleted
                                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                                              : Text(
                                                  '${index + 1}',
                                                  style: TextStyle(
                                                    color: isActive ? Colors.white : Colors.grey.shade600,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      
                                      // Step label
                                      const SizedBox(width: 4),
                                      Text(
                                        _steps[index],
                                        style: TextStyle(
                                          color: isActive 
                                              ? Theme.of(context).primaryColor 
                                              : isCompleted
                                                  ? Colors.green
                                                  : Colors.grey.shade600,
                                          fontSize: 12,
                                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      
                                      // Connector line
                                      if (index < _steps.length - 1)
                                        Container(
                                          width: 20,
                                          height: 2,
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          color: isCompleted
                                              ? Colors.green
                                              : Colors.grey.shade300,
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Current step content
                  Expanded(
                    child: _buildCurrentStep(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: // Upload
        return ReceiptUploadScreen(
          imageFile: _imageFile,
          isLoading: _isLoading,
          onImageSelected: (file) {
            setState(() {
              _imageFile = file;
              _hasUnsavedChanges = true;
            });
          },
          onParseReceipt: () async {
            if (_imageFile == null) return;
            
            setState(() {
              _isLoading = true;
              _loadingMessage = 'Analyzing receipt...';
              _hasUnsavedChanges = true;
            });
            
            try {
              // Call the actual receipt parser service - now returns a tuple of (receiptData, imageUri)
              final result = await ReceiptParserService.parseReceipt(_imageFile!);
              final receiptData = result.$1;
              final imageUri = result.$2;
              
              // Get the real receipt items from the parsed data
              _receiptItems = receiptData.getReceiptItems();
              _subtotal = receiptData.subtotal;
              
              // Store the image URI for saving to history later
              _imageUri = imageUri;
              
              setState(() {
                _isLoading = false;
              });
              
              _moveToNextStep();
            } catch (e) {
              _showErrorSnackbar('Error parsing receipt: ${e.toString()}');
              setState(() {
                _isLoading = false;
              });
            }
          },
          onRetry: () {
            setState(() {
              _imageFile = null;
              _imageUri = null;
              _hasUnsavedChanges = false;
            });
          },
        );
        
      case 1: // Review
        return ReceiptReviewScreen(
          initialItems: _receiptItems,
          onReviewComplete: (updatedItems, deletedItems) {
            // Handle review completion
            _moveToNextStep();
          },
          onItemsUpdated: (currentItems) {
            setState(() {
              _receiptItems = currentItems;
              _subtotal = _receiptItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
              _hasUnsavedChanges = true;
            });
          },
        );
        
      case 2: // Assign
        return VoiceAssignmentScreen(
          itemsToAssign: _receiptItems,
          initialTranscription: _transcription,
          onAssignmentProcessed: (assignmentResult) {
            // Convert the dynamic map to the expected type
            final Map<String, List<String>> typedResult = {};
            assignmentResult.forEach((key, value) {
              if (value is List) {
                typedResult[key] = value.map((item) => item.toString()).toList();
              }
            });
            
            // Process the assignment result
            // This should update the split manager with initial assignments
            _splitManager.initializeFromAssignments(
              _receiptItems, 
              typedResult,
              _subtotal,
            );
            
            _moveToNextStep();
          },
          onTranscriptionChanged: (transcription) {
            setState(() {
              _transcription = transcription;
              _hasUnsavedChanges = true;
            });
          },
        );
        
      case 3: // Split
        return Center(
          child: Text('Split Items - Implementation in progress'),
        );
        
      case 4: // Summary
        return ChangeNotifierProvider.value(
          value: _splitManager,
          child: Consumer<SplitManager>(
            builder: (context, splitManager, _) {
              return Scaffold(
                body: FinalSummaryScreen(),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: _showSaveDialog,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Receipt'),
                ),
              );
            },
          ),
        );
        
      default:
        return const SizedBox.shrink();
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Auto-save when leaving the screen
    if (_hasUnsavedChanges && _imageUri != null && _currentStep > 0) {
      _autoSaveDraft();
    }
    super.dispose();
  }
} 