import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'firebase_mock_setup.dart';

class TestUtil {
  static Future<void> initializeFirebaseCoreIfNecessary() async {
    await setupFirebaseForTesting();
  }
  
  static void setupTestErrorHandler() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };
  }
} 