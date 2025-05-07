import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  Map<String, dynamic> _parseReceiptResult = {};
  Map<String, dynamic> _transcribeAudioResult = {};
  Map<String, dynamic> _assignPeopleToItemsResult = {};
  Map<String, dynamic> _splitManagerState = {};
  bool _isLoading = false;
  String? _errorMessage;
  
  WorkflowState({required String restaurantName, String? receiptId})
      : _restaurantName = restaurantName,
        _receiptId = receiptId;
  
  // Getters
  int get currentStep => _currentStep;
  String get restaurantName => _restaurantName;
  String? get receiptId => _receiptId;
  File? get imageFile => _imageFile;
  Map<String, dynamic> get parseReceiptResult => _parseReceiptResult;
  Map<String, dynamic> get transcribeAudioResult => _transcribeAudioResult;
  Map<String, dynamic> get assignPeopleToItemsResult => _assignPeopleToItemsResult;
  Map<String, dynamic> get splitManagerState => _splitManagerState;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
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
    _imageFile = file;
    notifyListeners();
  }
  
  // Reset image file without directly setting to null
  void resetImageFile() {
    _imageFile = null;
    notifyListeners();
  }
  
  void setParseReceiptResult(Map<String, dynamic> result) {
    _parseReceiptResult = result;
    notifyListeners();
  }
  
  void setTranscribeAudioResult(Map<String, dynamic> result) {
    _transcribeAudioResult = result;
    notifyListeners();
  }
  
  void setAssignPeopleToItemsResult(Map<String, dynamic> result) {
    _assignPeopleToItemsResult = result;
    notifyListeners();
  }
  
  void setSplitManagerState(Map<String, dynamic> state) {
    _splitManagerState = state;
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
  
  // Convert to Receipt model for saving
  Receipt toReceipt() {
    if (_receiptId == null) {
      throw Exception('Receipt ID is required to create a Receipt object');
    }
    
    return Receipt(
      id: _receiptId!,
      restaurantName: _restaurantName,
      imageUri: _parseReceiptResult['image_uri'] as String?,
      thumbnailUri: _parseReceiptResult['thumbnail_uri'] as String?,
      parseReceipt: _parseReceiptResult,
      transcribeAudio: _transcribeAudioResult,
      assignPeopleToItems: _assignPeopleToItemsResult,
      splitManagerState: _splitManagerState,
      status: 'draft',
      people: _extractPeopleFromAssignments(),
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
          people.add(assignment['person_name'] as String);
        }
      }
    }
    
    return people;
  }
}

/// Dialog to prompt for restaurant name
Future<String?> showRestaurantNameDialog(BuildContext context, {String? initialName}) async {
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
  static Future<void> show(BuildContext context, {String? receiptId}) async {
    // First, show the restaurant name dialog
    final restaurantName = await showRestaurantNameDialog(context);
    
    // If the user cancels the dialog, don't show the modal
    if (restaurantName == null) {
      return;
    }
    
    // Then show the workflow modal
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Provider(
          create: (context) => WorkflowState(
            restaurantName: restaurantName,
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
      
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error Saving Draft'),
          content: Text(
            'There was an error saving your draft: $e\n\n'
            'Do you want to try again or discard changes?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Don't save, just exit
              child: const Text('DISCARD'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true), // Try again
              child: const Text('TRY AGAIN'),
            ),
          ],
        ),
      );
      
      if (result == true) {
        // Try again
        return _onWillPop();
      }
      
      // Discard and exit
      return true;
    }
  }
  
  // Save the current state as a draft
  Future<void> _saveDraft() async {
    final workflowState = Provider.of<WorkflowState>(context, listen: false);
    
    try {
      // Show loading indicator
      workflowState.setLoading(true);
      workflowState.setErrorMessage(null);
      
      // Convert state to Receipt model
      final receipt = workflowState.toReceipt();
      
      // Save to Firestore
      final receiptId = await _firestoreService.saveDraft(
        receiptId: workflowState.receiptId,
        data: receipt.toMap(),
      );
      
      // Update receipt ID if it was a new receipt
      if (workflowState.receiptId == null) {
        workflowState.setReceiptId(receiptId);
      }
      
      // Done
      workflowState.setLoading(false);
      
      if (mounted) {
        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error
      workflowState.setLoading(false);
      workflowState.setErrorMessage('Failed to save draft: $e');
      
      if (mounted) {
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save draft: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                  final prevStepIndex = index ~/ 2;
                  final nextStepIndex = prevStepIndex + 1;
                  final isActive = currentStep > prevStepIndex;
                  
                  return Container(
                    width: 24,
                    height: 2,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                  );
                }
              },
            ),
          ),
          
          // Step titles
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _stepTitles.length,
              (index) {
                final isActive = index == currentStep;
                final isCompleted = index < currentStep;
                
                return Text(
                  _stepTitles[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : isCompleted
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  // Build the current step content
  Widget _buildStepContent(int currentStep) {
    final workflowState = Provider.of<WorkflowState>(context);
    
    switch (currentStep) {
      case 0: // Upload
        return ReceiptUploadScreen(
          imageFile: workflowState.imageFile,
          isLoading: workflowState.isLoading,
          onImageSelected: (file) {
            if (file != null) {
              workflowState.setImageFile(file);
            }
          },
          onParseReceipt: () {
            // Start loading
            workflowState.setLoading(true);
            
            // TODO: In a real implementation, we would call the parse receipt API here
            // For now, simulate a delay and then go to the next step
            Future.delayed(const Duration(seconds: 2), () {
              // Set some dummy parse result data
              workflowState.setParseReceiptResult({
                'image_uri': 'path/to/image',
                'thumbnail_uri': 'path/to/thumbnail',
                'items': [
                  {'name': 'Item 1', 'quantity': 1, 'price': 10.99},
                  {'name': 'Item 2', 'quantity': 2, 'price': 5.99},
                  {'name': 'Item 3', 'quantity': 1, 'price': 15.50},
                ],
                'subtotal': 38.47,
                'tax': 3.41,
                'total': 41.88,
              });
              
              // Stop loading and go to next step
              workflowState.setLoading(false);
              workflowState.nextStep();
            });
          },
          onRetry: () {
            // Reset the state to allow picking a new image
            workflowState.resetImageFile();
            workflowState.setLoading(false);
            workflowState.setErrorMessage(null);
            workflowState.setParseReceiptResult({});
          },
        );
      case 1: // Review
        // Get items from parse receipt result and convert to ReceiptItem objects
        final items = _convertToReceiptItems(workflowState.parseReceiptResult);
        
        return ReceiptReviewScreen(
          initialItems: items,
          onReviewComplete: (updatedItems, deletedItems) {
            // Save the reviewed items to the workflow state
            final updatedResult = Map<String, dynamic>.from(workflowState.parseReceiptResult);
            updatedResult['items'] = updatedItems.map((item) => {
              'name': item.name,
              'quantity': item.quantity,
              'price': item.price,
            }).toList();
            
            // Update the workflow state
            workflowState.setParseReceiptResult(updatedResult);
            
            // Go to the next step
            workflowState.nextStep();
          },
          // Keep items updated in real-time
          onItemsUpdated: (currentItems) {
            // Optionally update the workflow state in real-time for auto-save
            final updatedResult = Map<String, dynamic>.from(workflowState.parseReceiptResult);
            updatedResult['items'] = currentItems.map((item) => {
              'name': item.name,
              'quantity': item.quantity,
              'price': item.price,
            }).toList();
            
            workflowState.setParseReceiptResult(updatedResult);
          },
        );
        
      case 2: // Assign
        // Convert receipt items from parse result to ReceiptItem objects for the voice assignment screen
        final itemsToAssign = _convertToReceiptItems(workflowState.parseReceiptResult);
        
        // Get the initial transcription from the state if available
        final initialTranscription = workflowState.transcribeAudioResult.containsKey('transcription')
            ? workflowState.transcribeAudioResult['transcription'] as String?
            : null;
        
        return VoiceAssignmentScreen(
          itemsToAssign: itemsToAssign,
          initialTranscription: initialTranscription,
          onTranscriptionChanged: (transcription) {
            // Keep transcription updated in real-time
            if (transcription != null) {
              final updatedResult = Map<String, dynamic>.from(workflowState.transcribeAudioResult);
              updatedResult['transcription'] = transcription;
              workflowState.setTranscribeAudioResult(updatedResult);
            }
          },
          onAssignmentProcessed: (assignmentsData) {
            // Save the assignment data to the workflow state
            workflowState.setAssignPeopleToItemsResult(assignmentsData);
            
            // Go to the next step
            workflowState.nextStep();
          },
        );
        
      case 3: // Split
        // Create a SplitManager instance with assigned items from previous step
        return ChangeNotifierProvider(
          create: (context) {
            // Get the assignment results from the workflow state
            final assignmentsData = workflowState.assignPeopleToItemsResult;
            
            // Create a new SplitManager
            final splitManager = SplitManager();
            
            // If we have assignment data, process it
            if (assignmentsData.isNotEmpty) {
              // Extract people and their assigned items
              if (assignmentsData.containsKey('assignments') && assignmentsData['assignments'] is List) {
                final assignments = assignmentsData['assignments'] as List;
                
                // Add each person and their assigned items
                for (final assignment in assignments) {
                  if (assignment is Map) {
                    final personName = assignment['person_name'] as String;
                    
                    // Create and add the person
                    splitManager.addPerson(personName);
                    final person = splitManager.people.last;
                    
                    // Add their assigned items
                    if (assignment.containsKey('items') && assignment['items'] is List) {
                      final items = assignment['items'] as List;
                      for (final item in items) {
                        if (item is Map) {
                          try {
                            // Create a ReceiptItem and assign it to the person
                            final receiptItem = ReceiptItem(
                              name: item['name'] as String,
                              price: (item['price'] as num).toDouble(),
                              quantity: item['quantity'] as int,
                            );
                            splitManager.assignItemToPerson(receiptItem, person);
                          } catch (e) {
                            print('Error processing assigned item: $e');
                          }
                        }
                      }
                    }
                  }
                }
              }
              
              // Add shared items
              if (assignmentsData.containsKey('shared_items') && assignmentsData['shared_items'] is List) {
                final sharedItems = assignmentsData['shared_items'] as List;
                
                for (final sharedItem in sharedItems) {
                  if (sharedItem is Map) {
                    try {
                      // Create the shared item
                      final receiptItem = ReceiptItem(
                        name: sharedItem['name'] as String,
                        price: (sharedItem['price'] as num).toDouble(),
                        quantity: sharedItem['quantity'] as int,
                      );
                      
                      // Get the list of people who share this item
                      final List<String> peopleNames = (sharedItem['people'] as List).cast<String>();
                      final List<Person> peopleForItem = splitManager.people
                          .where((p) => peopleNames.contains(p.name))
                          .toList();
                      
                      // Add the item as shared among these people
                      if (peopleForItem.isNotEmpty) {
                        splitManager.addItemToShared(receiptItem, peopleForItem);
                      }
                    } catch (e) {
                      print('Error processing shared item: $e');
                    }
                  }
                }
              }
              
              // Add unassigned items
              if (assignmentsData.containsKey('unassigned_items') && assignmentsData['unassigned_items'] is List) {
                final unassignedItems = assignmentsData['unassigned_items'] as List;
                
                for (final unassignedItem in unassignedItems) {
                  if (unassignedItem is Map) {
                    try {
                      // Create the unassigned item and add it
                      final receiptItem = ReceiptItem(
                        name: unassignedItem['name'] as String,
                        price: (unassignedItem['price'] as num).toDouble(),
                        quantity: unassignedItem['quantity'] as int,
                      );
                      splitManager.addUnassignedItem(receiptItem);
                    } catch (e) {
                      print('Error processing unassigned item: $e');
                    }
                  }
                }
              }
            }
            
            return splitManager;
          },
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  Expanded(
                    child: const SplitView(),
                  ),
                  // Listen for navigation requests from SplitView
                  NotificationListener<NavigateToPageNotification>(
                    onNotification: (notification) {
                      // Only navigate to the summary page if requested
                      if (notification.pageIndex == 4) {
                        // Save the split state to the workflow state
                        final splitManager = Provider.of<SplitManager>(context, listen: false);
                        
                        // Collect the final split data
                        final Map<String, dynamic> splitData = {
                          'people': splitManager.people.map((person) => {
                            'name': person.name,
                            'assigned_items': person.assignedItems.map((item) => {
                              'name': item.name,
                              'quantity': item.quantity,
                              'price': item.price,
                            }).toList(),
                            'shared_items': person.sharedItems.map((item) => {
                              'name': item.name,
                              'quantity': item.quantity,
                              'price': item.price,
                            }).toList(),
                            'total': person.totalAmount,
                          }).toList(),
                          'unassigned_items': splitManager.unassignedItems.map((item) => {
                            'name': item.name,
                            'quantity': item.quantity,
                            'price': item.price,
                          }).toList(),
                        };
                        
                        // Update the workflow state
                        workflowState.setSplitManagerState(splitData);
                        
                        // Go to the next step (summary)
                        workflowState.nextStep();
                      }
                      return true;
                    },
                    child: const SizedBox.shrink(), // Empty container as we're just listening
                  ),
                ],
              );
            },
          ),
        );
      
      case 4: // Summary
        // Provide the split manager state to the final summary screen
        return ChangeNotifierProvider(
          create: (context) {
            // Get the split data from the workflow state
            final splitData = workflowState.splitManagerState;
            
            // Create a new SplitManager with the data
            final splitManager = SplitManager();
            
            if (splitData.isNotEmpty && splitData.containsKey('people')) {
              // Add all people with their items
              final peopleList = splitData['people'] as List;
              
              for (final personData in peopleList) {
                if (personData is Map) {
                  final personName = personData['name'] as String;
                  
                  // Add person
                  splitManager.addPerson(personName);
                  final person = splitManager.people.last;
                  
                  // Add assigned items
                  if (personData.containsKey('assigned_items') && personData['assigned_items'] is List) {
                    final assignedItems = personData['assigned_items'] as List;
                    for (final itemData in assignedItems) {
                      if (itemData is Map) {
                        try {
                          final receiptItem = ReceiptItem(
                            name: itemData['name'] as String,
                            price: (itemData['price'] as num).toDouble(),
                            quantity: itemData['quantity'] as int,
                          );
                          splitManager.assignItemToPerson(receiptItem, person);
                        } catch (e) {
                          print('Error processing assigned item: $e');
                        }
                      }
                    }
                  }
                  
                  // Add shared items (will be properly connected later)
                  if (personData.containsKey('shared_items') && personData['shared_items'] is List) {
                    final sharedItems = personData['shared_items'] as List;
                    for (final itemData in sharedItems) {
                      if (itemData is Map) {
                        try {
                          final receiptItem = ReceiptItem(
                            name: itemData['name'] as String,
                            price: (itemData['price'] as num).toDouble(),
                            quantity: itemData['quantity'] as int,
                          );
                          
                          // Check if this item is already in the shared items list
                          final existingItem = splitManager.sharedItems.firstWhere(
                            (item) => item.name == receiptItem.name && item.price == receiptItem.price,
                            orElse: () => receiptItem, // Use the new item if not found
                          );
                          
                          if (!splitManager.sharedItems.contains(existingItem)) {
                            splitManager.addItemToShared(existingItem, [person]);
                          } else {
                            splitManager.addPersonToSharedItem(existingItem, person);
                          }
                        } catch (e) {
                          print('Error processing shared item: $e');
                        }
                      }
                    }
                  }
                }
              }
            }
            
            // Add unassigned items if any
            if (splitData.containsKey('unassigned_items') && splitData['unassigned_items'] is List) {
              final unassignedItems = splitData['unassigned_items'] as List;
              for (final itemData in unassignedItems) {
                if (itemData is Map) {
                  try {
                    final receiptItem = ReceiptItem(
                      name: itemData['name'] as String,
                      price: (itemData['price'] as num).toDouble(),
                      quantity: itemData['quantity'] as int,
                    );
                    splitManager.addUnassignedItem(receiptItem);
                  } catch (e) {
                    print('Error processing unassigned item: $e');
                  }
                }
              }
            }
            
            return splitManager;
          },
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  Expanded(
                    child: const FinalSummaryScreen(),
                  ),
                  // Listen for navigation requests from Summary screen to go back to Split
                  NotificationListener<NavigateToPageNotification>(
                    onNotification: (notification) {
                      // If requested, navigate to specified page
                      if (notification.pageIndex < 5) {
                        workflowState.goToStep(notification.pageIndex);
                      }
                      return true;
                    },
                    child: const SizedBox.shrink(), // Empty container as we're just listening
                  ),
                ],
              );
            },
          ),
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
          
          // Exit button (automatically saves)
          OutlinedButton(
            onPressed: () async {
              await _onWillPop(); // This will autosave and exit
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Exit'),
          ),
          
          // Next button (hidden on last step)
          FilledButton.icon(
            onPressed: currentStep < 4
                ? () => workflowState.nextStep()
                : null,
            label: const Text('Next'),
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workflowState = Provider.of<WorkflowState>(context);
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(workflowState.restaurantName),
          // Don't show automatic back button
          automaticallyImplyLeading: false,
          // Override the back button to show our confirmation dialog
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final canPop = await _onWillPop();
              if (canPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Step indicator
            _buildStepIndicator(workflowState.currentStep),
            
            // Current step content
            Expanded(
              child: _buildStepContent(workflowState.currentStep),
            ),
            
            // Navigation
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
            items.add(ReceiptItem(
              name: rawItem['name'] as String,
              price: (rawItem['price'] as num).toDouble(),
              quantity: rawItem['quantity'] as int,
            ));
          } catch (e) {
            // Skip items that don't match the expected format
            print('Error converting item: $e');
          }
        }
      }
    }
    
    return items;
  }
} 