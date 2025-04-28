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
  // Default values
  static const double DEFAULT_TAX_RATE = 8.875; // Default NYC tax rate

  // State variables
  int _currentStep = 0;
  final PageController _pageController = PageController();
  double _tipPercentage = 20.0;
  double _taxPercentage = DEFAULT_TAX_RATE; // Mutable tax rate
  File? _imageFile; // Keep _imageFile here as it's needed by _parseReceipt
  bool _isLoading = false; // This now represents overall loading, including parsing
  Map<String, dynamic>? _assignments;

  // Keep _editableItems here, as it holds the result from parsing/mock
  // and is passed to the review screen. Initialize it.
  List<ReceiptItem> _editableItems = [];

  // Step completion tracking
  bool _isUploadComplete = false;
  bool _isReviewComplete = false;
  bool _isAssignmentComplete = false;

  // Controllers
  late TextEditingController _taxController;

  @override
  void initState() {
    super.initState();
    
    // Check if we should use mock data
    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
    
    if (useMockData) {
      // Initialize _editableItems directly for mock data case
      _editableItems = [
        ...List.from(MockDataService.mockItems),
        ...List.from(MockDataService.mockSharedItems),
        ...List.from(MockDataService.mockUnassignedItems),
      ];
      
      // Remove duplicates (since unassigned items may be references to mockItems)
      _editableItems = _editableItems.toSet().toList();
      
      _currentStep = 0;
      
      // Initialize completion flags as false
      _isUploadComplete = false;
      _isReviewComplete = false;
      _isAssignmentComplete = false;
    } else {
      _editableItems = [];
    }
    
    _taxController = TextEditingController(text: DEFAULT_TAX_RATE.toStringAsFixed(3));

    // Add listener for tax changes
    _taxController.addListener(() {
      final newTax = double.tryParse(_taxController.text);
      if (newTax != null && _taxController.text.isNotEmpty) {
        setState(() {
          _taxPercentage = newTax;
        });
      }
    });
  }

  @override
  void dispose() {
    _taxController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<Widget> pages = [
      ReceiptUploadScreen( // Use the new screen
        imageFile: _imageFile,
        isLoading: _isLoading,
        onImageSelected: (file) {
          setState(() {
            _imageFile = file;
            _isLoading = false; // Reset loading state if selecting a new image
          });
        },
        onParseReceipt: _parseReceipt, // Pass the parsing function
        onRetry: () { // Pass the retry function
          setState(() {
            _imageFile = null;
            _isLoading = false; // Reset loading state on retry
          });
        },
      ),
      ReceiptReviewScreen( // Use the new screen
        key: ValueKey('ReviewScreen_${_editableItems.hashCode}'), // Use a key if needed for state reset
        initialItems: _editableItems, // Pass the parsed/mock items
        onReviewComplete: (updatedItems, deletedItems) {
          print('DEBUG: Review Complete. Updated: ${updatedItems.length}, Deleted: ${deletedItems.length}');
          // Update the main state with the results from the review screen
          setState(() {
            _editableItems = updatedItems;
            // We might need the deleted items later, but store them for now.
            // _deletedItems = deletedItems; // If you need to access deleted items later
            _isReviewComplete = true;
          });
          _navigateToPage(2); // Navigate to the next step
        },
      ),
      VoiceAssignmentScreen( // Use the new screen
        key: ValueKey('VoiceScreen_${_editableItems.hashCode}'),
        itemsToAssign: _editableItems, // Pass reviewed items
        onAssignmentProcessed: _handleAssignmentProcessed, // Pass callback
      ),
      _buildAssignmentReviewStep(context),
      _buildFinalSummaryStep(context),
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
          // REMOVE restart button for now
          // IconButton(
          //   onPressed: () => _showStartOverConfirmationDialog(),
          //   icon: Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.primary), // Explicitly set color
          //   tooltip: 'Start Over',
          // ),
        ],
      ),
      body: NotificationListener<NavigateToPageNotification>(
        onNotification: (notification) {
          _navigateToPage(notification.pageIndex);
          return true; // Stop notification from propagating further
        },
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              _currentStep = index;
            });
          },
          children: pages.map((page) {
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
    // In mock mode, we still need to follow the step order
    switch (step) {
      case 0: // Upload
        return true; // Always allow going back to upload
      case 1: // Review
        return _isUploadComplete;
      case 2: // Assign
        return _isReviewComplete;
      case 3: // Split
        return _isAssignmentComplete;
      case 4: // Summary
        return _isAssignmentComplete;
      default:
        return false;
    }
  }

  void _resetState() {
    // Dispose existing controllers first if they exist
    // No controllers to dispose here anymore that belong to ReceiptSplitterUI state itself
    // related to items.

    setState(() {
      // Reset step and navigation
      _currentStep = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      // Reset image and recording state
      _imageFile = null;
      _isLoading = false;
      _assignments = null;

      // Reset calculations
      _tipPercentage = 20.0;
      _taxPercentage = DEFAULT_TAX_RATE;
      _taxController.text = DEFAULT_TAX_RATE.toStringAsFixed(3);

      // Reset items state handled by ReceiptSplitterUI
      _editableItems = [];

      // Reset completion flags
      _isUploadComplete = false;
      _isReviewComplete = false;
      _isAssignmentComplete = false;

      // Reset SplitManager state
      if (mounted) { // Check if mounted before accessing context
         final splitManager = context.read<SplitManager>();
         splitManager.reset();
      }
    });

    // Show confirmation snackbar
    if (mounted) { // Check if mounted before accessing ScaffoldMessenger
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Row(
             children: [
               Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.onPrimary),
               const SizedBox(width: 12),
               const Text('Reset complete. Ready to start over!'),
             ],
           ),
           behavior: SnackBarBehavior.floating,
           duration: const Duration(seconds: 2),
         ),
       );
     }
  }

  Future<void> _parseReceipt() async {
    if (_imageFile == null) return;

    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
    print('DEBUG: In _parseReceipt, useMockData = $useMockData');

    // Set loading state HERE, inside the main UI state
    setState(() {
      _isLoading = true;
    });

    if (useMockData) {
      print('DEBUG: Using mock data in _parseReceipt');
      // Simulate network delay for mock data
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _editableItems = [
          ...List.from(MockDataService.mockItems),
          ...List.from(MockDataService.mockSharedItems),
          ...List.from(MockDataService.mockUnassignedItems),
        ];
        _editableItems = _editableItems.toSet().toList();

        _isUploadComplete = true;
        _isLoading = false; // Clear loading state
        _navigateToPage(1);
      });
      return;
    }

    print('DEBUG: Making API call in _parseReceipt');
    try {
      final result = await ReceiptParserService.parseReceipt(_imageFile!);

      setState(() {
        _editableItems = (result['items'] as List).map((item) {
          final name = item['item'] as String;
          final price = item['price'].toDouble();
          final quantity = item['quantity'] as int;

          return ReceiptItem(
            name: name,
            price: price,
            quantity: quantity,
          );
        }).toList();

        _isUploadComplete = true;
        _isLoading = false; // Clear loading state
        _navigateToPage(1);
      });
    } catch (e) {
      setState(() {
        _isLoading = false; // Clear loading state on error
      });
      if (!mounted) return; // Check mount status before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing receipt: ${e.toString()}')),
      );
    }
  }

  void _navigateToPage(int page) {
    if (_canNavigateToStep(page)) {
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

  // Method to handle the results from VoiceAssignmentScreen
  void _handleAssignmentProcessed(Map<String, dynamic> assignmentsData) {
    print("DEBUG: Handling assignment data in main UI");
    setState(() {
      _isLoading = true; // Show loading while processing assignments in SplitManager
    });

    try {
      final splitManager = context.read<SplitManager>();
      splitManager.reset(); // Clear previous assignments

      // Add people
      final people = List<Map<String, dynamic>>.from(assignmentsData['people'] ?? []);
      for (var personData in people) {
        splitManager.addPerson(personData['name'] as String);
      }

      // Add assigned items
      final orders = List<Map<String, dynamic>>.from(assignmentsData['orders'] ?? []);
      for (var order in orders) {
        final personName = order['person'] as String;
        final person = splitManager.people.firstWhere((p) => p.name == personName, orElse: () {
          print("WARN: Person '$personName' found in order but not in people list.");
          throw Exception("Person '$personName' not found");
        });

        final itemName = order['item'] as String;
        final itemPrice = (order['price'] as num).toDouble();
        final itemQuantity = order['quantity'] as int;

        final originalItem = _editableItems.firstWhere(
           (item) => item.name == itemName && (item.price - itemPrice).abs() < 0.01, // Match name and similar price
           orElse: () {
              print("WARN: Assigned item not found in original list via name/price: Name='$itemName', Price='$itemPrice'. Trying by name only.");
              // Fallback: Try matching by name only if price is slightly different
              return _editableItems.firstWhere(
                (item) => item.name == itemName,
                orElse: () => throw Exception("Assigned item '$itemName' not found in original list")
              );
           }
        );

        final assignedItem = ReceiptItem.clone(originalItem);
        assignedItem.updateQuantity(itemQuantity);

        splitManager.setOriginalQuantity(assignedItem, originalItem.originalQuantity);
        splitManager.assignItemToPerson(assignedItem, person);
      }

      // Add shared items
      final sharedItemsData = List<Map<String, dynamic>>.from(assignmentsData['shared_items'] ?? []);
      for (var itemData in sharedItemsData) {
         final itemName = itemData['item'] as String;
         final itemPrice = (itemData['price'] as num).toDouble();
         final itemQuantity = itemData['quantity'] as int;
         final peopleNames = (itemData['people'] as List).cast<String>();

         final originalItem = _editableItems.firstWhere(
            (item) => item.name == itemName && (item.price - itemPrice).abs() < 0.01,
             orElse: () {
               print("WARN: Shared item not found in original list via name/price: Name='$itemName', Price='$itemPrice'. Trying by name only.");
               return _editableItems.firstWhere(
                 (item) => item.name == itemName,
                 orElse: () => throw Exception("Shared item '$itemName' not found in original list")
               );
            }
         );

         final sharedItem = ReceiptItem.clone(originalItem);
         sharedItem.updateQuantity(itemQuantity);

         final peopleToShareWith = splitManager.people.where((p) => peopleNames.contains(p.name)).toList();
         splitManager.setOriginalQuantity(sharedItem, originalItem.originalQuantity);
         splitManager.addItemToShared(sharedItem, peopleToShareWith);
      }

      // Add unassigned items
      final unassignedItemsData = List<Map<String, dynamic>>.from(assignmentsData['unassigned_items'] ?? []);
      for (var itemData in unassignedItemsData) {
         final itemName = itemData['item'] as String;
         final itemPrice = (itemData['price'] as num).toDouble();
         final itemQuantity = itemData['quantity'] as int;

         final originalItem = _editableItems.firstWhere(
            (item) => item.name == itemName && (item.price - itemPrice).abs() < 0.01,
             orElse: () {
               print("WARN: Unassigned item not found in original list via name/price: Name='$itemName', Price='$itemPrice'. Trying by name only.");
               return _editableItems.firstWhere(
                 (item) => item.name == itemName,
                 orElse: () => throw Exception("Unassigned item '$itemName' not found in original list")
               );
             }
         );

         final unassignedItem = ReceiptItem.clone(originalItem);
         unassignedItem.updateQuantity(itemQuantity);

         splitManager.setOriginalQuantity(unassignedItem, originalItem.originalQuantity);
         splitManager.addUnassignedItem(unassignedItem);
      }

      setState(() {
        _isAssignmentComplete = true;
        _isLoading = false;
        _assignments = assignmentsData; // Store raw results if needed later
      });
      _navigateToPage(3); // Navigate to the next step (Assignment Review)

    } catch (e) {
      print("Error processing assignments in SplitManager: $e");
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying assignments: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildAssignmentReviewStep(BuildContext context) {
    // This step likely just needs the SplitManager via Provider
    // It might need an onComplete callback to navigate to the final summary
    return const SplitView(); // Assuming SplitView handles its own logic via Provider
    // TODO: Add a button/callback here to navigate to the final summary step?
    // Maybe SplitView should have an `onReviewComplete` callback?
  }

  Widget _buildFinalSummaryStep(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final splitManager = context.watch<SplitManager>();

    // Check if items have been assigned
    if (_editableItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.summarize_outlined,
                size: 60,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Split Summary Available',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please complete the previous steps first',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _navigateToPage(2),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go to Assignments'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final people = splitManager.people;
    
    // Calculate subtotal, tax, tip and total
    final double subtotal = splitManager.totalAmount;
    final double taxRate = _taxPercentage / 100;
    final double tipRate = _tipPercentage / 100;
    final double tax = subtotal * taxRate;
    final double tip = subtotal * tipRate;
    final double total = subtotal + tax + tip;
    
    // Calculate sum of individual totals for verification
    double sumOfIndividualTotals = 0.0;
    List<double> personTotals = [];

    // Calculate each person's total and sum them
    for (var person in people) {
      // Calculate person's subtotal (assigned + shared items)
      final double personSubtotal = person.totalAssignedAmount + 
          splitManager.sharedItems.where((item) => 
            person.sharedItems.contains(item)).fold(0.0, 
            (sum, item) => sum + (item.price * item.quantity / 
              splitManager.people.where((p) => 
                p.sharedItems.contains(item)).length));
    
      // Calculate tax and tip directly from person's subtotal
      final double personTax = personSubtotal * taxRate;
      final double personTip = personSubtotal * tipRate;
      final double personFinalTotal = personSubtotal + personTax + personTip;
    
      personTotals.add(personFinalTotal);
      sumOfIndividualTotals += personFinalTotal;
    }

    // Add unassigned items total if any
    if (splitManager.unassignedItems.isNotEmpty) {
      final double unassignedSubtotal = splitManager.unassignedItemsTotal;
      final double unassignedTax = unassignedSubtotal * taxRate;
      final double unassignedTip = unassignedSubtotal * tipRate;
      sumOfIndividualTotals += unassignedSubtotal + unassignedTax + unassignedTip;
    }

    // Check if totals match (allowing for small floating point differences)
    final bool totalsMatch = (total - sumOfIndividualTotals).abs() < 0.01;

    return Stack(
      children: [
        ListView(
          children: [
            // Show warning if totals don't match
            if (!totalsMatch)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: Individual totals (${sumOfIndividualTotals.toStringAsFixed(2)}) ' +
                          'don\'t match overall total (${total.toStringAsFixed(2)})',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Header Card with Tax and Tip adjustments
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Receipt Summary',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Subtotal row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal:', style: textTheme.titleMedium),
                        Text(
                          '\$${subtotal.toStringAsFixed(2)}',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tax Input Row
                    Row(
                      children: [
                        Text('Tax:', style: textTheme.bodyLarge),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _taxController, // Use the existing controller
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              suffixText: '%',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            textAlign: TextAlign.right,
                            // Listener is already set in initState to update _taxPercentage
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '\$${tax.toStringAsFixed(2)}', // Display calculated tax
                            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tip Section
                    Row(
                      children: [
                        Text('Tip:', style: textTheme.bodyLarge),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Tip Percentage Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_tipPercentage.toStringAsFixed(1)}%',
                          style: textTheme.titleLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Tip Slider with Quick Select Buttons
                    Column(
                      children: [
                        // Quick select buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [15, 18, 20, 25].map((percentage) {
                            return ElevatedButton(
                              onPressed: () {
                                setState(() { _tipPercentage = percentage.toDouble(); });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _tipPercentage == percentage.toDouble() 
                                  ? colorScheme.primary 
                                  : colorScheme.surfaceVariant,
                                foregroundColor: _tipPercentage == percentage.toDouble() 
                                  ? colorScheme.onPrimary 
                                  : colorScheme.onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Text('$percentage%'),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        
                        // Fine-tune slider
                        Slider(
                          value: _tipPercentage,
                          min: 0,
                          max: 30,
                          divisions: 60,
                          label: '${_tipPercentage.toStringAsFixed(1)}%',
                          onChanged: (value) {
                            setState(() { _tipPercentage = value; });
                          },
                        ),
                      ],
                    ),
                    
                    // Tip Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Tip Amount: ',
                          style: textTheme.bodyLarge,
                        ),
                        Text(
                          '\$${tip.toStringAsFixed(2)}', // Display calculated tip
                          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    
                    const Divider(height: 24, thickness: 1),
                    
                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // People section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.people, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'People (${people.length})',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Person cards
            ...people.map((person) {
              // Calculate person's subtotal (assigned + shared items)
              final double personSubtotal = person.totalAssignedAmount + 
                  splitManager.sharedItems.where((item) => 
                    person.sharedItems.contains(item)).fold(0.0, 
                    (sum, item) => sum + (item.price * item.quantity / 
                      splitManager.people.where((p) => 
                        p.sharedItems.contains(item)).length));
              
              // Calculate tax and tip directly from person's subtotal
              final double personTax = personSubtotal * taxRate;
              final double personTip = personSubtotal * tipRate;
              final double personFinalTotal = personSubtotal + personTax + personTip;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorScheme.secondaryContainer,
                            child: Text(
                              person.name.substring(0, 1).toUpperCase(), 
                              style: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              person.name, 
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            'Total:',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\$${personFinalTotal.toStringAsFixed(2)}',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Assigned items
                      if (person.assignedItems.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Assigned Items:',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...person.assignedItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.quantity}x ${item.name}',
                                  style: textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                      
                      // Shared items
                      if (person.sharedItems.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Shared Items:',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.tertiary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...person.sharedItems.map((item) {
                          // Count how many people share this item
                          final int sharingCount = splitManager.people
                              .where((p) => p.sharedItems.contains(item))
                              .length;
                          
                          // Calculate individual share
                          final double individualShare = item.price * item.quantity / sharingCount;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x ${item.name} (shared ${sharingCount} ways)',
                                    style: textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '\$${individualShare.toStringAsFixed(2)}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      
                      // Tax and tip rows
                      const SizedBox(height: 12),
                      Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tax (${_taxPercentage.toStringAsFixed(1)}%):',
                            style: textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Text(
                            '\$${personTax.toStringAsFixed(2)}',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tip (${_tipPercentage.toStringAsFixed(1)}%):',
                            style: textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Text(
                            '\$${personTip.toStringAsFixed(2)}',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                      // Remove the final divider and total row
                    ],
                  ),
                ),
              );
            }).toList(),
            
            // Unassigned items section if any
            if (splitManager.unassignedItems.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      'Unassigned Items',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorScheme.surfaceVariant,
                            child: Icon(Icons.question_mark, color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Unassigned', 
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\$${splitManager.unassignedItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity)).toStringAsFixed(2)}',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...splitManager.unassignedItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity}x ${item.name}',
                                style: textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        // Floating share button and Buy Me a Coffee button
        Positioned(
          right: 16,
          bottom: 16,
          child: Row( // Change Column to Row
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'buyMeACoffeeButton', // Add unique heroTag
                onPressed: () => _launchBuyMeACoffee(context),
                icon: const Icon(Icons.coffee), // Coffee icon
                label: const Text('Buy me a coffee'),
                backgroundColor: AppColors.secondary, // Use a distinct color
                foregroundColor: Colors.white,
              ),
              const SizedBox(width: 12), // Spacing between buttons
              FloatingActionButton.extended(
                heroTag: 'shareButton', // Add unique heroTag
                onPressed: () => _generateAndShareReceipt(context),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Method to launch the Buy Me a Coffee link
  Future<void> _launchBuyMeACoffee(BuildContext context) async {
    final String? buyMeACoffeeLink = dotenv.env['BUY_ME_A_COFFEE_LINK'];
    if (buyMeACoffeeLink == null || buyMeACoffeeLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buy Me a Coffee link is not configured.')),
      );
      return;
    }

    final Uri url = Uri.parse(buyMeACoffeeLink);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $buyMeACoffeeLink')),
      );
    }
  }

  // Method to generate and share receipt
  Future<void> _generateAndShareReceipt(BuildContext context) async {
    final splitManager = context.read<SplitManager>();
    final people = splitManager.people;
    final colorScheme = Theme.of(context).colorScheme;
    
    // Calculate totals
    final double subtotal = splitManager.totalAmount;
    final double taxRate = _taxPercentage / 100;
    final double tipRate = _tipPercentage / 100;
    final double tax = subtotal * taxRate;
    final double tip = subtotal * tipRate;
    final double total = subtotal + tax + tip;

    // Build receipt text
    StringBuffer receipt = StringBuffer();
    
    // Header
    receipt.writeln('🧾 RECEIPT SUMMARY');
    receipt.writeln('═══════════════════\n');
    
    // Totals section
    receipt.writeln('📊 TOTALS');
    receipt.writeln('Subtotal: \$${subtotal.toStringAsFixed(2)}');
    receipt.writeln('Tax (${_taxPercentage.toStringAsFixed(1)}%): \$${tax.toStringAsFixed(2)}');
    receipt.writeln('Tip (${_tipPercentage.toStringAsFixed(1)}%): \$${tip.toStringAsFixed(2)}');
    receipt.writeln('TOTAL: \$${total.toStringAsFixed(2)}\n');
    
    // Individual breakdowns
    receipt.writeln('👥 INDIVIDUAL BREAKDOWNS');
    receipt.writeln('═══════════════════');
    
    for (var person in people) {
      // Calculate person's totals
      final double personSubtotal = person.totalAssignedAmount + 
          splitManager.sharedItems.where((item) => 
            person.sharedItems.contains(item)).fold(0.0, 
            (sum, item) => sum + (item.price * item.quantity / 
              splitManager.people.where((p) => 
                p.sharedItems.contains(item)).length));
      
      final double personTax = personSubtotal * taxRate;
      final double personTip = personSubtotal * tipRate;
      final double personTotal = personSubtotal + personTax + personTip;
      
      receipt.writeln('\n👤 ${person.name.toUpperCase()} → YOU OWE: \$${personTotal.toStringAsFixed(2)}');
      receipt.writeln('───────────────');
      
      // Assigned items
      if (person.assignedItems.isNotEmpty) {
        receipt.writeln('Individual Items:');
        for (var item in person.assignedItems) {
          receipt.writeln('  • ${item.quantity}x ${item.name} (\$${(item.price * item.quantity).toStringAsFixed(2)})');
        }
      }
      
      // Shared items
      if (person.sharedItems.isNotEmpty) {
        receipt.writeln('\nShared Items:');
        for (var item in person.sharedItems) {
          final sharingCount = splitManager.people.where((p) => p.sharedItems.contains(item)).length;
          final individualShare = item.price * item.quantity / sharingCount;
          receipt.writeln('  • ${item.quantity}x ${item.name} (${sharingCount}-way split: \$${individualShare.toStringAsFixed(2)})');
        }
      }
      
      // Breakdown at the bottom in smaller detail
      receipt.writeln('\nDetails:');
      receipt.writeln('  Subtotal: \$${personSubtotal.toStringAsFixed(2)}');
      receipt.writeln('  + Tax (${_taxPercentage.toStringAsFixed(1)}%): \$${personTax.toStringAsFixed(2)}');
      receipt.writeln('  + Tip (${_tipPercentage.toStringAsFixed(1)}%): \$${personTip.toStringAsFixed(2)}');
      receipt.writeln('  = Total: \$${personTotal.toStringAsFixed(2)}');
    }
    
    // Unassigned items section if any
    if (splitManager.unassignedItems.isNotEmpty) {
      receipt.writeln('\n⚠️ UNASSIGNED ITEMS');
      receipt.writeln('═══════════════════');
      for (var item in splitManager.unassignedItems) {
        receipt.writeln('• ${item.quantity}x ${item.name} (\$${(item.price * item.quantity).toStringAsFixed(2)})');
      }
      final double unassignedSubtotal = splitManager.unassignedItemsTotal;
      final double unassignedTax = unassignedSubtotal * taxRate;
      final double unassignedTip = unassignedSubtotal * tipRate;
      final double unassignedTotal = unassignedSubtotal + unassignedTax + unassignedTip;
      receipt.writeln('\nUnassigned Total: \$${unassignedTotal.toStringAsFixed(2)}');
    }

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: receipt.toString()));

    // Show success dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Receipt Copied!'),
          ],
        ),
        content: const Text('The receipt summary has been copied to your clipboard. You can now paste it anywhere!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Receipt copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  double _calculateSubtotal() {
    // Use the SplitManager's totalAmount calculation for consistency
    final splitManager = context.read<SplitManager>();
    if (splitManager.people.isNotEmpty || splitManager.unassignedItems.isNotEmpty) {
      return splitManager.totalAmount;
    }
    
    // Fall back to summing _editableItems when SplitManager is not populated
    double total = 0.0;
    for (var item in _editableItems) {
      double itemTotal = item.price * item.quantity;
      total += itemTotal;
    }
    return total;
  }

  double _calculateTax() {
    final subtotal = _calculateSubtotal();
    final tax = (subtotal * (_taxPercentage / 100) * 100).ceil() / 100;
    return tax;
  }

  double _calculateTip() {
    final subtotal = _calculateSubtotal();
    final tip = subtotal * (_tipPercentage / 100);
    return tip;
  }

  double _calculateTotal() {
    return _calculateSubtotal() + _calculateTax() + _calculateTip();
  }

  double _calculatePersonTotal(String person) {
    return _calculateTotal() / MockData.people.length;
  }
} 