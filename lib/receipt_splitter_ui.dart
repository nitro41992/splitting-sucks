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
        // _moveToNextStep(); // REMOVED: Do not automatically move to next step
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
        // _moveToNextStep(); // REMOVED: Do not automatically move to next step
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

  void _moveToNextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep += 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Splitter'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Start Over',
            onPressed: _showStartOverConfirmationDialog,
          ),
        ],
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 4) {
            setState(() {
              _currentStep += 1;
            });
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          }
        },
        steps: [
          // Step 1: Receipt Input
          Step(
            title: const Text('Upload Receipt'),
            content: _buildReceiptUploadStep(),
            isActive: _currentStep >= 0,
          ),
          // Step 2: Parsed Receipt Review
          Step(
            title: const Text('Review Items'),
            content: _buildParsedReceiptStep(),
            isActive: _currentStep >= 1,
          ),
          // Step 3: Voice Assignment
          Step(
            title: const Text('Assign Items'),
            content: _buildVoiceAssignmentStep(),
            isActive: _currentStep >= 2,
          ),
          // Step 4: Review Assignments
          Step(
            title: const Text('Review Assignments'),
            content: _buildAssignmentReviewStep(),
            isActive: _currentStep >= 3,
          ),
          // Step 5: Final Summary
          Step(
            title: const Text('Final Summary'),
            content: _buildFinalSummaryStep(),
            isActive: _currentStep >= 4,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptUploadStep() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _imageFile!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            const Icon(Icons.cloud_upload, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Upload Receipt Image',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Take a picture or select from gallery'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Picture'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParsedReceiptStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Review & Edit Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: MediaQuery.of(context).size.height * 0.3,
          child: ListView.builder(
            itemCount: _editableItems.length,
            itemBuilder: (context, index) {
              final item = _editableItems[index];
              // Ensure controllers are available for this index
              if (index >= _itemPriceControllers.length) return SizedBox.shrink(); 
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.name)),
                      // Price TextField
                      SizedBox(
                        width: 70, // Slightly wider for price
                        child: TextField(
                          controller: _itemPriceControllers[index],
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            prefixText: '\$',
                            isDense: true,
                          ),
                          textAlign: TextAlign.right,
                           style: TextStyle(fontSize: 14), // Smaller font
                        ),
                      ),
                      const SizedBox(width: 8), // Spacing
                      // Quantity Buttons
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        tooltip: 'Decrease Quantity',
                        onPressed: () {
                          if (item.quantity > 1) {
                            setState(() {
                              item.quantity--;
                              // Optional: Update controller if needed, though it's removed
                            });
                          } else {
                            // Optionally remove item if quantity reaches 0
                            // _removeItem(index);
                          }
                        },
                      ),
                      Text('${item.quantity}', style: TextStyle(fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        tooltip: 'Increase Quantity',
                        onPressed: () {
                          setState(() {
                            item.quantity++;
                             // Optional: Update controller if needed
                          });
                        },
                      ),
                       // Remove Item Button
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                         iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
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
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:'),
                    Text('\$${_calculateSubtotal().toStringAsFixed(2)}'),
                  ],
                ),
                const SizedBox(height: 8),
                // Tax Slider
                Row(
                  children: [
                    const Text('Tax:'),
                    Expanded(
                      child: Slider(
                        value: _taxPercentage,
                        min: 0,    // Min US tax is 0%
                        max: 15,   // Max common US tax ~11-12%, allow some buffer
                        // divisions: 1500, // ~0.01% precision if needed, or remove for continuous
                        label: '${_taxPercentage.toStringAsFixed(3)}%', // Show more precision
                        onChanged: (value) {
                          setState(() {
                            _taxPercentage = value;
                          });
                        },
                      ),
                    ),
                    // Consider Text Field for precise tax input if slider is too coarse
                    SizedBox(
                      width: 70,
                      child: Text('${_taxPercentage.toStringAsFixed(3)}%', textAlign: TextAlign.right),
                    ),
                  ],
                ),
                // Tip Slider
                Row(
                   children: [
                    const Text('Tip:'),
                    Expanded(
                      child: Slider(
                        value: _tipPercentage,
                        min: 0,
                        max: 50,
                        divisions: 50,
                        label: '${_tipPercentage.round()}%',
                        onChanged: (value) {
                          setState(() {
                            _tipPercentage = value;
                          });
                        },
                      ),
                    ),
                     SizedBox(
                      width: 70,
                      child: Text('${_tipPercentage.toStringAsFixed(1)}%', textAlign: TextAlign.right),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${_calculateTotal().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceAssignmentStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mic, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        const Text(
          'Voice Assignment',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Speak clearly to assign items to people\nExample: "John ordered the burger and fries"',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _isRecording = !_isRecording;
            });
          },
          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
          label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording ? Colors.red : Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
        if (_isRecording) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildAssignmentReviewStep() {
    return Column(
      children: [
        // Individual Assignments
        const Text('Individual Items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Expanded(
          child: ListView.builder(
            itemCount: MockData.assignments.length,
            itemBuilder: (context, index) {
              final person = MockData.people[index];
              final assignedMockItems = MockData.assignments[person] ?? [];
              // Filter _editableItems based on assignedMockItems names for display (Simple approach)
              final currentAssignedItems = _editableItems.where((editItem) => 
                  assignedMockItems.any((mockItem) => mockItem.name == editItem.name)).toList();
              
              return ExpansionTile(
                title: Text(person),
                children: currentAssignedItems.map((item) {
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text('\$${item.price.toStringAsFixed(2)}'),
                    trailing: Text('x${item.quantity}'),
                  );
                }).toList(),
              );
            },
          ),
        ),
        // Shared Items
        const Text('Shared Items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: MockData.sharedItems.length,
          itemBuilder: (context, index) {
            final item = MockData.sharedItems[index];
             // Find corresponding editable item if exists (or just display mock data)
             final editableSharedItem = _editableItems.firstWhere((editItem) => editItem.name == item.name, orElse: () => item);
            return Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(editableSharedItem.name),
                    subtitle: Text('\$${editableSharedItem.price.toStringAsFixed(2)}'),
                  ),
                  Wrap(
                    spacing: 8,
                    children: MockData.people.map((person) {
                      return FilterChip(
                        label: Text(person),
                        selected: true, // TODO: Needs state for selection
                        onSelected: (bool selected) {
                          // TODO: Implement shared item selection logic
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFinalSummaryStep() {
    return Column(
      children: [
        const Text('Final Amounts',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...MockData.people.map((person) {
          return Card(
            child: ListTile(
              title: Text(person),
              trailing: Text(
                '\$${_calculatePersonTotal(person).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            // TODO: Implement payment processing
          },
          child: const Text('Complete Split'),
        ),
      ],
    );
  }

  // Helper methods for calculations
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
    // TODO: This calculation needs to be completely revised based on _editableItems and actual assignments
    // Mock calculation remains for now
    return _calculateTotal() / MockData.people.length;
  }

  // Helper function to remove item and controllers safely
  void _removeItem(int index) {
    setState(() {
      _editableItems.removeAt(index);
      _itemPriceControllers.removeAt(index).dispose();
      // No quantity controller to remove anymore
      // _itemQuantityControllers.removeAt(index).dispose(); 
    });
  }

  void _showStartOverConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Use a different context name
        return AlertDialog(
          title: const Text('Start Over?'),
          content: const Text('Are you sure you want to start over? All current progress will be lost.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
                _resetState(); // Call the reset function
              },
            ),
          ],
        );
      },
    );
  }

  void _resetState() {
     // Dispose existing controllers before creating new ones
    _itemPriceControllers.forEach((controller) => controller.dispose());
    // _itemQuantityControllers.forEach((controller) => controller.dispose()); // Already removed

    setState(() {
      _currentStep = 0;
      _imageFile = null;
      _taxPercentage = 8.876; // Reset to default
      _tipPercentage = 15.0; // Reset to default
      // Re-initialize items and controllers from mock data
      _initializeEditableItems(); 
    });
  }
} 