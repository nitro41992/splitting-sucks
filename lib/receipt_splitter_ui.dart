import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'services/receipt_parser_service.dart';
import 'services/mock_data_service.dart';
import 'services/file_helper.dart'; // Import the new helper
import 'widgets/split_view.dart';
import 'package:provider/provider.dart';
import 'models/split_manager.dart';
import 'models/receipt_item.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';  // Added import for AppColors
import 'package:flutter/services.dart';  // Add this import for clipboard
import 'package:url_launcher/url_launcher.dart'; // Add this import for launching URLs
import 'services/auth_service.dart'; // Import AuthService
import 'package:flutter/services.dart';  // Add this import for system navigation

// Import the new screen
import 'screens/receipt_upload_screen.dart';
import 'screens/receipt_review_screen.dart';
import 'screens/voice_assignment_screen.dart'; // Import new screen
import 'screens/assignment_review_screen.dart'; // Import new screen
import 'screens/final_summary_screen.dart'; // Import the new screen

// Mock data for demonstration
class MockData {
  // Use same mock items as MockDataService for consistency
  static final List<ReceiptItem> items = MockDataService.mockItems;

  // Use same mock people as MockDataService for consistency
  static final List<String> people = MockDataService.mockPeople;
  
  // Use same mock assignments as MockDataService for consistency
  static final Map<String, List<ReceiptItem>> assignments = MockDataService.mockAssignments;

  // Use same mock shared items as MockDataService for consistency
  static final List<ReceiptItem> sharedItems = MockDataService.mockSharedItems;
}

class ReceiptSplitterUI extends StatefulWidget {
  const ReceiptSplitterUI({super.key});

  @override
  State<ReceiptSplitterUI> createState() => _ReceiptSplitterUIState();
}

class _ReceiptSplitterUIState extends State<ReceiptSplitterUI> with WidgetsBindingObserver {
  // State variables for the main coordinator
  int _currentStep = 0;
  final PageController _pageController = PageController();
  File? _imageFile; // Needed for parsing
  bool _isLoading = false; // Overall loading state
  Map<String, dynamic>? _assignments; // Raw assignment results (optional to keep)
  List<ReceiptItem> _editableItems = []; // Holds items between parsing and review

  // Voice assignment state preservation
  String? _savedTranscription; // Added to preserve transcription when navigating

  // Step completion tracking (kept in coordinator)
  bool _isUploadComplete = false;
  bool _isReviewComplete = false;
  bool _isAssignmentComplete = false;

  // Path to temporarily saved image for state restoration
  String? _savedImagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Register for lifecycle events
    _loadSavedState(); // Load saved state on startup

    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';

    if (useMockData) {
      _editableItems = [
        ...List.from(MockDataService.mockItems),
        ...List.from(MockDataService.mockSharedItems),
        ...List.from(MockDataService.mockUnassignedItems),
      ];
      _editableItems = _editableItems.toSet().toList();
      _currentStep = 0; // Start at upload even with mock data
      _isUploadComplete = false; // Reset flags for mock data start
      _isReviewComplete = false;
      _isAssignmentComplete = false;
    } else {
      _editableItems = [];
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Unregister from lifecycle events
    _pageController.dispose();
    super.dispose();
  }

  // Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive) {
      // App is going to background, save state
      _saveCurrentState();
    } else if (state == AppLifecycleState.resumed) {
      // App is coming back to foreground, refresh state if needed
      // (We already load state in initState, but can add additional logic here if needed)
    }
  }

  // Save the current state to persistent storage
  Future<void> _saveCurrentState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save current step and completion flags
      await prefs.setInt('current_step', _currentStep);
      await prefs.setBool('is_upload_complete', _isUploadComplete);
      await prefs.setBool('is_review_complete', _isReviewComplete);
      await prefs.setBool('is_assignment_complete', _isAssignmentComplete);
      
      // Save transcription if available
      if (_savedTranscription != null) {
        await prefs.setString('saved_transcription', _savedTranscription!);
      }
      
      // Enhanced image saving logic
      if (_imageFile != null) {
        try {
          // Check if the image file is valid before attempting to save
          if (FileHelper.isValidImageFile(_imageFile!)) {
            final tempDir = await getTemporaryDirectory();
            final fileName = 'saved_receipt_image.${_imageFile!.path.split('.').last}'; // Preserve extension
            final imagePath = '${tempDir.path}/$fileName';
            
            // Create the directory if it doesn't exist
            final directory = Directory(tempDir.path);
            if (!directory.existsSync()) {
              directory.createSync(recursive: true);
            }
            
            // For robustness, make a direct copy of the bytes
            try {
              final bytes = await _imageFile!.readAsBytes();
              final newFile = File(imagePath);
              await newFile.writeAsBytes(bytes);
              
              // Verify the file was correctly written
              if (newFile.existsSync() && newFile.lengthSync() > 0) {
                await prefs.setString('saved_image_path', newFile.path);
                print('Image saved successfully to: ${newFile.path}');
              } else {
                print('Failed to save image - file not created or empty');
                prefs.remove('saved_image_path');
              }
            } catch (e) {
              print('Error during direct file copy: $e');
              prefs.remove('saved_image_path');
            }
          } else {
            print('Cannot save invalid image file: ${_imageFile!.path}');
            prefs.remove('saved_image_path');
          }
        } catch (e) {
          print('Error saving image file: $e');
          // Remove any old reference on error
          prefs.remove('saved_image_path');
        }
      }
      
      // Save editable items as JSON if available
      if (_editableItems.isNotEmpty) {
        final itemsJson = jsonEncode(_editableItems.map((item) => item.toJson()).toList());
        await prefs.setString('editable_items', itemsJson);
      }
      
      // Save assignments if available
      if (_assignments != null) {
        await prefs.setString('assignments', jsonEncode(_assignments));
      }
      
      print('App state saved successfully');
    } catch (e) {
      print('Error saving app state: $e');
    }
  }

  // Load previously saved state from persistent storage
  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if we have saved state
      if (!prefs.containsKey('current_step')) {
        print('No saved state found');
        return;
      }
      
      setState(() {
        // Restore workflow state
        _currentStep = prefs.getInt('current_step') ?? 0;
        _isUploadComplete = prefs.getBool('is_upload_complete') ?? false;
        _isReviewComplete = prefs.getBool('is_review_complete') ?? false;
        _isAssignmentComplete = prefs.getBool('is_assignment_complete') ?? false;
        
        // Restore transcription
        _savedTranscription = prefs.getString('saved_transcription');
        
        // Restore image if available - with enhanced validation
        final imagePath = prefs.getString('saved_image_path');
        if (imagePath != null) {
          final imageFile = File(imagePath);
          
          // Verify the file exists and is valid
          if (imageFile.existsSync() && imageFile.lengthSync() > 0) {
            try {
              // Additional check to ensure the file is readable
              imageFile.readAsBytesSync();
              _imageFile = imageFile;
              print('Successfully restored image from: $imagePath');
            } catch (e) {
              print('Error reading restored image file: $e');
              prefs.remove('saved_image_path');
            }
          } else {
            // File doesn't exist, is empty, or invalid - remove the reference
            print('Image file is invalid: $imagePath');
            prefs.remove('saved_image_path');
          }
        }
        
        // Restore editable items
        final itemsJson = prefs.getString('editable_items');
        if (itemsJson != null) {
          final List<dynamic> itemsList = jsonDecode(itemsJson);
          _editableItems = itemsList.map((item) => ReceiptItem.fromJson(item)).toList();
        }
        
        // Restore assignments
        final assignmentsJson = prefs.getString('assignments');
        if (assignmentsJson != null) {
          _assignments = jsonDecode(assignmentsJson);
        }
      });
      
      // If we have a saved state, initialize the page controller to that page
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentStep);
      }
      
      // If we've restored state past the upload stage, initialize the SplitManager
      if (_isReviewComplete && _editableItems.isNotEmpty) {
        // Call _initializeSplitManager after the build method completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeSplitManager(_editableItems);
        });
      }
      
      print('App state restored successfully to step: $_currentStep');
    } catch (e) {
      print('Error loading saved state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<Widget> pages = [
      ReceiptUploadScreen(
        imageFile: _imageFile,
        isLoading: _isLoading,
        onImageSelected: (file) {
          setState(() {
            _imageFile = file;
            _isLoading = false;
          });
        },
        onParseReceipt: _parseReceipt,
        onRetry: () {
          setState(() {
            _imageFile = null;
            _isLoading = false;
          });
        },
      ),
      ReceiptReviewScreen(
        key: ValueKey('ReviewScreen_${_editableItems.hashCode}'),
        initialItems: _editableItems,
        onReviewComplete: (updatedItems, deletedItems) {
          print('DEBUG: Review Complete. Updated: ${updatedItems.length}, Deleted: ${deletedItems.length}');
          setState(() {
            _editableItems = updatedItems;
            _isReviewComplete = true;
          });
          
          // --- EDIT: Initialize SplitManager and store original subtotal ---
          _initializeSplitManager(_editableItems); // Initialize SplitManager state
          
          // Calculate the total from review stage
          final splitManager = context.read<SplitManager>();
          // Calculate the TOTAL subtotal from all items, not just unassigned
          final double originalReviewTotal = _editableItems.fold(
            0.0, 
            (sum, item) => sum + (item.price * item.quantity)
          );
          splitManager.setOriginalUnassignedSubtotal(originalReviewTotal);
          // --- EDIT: Add more detailed debug print ---
          print('DEBUG (ReceiptSplitterUI): Stored original review total: $originalReviewTotal (from ${_editableItems.length} items)');
          // --- END EDIT ---
          
          _navigateToPage(2); // Navigate to Voice Assignment
        },
      ),
      VoiceAssignmentScreen(
        key: ValueKey('VoiceScreen_${_editableItems.hashCode}'),
        itemsToAssign: _editableItems,
        initialTranscription: _savedTranscription, // Pass saved transcription
        onAssignmentProcessed: _handleAssignmentProcessed,
        onTranscriptionChanged: (transcription) {
          // Save transcription when it changes
          setState(() {
            _savedTranscription = transcription;
          });
        },
      ),
      const AssignmentReviewScreen(),
      const FinalSummaryScreen(), // Use the new screen widget
    ];

    return PopScope(
      canPop: false, // Prevent automatic popping
      onPopInvoked: (didPop) async {
        // didPop will be false since we set canPop to false
        if (!didPop) {
          await _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.background,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
          leading: _currentStep > 0 
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  _navigateToPage(_currentStep - 1);
                },
              )
            : null,  // No back button on first screen
          title: Row(
            children: [
              Image.asset(
                'logo.png',
                height: 40,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Billfie',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Smart Bill Splitting',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Reset Button
            IconButton(
              icon: Icon(Icons.refresh, color: colorScheme.onSurface),
              tooltip: 'Start Over',
              onPressed: () async {
                final bool? confirmReset = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Start Over?'),
                      content: const Text('Are you sure you want to discard all progress and start over?'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(dialogContext).pop(false); // Return false
                          },
                        ),
                        TextButton(
                          child: Text('Reset', style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
                          onPressed: () {
                            Navigator.of(dialogContext).pop(true); // Return true
                          },
                        ),
                      ],
                    );
                  },
                );

                // If the user confirmed, call _resetState
                if (confirmReset == true) {
                  _resetState();
                }
              },
            ),
            // Logout Button
            IconButton(
              icon: Icon(Icons.logout, color: colorScheme.onSurface),
              tooltip: 'Log Out',
              onPressed: () async {
                // Optional: Show confirmation dialog
                final bool? confirmLogout = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Log Out?'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(dialogContext).pop(false);
                          },
                        ),
                        TextButton(
                          child: Text('Log Out', style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
                          onPressed: () {
                            Navigator.of(dialogContext).pop(true);
                          },
                        ),
                      ],
                    );
                  },
                );

                // If the user confirmed, call signOut
                if (confirmLogout == true) {
                  try {
                    // Get AuthService instance from Provider
                    final authService = context.read<AuthService>();
                    await authService.signOut();
                    // No need to navigate here, StreamBuilder in main.dart handles it.
                    if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                           content: const Text('Logged out successfully.'),
                           backgroundColor: Colors.green, // Or use theme color
                         ),
                       );
                    }
                  } catch (e) {
                     if (mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(
                           content: Text('Error logging out: $e'),
                           backgroundColor: Theme.of(context).colorScheme.error,
                         ),
                       );
                     }
                  }
                }
              },
            ),
          ],
        ),
        body: NotificationListener<NavigateToPageNotification>(
          onNotification: (notification) {
            // Check if the notification is the correct type before accessing its properties
            if (notification is NavigateToPageNotification) {
               _navigateToPage(notification.pageIndex);
               return true; // Consume the notification
            }
            return false; // Let other listeners handle it if it's not the type we expect
          },
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              // Prevent manual swipe updates if necessary
              // setState(() { _currentStep = index; });
            },
            children: pages.map((page) {
              // Add padding around each page content
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: page,
              );
            }).toList(),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentStep,
          onTap: (index) {
            // Navigation logic remains the same, controlled by coordinator state
            if (_canNavigateToStep(index)) {
              _navigateToPage(index);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: colorScheme.surface,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant.withOpacity(0.5),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_document),
              label: 'Review',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mic),
              label: 'Assign',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Split',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.summarize),
              label: 'Summary',
            ),
          ],
        ),
      ),
    );
  }

  bool _canNavigateToStep(int step) {
    // Logic remains the same
    switch (step) {
      case 0: return true;
      case 1: return _isUploadComplete;
      case 2: return _isReviewComplete;
      case 3: return _isAssignmentComplete;
      case 4: return _isAssignmentComplete;
      default: return false;
    }
  }

  void _resetState() {
    setState(() {
      _imageFile = null;
      _isLoading = false;
      _editableItems = [];
      _assignments = null;
      _isUploadComplete = false;
      _isReviewComplete = false;
      _isAssignmentComplete = false;
      _savedTranscription = null; // Reset saved transcription
      _savedImagePath = null;
      _currentStep = 0;
    });
    
    // Jump to first page
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    
    // Clear saved preferences
    _clearSavedPreferences();
  }

  Future<void> _parseReceipt() async {
    if (_imageFile == null) return;
    
    // Use the FileHelper to validate the image file
    if (!FileHelper.isValidImageFile(_imageFile)) {
      setState(() { _isLoading = false; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: The receipt image is invalid or corrupted. Please try uploading again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    
    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';

    setState(() { _isLoading = true; });

    if (useMockData) {
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _editableItems = [
          ...List.from(MockDataService.mockItems),
          ...List.from(MockDataService.mockSharedItems),
          ...List.from(MockDataService.mockUnassignedItems),
        ];
        _editableItems = _editableItems.toSet().toList();
        _isUploadComplete = true; // Mark upload as complete for mock data
        _isLoading = false;
      });
       _navigateToPage(1); // Navigate after setting state
      return;
    }

    try {
      final result = await ReceiptParserService.parseReceipt(_imageFile!);
      setState(() {
        // Use the getReceiptItems helper method to convert raw data to ReceiptItem objects
        _editableItems = result.getReceiptItems();
        _isUploadComplete = true;
        _isLoading = false;
      });
       _navigateToPage(1); // Navigate after setting state
    } catch (e) {
      setState(() { _isLoading = false; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing receipt: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  void _navigateToPage(int page) async {
    if (_pageController.hasClients && _canNavigateToStep(page)) {
      // Check if we're navigating backward
      bool isNavigatingBackward = page < _currentStep;
      
      if (isNavigatingBackward) {
        // Handle state cleanup for backward navigation
        switch (page) {
          case 0: // Back to Upload
            // Reset review state but preserve uploaded image
            setState(() {
              _isReviewComplete = false;
              _isAssignmentComplete = false;
            });
            break;
          case 1: // Back to Review
            // Reset assignment state but preserve review data
            setState(() {
              _isAssignmentComplete = false;
            });
            break;
          // Add cases for other backward transitions
        }
      }
      
      // Only update _currentStep if navigation is successful/allowed
      setState(() {
        _currentStep = page;
      });
      
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      
      // Automatically save state when navigating between tabs
      await _saveCurrentState();
    }
  }

  // --- EDIT: Add method to initialize SplitManager ---
  void _initializeSplitManager(List<ReceiptItem> items) {
    final splitManager = context.read<SplitManager>();
    splitManager.reset(); // Clear any previous state

    // For now, assume all items start as unassigned
    // TODO: Implement logic to handle pre-assigned/shared items if needed
    for (var item in items) {
      splitManager.addUnassignedItem(ReceiptItem.clone(item)); // Add clones to prevent mutation issues
    }

    // Add default people or load from storage if applicable (example)
    // if (splitManager.people.isEmpty) {
    //   splitManager.addPerson("Person 1");
    //   splitManager.addPerson("Person 2"); 
    // }
    
    print('DEBUG: SplitManager initialized with ${splitManager.unassignedItems.length} unassigned items.');
  }
  // --- END EDIT ---

  // Handles data from VoiceAssignmentScreen and updates SplitManager
  Future<void> _handleAssignmentProcessed(Map<String, dynamic> assignmentsData) async {
    print("DEBUG: Handling assignment data in main UI");
    setState(() { _isLoading = true; });

    try {
      final splitManager = context.read<SplitManager>();
      
      // Calculate the total from all items BEFORE reset
      final double originalReviewTotal = _editableItems.fold(
        0.0, 
        (sum, item) => sum + (item.price * item.quantity)
      );
      
      splitManager.reset(); // Clear previous state in manager
      
      // Save the original review total AFTER reset
      splitManager.setOriginalReviewTotal(originalReviewTotal);
      print('DEBUG (ReceiptSplitterUI): Stored original review total: $originalReviewTotal (from ${_editableItems.length} items) in assignment processing');

      // Add people
      final peopleData = List<Map<String, dynamic>>.from(assignmentsData['people'] ?? []);
      for (var personData in peopleData) {
        final personName = personData['name'] as String?; // Cast as nullable String
        if (personName != null && personName.isNotEmpty) {
          splitManager.addPerson(personName);
        } else {
          print("WARN: Skipping person with missing or empty name.");
        }
      }

      // Helper to find original item robustly
      ReceiptItem findOriginalItem(String name, double price) {
         // Check if _editableItems is empty before proceeding
         if (_editableItems.isEmpty) {
           throw Exception("Cannot find items because the editable items list is empty.");
         }
         return _editableItems.firstWhere(
           (item) => item.name == name && (item.price - price).abs() < 0.01,
           orElse: () {
              print("WARN: Item not found via name/price: Name='$name', Price='$price'. Trying name only.");
              // Find by name only as a fallback
              return _editableItems.firstWhere(
                (item) => item.name == name,
                orElse: () => throw Exception("Item '$name' not found in original list after checking name and price, and name only.")
              );
           }
         );
      }

      // Process assigned items ('orders')
      final orders = List<Map<String, dynamic>>.from(assignmentsData['orders'] ?? []);
      for (var order in orders) {
        final personName = order['person'] as String?; // Cast as nullable String
        final itemName = order['item'] as String?;     // Cast as nullable String
        final itemPrice = (order['price'] as num?)?.toDouble(); // Handle nullable num
        final itemQuantity = (order['quantity'] as num?)?.toInt(); // Handle nullable num and convert to int

        if (personName == null || personName.isEmpty) {
          print("WARN: Skipping order with missing or empty person name.");
          continue;
        }
        if (itemName == null || itemName.isEmpty) {
          print("WARN: Skipping order for person '$personName' with missing or empty item name.");
          continue;
        }
        if (itemPrice == null) {
          print("WARN: Skipping order for person '$personName', item '$itemName' due to missing price.");
          continue;
        }
        if (itemQuantity == null || itemQuantity <= 0) {
          print("WARN: Skipping order for person '$personName', item '$itemName' due to missing or invalid quantity.");
          continue;
        }

        final person = splitManager.people.firstWhere(
           (p) => p.name == personName,
           orElse: () {
             print("ERROR: Person '$personName' not found in SplitManager during assignment processing for item '$itemName'. Skipping order.");
             throw Exception("Person '$personName' not found for item '$itemName'");
           }
        );

        try {
          final originalItem = findOriginalItem(itemName, itemPrice);
          final assignedItem = ReceiptItem.clone(originalItem)..updateQuantity(itemQuantity);
          // Ensure original quantity exists before setting
          if (originalItem.originalQuantity > 0) {
             splitManager.setOriginalQuantity(assignedItem, originalItem.originalQuantity);
          } else {
             // Fallback: use current quantity if original wasn't set/parsed correctly
             splitManager.setOriginalQuantity(assignedItem, assignedItem.quantity);
             print("WARN: Original quantity for item '$itemName' was not set or zero. Using current quantity ${assignedItem.quantity}.");
          }
          splitManager.assignItemToPerson(assignedItem, person);
        } catch (e) {
           print("ERROR: Failed to process assigned item '$itemName' for person '$personName'. Error: $e. Skipping item.");
        }
      }

      // Process shared items
      final sharedItemsData = List<Map<String, dynamic>>.from(assignmentsData['shared_items'] ?? []);
      for (var itemData in sharedItemsData) {
         final itemName = itemData['item'] as String?;     // Cast as nullable String
         final itemPrice = (itemData['price'] as num?)?.toDouble(); // Handle nullable num
         final itemQuantity = (itemData['quantity'] as num?)?.toInt(); // Handle nullable int
         // Ensure list contains only non-null, non-empty strings
         final peopleNames = (itemData['people'] as List?)
             ?.map((p) => p as String?)
             .where((p) => p != null && p.isNotEmpty)
             .cast<String>()
             .toList() ?? [];

         if (itemName == null || itemName.isEmpty) {
           print("WARN: Skipping shared item with missing or empty item name.");
           continue;
         }
         if (itemPrice == null) {
           print("WARN: Skipping shared item '$itemName' due to missing price.");
           continue;
         }
         if (itemQuantity == null || itemQuantity <= 0) {
           print("WARN: Skipping shared item '$itemName' due to missing or invalid quantity.");
           continue;
         }
         if (peopleNames.isEmpty) {
            print("WARN: Shared item '$itemName' has no valid people listed or the 'people' list is missing/empty. Adding as unassigned.");
            // Attempt to add as unassigned only if we can find the original item
            try {
               final originalItem = findOriginalItem(itemName, itemPrice);
               final unassignedItem = ReceiptItem.clone(originalItem)..updateQuantity(itemQuantity);
               // Ensure original quantity exists before setting
               if (originalItem.originalQuantity > 0) {
                  splitManager.setOriginalQuantity(unassignedItem, originalItem.originalQuantity);
               } else {
                  splitManager.setOriginalQuantity(unassignedItem, unassignedItem.quantity);
                  print("WARN: Original quantity for unassigned item '$itemName' was not set or zero. Using current quantity ${unassignedItem.quantity}.");
               }
               splitManager.addUnassignedItem(unassignedItem);
            } catch (e) {
               print("ERROR: Failed to find original item for shared item '$itemName' listed with no people. Cannot add as unassigned. Error: $e. Skipping item.");
            }
            continue;
         }

         final peopleToShareWith = splitManager.people.where((p) => peopleNames.contains(p.name)).toList();

         if (peopleToShareWith.isEmpty) {
            print("WARN: Shared item '$itemName' - none of the listed people (${peopleNames.join(', ')}) exist in the SplitManager. Adding as unassigned.");
            try {
               final originalItem = findOriginalItem(itemName, itemPrice);
               final unassignedItem = ReceiptItem.clone(originalItem)..updateQuantity(itemQuantity);
               if (originalItem.originalQuantity > 0) {
                 splitManager.setOriginalQuantity(unassignedItem, originalItem.originalQuantity);
               } else {
                 splitManager.setOriginalQuantity(unassignedItem, unassignedItem.quantity);
                 print("WARN: Original quantity for unassigned item '$itemName' was not set or zero. Using current quantity ${unassignedItem.quantity}.");
               }
               splitManager.addUnassignedItem(unassignedItem);
            } catch (e) {
               print("ERROR: Failed to find original item for shared item '$itemName' with non-existent people. Cannot add as unassigned. Error: $e. Skipping item.");
            }
            continue;
         }

         try {
            final originalItem = findOriginalItem(itemName, itemPrice);
            final sharedItem = ReceiptItem.clone(originalItem)..updateQuantity(itemQuantity);
             if (originalItem.originalQuantity > 0) {
               splitManager.setOriginalQuantity(sharedItem, originalItem.originalQuantity);
             } else {
               splitManager.setOriginalQuantity(sharedItem, sharedItem.quantity);
               print("WARN: Original quantity for shared item '$itemName' was not set or zero. Using current quantity ${sharedItem.quantity}.");
             }
            splitManager.addItemToShared(sharedItem, peopleToShareWith);
         } catch (e) {
            print("ERROR: Failed to process shared item '$itemName'. Error: $e. Skipping item.");
         }
      }

      // Process unassigned items
      final unassignedItemsData = List<Map<String, dynamic>>.from(assignmentsData['unassigned_items'] ?? []);
      for (var itemData in unassignedItemsData) {
         final itemName = itemData['item'] as String?; // Cast as nullable String
         final itemPrice = (itemData['price'] as num?)?.toDouble(); // Handle nullable num
         final itemQuantity = (itemData['quantity'] as num?)?.toInt(); // Handle nullable int

         if (itemName == null || itemName.isEmpty) {
           print("WARN: Skipping unassigned item with missing or empty item name.");
           continue;
         }
         if (itemPrice == null) {
           print("WARN: Skipping unassigned item '$itemName' due to missing price.");
           continue;
         }
         if (itemQuantity == null || itemQuantity <= 0) {
           print("WARN: Skipping unassigned item '$itemName' due to missing or invalid quantity.");
           continue;
         }

         try {
            final originalItem = findOriginalItem(itemName, itemPrice);
            final unassignedItem = ReceiptItem.clone(originalItem)..updateQuantity(itemQuantity);
            if (originalItem.originalQuantity > 0) {
              splitManager.setOriginalQuantity(unassignedItem, originalItem.originalQuantity);
            } else {
              splitManager.setOriginalQuantity(unassignedItem, unassignedItem.quantity);
              print("WARN: Original quantity for unassigned item '$itemName' was not set or zero. Using current quantity ${unassignedItem.quantity}.");
            }
            splitManager.addUnassignedItem(unassignedItem);
         } catch (e) {
            print("ERROR: Failed to process unassigned item '$itemName'. Error: $e. Skipping item.");
         }
      }

      setState(() {
        _isAssignmentComplete = true;
        _isLoading = false;
        _assignments = assignmentsData; // Store raw results if needed
        // Don't clear _savedTranscription - we need to keep it for state persistence
      });
      _navigateToPage(3); // Navigate to Assignment Review (SplitView)

    } catch (e, stackTrace) { // Add stackTrace for more context
      print("Error processing assignments in SplitManager: $e");
      print("Stack trace: $stackTrace"); // Print stack trace
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying assignments: ${e.toString()}. Check logs for details.'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  // Update the back navigation handler to match the new PopScope pattern
  Future<void> _handleBackNavigation() async {
    if (_currentStep > 0) {
      _navigateToPage(_currentStep - 1);
      return; // Just return, no need for boolean with PopScope
    }
    
    // Save state before showing exit dialog so it's preserved if user returns later
    await _saveCurrentState();
    
    // Show dialog when attempting to exit the app
    final shouldExit = await _showExitConfirmationDialog();
    if (shouldExit == true) {
      // Only if user explicitly confirms exit
      SystemNavigator.pop(); // Properly exit the app
    }
  }

  // Exit confirmation dialog
  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Exit App?'),
          content: const Text('Are you sure you want to exit?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: Text(
                'Exit',
                style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    ) ?? false;  // Default to false if dialog is dismissed
  }

  // Clear saved preferences from persistent storage
  Future<void> _clearSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();  // Remove all saved state
      print('Saved state cleared successfully');
      
      // Reset SplitManager
      if (mounted) {
        context.read<SplitManager>().reset();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.onPrimary),
                const SizedBox(width: 12),
                const Text('Reset complete. Ready to start over!'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error clearing saved state: $e');
    }
  }
} 