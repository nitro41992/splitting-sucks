import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/receipt_parser_service.dart';
import 'services/audio_transcription_service.dart';
import 'services/mock_data_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'widgets/split_view.dart';
import 'package:provider/provider.dart';
import 'models/split_manager.dart';
import 'models/receipt_item.dart';

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
  final AudioTranscriptionService _audioService = AudioTranscriptionService();
  final _recorder = AudioRecorder();
  String? _transcription;
  Map<String, dynamic>? _assignments;

  // Step completion tracking
  bool _isUploadComplete = false;
  bool _isReviewComplete = false;
  bool _isAssignmentComplete = false;

  // Controllers
  late List<TextEditingController> _itemPriceControllers;
  late TextEditingController _taxController;
  late List<ReceiptItem> _editableItems;
  late ScrollController _itemsScrollController;

  // Add a flag to track FAB visibility
  bool _isFabVisible = true;
  bool _isContinueButtonVisible = true;

  // For tracking scroll direction
  double _lastScrollPosition = 0;

  late AudioTranscriptionService _transcriptionService;

  @override
  void initState() {
    super.initState();
    
    // Check if we should use mock data
    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
    
    if (useMockData) {
      // Initialize with mock data
      _editableItems = List.from(MockDataService.mockItems);
      _itemPriceControllers = _editableItems.map((item) =>
        TextEditingController(text: item.price.toStringAsFixed(2))).toList();
      
      // Start at the first step
      _currentStep = 0;
      
      // Initialize completion flags as false
      _isUploadComplete = false;
      _isReviewComplete = false;
      _isAssignmentComplete = false;
    } else {
      _initializeEditableItems();
    }
    
    _taxController = TextEditingController(text: DEFAULT_TAX_RATE.toStringAsFixed(3));
    _itemsScrollController = ScrollController();
    _itemsScrollController.addListener(_onScroll);

    // Add listener for tax changes
    _taxController.addListener(() {
      final newTax = double.tryParse(_taxController.text);
      if (newTax != null && _taxController.text.isNotEmpty) {
        setState(() {
          _taxPercentage = newTax;
        });
      }
    });

    _transcriptionService = AudioTranscriptionService();
  }

  void _initializeEditableItems() {
    _editableItems = [];
    _itemPriceControllers = [];
  }

  // Method to handle scroll events and update FAB visibility
  void _onScroll() {
    final currentPosition = _itemsScrollController.position.pixels;
    final bool isScrollingDown = currentPosition > _lastScrollPosition;
    _lastScrollPosition = currentPosition;
    
    if (isScrollingDown != !_isFabVisible) {
      setState(() {
        _isFabVisible = !isScrollingDown;
        _isContinueButtonVisible = !isScrollingDown;
      });
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _itemPriceControllers.forEach((controller) => controller.dispose());
    _taxController.dispose();
    _itemsScrollController.removeListener(_onScroll);
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
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          // Only allow navigation to completed steps or the next available step
          if (index <= _currentStep || _canNavigateToStep(index)) {
            setState(() {
              _currentStep = index;
            });
          } else {
            // Return to the current step
            _pageController.jumpToPage(_currentStep);
          }
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
    _itemPriceControllers.forEach((controller) => controller.dispose());
    
    setState(() {
      _currentStep = 0;
      _pageController.jumpToPage(0);
      _imageFile = null;
      _tipPercentage = 20.0;
      _taxPercentage = DEFAULT_TAX_RATE;
      _taxController.text = DEFAULT_TAX_RATE.toStringAsFixed(3);
      _isRecording = false;
      _isUploadComplete = false;
      _isReviewComplete = false;
      _isAssignmentComplete = false;
      _transcription = null;  // Clear transcription
      _assignments = null;    // Clear assignments
      _initializeEditableItems();
    });
  }

  Future<void> _parseReceipt() async {
    if (_imageFile == null) return;

    // Check if we should use mock data - do this BEFORE setting loading state
    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
    print('DEBUG: In _parseReceipt, useMockData = $useMockData');
    print('DEBUG: USE_MOCK_DATA env value = ${dotenv.env['USE_MOCK_DATA']}');
    
    if (useMockData) {
      print('DEBUG: Using mock data in _parseReceipt');
      // Use mock data immediately without any loading state
      setState(() {
        _editableItems = List.from(MockDataService.mockItems);
        _itemPriceControllers = _editableItems.map((item) =>
          TextEditingController(text: item.price.toStringAsFixed(2))).toList();
        _isUploadComplete = true;
        _navigateToPage(1);
      });
      return;
    }

    print('DEBUG: Making API call in _parseReceipt');
    try {
      setState(() {
        _isLoading = true;
      });

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

        _itemPriceControllers = _editableItems.map((item) =>
          TextEditingController(text: item.price.toStringAsFixed(2))).toList();

        // Set original quantities in SplitManager
        final splitManager = context.read<SplitManager>();
        for (var item in _editableItems) {
          splitManager.setOriginalQuantity(item, item.quantity);
        }

        _isUploadComplete = true;
        _isLoading = false;
        _navigateToPage(1);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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

  // Add a method to mark review as complete
  void _markReviewComplete() {
    setState(() {
      _isReviewComplete = true;
    });
  }

  // Add a method to mark assignment as complete
  void _markAssignmentComplete() {
    setState(() {
      _isAssignmentComplete = true;
    });
  }

  Widget _buildReceiptUploadStep(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_imageFile != null)
              Expanded(
                child: Stack(
                  children: [
                    // Image Preview
                    Center(
                      child: GestureDetector(
                        onTap: () => _showFullImage(_imageFile!),
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _imageFile!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Overlay with actions
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              colorScheme.surface,
                              colorScheme.surface.withOpacity(0),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (_isLoading)
                              const CircularProgressIndicator()
                            else ...[
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _imageFile = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.errorContainer,
                                  foregroundColor: colorScheme.onErrorContainer,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _parseReceipt,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Use This'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 80,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Upload Receipt',
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Take a picture or select one from your gallery',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildUploadButton(
                          context,
                          icon: Icons.camera_alt,
                          label: 'Camera',
                          onPressed: _takePicture,
                          colorScheme: colorScheme,
                        ),
                        const SizedBox(width: 16),
                        _buildUploadButton(
                          context,
                          icon: Icons.photo_library,
                          label: 'Gallery',
                          onPressed: _pickImage,
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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

    // If no image has been parsed, show empty state
    if (_imageFile == null) {
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
                Icons.receipt_long_outlined,
                size: 60,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Receipt Uploaded',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please upload and parse a receipt first',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _navigateToPage(0),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Receipt'),
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
                                      _editableItems[index].updatePrice(newPrice);
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
                                        item.updateQuantity(item.quantity - 1);
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
                                      item.updateQuantity(item.quantity + 1);
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
        // Bottom buttons
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Row(
            children: [
              // FAB for adding items
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isFabVisible ? 1.0 : 0.0,
                child: FloatingActionButton(
                  onPressed: () => _showAddItemDialog(context),
                  child: const Icon(Icons.add),
                ),
              ),
              const SizedBox(width: 16),
              // Confirmation button
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isContinueButtonVisible ? 1.0 : 0.0,
                  child: SizedBox(
                    height: 56.0,
                    child: Material(
                      color: Colors.transparent,
                      child: ElevatedButton(
                        onPressed: () {
                          _markReviewComplete();
                          _navigateToPage(2);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 20,
                              color: colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Continue',
                              style: textTheme.titleSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

    // Check if items have been parsed
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
                Icons.mic_none_outlined,
                size: 60,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Items to Assign',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please upload and parse a receipt first',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _navigateToPage(0),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Receipt'),
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mic_none, 
              size: 100, 
              color: _isRecording ? colorScheme.error : colorScheme.primary
            ),
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
              onPressed: _isLoading ? null : _toggleRecording,
              icon: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic),
              label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? colorScheme.errorContainer : colorScheme.primaryContainer,
                foregroundColor: _isRecording ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                textStyle: textTheme.titleMedium,
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Text('Processing...', style: textTheme.bodySmall, textAlign: TextAlign.center),
            ] else if (_transcription != null) ...[
              const SizedBox(height: 24),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transcription:',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _transcription!,
                        style: textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton.icon(
                  onPressed: _processTranscription,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Process Assignment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: textTheme.titleMedium,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    // Check if we should use mock data - do this BEFORE any recording logic
    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
    print('DEBUG: In _toggleRecording, useMockData = $useMockData');
    print('DEBUG: USE_MOCK_DATA env value = ${dotenv.env['USE_MOCK_DATA']}');
    
    if (useMockData) {
      print('DEBUG: Using mock data in _toggleRecording');
      // Simulate a delay to mimic recording
      setState(() {
        _isLoading = true;
      });
      
      // Simulate processing delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Use mock transcription
      setState(() {
        _transcription = "John ordered the burger and fries. Sarah got the soda. Mike had the salad. Emma took the pizza. The fries are shared between everyone.";
        _isLoading = false;
      });
      return;
    }

    print('DEBUG: Using real recording in _toggleRecording');
    if (!_isRecording) {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required for voice assignment')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_recording.wav';
        
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            numChannels: 1,
            sampleRate: 16000,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _isLoading = false;
        });
      } catch (e) {
        print('Error starting recording: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    } else {
      try {
        final path = await _recorder.stop();
        setState(() {
          _isRecording = false;
          _isLoading = true;
        });

        if (path != null) {
          // Read the audio file as bytes
          final File audioFile = File(path);
          final Uint8List audioBytes = await audioFile.readAsBytes();
          
          // Get transcription from the service
          final transcription = await _transcriptionService.getTranscription(audioBytes);
          
          setState(() {
            _transcription = transcription;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error stopping recording: $e');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing recording: $e')),
        );
      }
    }
  }

  Future<void> _processTranscription() async {
    if (_transcription == null) return;

    try {
      setState(() => _isLoading = true);

      // Check if we should use mock data - do this BEFORE any recording logic
      final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
      print('DEBUG: In _processTranscription, useMockData = $useMockData');
      
      if (useMockData) {
        print('DEBUG: Using mock data in _processTranscription');
        // Use mock data instead of making API call
        final splitManager = context.read<SplitManager>();
        
        // Reset the split manager
        splitManager.reset();
        
        // Add people from mock data
        for (final personName in MockDataService.mockPeople) {
          splitManager.addPerson(personName);
        }

        // Set original quantities for all mock items
        for (final item in MockDataService.mockItems) {
          splitManager.setOriginalQuantity(item, item.quantity);
        }
        for (final item in MockDataService.mockSharedItems) {
          splitManager.setOriginalQuantity(item, item.quantity);
        }
        for (final item in MockDataService.mockUnassignedItems) {
          splitManager.setOriginalQuantity(item, item.quantity);
        }

        // Add assigned items from mock data
        MockDataService.mockAssignments.forEach((personName, items) {
          final person = splitManager.people.firstWhere((p) => p.name == personName);
          for (final item in items) {
            splitManager.assignItemToPerson(item, person);
          }
        });

        // Add shared items and assign them to the correct people based on MockDataService
        final friesItem = MockDataService.mockSharedItems[0]; // Assuming Fries is first
        splitManager.addItemToShared(friesItem, splitManager.people); // Assign Fries to everyone

        final appetizerItem = MockDataService.mockSharedItems[1]; // Assuming Appetizer is second
        final johnAndSarah = splitManager.people
            .where((p) => p.name == "John" || p.name == "Sarah")
            .toList();
        splitManager.addItemToShared(appetizerItem, johnAndSarah); // Assign Appetizer to John & Sarah

        // Add unassigned items from mock data
        for (final item in MockDataService.mockUnassignedItems) {
          splitManager.addUnassignedItem(item);
        }

        setState(() {
          _isAssignmentComplete = true;
          _isLoading = false;
        });

        // Navigate to the next step
        _navigateToPage(3);
        return;
      }

      print('DEBUG: Making API call in _processTranscription');
      // Convert editable items to a format suitable for the assignment service
      final jsonReceipt = {
        'items': _editableItems.map((item) => {
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
        }).toList(),
      };

      // Get assignments from the service
      final assignments = await _audioService.assignPeopleToItems(
        _transcription!,
        jsonReceipt,
      );

      // Update the SplitManager with the assignments
      final splitManager = context.read<SplitManager>();
      
      // Clear existing data
      splitManager.reset();

      // Add people
      final people = List<Map<String, dynamic>>.from(assignments['people'] ?? []);
      for (var personData in people) {
        splitManager.addPerson(personData['name'] as String);
      }

      // Add assigned items
      final orders = List<Map<String, dynamic>>.from(assignments['orders'] ?? []);
      for (var order in orders) {
        final personName = order['person'] as String;
        final person = splitManager.people.firstWhere((p) => p.name == personName);
        
        final item = ReceiptItem(
          name: order['item'] as String,
          price: (order['price'] as num).toDouble(),
          quantity: order['quantity'] as int,
        );
        
        // Set original quantity before assigning
        splitManager.setOriginalQuantity(item, item.quantity);
        splitManager.assignItemToPerson(item, person);
      }

      // Add shared items
      final sharedItems = List<Map<String, dynamic>>.from(assignments['shared_items'] ?? []);
      for (var itemData in sharedItems) {
        final item = ReceiptItem(
          name: itemData['item'] as String,
          price: (itemData['price'] as num).toDouble(),
          quantity: itemData['quantity'] as int,
        );
        
        // Set original quantity before adding to shared
        splitManager.setOriginalQuantity(item, item.quantity);
        
        final peopleNames = (itemData['people'] as List).cast<String>();
        final people = splitManager.people.where((p) => peopleNames.contains(p.name)).toList();
        
        splitManager.addItemToShared(item, people);
      }

      // Add unassigned items
      final unassignedItems = List<Map<String, dynamic>>.from(assignments['unassigned_items'] ?? []);
      for (var itemData in unassignedItems) {
        final item = ReceiptItem(
          name: itemData['item'] as String,
          price: (itemData['price'] as num).toDouble(),
          quantity: itemData['quantity'] as int,
        );
        
        // Set original quantity before adding to unassigned
        splitManager.setOriginalQuantity(item, item.quantity);
        
        splitManager.addUnassignedItem(item);
      }

      setState(() {
        _isAssignmentComplete = true;
        _isLoading = false;
      });

      // Navigate to the next step
      _navigateToPage(3);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing assignment: ${e.toString()}')),
      );
    }
  }

  Widget _buildAssignmentReviewStep(BuildContext context) {
    return const SplitView();
  }

  Widget _buildFinalSummaryStep(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

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
} 