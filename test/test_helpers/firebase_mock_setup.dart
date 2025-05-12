// Helper utilities for mocking Firebase in tests

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

// Mock utility to skip Firebase tests or run with mock dependencies
class FirebaseMock {
  static bool get isTestEnvironment => true;
  static String get mockUserId => 'test-user-id';
  static bool get isFirebaseInitialized => true;
}

// Setup Firebase for testing
Future<void> setupFirebaseForTesting() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // This simpler approach focuses on providing flags and utility functions
  // that tests can use to bypass actual Firebase initialization
  print('Firebase test environment configured');
} 