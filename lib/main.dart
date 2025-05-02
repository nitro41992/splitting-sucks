import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/split_manager.dart';
import 'receipt_splitter_ui.dart';
import 'services/mock_data_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'routes.dart';
import 'firebase_options.dart';

void main() {
  // Entry point
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billfie',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const FirebaseInit(),
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
      debugPrint("Starting Firebase initialization...");
      
      // Wait for Flutter to be fully initialized
      WidgetsFlutterBinding.ensureInitialized();
      
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Test Firebase Auth initialization (important for debugging)
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        debugPrint('Auth state changed: ${user != null ? 'User is signed in' : 'User is signed out'}');
      });
      
      debugPrint("Firebase successfully initialized");
      
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
    // Use mock data by default for now
    const useMockData = true;
    
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
      child: Builder(
        builder: (context) {
          return Navigator(
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const ReceiptSplitterUI(),
                settings: settings,
              );
            },
          );
        }
      ),
    );
  }
}
