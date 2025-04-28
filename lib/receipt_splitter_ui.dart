import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/receipt_parser_service.dart';
import 'services/mock_data_service.dart';
import 'widgets/split_view.dart';
import 'package:provider/provider.dart';
import 'models/split_manager.dart';
import 'models/receipt_item.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';  // Added import for AppColors
import 'package:flutter/services.dart';  // Add this import for clipboard
import 'package:url_launcher/url_launcher.dart'; // Add this import for launching URLs

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

class _ReceiptSplitterUIState extends State<ReceiptSplitterUI> {
  // State variables for the main coordinator
  int _currentStep = 0;
  final PageController _pageController = PageController();
  File? _imageFile; // Needed for parsing
  bool _isLoading = false; // Overall loading state
  Map<String, dynamic>? _assignments; // Raw assignment results (optional to keep)
  List<ReceiptItem> _editableItems = []; // Holds items between parsing and review

  // Step completion tracking (kept in coordinator)
  bool _isUploadComplete = false;
  bool _isReviewComplete = false;
  bool _isAssignmentComplete = false;

  @override
  void initState() {
    super.initState();

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
    _pageController.dispose();
    super.dispose();
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
          _navigateToPage(2);
        },
      ),
      VoiceAssignmentScreen(
        key: ValueKey('VoiceScreen_${_editableItems.hashCode}'),
        itemsToAssign: _editableItems,
        onAssignmentProcessed: _handleAssignmentProcessed,
      ),
      const AssignmentReviewScreen(),
      const FinalSummaryScreen(), // Use the new screen widget
    ];

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
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
          // IconButton for reset (conditionally shown or handled differently)
          // Consider adding a reset button/option within specific screens or keeping it here.
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
      _currentStep = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _imageFile = null;
      _isLoading = false;
      _assignments = null;
      _editableItems = []; // Reset coordinator's item list
      _isUploadComplete = false;
      _isReviewComplete = false;
      _isAssignmentComplete = false;

      // Reset SplitManager
      if (mounted) {
         context.read<SplitManager>().reset();
      }
    });

    // Re-initialize mock data if needed, based on the initial logic
    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
    if (useMockData) {
       setState(() {
          _editableItems = [
            ...List.from(MockDataService.mockItems),
            ...List.from(MockDataService.mockSharedItems),
            ...List.from(MockDataService.mockUnassignedItems),
          ];
          _editableItems = _editableItems.toSet().toList();
       });
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
           backgroundColor: Theme.of(context).colorScheme.primary, // Use theme color
           behavior: SnackBarBehavior.floating,
           duration: const Duration(seconds: 2),
         ),
       );
     }
  }

  Future<void> _parseReceipt() async {
    if (_imageFile == null) return;
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
        _editableItems = (result['items'] as List).map((item) {
          final name = item['item'] as String;
          final price = item['price']?.toDouble() ?? 0.0; // Handle potential null price
          final quantity = item['quantity'] as int? ?? 1; // Handle potential null quantity

          return ReceiptItem(
            name: name,
            price: price,
            quantity: quantity,
          );
        }).toList();
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

  void _navigateToPage(int page) {
    if (_pageController.hasClients && _canNavigateToStep(page)) {
      // Only update _currentStep if navigation is successful/allowed
      setState(() {
         _currentStep = page;
      });
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Handles data from VoiceAssignmentScreen and updates SplitManager
  void _handleAssignmentProcessed(Map<String, dynamic> assignmentsData) {
    print("DEBUG: Handling assignment data in main UI");
    setState(() { _isLoading = true; });

    try {
      final splitManager = context.read<SplitManager>();
      splitManager.reset(); // Clear previous state in manager

      // Add people
      final peopleData = List<Map<String, dynamic>>.from(assignmentsData['people'] ?? []);
      for (var personData in peopleData) {
        splitManager.addPerson(personData['name'] as String);
      }

      // Helper to find original item robustly
      ReceiptItem findOriginalItem(String name, double price) {
         return _editableItems.firstWhere(
           (item) => item.name == name && (item.price - price).abs() < 0.01,
           orElse: () {
              print("WARN: Item not found via name/price: Name='$name', Price='$price'. Trying name only.");
              return _editableItems.firstWhere(
                (item) => item.name == name,
                orElse: () => throw Exception("Item '$name' not found in original list.")
              );
           }
         );
      }

      // Process assigned items ('orders')
      final orders = List<Map<String, dynamic>>.from(assignmentsData['orders'] ?? []);
      for (var order in orders) {
        final personName = order['person'] as String;
        final person = splitManager.people.firstWhere(
           (p) => p.name == personName,
           orElse: () => throw Exception("Person '$personName' not found during assignment processing")
        );

        final itemName = order['item'] as String;
        final itemPrice = (order['price'] as num).toDouble();
        final itemQuantity = order['quantity'] as int;

        final originalItem = findOriginalItem(itemName, itemPrice);
        final assignedItem = ReceiptItem.clone(originalItem)..updateQuantity(itemQuantity);
        splitManager.setOriginalQuantity(assignedItem, originalItem.originalQuantity);
        splitManager.assignItemToPerson(assignedItem, person);
      }

      // Process shared items
      final sharedItemsData = List<Map<String, dynamic>>.from(assignmentsData['shared_items'] ?? []);
      for (var itemData in sharedItemsData) {
         final itemName = itemData['item'] as String;
         final itemPrice = (itemData['price'] as num).toDouble();
         final itemQuantity = itemData['quantity'] as int;
         final peopleNames = List<String>.from(itemData['people'] ?? []);

         final originalItem = findOriginalItem(itemName, itemPrice);
         final sharedItem = ReceiptItem.clone(originalItem)..updateQuantity(itemQuantity);
         final peopleToShareWith = splitManager.people.where((p) => peopleNames.contains(p.name)).toList();
         if (peopleToShareWith.isEmpty) {
            print("WARN: Shared item '$itemName' has no valid people to share with listed.");
            // Decide: add as unassigned or ignore?
            splitManager.addUnassignedItem(sharedItem);
            continue;
         }
         splitManager.setOriginalQuantity(sharedItem, originalItem.originalQuantity);
         splitManager.addItemToShared(sharedItem, peopleToShareWith);
      }

      // Process unassigned items
      final unassignedItemsData = List<Map<String, dynamic>>.from(assignmentsData['unassigned_items'] ?? []);
      for (var itemData in unassignedItemsData) {
         final itemName = itemData['item'] as String;
         final itemPrice = (itemData['price'] as num).toDouble();
         final itemQuantity = itemData['quantity'] as int;

         final originalItem = findOriginalItem(itemName, itemPrice);
         final unassignedItem = ReceiptItem.clone(originalItem)..updateQuantity(itemQuantity);
         splitManager.setOriginalQuantity(unassignedItem, originalItem.originalQuantity);
         splitManager.addUnassignedItem(unassignedItem);
      }

      setState(() {
        _isAssignmentComplete = true;
        _isLoading = false;
        _assignments = assignmentsData; // Store raw results if needed
      });
      _navigateToPage(3); // Navigate to Assignment Review (SplitView)

    } catch (e) {
      print("Error processing assignments in SplitManager: $e");
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying assignments: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }
} 