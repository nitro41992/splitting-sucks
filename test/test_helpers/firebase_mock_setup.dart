// Helper utilities for mocking Firebase in tests

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/services.dart';

// Mock for Firebase app
class MockFirebaseApp implements FirebaseApp {
  @override
  String get name => '[DEFAULT]';
  
  @override
  FirebaseOptions get options => FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-messaging-sender-id',
    projectId: 'test-project-id',
  );
  
  @override
  Future<void> delete() async {}
  
  @override
  bool operator ==(Object other) => 
    identical(this, other) || 
    other is MockFirebaseApp && name == other.name;
  
  @override
  int get hashCode => name.hashCode;
  
  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}
  
  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}
  
  @override
  bool get isAutomaticDataCollectionEnabled => false;
}

// Mock utility class
class FirebaseMock {
  static bool get isTestEnvironment => true;
  static String get mockUserId => 'test-user-id';
  static bool get isFirebaseInitialized => true;
}

// Setup mocks for platform channels
class _MockFirebasePlatform extends FirebasePlatform {
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseApp() as FirebaseAppPlatform;
  }
  
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseApp() as FirebaseAppPlatform;
  }
  
  @override
  List<FirebaseAppPlatform> get apps {
    return [MockFirebaseApp() as FirebaseAppPlatform];
  }
}

// Setup Firebase for testing
Future<void> setupFirebaseForTesting() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Setup the mock handlers for platform messages
  // This will intercept Firebase initialization calls and return mocked values
  FirebasePlatform.instance = _MockFirebasePlatform();
  
  // Handle any method channels for Firebase services
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    MethodChannel('plugins.flutter.io/firebase_core'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'Firebase#initializeCore':
          return [
            {
              'name': '[DEFAULT]',
              'options': {
                'apiKey': 'test-api-key',
                'appId': 'test-app-id',
                'messagingSenderId': 'test-messaging-sender-id',
                'projectId': 'test-project-id',
              },
              'pluginConstants': {},
            }
          ];
        case 'Firebase#initializeApp':
          return {
            'name': '[DEFAULT]',
            'options': {
              'apiKey': 'test-api-key',
              'appId': 'test-app-id',
              'messagingSenderId': 'test-messaging-sender-id',
              'projectId': 'test-project-id',
            },
            'pluginConstants': {},
          };
        default:
          return null;
      }
    },
  );
  
  print('Firebase test environment configured');
} 