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

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase - with error handling
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
    // Continue with app initialization even if Firebase fails
  }
  
  // Initialize SharedPreferences (attempt but don't block on failure)
  try {
    await SharedPreferences.getInstance();
  } catch (e) {
    // Log error but continue
    debugPrint('Error initializing SharedPreferences: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp(
            title: 'Billfie',
            theme: AppTheme.lightTheme,
            routes: Routes.getRoutes(),
            home: StreamBuilder<User?>(
              stream: context.read<AuthService>().authStateChanges,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                // Always go to the main app screen first during development
                // Remove this line for production to enforce authentication
                return const ReceiptSplitterUI();
                
                // Below is the authentication flow code - comment out for now
                /*
                if (snapshot.hasData) {
                  return const ReceiptSplitterUI(); // User is signed in
                }
                
                return const LoginScreen(); // User is not signed in
                */
              },
            ),
          );
        }
      ),
    );
  }
}
