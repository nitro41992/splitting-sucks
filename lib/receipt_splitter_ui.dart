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
  ];

  static final List<String> people = ['John', 'Alice', 'Bob', 'Carol'];
  
  static final Map<String, List<ReceiptItem>> assignments = {
    'John': [items[0], items[1]],
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
  late List<ReceiptItem> _editableItems; // Keep a mutable copy

  @override
  void initState() {
    super.initState();
    _initializeEditableItems();
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

  @override
  void dispose() {
    _itemPriceControllers.forEach((controller) => controller.dispose());
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
      appBar: AppBar(
        title: Text('Receipt Splitter - Step ${_currentStep + 1} of 5'),
        backgroundColor: colorScheme.primaryContainer,
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
       floatingActionButton: _currentStep < 4 ? FloatingActionButton.extended(
         onPressed: () => _navigateToPage(_currentStep + 1),
         label: const Text('Next'),
         icon: const Icon(Icons.arrow_forward),
       ) : null,
    );
  }

  Widget _buildReceiptUploadStep(BuildContext context) {
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
                   Icon(Icons.image_search, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                   const SizedBox(height: 20),
                   Text(
                     'Upload Receipt',
                     style: Theme.of(context).textTheme.headlineSmall,
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(imageFile),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedReceiptStep(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
         Padding(
           padding: const EdgeInsets.only(bottom: 16.0),
           child: Text('Review & Edit Items', style: textTheme.headlineSmall),
         ),

        Expanded(
          child: ListView.builder(
            itemCount: _editableItems.length,
            itemBuilder: (context, index) {
               final item = _editableItems[index];
              if (index >= _itemPriceControllers.length) return SizedBox.shrink();
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
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
                              color: Theme.of(context).colorScheme.secondary,
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
                              color: Theme.of(context).colorScheme.secondary,
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
                        icon: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error),
                         iconSize: 22,
                        tooltip: 'Remove Item',
                        onPressed: () => _removeItem(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
         const SizedBox(height: 16),

        Card(
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal:', style: textTheme.titleMedium),
                    Text('\$${_calculateSubtotal().toStringAsFixed(2)}', style: textTheme.titleMedium),
                  ],
                ),
                 const Divider(height: 24),

                Row(
                  children: [
                    Text('Tax:', style: textTheme.bodyLarge),
                    Expanded(
                      child: Slider(
                        value: _taxPercentage,
                        min: 0,
                        max: 20,
                        label: '${_taxPercentage.toStringAsFixed(2)}%',
                        onChanged: (value) {
                          setState(() { _taxPercentage = value; });
                        },
                      ),
                    ),
                    SizedBox(
                       width: 70,
                       child: Text('${_taxPercentage.toStringAsFixed(2)}%', textAlign: TextAlign.right, style: textTheme.bodyLarge),
                    ),
                  ],
                ),

                Row(
                   children: [
                    Text('Tip:', style: textTheme.bodyLarge),
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
                       child: Text('${_tipPercentage.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: textTheme.bodyLarge),
                    ),
                  ],
                ),
                 const Divider(height: 24),

                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total:', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    Text('\$${_calculateTotal().toStringAsFixed(2)}', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
    _itemPriceControllers.forEach((controller) => controller.dispose());

    setState(() {
      _currentStep = 0;
      _pageController.jumpToPage(0);
      _imageFile = null;
      _taxPercentage = 8.876;
      _tipPercentage = 15.0;
      _isRecording = false;
      _initializeEditableItems();
    });
  }
} 