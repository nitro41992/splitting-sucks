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
            backgroundColor: Colors.green,
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
    final user = FirebaseAuth.instance.currentUser;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
          const SizedBox(height: 20),
          Text(
            'Welcome ${user?.displayName ?? user?.email ?? "User"}!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your app is ready to use.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptScreenWrapper(),
                ),
              );
            },
            child: const Text('Upload Receipt'),
          ),
        ],
      ),
    );
  }
}

// Wrapper class for ReceiptUploadScreen to manage state
class ReceiptScreenWrapper extends StatefulWidget {
  const ReceiptScreenWrapper({super.key});

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

  void _handleParseReceipt() {
    if (_imageFile == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    // Simulate processing
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });
      
      // Navigate to next screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt processed successfully!')),
        );
      }
    });
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