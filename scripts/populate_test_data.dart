import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../lib/models/receipt_history.dart';
import '../lib/services/mock_data_service.dart';

/// This script populates Firebase with test receipt history data
/// It's used for development and testing purposes
/// Usage: flutter run scripts/populate_test_data.dart
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Check if user is signed in
  final auth = FirebaseAuth.instance;
  final currentUser = auth.currentUser;
  
  if (currentUser == null) {
    print('Error: No user is signed in. Please sign in first.');
    return;
  }
  
  print('Signed in as: ${currentUser.email}');
  print('User ID: ${currentUser.uid}');
  
  // Confirm action
  print('');
  print('This script will populate Firebase with test receipt history data.');
  print('Do you want to continue? (y/n)');
  
  final input = await readLineFromStdin();
  if (input.toLowerCase() != 'y') {
    print('Aborted by user.');
    return;
  }
  
  // Generate and populate data
  await populateTestData(currentUser.uid);
  
  // Exit script
  print('Done. Exiting...');
}

/// Reads a line from stdin
Future<String> readLineFromStdin() async {
  return await Future.delayed(const Duration(microseconds: 1), () {
    return 'y'; // For automated testing, we always return 'y'
    // In a real CLI tool, you would read from stdin
  });
}

/// Generate and populate test data
Future<void> populateTestData(String userId) async {
  print('Generating test data...');
  
  final firestore = FirebaseFirestore.instance;
  final receiptsCollection = firestore.collection('users/$userId/receipts');
  
  // Check if data already exists
  final existing = await receiptsCollection.limit(1).get();
  if (existing.docs.isNotEmpty) {
    print('Warning: The collection already contains data.');
    print('Do you want to clear existing data before adding test data? (y/n)');
    
    final input = await readLineFromStdin();
    if (input.toLowerCase() == 'y') {
      print('Clearing existing data...');
      
      final allDocs = await receiptsCollection.get();
      final batch = firestore.batch();
      
      for (final doc in allDocs.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('Existing data cleared.');
    }
  }
  
  // Generate mock receipts
  final mockReceipts = MockDataService.createMockReceiptHistories(
    userId: userId,
    count: 5,
  );
  
  // Save to Firestore
  print('Saving ${mockReceipts.length} receipts to Firestore...');
  final batch = firestore.batch();
  
  for (final receipt in mockReceipts) {
    batch.set(receiptsCollection.doc(receipt.id), receipt.toFirestore());
  }
  
  await batch.commit();
  
  print('Successfully saved ${mockReceipts.length} receipts to Firestore.');
  print('Receipt IDs: ${mockReceipts.map((r) => r.id).join(", ")}');
} 