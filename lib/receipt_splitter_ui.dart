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

class ReceiptSplitterUI extends StatelessWidget {
  const ReceiptSplitterUI({super.key});

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
        
        // If logged in, show the main app
        return Scaffold(
          appBar: AppBar(
            title: const Text('Billfie'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                    debugPrint('User signed out');
                  } catch (e) {
                    debugPrint('Error signing out: $e');
                  }
                },
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
  const MainPageController({super.key});

  @override
  State<MainPageController> createState() => _MainPageControllerState();
}

class _MainPageControllerState extends State<MainPageController> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  List<ReceiptItem> _receiptItems = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<NavigateToPageNotification>(
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
          },
          children: [
            // Page 0: Receipt Upload
            ReceiptScreenWrapper(
              onReviewComplete: (items) {
                setState(() {
                  _receiptItems = items;
                });
                _navigateToPage(1); // Navigate to receipt review
              },
            ),
            
            // Page 1: Receipt Review
            ReceiptReviewScreen(
              initialItems: _receiptItems,
              onReviewComplete: (updatedItems, deletedItems) {
                // Save updated items to SplitManager
                final splitManager = Provider.of<SplitManager>(context, listen: false);
                splitManager.setReceiptItems(updatedItems);
                
                // Navigate to the next page (Voice Assignment)
                _navigateToPage(2);
              },
            ),
            
            // Page 2: Voice Assignment
            VoiceAssignmentScreen(
              itemsToAssign: _receiptItems,
              onAssignmentProcessed: (assignmentData) {
                // Process assignments and navigate to next page
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
    );
  }
  
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentPage == 0 ? 0 : _currentPage - 1, // Adjust based on current page
      onTap: (index) {
        if (index == 0) {
          _navigateToPage(0); // Navigate to upload
        } else {
          _navigateToPage(index); // Navigate to other pages (already adjusted index)
        }
      },
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.upload_file),
          label: 'Upload',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Review',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.record_voice_over),
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
    );
  }
}

// Wrapper class for ReceiptUploadScreen to manage state
class ReceiptScreenWrapper extends StatefulWidget {
  final Function(List<ReceiptItem>)? onReviewComplete;

  const ReceiptScreenWrapper({super.key, this.onReviewComplete});

  @override
  State<ReceiptScreenWrapper> createState() => _ReceiptScreenWrapperState();
}

class _ReceiptScreenWrapperState extends State<ReceiptScreenWrapper> {
  File? _imageFile;
  bool _isLoading = false;

  void _handleImageSelected(File? file) {
    setState(() {
      _imageFile = file;
    });
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt processed successfully!')),
      );
      
      // If onReviewComplete is provided, call it with the parsed items
      if (widget.onReviewComplete != null) {
        widget.onReviewComplete!(items);
      }
      
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing receipt: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
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
  }

  @override
  Widget build(BuildContext context) {
    return ReceiptUploadScreen(
      imageFile: _imageFile,
      isLoading: _isLoading,
      onImageSelected: _handleImageSelected,
      onParseReceipt: _handleParseReceipt,
      onRetry: _handleRetry,
    );
  }
} 