import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'services/receipt_parser_service.dart';

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
  // Default values
  static const double DEFAULT_TAX_RATE = 8.875; // Default NYC tax rate

  // State variables
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isRecording = false;
  double _tipPercentage = 20.0;
  double _taxPercentage = DEFAULT_TAX_RATE; // Mutable tax rate
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // Controllers
  late List<TextEditingController> _itemPriceControllers;
  late TextEditingController _taxController;
  late List<ReceiptItem> _editableItems;
  late ScrollController _itemsScrollController;

  // Add a flag to track FAB visibility
  bool _isFabVisible = true;

  // For tracking scroll direction
  double _lastScrollPosition = 0;

  @override
  void initState() {
    super.initState();
    _initializeEditableItems();
    _taxController = TextEditingController(text: DEFAULT_TAX_RATE.toStringAsFixed(3));
    _itemsScrollController = ScrollController();
    _itemsScrollController.addListener(_onScroll);

    // Add listener for tax changes
    _taxController.addListener(() {
      final newTax = double.tryParse(_taxController.text);
      if (newTax != null && _taxController.text.isNotEmpty) {
        setState(() {
          _taxPercentage = newTax;
          print('Updated tax rate to: ${_taxPercentage.toStringAsFixed(3)}%');
        });
      }
    });
  }

  void _initializeEditableItems() {
    _editableItems = List.from(MockData.items.map((item) =>
      ReceiptItem(name: item.name, price: item.price, quantity: item.quantity)
    ));
    
    // Initialize price controllers with current values
    _itemPriceControllers = _editableItems.map((item) =>
      TextEditingController(text: item.price.toStringAsFixed(2))).toList();
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
              Column(
                children: [
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
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _parseReceipt,
                      child: const Text('Parse Receipt'),
                    ),
                ],
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
          ],
        ),
      ),
    );
  }

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
          _isLoading = false; // Reset loading state
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
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
          _isLoading = false; // Reset loading state
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _parseReceipt() async {
    if (_imageFile == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final result = await ReceiptParserService.parseReceipt(_imageFile!);
      
      setState(() {
        // Parse items with detailed logging
        _editableItems = (result['items'] as List).map((item) {
          final name = item['item'] as String;
          final price = item['price'].toDouble();
          final quantity = item['quantity'] as int;
          
          print('Parsing item: $name, Price: \$$price, Quantity: $quantity');
          
          return ReceiptItem(
            name: name,
            price: price,
            quantity: quantity,
          );
        }).toList();

        // Log all items after parsing
        print('\nAll parsed items:');
        for (var item in _editableItems) {
          final itemTotal = item.price * item.quantity;
          print('${item.name}: \$${item.price} × ${item.quantity} = \$${itemTotal.toStringAsFixed(2)}');
        }

        // Calculate and verify subtotal
        final calculatedSubtotal = _calculateSubtotal();
        final expectedSubtotal = result['subtotal']?.toDouble() ?? 0.0;
        print('\nSubtotal verification:');
        print('Calculated subtotal: \$${calculatedSubtotal.toStringAsFixed(2)}');
        print('Expected subtotal: \$${expectedSubtotal.toStringAsFixed(2)}');

        // Update price controllers
        _itemPriceControllers = _editableItems.map((item) =>
          TextEditingController(text: item.price.toStringAsFixed(2))).toList();

        // Navigate to the next step after successful parsing
        _navigateToPage(1);
      });
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error Parsing Receipt'),
            content: SingleChildScrollView(
              child: Text(e.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    return Stack(
      children: [
        Scrollbar(
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
                      const SizedBox(height: 16),
                      
                      // Subtotal Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal:', style: textTheme.bodyLarge),
                          Text('\$${_calculateSubtotal().toStringAsFixed(2)}', 
                            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tax Input Row
                      Row(
                        children: [
                          Text('Tax:', style: textTheme.bodyLarge),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 100,
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
                              onChanged: (value) {
                                final newTax = double.tryParse(value);
                                if (newTax != null) {
                                  setState(() {
                                    _taxPercentage = newTax;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '\$${_calculateTax().toStringAsFixed(2)}',
                              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Pre-tip Total Row (highlighted)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pre-tip Total:', 
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${(_calculateSubtotal() + _calculateTax()).toStringAsFixed(2)}',
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tip Section
                      Text('Tip:', style: textTheme.bodyLarge),
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
                          // Quick select buttons for common tip percentages
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [15, 18, 20, 25].map((percentage) {
                              return ElevatedButton(
                                onPressed: () {
                                  setState(() { _tipPercentage = percentage.toDouble(); });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _tipPercentage == percentage 
                                    ? colorScheme.primary 
                                    : colorScheme.surfaceVariant,
                                  foregroundColor: _tipPercentage == percentage 
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
                            '\$${_calculateTip().toStringAsFixed(2)}',
                            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      
                      const Divider(height: 32),
                      
                      // Final Total
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total:',
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${_calculateTotal().toStringAsFixed(2)}',
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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
                    child: Column(
                      children: [
                        Row(
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
                                onChanged: (value) {
                                  final newPrice = double.tryParse(value);
                                  if (newPrice != null) {
                                    setState(() {
                                      _editableItems[index].price = newPrice;
                                      print('Updated price for ${_editableItems[index].name} to \$${newPrice.toStringAsFixed(2)}');
                                      print('New item total: \$${(newPrice * _editableItems[index].quantity).toStringAsFixed(2)}');
                                      
                                      // Recalculate and print the new subtotal
                                      final newSubtotal = _calculateSubtotal();
                                      print('New subtotal after price update: \$${newSubtotal.toStringAsFixed(2)}');
                                    });
                                  }
                                },
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
                                        print('Decreased quantity for ${item.name} to ${item.quantity}. New item total: ${(item.price * item.quantity).toStringAsFixed(2)}');
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
                                      print('Increased quantity for ${item.name} to ${item.quantity}. New item total: ${(item.price * item.quantity).toStringAsFixed(2)}');
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
                        // Add total price row
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                item.quantity > 1
                                    ? '\$${item.price.toStringAsFixed(2)} × ${item.quantity} = '
                                    : '',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
        ),
        if (_isFabVisible)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () => _showAddItemDialog(context),
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    int quantity = 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'Enter item name',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        hintText: 'Enter price',
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Quantity: '),
                        IconButton(
                          icon: const Icon(Icons.remove_circle),
                          onPressed: () {
                            if (quantity > 1) {
                              setState(() => quantity--);
                            }
                          },
                        ),
                        Text(
                          quantity.toString(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: () {
                            setState(() => quantity++);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text);
                    
                    if (name.isNotEmpty && price != null && price > 0) {
                      setState(() {
                        _editableItems.add(ReceiptItem(
                          name: name,
                          price: price,
                          quantity: quantity,
                        ));
                        _itemPriceControllers.add(
                          TextEditingController(text: price.toStringAsFixed(2))
                        );
                      });
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid name and price'),
                        ),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
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
    double total = 0.0;
    print('\nCalculating subtotal:');
    for (var item in _editableItems) {
      double itemTotal = item.price * item.quantity;
      print('${item.name}: \$${item.price.toStringAsFixed(2)} × ${item.quantity} = \$${itemTotal.toStringAsFixed(2)}');
      total += itemTotal;
    }
    print('Final Subtotal: \$${total.toStringAsFixed(2)}\n');
    return total;
  }

  double _calculateTax() {
    final subtotal = _calculateSubtotal();
    final tax = (subtotal * (_taxPercentage / 100) * 100).ceil() / 100;
    print('Tax calculation: \$${subtotal.toStringAsFixed(2)} × ${_taxPercentage.toStringAsFixed(3)}% = \$${tax.toStringAsFixed(2)}');
    return tax;
  }

  double _calculateTip() {
    final subtotal = _calculateSubtotal();
    final tip = subtotal * (_tipPercentage / 100);
    print('Tip calculation: \$${subtotal.toStringAsFixed(2)} × ${_tipPercentage.toStringAsFixed(2)}% = \$${tip.toStringAsFixed(2)}');
    return tip;
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
    
    setState(() {
      _currentStep = 0;
      _pageController.jumpToPage(0);
      _imageFile = null;
      _tipPercentage = 20.0;
      _taxPercentage = DEFAULT_TAX_RATE; // Reset to default tax rate
      _taxController.text = DEFAULT_TAX_RATE.toStringAsFixed(3);
      _isRecording = false;
      // Re-initialize items and controllers from mock data
      _initializeEditableItems();
    });
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
} 