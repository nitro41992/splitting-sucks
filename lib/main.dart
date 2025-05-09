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
import 'screens/main_navigation.dart';
import 'services/mock_data_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'routes.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// Flag to track if Firebase initialized successfully
bool firebaseInitialized = false;

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env file
  try {
    await dotenv.load(fileName: ".env");
    debugPrint(".env file loaded successfully.");
  } catch (e) {
    debugPrint("Error loading .env file: $e (THIS IS NORMAL if running in prod or .env doesn't exist)");
  }

  try {
    // Initialize Firebase
    debugPrint("Attempting Firebase.initializeApp...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase.initializeApp completed.");

    // Set Firebase Auth persistence
    // IMPORTANT: Only set persistence if NOT on Web AND using Android/iOS.
    //            For Web, it's set by default or handled differently.
    //            Avoid setting persistence on unsupported platforms.
    if (!kIsWeb) {
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint("FirebaseAuth persistence set to LOCAL for mobile.");
        } catch (e) {
          debugPrint("Error setting FirebaseAuth persistence on mobile (might be okay if already set or not critical): $e");
        }
      }
    } else { // Web
        try {
            await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
            debugPrint("Firebase Auth persistence set to LOCAL for Web (explicit).");
        } catch (e) {
            debugPrint("Error setting FirebaseAuth persistence on web: $e");
        }
    }
    
    // Activate Firebase App Check
    // TODO: Ensure your App Check providers (Play Integrity/Device Check/App Attest) are configured
    // in your Firebase project console.
    try {
      await FirebaseAppCheck.instance.activate(
        // You must provide a webRecaptchaSiteKey for web builds.
        // Default is `androidDebugProvider: true` for Android debug builds.
        // Default is `appleDebugProvider: true` for Apple debug builds.
        webProvider: ReCaptchaV3Provider('YOUR_RECAPTCHA_V3_SITE_KEY'), // REPLACE with your actual key if targeting web
        androidProvider: AndroidProvider.debug, // Or AndroidProvider.playIntegrity for release
        appleProvider: AppleProvider.debug, // Or AppleProvider.appAttest for release
      );
      debugPrint("Firebase App Check activated.");
    } catch (e) {
      debugPrint("Error activating Firebase App Check: $e. Ensure providers are configured and keys are correct.");
    }
    
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    firebaseInitialized = false; // Ensure this is set on error
  }
  
  runApp(const AppWithProviders());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // This widget now just decides between LoginScreen and MainNavigation
    // It no longer returns a MaterialApp.
    if (!firebaseInitialized) {
      return const Scaffold(body: Center(child: Text("Failed to initialize Firebase")));
    }

    return StreamBuilder<User?>(
      stream: context.watch<AuthService>().authStateChanges, // Use context.watch if directly under Provider
      builder: (context, snapshot) {
        // ... (existing debug prints for snapshot state)
        debugPrint('[MyApp StreamBuilder] ConnectionState: ${snapshot.connectionState}');
        debugPrint('[MyApp StreamBuilder] HasData: ${snapshot.hasData}');
        debugPrint('[MyApp StreamBuilder] Data: ${snapshot.data}');
        debugPrint('[MyApp StreamBuilder] HasError: ${snapshot.hasError}');
        debugPrint('[MyApp StreamBuilder] Error: ${snapshot.error}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.blue, // Distinct color
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), Text('Waiting for Auth...')]),
            ),
          );
        }
        
        if (snapshot.hasData) {
          debugPrint('[MyApp StreamBuilder] User detected, returning MainNavigation');
          return const MainNavigation();
        }
        
        debugPrint('[MyApp StreamBuilder] No user detected, returning LoginScreen');
        return const LoginScreen();
      },
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
    const useMockData = false; // Keep this if needed for testing
    
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
        // StreamProvider for User? is no longer strictly necessary here if MyApp uses context.watch
        // However, if other parts of the app might need to Provider.of<User?>(context), it can be kept.
        // For this specific refactor, let's assume MyApp's context.watch is sufficient.
        // If keeping, ensure it uses context.read for create:
        // StreamProvider<User?>(
        //   create: (context) => context.read<AuthService>().authStateChanges,
        //   initialData: FirebaseAuth.instance.currentUser, // More robust initialData
        //   catchError: (_, error) {
        //     debugPrint("Error in authStateChanges stream: $error");
        //     return null;
        //   },
        // ),
      ],
      child: MaterialApp( // This is now the SINGLE, ROOT MaterialApp
        navigatorKey: navigatorKey, // Assign the global navigator key
        title: 'Billfie',
        theme: AppTheme.lightTheme,
        routes: Routes.getRoutes(),
        home: const MyApp(), // MyApp now just returns the content based on auth state
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
