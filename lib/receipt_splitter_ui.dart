import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

// Mock data for demonstration
class MockData {
  static final List<ReceiptItem> items = [
    ReceiptItem(name: 'Burger', price: 12.99, quantity: 1),
    ReceiptItem(name: 'Fries', price: 4.99, quantity: 2),
    ReceiptItem(name: 'Soda', price: 2.99, quantity: 3),
    ReceiptItem(name: 'Salad', price: 8.99, quantity: 1),
    ReceiptItem(name: 'Rice Bowl', price: 8.99, quantity: 1),
    ReceiptItem(name: 'Dessert', price: 8.99, quantity: 1),
    ReceiptItem(name: 'Soba', price: 8.99, quantity: 1),
  ];

  static final List<String> people = ['John', 'Alice', 'Bob', 'Carol'];
  
  static final Map<String, List<ReceiptItem>> assignments = {
    'John': [items[0], items[1], items[4]],
    'Alice': [items[2]],
    'Bob': [items[3]],
    'Carol': [],
  };

  static final List<ReceiptItem> sharedItems = [
    ReceiptItem(name: 'Appetizer', price: 15.99, quantity: 1),
  ];
}

class ReceiptItem {
  final String name;
  double price;
  int quantity;

  ReceiptItem({required this.name, required this.price, required this.quantity});
}

class ReceiptSplitterUI extends StatefulWidget {
  const ReceiptSplitterUI({super.key});

  @override
  State<ReceiptSplitterUI> createState() => _ReceiptSplitterUIState();
}

class _ReceiptSplitterUIState extends State<ReceiptSplitterUI> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isRecording = false;
  double _tipPercentage = 15.0;
  double _taxPercentage = 8.876; // Default NYC tax
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // Controllers for editable fields
  late List<TextEditingController> _itemPriceControllers;
  late TextEditingController _taxController; // Controller for Tax TextField
  late List<ReceiptItem> _editableItems; // Keep a mutable copy
  late ScrollController _itemsScrollController; // Controller for review list scroll

  // Add a flag to track FAB visibility
  bool _isFabVisible = true;

  // For tracking scroll direction
  double _lastScrollPosition = 0;

  @override
  void initState() {
    super.initState();
    _initializeEditableItems();
    _taxController = TextEditingController(text: _taxPercentage.toStringAsFixed(3));
    _itemsScrollController = ScrollController();

    // Add scroll listener to control FAB visibility
    _itemsScrollController.addListener(_onScroll);

    // Add listener to update tax percentage state when text field changes
    _taxController.addListener(() {
      final newTax = double.tryParse(_taxController.text);
      if (newTax != null && newTax != _taxPercentage) {
        // Use addPostFrameCallback to avoid calling setState during build
         WidgetsBinding.instance.addPostFrameCallback((_) {
           if (mounted) { // Check if widget is still mounted
              setState(() {
                _taxPercentage = newTax;
              });
           }
         });
      }
    });
  }

  void _initializeEditableItems() {
    _editableItems = List.from(MockData.items.map((item) =>
      ReceiptItem(name: item.name, price: item.price, quantity: item.quantity)
    ));
    _itemPriceControllers = _editableItems.map((item) =>
      TextEditingController(text: item.price.toStringAsFixed(2))).toList();

    // Add listeners only for price controllers
    for (int i = 0; i < _editableItems.length; i++) {
      _itemPriceControllers[i].addListener(() {
        final newPrice = double.tryParse(_itemPriceControllers[i].text);
        // Prevent updating state during build if controller clears itself
        if (newPrice != null && _itemPriceControllers[i].text.isNotEmpty && newPrice != _editableItems[i].price) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
              if(mounted) { // Check if widget is still in the tree
                setState(() {
                  _editableItems[i].price = newPrice;
                });
              }
            });
        }
      });
    }
  }

  // Method to handle scroll events and update FAB visibility
  void _onScroll() {
    // Determine if scrolling down by comparing current position to previous position
    final currentPosition = _itemsScrollController.position.pixels;
    final bool isScrollingDown = currentPosition > _lastScrollPosition;
    _lastScrollPosition = currentPosition;
    
    // Only update state if visibility changed
    if (isScrollingDown != !_isFabVisible) {
      setState(() {
        _isFabVisible = !isScrollingDown;
      });
    }
  }

  @override
  void dispose() {
    _itemPriceControllers.forEach((controller) => controller.dispose());
    _taxController.dispose();
    _itemsScrollController.removeListener(_onScroll); // Remove listener before disposing
    _itemsScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
      }
    } catch (e) {
      print('Error taking picture: $e');
      if (mounted) {
        _showErrorDialog('Failed to take picture. Please check camera permissions and try again.');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        _showErrorDialog('Failed to pick image. Please check storage permissions and try again.');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToPage(int page) {
    if (page >= 0 && page < 5) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<Widget> pages = [
      _buildReceiptUploadStep(context),
      _buildParsedReceiptStep(context),
      _buildVoiceAssignmentStep(context),
      _buildAssignmentReviewStep(context),
      _buildFinalSummaryStep(context),
    ];

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text('Receipt Splitter - Step ${_currentStep + 1} of 5'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Start Over',
            onPressed: _showStartOverConfirmationDialog,
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentStep,
        onTap: _navigateToPage,
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
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
       floatingActionButton: _currentStep < 4 && (_currentStep != 1 || _isFabVisible) ? 
        FloatingActionButton.extended(
          onPressed: () => _navigateToPage(_currentStep + 1),
          label: const Text('Next'),
          icon: const Icon(Icons.arrow_forward),
        ) : null,
    );
  }

  Widget _buildReceiptUploadStep(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_imageFile != null)
              GestureDetector(
                onTap: () => _showFullImage(_imageFile!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _imageFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.image_search, size: 80, color: colorScheme.primary.withOpacity(0.7)),
                   const SizedBox(height: 20),
                   Text(
                     'Upload Receipt',
                     style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
                   ),
                   const SizedBox(height: 10),
                    Text(
                     'Take a picture or select one from your gallery.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                   ),
                 ],
              ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _takePicture,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
             if (_imageFile != null) ...[
                const SizedBox(height: 20),
                Text(
                 'Tap image to view full size. Use buttons to change.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
             ]
          ],
        ),
      ),
    );
  }

  void _showFullImage(File imageFile) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Receipt Image', style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.primary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(),
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(imageFile),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.zoom_out_map, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Pinch to zoom, drag to move',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedReceiptStep(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Rebuild this step completely as a single scrollable list
    return Scrollbar(
      controller: _itemsScrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _itemsScrollController,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Review & Edit Items',
              style: textTheme.headlineSmall?.copyWith(color: colorScheme.primary),
            ),
          ),

          // Totals Section (now at the top)
          Card(
            elevation: 2.0,
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receipt Summary', 
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal:', style: textTheme.bodyLarge),
                      Text('\$${_calculateSubtotal().toStringAsFixed(2)}', style: textTheme.bodyLarge),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tax Input Row (TextField)
                  Row(
                    children: [
                      Text('Tax:', style: textTheme.bodyLarge),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _taxController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            suffixText: '%',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          textAlign: TextAlign.right,
                          style: textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tip Input Row (Slider)
                  Text('Tip:', style: textTheme.bodyLarge),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _tipPercentage,
                          min: 0,
                          max: 50,
                          divisions: 50,
                          label: '${_tipPercentage.round()}%',
                          onChanged: (value) {
                            setState(() { _tipPercentage = value; });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text('${_tipPercentage.toStringAsFixed(1)}%', 
                          textAlign: TextAlign.right, 
                          style: textTheme.bodyLarge
                        ),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total:', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text('\$${_calculateTotal().toStringAsFixed(2)}', 
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, 
                          color: colorScheme.primary
                        )
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Items Section Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Items',
              style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
            ),
          ),
          
          // List of Items (now below the totals)
          ...List.generate(_editableItems.length, (index) {
            final item = _editableItems[index];
            if (index >= _itemPriceControllers.length) return const SizedBox.shrink();
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item.name, style: textTheme.titleMedium)
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _itemPriceControllers[index],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          prefixText: '\$ ',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        textAlign: TextAlign.right,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle),
                          iconSize: 22,
                          color: colorScheme.secondary,
                          tooltip: 'Decrease Quantity',
                          onPressed: () {
                            if (item.quantity > 1) {
                              setState(() {
                                item.quantity--;
                              });
                            }
                          },
                        ),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${item.quantity}',
                            style: textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          iconSize: 22,
                          color: colorScheme.secondary,
                          tooltip: 'Increase Quantity',
                          onPressed: () {
                            setState(() {
                              item.quantity++;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_sweep_outlined, color: colorScheme.error),
                      iconSize: 22,
                      tooltip: 'Remove Item',
                      onPressed: () => _removeItem(index),
                    ),
                  ],
                ),
              ),
            );
          }),
          
          // Bottom padding to ensure last items are fully visible
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildVoiceAssignmentStep(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mic_none, size: 100, color: _isRecording ? colorScheme.error : colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          'Assign Items via Voice',
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Tap the button and speak clearly.\nExample: "John ordered the burger and fries"',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () {
            setState(() { _isRecording = !_isRecording; });
          },
          icon: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic),
          label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording ? colorScheme.errorContainer : colorScheme.primaryContainer,
            foregroundColor: _isRecording ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            textStyle: textTheme.titleMedium,
          ),
        ),
        if (_isRecording) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
           Text('Listening...', style: textTheme.bodySmall, textAlign: TextAlign.center),
        ] else ... [
          const SizedBox(height: 32),
        ],
      ],
    );
  }

 Widget _buildAssignmentReviewStep(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final assignments = MockData.assignments;
    final people = MockData.people;
    final sharedItems = MockData.sharedItems;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Assigned Items', style: textTheme.headlineSmall),
        ),

        ...people.map((person) {
          final assignedMockItems = assignments[person] ?? [];
          final currentAssignedItems = _editableItems.where((editItem) =>
              assignedMockItems.any((mockItem) => mockItem.name == editItem.name)).toList();

          if (currentAssignedItems.isEmpty) {
             return Card(
                 margin: const EdgeInsets.symmetric(vertical: 6.0),
                 child: ListTile(
                   title: Text(person),
                   subtitle: Text('No items assigned yet.', style: TextStyle(color: Colors.grey[600])),
                 )
             );
          }

          return Card(
             margin: const EdgeInsets.symmetric(vertical: 6.0),
             child: ExpansionTile(
                title: Text(person, style: textTheme.titleLarge),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(top: 0),
                children: currentAssignedItems.map((item) {
                  return ListTile(
                    title: Text(item.name, style: textTheme.titleMedium),
                    trailing: Text(
                        '\$${item.price.toStringAsFixed(2)} x ${item.quantity}',
                         style: textTheme.bodyLarge,
                      ),
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
          );
        }).toList(),

        const SizedBox(height: 24),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Shared Items', style: textTheme.headlineSmall),
        ),

        ...sharedItems.map((item) {
          final editableSharedItem = _editableItems.firstWhere(
              (editItem) => editItem.name == item.name, orElse: () => item);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${editableSharedItem.name} (\$${editableSharedItem.price.toStringAsFixed(2)})',
                     style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('Shared by:', style: textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: people.map((person) {
                      bool isSelected = true;
                      return FilterChip(
                        label: Text(person),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setState(() {
                          });
                        },
                        selectedColor: colorScheme.primaryContainer,
                        checkmarkColor: colorScheme.onPrimaryContainer,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }).toList(),

        if (sharedItems.isEmpty)
           Padding(
             padding: const EdgeInsets.symmetric(vertical: 8.0),
             child: Center(child: Text('No items marked as shared.', style: textTheme.bodyMedium)),
           ),
      ],
    );
  }


   Widget _buildFinalSummaryStep(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final people = MockData.people;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Final Split', style: textTheme.headlineSmall, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 16),

        ...people.map((person) {
          double personTotal = _calculatePersonTotal(person);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            child: ListTile(
              leading: CircleAvatar(
                 backgroundColor: colorScheme.secondaryContainer,
                 child: Text(person.substring(0, 1), style: TextStyle(color: colorScheme.onSecondaryContainer)),
              ),
              title: Text(person, style: textTheme.titleLarge),
              trailing: Text(
                '\$${personTotal.toStringAsFixed(2)}',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            ),
          );
        }).toList(),

        const SizedBox(height: 32),

        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete & Share'),
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Split finalized (sharing not implemented yet).')),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: textTheme.titleMedium,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  double _calculateSubtotal() {
    return _editableItems.fold(0,
        (sum, item) => sum + (item.price * item.quantity));
  }

  double _calculateTax() {
    return _calculateSubtotal() * (_taxPercentage / 100);
  }

  double _calculateTip() {
    return _calculateSubtotal() * (_tipPercentage / 100);
  }

  double _calculateTotal() {
    return _calculateSubtotal() + _calculateTax() + _calculateTip();
  }

  double _calculatePersonTotal(String person) {
    return _calculateTotal() / MockData.people.length;
  }

  void _removeItem(int index) {
    setState(() {
      _editableItems.removeAt(index);
      _itemPriceControllers.removeAt(index).dispose();
    });
  }

   void _showStartOverConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Start Over?'),
          content: const Text('Are you sure you want to start over? All current progress will be lost.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Confirm'),
               style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _resetState();
              },
            ),
          ],
        );
      },
    );
  }


  void _resetState() {
    // Dispose existing controllers first if they exist
    _itemPriceControllers.forEach((controller) => controller.dispose());
    // Don't dispose _taxController here as we re-initialize right after

    setState(() {
      _currentStep = 0;
      _pageController.jumpToPage(0);
      _imageFile = null;
      _taxPercentage = 8.876;
      _tipPercentage = 15.0;
      _isRecording = false;
      // Re-initialize items and controllers from mock data
      _initializeEditableItems();
      // Reset tax controller text to default
      _taxController.text = _taxPercentage.toStringAsFixed(3);
      // TODO: Reset actual assignment data when implemented
    });
  }
} 