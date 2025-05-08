import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
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
import 'package:image_picker/image_picker.dart';
import 'models/person.dart'; // Added import for Person
import 'screens/receipt_upload_screen.dart';
import 'screens/receipt_review_screen.dart';
import 'screens/voice_assignment_screen.dart';
import 'screens/assignment_review_screen.dart'; // SplitView is used here
import 'screens/final_summary_screen.dart';
import 'screens/login_screen.dart'; // Import login screen
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'services/audio_transcription_service.dart' hide Person;
import 'main.dart'; // Import MyApp from main.dart
import 'utils/toast_helper.dart'; // Import the toast helper

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

// Helper to force refresh the app state (emergency reset)
void forceRefreshApp(BuildContext context) async {
  try {
    // 1. Clear all SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Show a success toast before navigating
    ToastHelper.showToast(
      context,
      'App has been reset successfully',
      isSuccess: true
    );

    // Small delay to ensure the toast is visible before navigation
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Don't use Provider here - it will cause scope issues
    // Instead, directly navigate to reset the entire app
    
    // 3. Force navigation to the very root of the app - MyApp instead of FirebaseInit
    // This ensures we get a completely fresh start with proper provider setup
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MyApp()),
      (route) => false,
    );
  } catch (e) {
    // Show error notification
    ToastHelper.showToast(
      context,
      'Error during reset: $e',
      isError: true,
    );
  }
}

class ReceiptSplitterUI extends StatefulWidget {
  const ReceiptSplitterUI({super.key});

  @override
  State<ReceiptSplitterUI> createState() => _ReceiptSplitterUIState();
}

class _ReceiptSplitterUIState extends State<ReceiptSplitterUI> {
  // Keep track of listeners to prevent duplicates
  bool _hasSetupListeners = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // If the user is not logged in, show the login screen
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }
        
        // Set up success message listener once
        if (!_hasSetupListeners) {
          // NOTE: We don't need this anymore since we're showing toasts directly in the login screens
          // But we'll keep the structure in case we need to add other listeners in the future
          _hasSetupListeners = true;
        }
        
        // If logged in, show the main app
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                'logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Billfie',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Smarter bill splitting',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            actions: [
              // Reset button
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black54),
                onPressed: () {
                  // Show confirmation dialog before resetting
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Reset app?'),
                      content: const Text('This will clear all your data and start over. Are you sure?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            
                            try {
                              // 1. Try to find and reset the MainPageController directly
                              final mainPageState = context.findAncestorStateOfType<_MainPageControllerState>();
                              if (mainPageState != null) {
                                await mainPageState.resetApp();
                                
                                // Show success notification
                                ToastHelper.showToast(
                                  context, 
                                  'App has been reset successfully',
                                  isSuccess: true,
                                );
                                return; // If this worked, exit early
                              }
                              
                              // If we couldn't find the controller, use the emergency reset
                              forceRefreshApp(context);
                              
                            } catch (e) {
                              // Handle any errors that might occur during reset
                              ToastHelper.showToast(
                                context,
                                'Error during reset: ${e.toString()}',
                                isError: true,
                              );
                              
                              // Try emergency reset as last resort
                              try {
                                forceRefreshApp(context);
                              } catch (_) {
                                // If even that fails, show error
                                ToastHelper.showToast(
                                  context,
                                  'Reset failed. Please restart the app manually.',
                                  isError: true,
                                );
                              }
                            }
                          },
                          child: const Text('RESET'),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Reset app',
              ),
              // Logout button
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.black54),
                onPressed: () async {
                  // Show confirmation dialog before logging out
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Log Out?'),
                      content: const Text('Are you sure you want to log out of Billfie?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('CANCEL'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
                          child: const Text('LOG OUT'),
                        ),
                      ],
                    ),
                  ) ?? false;
                  
                  if (shouldLogout) {
                    try {
                      // Sign out without resetting app state
                      await FirebaseAuth.instance.signOut();
                      debugPrint('User signed out');
                      
                      // Show success toast after logout
                      if (context.mounted) {
                        ToastHelper.showToast(
                          context,
                          'You have successfully logged out',
                          isSuccess: true
                        );
                      }
                    } catch (e) {
                      debugPrint('Error signing out: $e');
                      if (context.mounted) {
                        ToastHelper.showToast(
                          context,
                          'Error signing out: $e',
                          isError: true
                        );
                      }
                    }
                  }
                },
                tooltip: 'Logout',
              ),
            ],
          ),
          body: const MainAppContent(),
        );
      },
    );
  }
}

// Separate widget for the main app content
class MainAppContent extends StatelessWidget {
  const MainAppContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap the MainPageController with MultiProvider to provide SplitManager
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SplitManager(),
        ),
      ],
      child: const MainPageController(),
    );
  }
}

// Main page controller to handle all screens with navigation
class MainPageController extends StatefulWidget {
  const MainPageController({Key? key}) : super(key: key);

  @override
  State<MainPageController> createState() => _MainPageControllerState();
}

class _MainPageControllerState extends State<MainPageController> with WidgetsBindingObserver {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  List<ReceiptItem> _receiptItems = [];
  
  // State management variables
  bool _isUploadComplete = false;
  bool _isReviewComplete = false;
  bool _isAssignmentComplete = false;
  String? _savedTranscription;
  File? _imageFile;
  Map<String, dynamic>? _assignments;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Register for lifecycle events
    _loadSavedState(); // Load saved state on startup
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

  // Method to reset the upload step status
  void resetUploadStepStatus() {
    setState(() {
      _isUploadComplete = false;
      _receiptItems = []; // Clear items as they are from the previous parse
      // Optionally, also reset subsequent steps if this flow is linear
      _isReviewComplete = false;
      _isAssignmentComplete = false;
      _savedTranscription = null; // Clear transcription related to old items
      _assignments = null; // Clear assignments related to old items
    });
    _saveCurrentState(); // Persist the reset state
    debugPrint('Upload step status reset.');
  }

  // Save the current state to persistent storage
  Future<void> _saveCurrentState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get current user ID for user-specific storage
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Cannot save state: No user logged in');
        return;
      }
      final userId = user.uid;
      
      // Save current step and completion flags with user-specific keys
      await prefs.setInt('${userId}_current_page', _currentPage);
      await prefs.setBool('${userId}_is_upload_complete', _isUploadComplete);
      await prefs.setBool('${userId}_is_review_complete', _isReviewComplete);
      await prefs.setBool('${userId}_is_assignment_complete', _isAssignmentComplete);
      
      // Save transcription if available
      if (_savedTranscription != null) {
        await prefs.setString('${userId}_saved_transcription', _savedTranscription!);
      }
      
      // Save image path if available
      if (_imageFile != null && _imageFile!.existsSync()) {
        await prefs.setString('${userId}_saved_image_path', _imageFile!.path);
      }
      
      // Save receipt items
      if (_receiptItems.isNotEmpty) {
        final itemsJson = jsonEncode(_receiptItems.map((item) => item.toJson()).toList());
        await prefs.setString('${userId}_receipt_items', itemsJson);
      }
      
      // Save assignments
      if (_assignments != null) {
        final assignmentsJson = jsonEncode(_assignments);
        await prefs.setString('${userId}_assignments', assignmentsJson);
      }
      
      debugPrint('App state saved successfully for user $userId with page: $_currentPage');
    } catch (e) {
      debugPrint('Error saving app state: $e');
    }
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get current user ID for user-specific storage
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Cannot load state: No user logged in');
        return;
      }
      final userId = user.uid;
      
      // Check if we have saved state for this user
      if (!prefs.containsKey('${userId}_current_page')) {
        debugPrint('No saved state found for user $userId');
        return;
      }
      
      setState(() {
        // Restore workflow state
        _currentPage = prefs.getInt('${userId}_current_page') ?? 0;
        _isUploadComplete = prefs.getBool('${userId}_is_upload_complete') ?? false;
        _isReviewComplete = prefs.getBool('${userId}_is_review_complete') ?? false;
        _isAssignmentComplete = prefs.getBool('${userId}_is_assignment_complete') ?? false;
        
        // Restore transcription
        _savedTranscription = prefs.getString('${userId}_saved_transcription');
        
        // Restore image if available
        final imagePath = prefs.getString('${userId}_saved_image_path');
        if (imagePath != null) {
          final imageFile = File(imagePath);
          
          // Verify the file exists and is valid
          if (imageFile.existsSync() && imageFile.lengthSync() > 0) {
            try {
              // Additional check to ensure the file is readable
              imageFile.readAsBytesSync();
              _imageFile = imageFile;
              debugPrint('Successfully restored image from: $imagePath');
            } catch (e) {
              debugPrint('Error reading restored image file: $e');
              prefs.remove('${userId}_saved_image_path');
            }
          } else {
            // File doesn't exist or is invalid - remove the reference
            debugPrint('Image file is invalid: $imagePath');
            prefs.remove('${userId}_saved_image_path');
          }
        }
        
        // Restore receipt items
        final itemsJson = prefs.getString('${userId}_receipt_items');
        if (itemsJson != null) {
          final List<dynamic> itemsList = jsonDecode(itemsJson);
          _receiptItems = itemsList.map((item) => ReceiptItem.fromJson(item)).toList();
        }
        
        // Restore assignments
        final assignmentsJson = prefs.getString('${userId}_assignments');
        if (assignmentsJson != null) {
          _assignments = jsonDecode(assignmentsJson);
        }
      });
      
      // If we have a saved state, initialize the page controller to that page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
        
        // If we've restored state to the split view page, ensure SplitManager is initialized
        if (_currentPage == 3 && _isAssignmentComplete && _assignments != null && _receiptItems.isNotEmpty) {
          debugPrint('Restoring split view from saved state for user $userId');
          
          // Get the SplitManager
          final splitManager = context.read<SplitManager>();
          
          // Clean reset of the manager
          splitManager.reset();
          
          // Set original review total for validation
          final originalTotal = _receiptItems.fold(
            0.0, 
            (sum, item) => sum + (item.price * item.quantity)
          );
          splitManager.setOriginalReviewTotal(originalTotal);
          debugPrint('Setting original review total to: $originalTotal from saved state');
          
          // Process saved assignments
          final Map<String, dynamic> assignments = _assignments!['assignments'] as Map<String, dynamic>;
          final List<dynamic> sharedItems = _assignments!['shared_items'] as List<dynamic>;
          final List<dynamic> unassignedItems = _assignments!['unassigned_items'] as List<dynamic>? ?? [];
          
          // Process people and assignments
          assignments.forEach((name, items) {
            // Add the person if they don't exist
            if (!splitManager.people.any((p) => p.name == name)) {
              splitManager.addPerson(name);
            }
            
            // Find the person object
            final person = splitManager.people.firstWhere((p) => p.name == name);
            
            // Assign items to the person
            final List<dynamic> personItems = items as List<dynamic>;
            for (var itemData in personItems) {
              final int itemId = itemData['id'];
              final int quantity = itemData['quantity'];
              
              // Find the receipt item with this ID (subtract 1 as IDs are 1-based)
              if (itemId > 0 && itemId <= _receiptItems.length) {
                final receiptItem = _receiptItems[itemId - 1];
                
                // Create a copy of the item with the right quantity
                final itemToAssign = receiptItem.copyWithQuantity(quantity);
                
                // Assign to the person
                splitManager.assignItemToPerson(itemToAssign, person);
              }
            }
          });
          
          // Process shared items
          for (var itemData in sharedItems) {
            final int itemId = itemData['id'];
            final int quantity = itemData['quantity'];
            
            // Find the receipt item with this ID (subtract 1 as IDs are 1-based)
            if (itemId > 0 && itemId <= _receiptItems.length) {
              final receiptItem = _receiptItems[itemId - 1];
              
              // Create a copy with the right quantity
              final itemToShare = receiptItem.copyWithQuantity(quantity);
              
              // Add to shared for all people
              splitManager.addItemToShared(itemToShare, splitManager.people);
            }
          }
          
          // Process unassigned items
          if (unassignedItems.isNotEmpty) {
            for (var itemData in unassignedItems) {
              final int itemId = itemData['id'];
              final int quantity = itemData['quantity'];
              
              // Find the receipt item with this ID (subtract 1 as IDs are 1-based)
              if (itemId > 0 && itemId <= _receiptItems.length) {
                final receiptItem = _receiptItems[itemId - 1];
                
                // Create a copy with the right quantity
                final itemToKeepUnassigned = receiptItem.copyWithQuantity(quantity);
                
                // Keep in unassigned
                splitManager.addUnassignedItem(itemToKeepUnassigned);
              }
            }
          }
          
          // Debug - verify total after initialization
          debugPrint('Split view restored with total: ${splitManager.totalAmount}');
        }
      });
      
      debugPrint('App state restored successfully for user $userId to page: $_currentPage');
    } catch (e) {
      debugPrint('Error loading saved state: $e');
    }
  }
  
  // Method to update the image file from child widgets
  void updateImageFile(File file) {
    setState(() {
      _imageFile = file;
    });
    _saveCurrentState(); // Save state when image changes
  }

  void _navigateToPage(int page) {
    // Save current state before navigating
    _saveCurrentState();
    
    // Only initialize SplitManager when going from the assignment screen (page 2) 
    // to the split view (page 3) with completed assignments
    if (page == 3 && _currentPage == 2 && _isAssignmentComplete && _assignments != null) {
      debugPrint('Initializing SplitManager with assignments from audio service');
      
      // Get the SplitManager and reset it
      final splitManager = context.read<SplitManager>();
      
      // First save the original total for comparison
      final originalTotal = _receiptItems.fold(
        0.0, 
        (sum, item) => sum + (item.price * item.quantity)
      );
      
      // Clean reset of the manager
      splitManager.reset();
      
      // Set original review total for validation
      splitManager.setOriginalReviewTotal(originalTotal);
      debugPrint('Setting original review total to: $originalTotal');
      
      // Process assignments that came from the AI service
      final Map<String, dynamic> assignments = _assignments!['assignments'] as Map<String, dynamic>;
      final List<dynamic> sharedItems = _assignments!['shared_items'] as List<dynamic>;
      final List<dynamic> unassignedItems = _assignments!['unassigned_items'] as List<dynamic>? ?? [];
      
      debugPrint('Processing assignments: ${assignments.keys.length} people, ${sharedItems.length} shared items');
      
      // 1. Create people from assignments
      assignments.forEach((name, items) {
        // Add the person if they don't exist
        if (!splitManager.people.any((p) => p.name == name)) {
          splitManager.addPerson(name);
        }
        
        // Find the person object
        final person = splitManager.people.firstWhere((p) => p.name == name);
        
        // Assign items to the person
        final List<dynamic> personItems = items as List<dynamic>;
        for (var itemData in personItems) {
          final int itemId = itemData['id'];
          final int quantity = itemData['quantity'];
          
          // Find the receipt item with this ID (subtract 1 as IDs are 1-based)
          if (itemId > 0 && itemId <= _receiptItems.length) {
            final receiptItem = _receiptItems[itemId - 1];
            
            // Create a copy of the item with the right quantity
            final itemToAssign = receiptItem.copyWithQuantity(quantity);
            
            // Assign to the person
            splitManager.assignItemToPerson(itemToAssign, person);
          }
        }
      });
      
      // 2. Process shared items
      for (var itemData in sharedItems) {
        final int itemId = itemData['id'];
        final int quantity = itemData['quantity'];
        
        // Find the receipt item with this ID (subtract 1 as IDs are 1-based)
        if (itemId > 0 && itemId <= _receiptItems.length) {
          final receiptItem = _receiptItems[itemId - 1];
          
          // Create a copy with the right quantity
          final itemToShare = receiptItem.copyWithQuantity(quantity);
          
          // Add to shared for all people
          splitManager.addItemToShared(itemToShare, splitManager.people);
        }
      }
      
      // 3. Process unassigned items (if any)
      if (unassignedItems.isNotEmpty) {
        for (var itemData in unassignedItems) {
          final int itemId = itemData['id'];
          final int quantity = itemData['quantity'];
          
          // Find the receipt item with this ID (subtract 1 as IDs are 1-based)
          if (itemId > 0 && itemId <= _receiptItems.length) {
            final receiptItem = _receiptItems[itemId - 1];
            
            // Create a copy with the right quantity
            final itemToKeepUnassigned = receiptItem.copyWithQuantity(quantity);
            
            // Keep in unassigned
            splitManager.addUnassignedItem(itemToKeepUnassigned);
          }
        }
      }
      
      // Debug - verify total after initialization
      debugPrint('Split view initialized with total: ${splitManager.totalAmount}');
    }
    
    // If we are navigating to split view (3) or summary (4), ensure we save current state 
    // immediately after navigation to have the latest for hot reload
    final needsImmediateSave = (page == 3 || page == 4);
    
    setState(() {
      _currentPage = page;
    });
    
    // Animate to the target page
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    
    // Save state again after navigation if needed
    if (needsImmediateSave) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveCurrentState();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add post-frame callback to ensure SplitManager is initialized after hot reload
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If we're already on the split view or summary view, restore the state
      if ((_currentPage == 3 || _currentPage == 4) && 
          _isAssignmentComplete && 
          _assignments != null && 
          _receiptItems.isNotEmpty) {
        debugPrint('Post-build: Ensuring split view state is initialized');
        
        // Get the SplitManager
        final splitManager = context.read<SplitManager>();
        
        // Only initialize if the manager doesn't have any data already
        if (splitManager.people.isEmpty && splitManager.unassignedItems.isEmpty) {
          debugPrint('SplitManager is empty, restoring from saved state');
          
          // Set original review total for validation
          final originalTotal = _receiptItems.fold(
            0.0, 
            (sum, item) => sum + (item.price * item.quantity)
          );
          splitManager.setOriginalReviewTotal(originalTotal);
          
          // Process saved assignments
          final Map<String, dynamic> assignments = _assignments!['assignments'] as Map<String, dynamic>;
          final List<dynamic> sharedItems = _assignments!['shared_items'] as List<dynamic>;
          final List<dynamic> unassignedItems = _assignments!['unassigned_items'] as List<dynamic>? ?? [];
          
          // Process people and assignments
          assignments.forEach((name, items) {
            // Add the person if they don't exist
            if (!splitManager.people.any((p) => p.name == name)) {
              splitManager.addPerson(name);
            }
            
            // Find the person object
            final person = splitManager.people.firstWhere((p) => p.name == name);
            
            // Assign items to the person
            final List<dynamic> personItems = items as List<dynamic>;
            for (var itemData in personItems) {
              final int itemId = itemData['id'];
              final int quantity = itemData['quantity'];
              
              // Find the receipt item with this ID (subtract 1 as IDs are 1-based)
              if (itemId > 0 && itemId <= _receiptItems.length) {
                final receiptItem = _receiptItems[itemId - 1];
                
                // Create a copy of the item with the right quantity
                final itemToAssign = receiptItem.copyWithQuantity(quantity);
                
                // Assign to the person
                splitManager.assignItemToPerson(itemToAssign, person);
              }
            }
          });
          
          // Process shared items
          for (var itemData in sharedItems) {
            final int itemId = itemData['id'];
            final int quantity = itemData['quantity'];
            
            // Find the receipt item with this ID (subtract 1 as IDs are 1-based)
            if (itemId > 0 && itemId <= _receiptItems.length) {
              final receiptItem = _receiptItems[itemId - 1];
              
              // Create a copy with the right quantity
              final itemToShare = receiptItem.copyWithQuantity(quantity);
              
              // Add to shared for all people
              splitManager.addItemToShared(itemToShare, splitManager.people);
            }
          }
          
          // Process unassigned items
          if (unassignedItems.isNotEmpty) {
            for (var itemData in unassignedItems) {
              final int itemId = itemData['id'];
              final int quantity = itemData['quantity'];
              
              // Find the receipt item with this ID (subtract 1 as IDs are 1-based)
              if (itemId > 0 && itemId <= _receiptItems.length) {
                final receiptItem = _receiptItems[itemId - 1];
                
                // Create a copy with the right quantity
                final itemToKeepUnassigned = receiptItem.copyWithQuantity(quantity);
                
                // Keep in unassigned
                splitManager.addUnassignedItem(itemToKeepUnassigned);
              }
            }
          }
        }
      }
    });

    return PopScope(
      canPop: false, // Prevent automatically popping
      onPopInvoked: (didPop) async {
        // didPop will be false since we set canPop to false
        if (!didPop) {
          // Handle back navigation - save state and go back if possible
          if (_currentPage > 0) {
            _navigateToPage(_currentPage - 1);
          } else {
            // We're at the first screen, show exit confirmation
            final shouldExit = await _showExitConfirmationDialog();
            if (shouldExit == true) {
              // Only exit if user confirms
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: NotificationListener<NavigateToPageNotification>(
        onNotification: (notification) {
          _navigateToPage(notification.pageIndex);
          return true;
        },
        child: Scaffold(
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              _saveCurrentState(); // Save state on page change
            },
            children: [
              // Page 0: Receipt Upload
              ReceiptScreenWrapper(
                onReviewComplete: (items) {
                  setState(() {
                    _receiptItems = items;
                    _isUploadComplete = true; // Mark upload as complete regardless of current state
                  });
                  _saveCurrentState(); // Save state after upload
                  _navigateToPage(1); // Navigate to receipt review
                },
                initialImage: _imageFile, // Pass saved image if available
                uploadComplete: _isUploadComplete, // Pass upload completion status
                // If upload is already complete, make the "Use This" button visible immediately
              ),
              
              // Page 1: Receipt Review
              ReceiptReviewScreen(
                initialItems: _isUploadComplete ? _receiptItems : [], // Use empty list if upload not complete
                onReviewComplete: (updatedItems, deletedItems) {
                  // Save updated items to SplitManager
                  setState(() {
                    _receiptItems = updatedItems;
                    _isReviewComplete = true;
                  });
                  
                  final splitManager = Provider.of<SplitManager>(context, listen: false);
                  splitManager.setReceiptItems(updatedItems);
                  
                  _saveCurrentState(); // Save state after review
                  // Navigate to the next page (Voice Assignment)
                  _navigateToPage(2);
                },
                onItemsUpdated: (currentItems) {
                  // Update items whenever they change (add, edit, delete)
                  setState(() {
                    _receiptItems = currentItems;
                  });
                  _saveCurrentState(); // Save state when items change
                },
              ),
              
              // Page 2: Voice Assignment
              VoiceAssignmentScreen(
                itemsToAssign: _isReviewComplete ? _receiptItems : [], // Use empty list if review not complete
                initialTranscription: _savedTranscription, // Pass saved transcription
                onTranscriptionChanged: (transcription) {
                  // Save transcription when it changes
                  setState(() {
                    _savedTranscription = transcription;
                  });
                  _saveCurrentState(); // Save state when transcription changes
                },
                onAssignmentProcessed: (assignmentData) {
                  // Store the assignment data but don't apply it yet
                  // It will be applied only once when navigating to the split view
                  setState(() {
                    _assignments = assignmentData;
                    _isAssignmentComplete = true;
                  });
                  
                  debugPrint('Received assignment data from AI service, storing for split view');
                  
                  // Save state before navigating
                  _saveCurrentState();
                  
                  // Navigate to the split view (page 3)
                  // The actual assignment application will happen in _navigateToPage
                  _navigateToPage(3);
                },
              ),
              
              // Page 3: Assignment Review (Split View)
              const AssignmentReviewScreen(),
              
              // Page 4: Final Summary
              const FinalSummaryScreen(),
            ],
          ),
          bottomNavigationBar: _buildBottomNavBar(),
        ),
      ),
    );
  }
  
  Widget _buildBottomNavBar() {
    // Get the furthest reached page based on completion flags
    int furthestAllowedPage = 0; // Start with upload screen
    
    if (_isAssignmentComplete) {
      furthestAllowedPage = 4; // Can navigate all the way to summary
    } else if (_isReviewComplete) {
      furthestAllowedPage = 2; // Can navigate up to assign
    } else if (_isUploadComplete) {
      furthestAllowedPage = 1; // Can navigate up to review
    }
    
    return BottomNavigationBar(
      currentIndex: _currentPage >= 4 ? 4 : _currentPage,
      onTap: (index) {
        // Calculate the actual page index
        // Bottom nav indices are offset from page indices: 
        // nav index 0 = page 0, nav index 1 = page 1, etc.
        final targetPage = index == 0 ? 0 : index;
        
        // Allow navigation if target is within allowed range
        if (targetPage <= furthestAllowedPage) {
          _navigateToPage(targetPage);
        } else {
          // Show toast notification at the top
          ToastHelper.showToast(
            context,
            'Please complete the previous steps first',
            isError: true
          );
        }
      },
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.upload_file),
          label: 'Upload',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.receipt_long, 
            color: furthestAllowedPage >= 1 ? null : Colors.grey,
          ),
          label: 'Review',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.record_voice_over,
            color: furthestAllowedPage >= 2 ? null : Colors.grey,
          ),
          label: 'Assign',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.people,
            color: furthestAllowedPage >= 3 ? null : Colors.grey,
          ),
          label: 'Split',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            Icons.summarize,
            color: furthestAllowedPage >= 4 ? null : Colors.grey,
          ),
          label: 'Summary',
        ),
      ],
    );
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Exit Confirmation'),
          content: Text('Are you sure you want to exit? Your progress will not be saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Exit'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Explicit reset method for the MainPageController
  Future<void> resetApp({bool showToast = true}) async {
    // Reset all state variables
    setState(() {
      _imageFile = null;
      _receiptItems = [];
      _savedTranscription = null;
      _assignments = null;
      _isUploadComplete = false;
      _isReviewComplete = false;
      _isAssignmentComplete = false;
      _currentPage = 0;
    });
    
    // Clear all saved state
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Error clearing preferences: $e');
    }
    
    // Navigate to upload screen immediately
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    
    // Show success toast if requested
    if (mounted && showToast) {
      ToastHelper.showToast(
        context,
        'App has been reset successfully',
        isSuccess: true
      );
    }
  }
}

// Wrapper class for ReceiptUploadScreen to manage state
class ReceiptScreenWrapper extends StatefulWidget {
  final Function(List<ReceiptItem>)? onReviewComplete;
  final File? initialImage;
  final bool uploadComplete;

  const ReceiptScreenWrapper({
    super.key, 
    this.onReviewComplete, 
    this.initialImage,
    this.uploadComplete = false,
  });

  @override
  State<ReceiptScreenWrapper> createState() => _ReceiptScreenWrapperState();
}

class _ReceiptScreenWrapperState extends State<ReceiptScreenWrapper> {
  late File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with provided image if available
    _imageFile = widget.initialImage;
  }

  void _handleImageSelected(File? file) {
    setState(() {
      _imageFile = file;
    });
    
    // Also update the global state through the parent widget
    if (file != null) {
      // Get access to the parent StatefulWidget (_MainPageControllerState)
      final mainPage = context.findAncestorStateOfType<_MainPageControllerState>();
      if (mainPage != null) {
        mainPage.updateImageFile(file);
        // If a new image is selected, the previous upload/parse is no longer valid for completion status
        if (mainPage._isUploadComplete) {
          mainPage.resetUploadStepStatus(); 
        }
      }
    }
  }

  void _handleParseReceipt() async {
    if (_imageFile == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Actually parse the receipt using ReceiptParserService
      final receiptData = await ReceiptParserService.parseReceipt(_imageFile!);
      
      if (!mounted) return;
      
      // Get the receipt items and pass them to parent
      final items = receiptData.getReceiptItems();
      
      ToastHelper.showToast(
        context,
        'Receipt processed successfully!',
        isSuccess: true,
      );
      
      // If onReviewComplete is provided, call it with the parsed items
      if (widget.onReviewComplete != null) {
        widget.onReviewComplete!(items);
      }
      
    } catch (e) {
      if (!mounted) return;
      
      ToastHelper.showToast(
        context,
        'Error processing receipt: ${e.toString()}',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleRetry() {
    setState(() {
      _imageFile = null;
    });
    // Notify parent to reset upload step status if it was considered complete
    final mainPage = context.findAncestorStateOfType<_MainPageControllerState>();
    if (mainPage != null && mainPage._isUploadComplete) {
       mainPage.resetUploadStepStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we already have an image and upload is complete, show parse button automatically
    final showParseButton = _imageFile != null && widget.uploadComplete;
    
    return ReceiptUploadScreen(
      imageFile: _imageFile,
      isLoading: _isLoading,
      isSuccessfullyParsed: widget.uploadComplete, // Pass widget.uploadComplete here
      onImageSelected: _handleImageSelected,
      onParseReceipt: _handleParseReceipt,
      onRetry: _handleRetry,
    );
  }
}

// Helper method in _MainPageControllerState to reset upload status
// void resetUploadStepStatus() {
//   setState(() {
//     _isUploadComplete = false;
//     _receiptItems = []; // Clear items as well, as they are from the previous parse
//   });
// } 