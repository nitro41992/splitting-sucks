import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'models/split_manager.dart';
import 'receipt_splitter_ui.dart';
import 'services/mock_data_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'routes.dart';
import 'firebase_options.dart';

// Global variable to track initialization
bool firebaseInitialized = false;

void main() async {
  // Wait for Flutter to be fully initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase at the entry point
  try {
    // Only initialize if it hasn't been initialized yet
    if (Firebase.apps.isEmpty) {
      debugPrint("Initializing Firebase in main() function...");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Configure Firebase Auth persistence to fix the "missing initial state" issue
      // This addresses problems with browser sessionStorage in web/PWA contexts and
      // similar state persistence issues in the Android app
      try {
        // For Android, set the persistence to LOCAL (default is already LOCAL on native platforms)
        if (!kIsWeb && Platform.isAndroid) {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint("Firebase Auth persistence set to LOCAL for Android");
        }
        
        // For web, explicitly set persistence to prevent issues with sessionStorage
        if (kIsWeb) {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint("Firebase Auth persistence set to LOCAL for Web");
        }
      } catch (e) {
        debugPrint("Error setting persistence: $e - continuing anyway");
      }
      
      debugPrint("Firebase successfully initialized in main()");
      firebaseInitialized = true;
    } else {
      debugPrint("Firebase already initialized, using existing instance");
      firebaseInitialized = true;
    }
  } catch (e) {
    debugPrint("Error initializing Firebase in main(): $e");
    // Continue with the app, the FirebaseInit widget will handle retries
  }
  
  // Entry point
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide AuthService globally
        Provider<AuthService>(
          create: (_) => AuthService(),
          dispose: (_, service) => service.dispose(),
        ),
        // Stream of auth state changes
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Billfie',
        theme: AppTheme.lightTheme,
        home: firebaseInitialized ? const ReceiptSplitterUI() : const FirebaseInit(),
        routes: Routes.getRoutes(),
        onGenerateRoute: (settings) {
          if (settings.name == '/signup') {
            return MaterialPageRoute(
              builder: (_) => Routes.getRoutes()['/signup']!(_),
            );
          } else if (settings.name == '/forgot-password') {
            return MaterialPageRoute(
              builder: (_) => Routes.getRoutes()['/forgot-password']!(_),
            );
          }
          return null;
        },
      ),
    );
  }
}

class FirebaseInit extends StatefulWidget {
  const FirebaseInit({super.key});

  @override
  State<FirebaseInit> createState() => _FirebaseInitState();
}

class _FirebaseInitState extends State<FirebaseInit> {
  // Initialize state
  bool _initialized = false;
  bool _error = false;
  String _errorMessage = "";

  // Initialize Firebase
  void initializeFirebase() async {
    try {
      debugPrint("Attempting Firebase initialization from widget...");
      
      // Check if already initialized
      if (Firebase.apps.isNotEmpty) {
        debugPrint("Firebase already initialized, using existing instance");
        setState(() {
          _initialized = true;
        });
        return;
      }
      
      // Initialize Firebase only if not already initialized
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Configure Firebase Auth persistence (backup in case it wasn't set in main)
      try {
        // For Android, set the persistence to LOCAL
        if (!kIsWeb && Platform.isAndroid) {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint("Firebase Auth persistence set to LOCAL for Android");
        }
        
        // For web, explicitly set persistence
        if (kIsWeb) {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint("Firebase Auth persistence set to LOCAL for Web");
        }
      } catch (e) {
        debugPrint("Error setting persistence: $e - continuing anyway");
      }
      
      debugPrint("Firebase successfully initialized from widget");
      
      setState(() {
        _initialized = true;
      });
      
    } catch (e) {
      debugPrint("Firebase initialization failed: $e");
      setState(() {
        _error = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void initState() {
    initializeFirebase();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Show error
    if (_error) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Firebase Initialization Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = false;
                    _initialized = false;
                  });
                  initializeFirebase();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show loading
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Firebase...'),
            ],
          ),
        ),
      );
    }

    // Show app
    return const ReceiptSplitterUI();
  }
}

class AppWithProviders extends StatelessWidget {
  const AppWithProviders({super.key});
  
  @override
  Widget build(BuildContext context) {
    // Always use real data
    const useMockData = false;
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => useMockData 
              ? MockDataService.createMockSplitManager() 
              : SplitManager(),
        ),
        Provider<AuthService>(
          create: (_) => AuthService(),
          dispose: (_, service) => service.dispose(),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Billfie',
        theme: AppTheme.lightTheme,
        routes: Routes.getRoutes(),
        home: const ReceiptSplitterUI(),
      ),
    );
  }
}
