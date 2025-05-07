import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    await Firebase.initializeApp();
    firebaseInitialized = true;
    
    // Check if using emulator and auto-sign in if needed
    final bool useEmulator = dotenv.env['USE_FIRESTORE_EMULATOR'] == 'true';
    if (useEmulator) {
      // Auto sign-in for emulator mode
      final authService = AuthService();
      await authService.autoSignInForEmulator();
    }
  } catch (e) {
    debugPrint("Error initializing Firebase in main(): $e");
    firebaseInitialized = false;
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billfie',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: !firebaseInitialized 
        ? const Scaffold(body: Center(child: Text("Failed to initialize Firebase")))
        : Builder(
            builder: (context) {
              // Check if emulator mode is active to bypass auth
              final bool useEmulator = dotenv.env['USE_FIRESTORE_EMULATOR'] == 'true';
              
              if (useEmulator) {
                // Skip auth check completely in emulator mode
                debugPrint('🔧 Bypassing auth in emulator mode');
                return const MainNavigation();
              }
              
              // Continue with normal auth flow
              return StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  if (snapshot.hasData) {
                    // User is logged in
                    return const MainNavigation();
                  }
                  
                  // User is not logged in
                  return const LoginScreen();
                },
              );
            }
          ),
      routes: Routes.getRoutes(),
    );
  }
}

/// Wrapper widget that shows either the login screen or the main app
/// based on authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    
    // If user is not logged in, show login screen
    if (user == null) {
      return const LoginScreen();
    }
    
    // Otherwise, show the main navigation
    return const MainNavigation();
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

    // Show auth wrapper
    return const AuthWrapper();
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
