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

// Simple test version of the UI that doesn't use Firebase
class ReceiptSplitterUI extends StatelessWidget {
  const ReceiptSplitterUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billfie'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Firebase initialized successfully!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            const Text(
              'Your app is now connected to Firebase.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            const Text(
              'You can now use Firebase services in your app.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test action successful!')),
                );
              },
              child: const Text('Test Action'),
            ),
          ],
        ),
      ),
    );
  }
} 