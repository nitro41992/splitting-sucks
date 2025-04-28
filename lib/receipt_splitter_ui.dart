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
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';  // Added import for AppColors

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
  List<ReceiptItem> _deletedItems = []; // Track deleted items

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
  late TextEditingController _transcriptionController;

  // Add a flag to track subtotal collapse
  bool _isSubtotalCollapsed = true;

  @override
  void initState() {
    super.initState();
    
    // Check if we should use mock data
    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
    
    if (useMockData) {
      // Initialize with ALL mock data - include regular items, shared items and unassigned items
      _editableItems = [
        ...List.from(MockDataService.mockItems),
        ...List.from(MockDataService.mockSharedItems),
        ...List.from(MockDataService.mockUnassignedItems),
      ];
      
      // Remove duplicates (since unassigned items may be references to mockItems)
      _editableItems = _editableItems.toSet().toList();
      
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
    _transcriptionController = TextEditingController();
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
    
    // Show buttons when scrolling up, hide when scrolling down
    // Use a small threshold to make it more sensitive
    final scrollThreshold = 5.0;
    if ((currentPosition - _lastScrollPosition).abs() > scrollThreshold) {
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
    _transcriptionController.dispose();
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
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: _currentStep == 2 ? 16.0 : 16.0, // Add top padding for assign view
                bottom: 16.0,
              ),
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
        // Use the same comprehensive list as initState
        _editableItems = [
          ...List.from(MockDataService.mockItems),
          ...List.from(MockDataService.mockSharedItems),
          ...List.from(MockDataService.mockUnassignedItems),
        ];
        // Remove duplicates (important if unassigned/shared reference base items)
        _editableItems = _editableItems.toSet().toList();

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

    // Rebuild this step with CustomScrollView for better header handling
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
            if (scrollNotification is ScrollUpdateNotification) {
              setState(() {
                _isSubtotalCollapsed = scrollNotification.metrics.pixels > 50;
                _isFabVisible = !_isSubtotalCollapsed;
                _isContinueButtonVisible = !_isSubtotalCollapsed;
              });
            }
            return true;
          },
          child: CustomScrollView(
            controller: _itemsScrollController,
            slivers: [
              // Pinned, collapsible subtotal header
              SliverPersistentHeader(
                pinned: true,
                delegate: _SubtotalHeaderDelegate(
                  minHeight: 60,
                  maxHeight: 120,
                  isCollapsed: _isSubtotalCollapsed,
                  subtotal: _calculateSubtotal(),
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ),

              // Items List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Items',
                      style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
                    ),
                  ),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _editableItems[index];
                    if (index >= _itemPriceControllers.length) return const SizedBox.shrink();
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: InkWell(
                        onTap: () => _showEditDialog(context, item),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: colorScheme.surfaceVariant,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${item.quantity}x',
                                                style: textTheme.bodySmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '\$${item.price.toStringAsFixed(2)} each',
                                              style: textTheme.bodyMedium?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                      style: textTheme.titleMedium?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Add divider for visual separation
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: colorScheme.outlineVariant.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Edit name button - now just an icon button
                                  IconButton(
                                    onPressed: () => _showEditDialog(context, item),
                                    icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                                    style: IconButton.styleFrom(
                                      backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                    tooltip: 'Edit item name',
                                  ),
                                  const SizedBox(width: 8),
                                  // Quantity controls
                                  IconButton(
                                    onPressed: () {
                                      if (item.quantity > 0) {
                                        setState(() {
                                          item.updateQuantity(item.quantity - 1);
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.remove_circle_outline),
                                    tooltip: 'Decrease quantity',
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: textTheme.titleMedium,
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        item.updateQuantity(item.quantity + 1);
                                      });
                                    },
                                    icon: const Icon(Icons.add_circle_outline),
                                    tooltip: 'Increase quantity',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline),
                                    tooltip: 'Remove Item',
                                    onPressed: () => _removeItem(index),
                                    style: IconButton.styleFrom(
                                      foregroundColor: colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _editableItems.length,
                ),
              ),

              // Deleted Items Section (if any items are deleted)
              if (_deletedItems.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outlined, color: colorScheme.error, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Deleted Items',
                            style: textTheme.titleMedium?.copyWith(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _deletedItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            item.name,
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(
                            '${item.quantity}x \$${item.price.toStringAsFixed(2)} each',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                          trailing: TextButton.icon(
                            icon: const Icon(Icons.restore),
                            label: const Text('Restore'),
                            onPressed: () {
                              setState(() {
                                final restoredItem = _deletedItems.removeAt(index);
                                _editableItems.add(restoredItem);
                                _itemPriceControllers.add(
                                  TextEditingController(text: restoredItem.price.toStringAsFixed(2))
                                );
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _deletedItems.length,
                  ),
                ),
              ],

              // Bottom padding to ensure last items are fully visible
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
                duration: const Duration(milliseconds: 150), // Faster animation
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
                  duration: const Duration(milliseconds: 150), // Faster animation
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

  Widget _buildTotalRow(BuildContext context, {required String label, required String value, TextStyle? style, FontWeight? fontWeight}) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final effectiveStyle = style ?? textTheme.bodyMedium; // Default style

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: effectiveStyle?.copyWith(fontWeight: fontWeight)),
          Text(value, style: effectiveStyle?.copyWith(fontWeight: fontWeight)),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    int quantity = 1;
    const int maxNameLength = 15; // Same limit as in edit dialog

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_shopping_cart, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Add New Item'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item name field with character counter
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'Enter item name',
                        prefixIcon: const Icon(Icons.shopping_bag_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        counterText: '${nameController.text.length}/$maxNameLength',
                      ),
                      maxLength: maxNameLength,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (value) {
                        // Force rebuild to update counter
                        (context as Element).markNeedsBuild();
                      },
                      autofocus: true,
                    ),
                    // const SizedBox(height: 8),
                    // Text(
                    //   'Maximum $maxNameLength characters',
                    //   style: textTheme.bodySmall?.copyWith(
                    //     color: colorScheme.onSurfaceVariant,
                    //   ),
                    // ),
                    const SizedBox(height: 16),
                    // Price field
                    TextField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        prefixText: '\$ ',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    // Quantity selector - more compact design
                    Row(
                      children: [
                        // Icon(Icons.format_list_numbered, 
                        //   size: 20, 
                        //   color: colorScheme.primary
                        // ),
                        const SizedBox(width: 8),
                        Text(
                          'Quantity:',
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            if (quantity > 1) {
                              setState(() => quantity--);
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            quantity.toString(),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() => quantity++);
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text);
                    
                    if (name.isNotEmpty && name.length <= maxNameLength && price != null && price > 0) {
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
                      
                      // Show success snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added $name to the receipt'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: colorScheme.primaryContainer,
                          showCloseIcon: true,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please enter a valid name and price'),
                          backgroundColor: colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Item'),
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
      child: Column(
        children: [
          // Recording Controls Section
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mic_none, 
                    size: 48, 
                    color: _isRecording ? colorScheme.error : colorScheme.primary
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Assign Items via Voice',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button and speak clearly.\nExample: "John ordered the burger and fries"',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _toggleRecording,
                    icon: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic),
                    label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isRecording ? colorScheme.error : colorScheme.primary,
                      foregroundColor: _isRecording ? colorScheme.onError : colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: textTheme.titleMedium,
                    ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text('Processing...', style: textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),

          // Transcription Section (if available)
          if (_transcription != null) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon and title
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.transcribe,
                              color: colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transcription',
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Edit the transcription if needed',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Divider
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    
                    // Transcription text field
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: Stack(
                              children: [
                                TextField(
                                  controller: _transcriptionController,
                                  maxLines: 8,
                                  minLines: 5,
                                  decoration: InputDecoration(
                                    hintText: 'Edit transcription if needed...',
                                    hintStyle: textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                  style: textTheme.bodyLarge?.copyWith(
                                    height: 1.5,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _processTranscription,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Process Assignment'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.secondary,  // Using puce color
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Receipt Summary Section
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
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
                          Icon(Icons.receipt_long_outlined, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Receipt Summary',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: _editableItems.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${item.quantity}x',
                                    style: textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${_calculateSubtotal().toStringAsFixed(2)}',
                            style: textTheme.titleMedium?.copyWith(
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
            ],
          ),
          // Add bottom padding for better scroll experience
          const SizedBox(height: 32),
        ],
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
      
      // Use mock transcription with more detailed content
      setState(() {
        _transcription = "John ordered the burger and chicken wings. Sarah got the soda and milkshake. Mike had the salad and caesar salad. Emma took the pizza and nachos. The appetizer is shared between John and Sarah. The garlic bread is shared between everyone. The fries, ice cream, and coffee are still unassigned.";
        _transcriptionController.text = _transcription!;  // Update controller
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
            _transcriptionController.text = transcription;  // Update controller
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

      // Use the edited transcription from the controller
      final editedTranscription = _transcriptionController.text;

      // Check if we should use mock data - do this BEFORE any recording logic
      final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
      print('DEBUG: In _processTranscription, useMockData = $useMockData');
      
      if (useMockData) {
        print('DEBUG: Using mock data in _processTranscription');
        // Use the MockDataService's createMockSplitManager method instead of manual setup
        final mockSplitManager = MockDataService.createMockSplitManager();
        final splitManager = context.read<SplitManager>();
        
        // Transfer all data from the mock split manager to the real one
        splitManager.reset();
        
        // Add people
        for (final person in mockSplitManager.people) {
          splitManager.addPerson(person.name);
        }
        
        // Set original quantities for all mock items
        for (final item in MockDataService.mockItems) {
          splitManager.setOriginalQuantity(item, item.quantity);
        }
        
        // Add assigned items
        for (int i = 0; i < mockSplitManager.people.length; i++) {
          final mockPerson = mockSplitManager.people[i];
          final realPerson = splitManager.people[i]; // Same index as we just added them in same order
          
          for (final item in mockPerson.assignedItems) {
            splitManager.assignItemToPerson(item, realPerson);
          }
        }
        
        // Add shared items
        for (final sharedItem in mockSplitManager.sharedItems) {
          splitManager.addSharedItem(sharedItem);
          
          // Find which people share this item in the mock manager
          final peopleWithItem = mockSplitManager.getPeopleForSharedItem(sharedItem);
          
          // Assign to the same people in the real manager
          for (int i = 0; i < peopleWithItem.length; i++) {
            final personIndex = mockSplitManager.people.indexOf(peopleWithItem[i]);
            if (personIndex >= 0 && personIndex < splitManager.people.length) {
              splitManager.people[personIndex].addSharedItem(sharedItem);
            }
          }
        }
        
        // Add unassigned items
        for (final item in mockSplitManager.unassignedItems) {
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
        editedTranscription,
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
    // Get the SplitManager instance
    // final splitManager = Provider.of<SplitManager>(context, listen: false); // This might not be needed here anymore if only SplitView is returned

    // Return ONLY the SplitView widget (no parameters needed now)
    return const SplitView(); 
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
    final double tax = subtotal * (_taxPercentage / 100);
    final double tip = subtotal * (_tipPercentage / 100);
    final double total = subtotal + tax + tip;
    
    return ListView(
      children: [
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
          // Calculate this person's share of tax and tip
          final double personSubtotal = person.totalAssignedAmount + 
              splitManager.sharedItems.where((item) => 
                person.sharedItems.contains(item)).fold(0.0, 
                (sum, item) => sum + (item.price * item.quantity / 
                  splitManager.people.where((p) => 
                    p.sharedItems.contains(item)).length));
          
          final double personTaxShare = personSubtotal / subtotal * tax;
          final double personTipShare = personSubtotal / subtotal * tip;
          final double personFinalTotal = personSubtotal + personTaxShare + personTipShare;
          
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
                  
                  // Tax and tip row
                  const SizedBox(height: 12),
                  Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tax + Tip:',
                        style: textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      Text(
                        '\$${(personTaxShare + personTipShare).toStringAsFixed(2)}',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total:',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${personFinalTotal.toStringAsFixed(2)}',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
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
        
        // Complete & Share button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: ElevatedButton.icon(
            onPressed: () => _generateAndShareReceipt(context),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Complete & Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // Method to generate and share receipt image
  Future<void> _generateAndShareReceipt(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // In a real app, this would generate an image of the receipt
      // For now, we'll just show a success dialog
      Navigator.of(context).pop(); // Close loading dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Receipt Generated'),
          content: const Text('Your receipt has been generated and is ready to share!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // In a real app, this would share the receipt image
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Receipt shared successfully!')),
                );
              },
              child: const Text('Share'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating receipt: $e')),
      );
    }
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
      // Move the item to deleted items list
      _deletedItems.add(_editableItems[index]);
      _editableItems.removeAt(index);
      _itemPriceControllers.removeAt(index).dispose();

      // Show a snackbar with undo option
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Item moved to deleted items'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              setState(() {
                // Move the item back
                final item = _deletedItems.removeLast();
                _editableItems.insert(index, item);
                _itemPriceControllers.insert(
                  index,
                  TextEditingController(text: item.price.toStringAsFixed(2))
                );
              });
            },
          ),
        ),
      );
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

  void _showEditDialog(BuildContext context, ReceiptItem item) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toStringAsFixed(2));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const int maxNameLength = 15;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Edit Item'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                hintText: 'Enter item name',
                prefixIcon: const Icon(Icons.fastfood_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '${nameController.text.length}/$maxNameLength',
              ),
              maxLength: maxNameLength,
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                // Force rebuild to update counter
                (context as Element).markNeedsBuild();
              },
              autofocus: true,
            ),
            // const SizedBox(height: 8),
            // Text(
            //   'Maximum $maxNameLength characters',
            //   style: textTheme.bodySmall?.copyWith(
            //     color: colorScheme.onSurfaceVariant,
            //   ),
            // ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'Price',
                prefixText: '\$ ',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: textTheme.bodyLarge,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              final newName = nameController.text.trim();
              final newPrice = double.tryParse(priceController.text);
              
              if (newName.isNotEmpty && newName.length <= maxNameLength && newPrice != null && newPrice > 0) {
                setState(() {
                  item.updateName(newName);
                  item.updatePrice(newPrice);
                });
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtotalHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final bool isCollapsed;
  final double subtotal;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  _SubtotalHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.isCollapsed,
    required this.subtotal,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  double get minExtent => minHeight;
  
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Calculate the percentage of shrinking (0.0 to 1.0)
    final double shrinkPercentage = shrinkOffset / (maxExtent - minExtent);
    final bool shouldCollapse = shrinkPercentage > 0.5 || isCollapsed;
    
    // Calculate the current height based on shrink percentage
    // Ensure it's never less than minHeight
    final double currentHeight = (maxHeight - (shrinkOffset)).clamp(minHeight, maxHeight);
    
    return SizedBox(
      height: currentHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: currentHeight,
        decoration: BoxDecoration(
          color: shouldCollapse ? colorScheme.surface.withOpacity(0.9) : colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(shouldCollapse ? 0 : 12),
          boxShadow: shouldCollapse 
            ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
            : null,
        ),
        child: shouldCollapse 
          // Collapsed view - just the subtotal
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '\$${subtotal.toStringAsFixed(2)}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            )
          // Expanded view - full card with icon
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        color: colorScheme.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Subtotal',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '\$${subtotal.toStringAsFixed(2)}',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SubtotalHeaderDelegate oldDelegate) {
    return isCollapsed != oldDelegate.isCollapsed || 
           subtotal != oldDelegate.subtotal ||
           maxHeight != oldDelegate.maxHeight ||
           minHeight != oldDelegate.minHeight;
  }
} 