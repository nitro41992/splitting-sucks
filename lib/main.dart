import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/split_manager.dart';
import 'receipt_splitter_ui.dart';
import 'screens/main_navigation.dart';
import 'services/mock_data_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'routes.dart';
import 'firebase_options.dart';

// Flag to track if Firebase initialized successfully
bool firebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Firebase
  try {
    if (Firebase.apps.isEmpty) {
      debugPrint("Attempting Firebase.initializeApp as Firebase.apps is empty...");
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform, // Ensure options are passed
      );
      firebaseInitialized = true;
      debugPrint("Firebase.initializeApp completed successfully.");
    } else {
      debugPrint("Firebase.apps was not empty. Using existing [DEFAULT] app.");
      // Get the existing app instance
      Firebase.app();
      firebaseInitialized = true; 
    }
    
    // Check if using emulator and CONFIGURE services if so
    final bool useEmulator = dotenv.env['USE_FIRESTORE_EMULATOR'] == 'true';
    if (useEmulator) {
      try {
        debugPrint('🔧 Configuring Firebase services for EMULATOR mode...');
        
        const localDevIp = '192.168.0.152'; // Your actual Wi-Fi IP

        // Configure Auth Emulator
        await FirebaseAuth.instance.useAuthEmulator(localDevIp, 9099);
        debugPrint('  - Auth Emulator configured for $localDevIp:9099');
        
        // Configure Firestore Emulator
        FirebaseFirestore.instance.useFirestoreEmulator(localDevIp, 8081);
        debugPrint('  - Firestore Emulator configured for $localDevIp:8081');

        // Configure Storage Emulator
        await FirebaseStorage.instance.useStorageEmulator(localDevIp, 9199);
        debugPrint('  - Storage Emulator configured for $localDevIp:9199');
        
        // Configure Functions Emulator
        FirebaseFunctions.instance.useFunctionsEmulator(localDevIp, 5001);
        debugPrint('  - Functions Emulator configured for $localDevIp:5001');

        // Auto sign-in should use the service provided later by AppWithProviders
        // Do NOT create a separate instance here.
        // debugPrint('  - Calling autoSignInForEmulator...');
        // final authService = AuthService(); // REMOVE THIS INSTANCE
        // await authService.autoSignInForEmulator(); // REMOVE THIS CALL
        // debugPrint('  - autoSignInForEmulator call finished.');
        debugPrint('  - Emulator configuration complete. Auto sign-in will be attempted by AuthService provider.');

      } catch (e) {
        debugPrint("Error configuring Firebase Emulators: $e");
        // Decide how to handle emulator config failure - maybe prevent app start?
        firebaseInitialized = false; // Mark as failed if emulator setup fails
      }
    }
  } catch (e) {
    // Add special handling for duplicate app error
    if (e.toString().contains('core/duplicate-app')) {
      debugPrint("Handling duplicate app error gracefully...");
      try {
        // Get the existing app instance
        Firebase.app();
        firebaseInitialized = true;
        debugPrint("Successfully recovered using existing Firebase app.");
      } catch (innerError) {
        debugPrint("CRITICAL: Could not recover from Firebase init error: $innerError");
        firebaseInitialized = false;
      }
    } else {
      debugPrint("CRITICAL Error during Firebase setup in main(): $e");
      if (e.toString().contains("[core/duplicate-app]")) {
          debugPrint("ERROR DETAILS: Received [core/duplicate-app] despite Firebase.apps.isEmpty check or during re-initialization attempt.");
      }
      firebaseInitialized = false;
    }
  }
  
  runApp(const AppWithProviders());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AuthService is now provided by AppWithProviders
    // final authService = AuthService(); // REMOVE THIS LINE

    return MaterialApp(
      title: 'Billfie',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: !firebaseInitialized 
        ? const Scaffold(body: Center(child: Text("Failed to initialize Firebase")))
        : StreamBuilder<User?>(
            // Use the stream from the provided AuthService
            stream: context.read<AuthService>().authStateChanges, // Use context.read
            builder: (context, snapshot) {
              debugPrint('[MyApp StreamBuilder] ConnectionState: ${snapshot.connectionState}');
              debugPrint('[MyApp StreamBuilder] HasData: ${snapshot.hasData}');
              debugPrint('[MyApp StreamBuilder] Data: ${snapshot.data}');
              debugPrint('[MyApp StreamBuilder] HasError: ${snapshot.hasError}');
              debugPrint('[MyApp StreamBuilder] Error: ${snapshot.error}');

              // Show spinner while waiting for the stream's initial value
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.blue, // Distinct color
                  body: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), Text('Waiting for Auth...')]),
                  ),
                );
              }
              
              // If the stream has emitted a user object, show the main app
              if (snapshot.hasData) {
                debugPrint('[MyApp StreamBuilder] User detected, returning MainNavigation');
                // User is logged in (or emulator auto-sign-in worked)
                return const MainNavigation(); // Restore original
              }
              
              // If no user data, show the LoginScreen
              debugPrint('[MyApp StreamBuilder] No user detected, returning LoginScreen');
              return const LoginScreen(); // Restore original
            },
          ),
      routes: Routes.getRoutes(),
    );
  }
}

/// Wrapper widget that shows either the login screen or the main app
/// based on authentication state
/// This widget might no longer be necessary as StreamBuilder handles it directly
/*
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    
    if (user == null) {
      return const LoginScreen();
    }
    
    return const MainNavigation();
  }
}
*/

/*
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
        // For Android, set the persistence to LOCAL - Check if kIsWeb first
        if (!kIsWeb && Platform.isAndroid) {
          // This might still cause issues if setPersistence is not available
          // Consider removing or conditionalizing further based on actual need
          // await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint("Skipping Firebase Auth persistence setting on Android in FirebaseInit"); 
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

    // Show auth wrapper
    // If MyApp's StreamBuilder is now the entry point, FirebaseInit might not be needed
    // or its purpose changes. For now, keep it returning AuthWrapper.
    // HOWEVER, AuthWrapper needs a Provider<User?> above it.
    // Since MyApp provides the StreamBuilder, we might need to restructure
    // how FirebaseInit and AuthWrapper are used or provide the User stream differently.
    
    // To resolve the immediate linter error, keep AuthWrapper uncommented,
    // but acknowledge that `context.watch<User?>()` within it will fail without a Provider.
    // A proper fix involves rethinking the FirebaseInit/AuthWrapper structure.
    return const AuthWrapper(); 
  }
}
*/

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
          catchError: (_, error) {
            debugPrint("Error in authStateChanges stream: $error");
            return null;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Billfie',
        theme: AppTheme.lightTheme,
        routes: Routes.getRoutes(),
        home: const MyApp(), // Set MyApp as the home widget
        debugShowCheckedModeBanner: false, // Moved here
      ),
    );
  }
}
