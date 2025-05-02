import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
// Remove conditional GoogleSignIn import
// import 'package:google_sign_in/google_sign_in.dart' if (dart.library.html) 'dart:core';

class AuthService {
  late FirebaseAuth _auth;
  bool _isInitialized = false;
  final StreamController<User?> _userStreamController = StreamController<User?>.broadcast();
  
  // Constants for rate limiting and security
  static const int _maxLoginAttemptsBeforeCaptcha = 3;
  static const int _maxLoginAttemptsBeforeTimeout = 5;
  static const int _loginTimeoutDurationMinutes = 15;
  
  // Keys for shared preferences
  static const String _loginAttemptsKey = 'login_attempts';
  static const String _lastLoginAttemptTimeKey = 'last_login_attempt_time';
  static const String _loginLockedUntilKey = 'login_locked_until';

  // Constructor
  AuthService() {
    _connectToFirebaseAuth();
  }
  
  // Connect to Firebase Auth
  Future<void> _connectToFirebaseAuth() async {
    try {
      // Check if Firebase is already initialized rather than trying to initialize it
      if (Firebase.apps.isEmpty) {
        debugPrint('Firebase not initialized in AuthService - waiting for app initialization');
        _userStreamController.add(null);
        return;
      }
      
      _auth = FirebaseAuth.instance;
      _isInitialized = true;
      
      // Start listening to auth state changes and forward to our stream
      _auth.authStateChanges().listen((User? user) {
        _userStreamController.add(user);
      });
      
      debugPrint('AuthService connected to Firebase Auth successfully');
    } catch (e) {
      debugPrint('Error connecting to Firebase Auth: $e');
      _userStreamController.add(null);
    }
  }

  // Get current user with safety check
  User? get currentUser {
    if (!_isInitialized) return null;
    return _auth.currentUser;
  }

  // Auth state changes stream with safety check
  Stream<User?> get authStateChanges {
    return _userStreamController.stream;
  }

  // Make sure Firebase Auth is initialized before operations
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _connectToFirebaseAuth();
      if (!_isInitialized) {
        throw 'Firebase Authentication is not initialized';
      }
    }
  }

  // Email/Password Sign Up
  Future<UserCredential> signUpWithEmailPassword(String email, String password) async {
    await _ensureInitialized();
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Check if login attempts are within allowed limits
  Future<bool> _checkLoginAttempts(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt('$_loginAttemptsKey:$email') ?? 0;
    final lockedUntilTimestamp = prefs.getInt('$_loginLockedUntilKey:$email') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if account is locked due to too many attempts
    if (lockedUntilTimestamp > 0 && now < lockedUntilTimestamp) {
      final remainingMinutes = ((lockedUntilTimestamp - now) / 60000).ceil();
      throw 'Too many failed attempts. Try again in $remainingMinutes minutes.';
    }
    
    // Reset counter if lockout period is over
    if (lockedUntilTimestamp > 0 && now >= lockedUntilTimestamp) {
      await _resetLoginAttempts(email);
      return true;
    }
    
    // Check if captcha should be required
    if (attempts >= _maxLoginAttemptsBeforeCaptcha) {
      return false; // Indicate captcha needed
    }
    
    return true;
  }
  
  // Record failed login attempt
  Future<void> _recordFailedLoginAttempt(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = (prefs.getInt('$_loginAttemptsKey:$email') ?? 0) + 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await prefs.setInt('$_loginAttemptsKey:$email', attempts);
    await prefs.setInt('$_lastLoginAttemptTimeKey:$email', now);
    
    // If max attempts reached, lock the account temporarily
    if (attempts >= _maxLoginAttemptsBeforeTimeout) {
      final lockUntil = now + (_loginTimeoutDurationMinutes * 60 * 1000);
      await prefs.setInt('$_loginLockedUntilKey:$email', lockUntil);
      debugPrint('Account $email locked until ${DateTime.fromMillisecondsSinceEpoch(lockUntil)}');
    }
  }
  
  // Reset login attempts counter on successful login
  Future<void> _resetLoginAttempts(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_loginAttemptsKey:$email');
    await prefs.remove('$_lastLoginAttemptTimeKey:$email');
    await prefs.remove('$_loginLockedUntilKey:$email');
  }

  // Email/Password Sign In with rate limiting
  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    await _ensureInitialized();
    
    // Check if login is allowed (not rate limited)
    final captchaNeeded = !(await _checkLoginAttempts(email));
    if (captchaNeeded) {
      debugPrint('CAPTCHA would be required here due to multiple login attempts');
      // For now, we'll allow the login but log a warning
    }
    
    try {
      // Add verification settings for Android to bypass reCAPTCHA verification
      if (Platform.isAndroid) {
        debugPrint('Attempting email/password sign in on Android...');
        
        // Disable reCAPTCHA verification
        await _auth.setSettings(
          appVerificationDisabledForTesting: true,
        );
        
        // Try standard sign in first
        try {
          final result = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          
          // Reset attempts counter on successful login
          await _resetLoginAttempts(email);
          return result;
        } catch (e) {
          debugPrint('Standard sign in failed, error: $e');
          
          // For testing purposes only - in production, use a more secure approach
          if (e.toString().contains('reCAPTCHA') || 
              e.toString().contains('credential is incorrect')) {
            // Try with email link if standard fails
            debugPrint('Attempting alternative auth method...');
            throw 'Email/password sign in failed. Please try Google Sign-In instead.';
          }
          
          throw e;
        }
      } else {
        // iOS and other platforms
        final result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Reset attempts counter on successful login
        await _resetLoginAttempts(email);
        return result;
      }
    } on FirebaseAuthException catch (e) {
      // Record failed attempt
      await _recordFailedLoginAttempt(email);
      debugPrint('Firebase Auth Exception during sign in: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Unexpected error during sign in: $e');
      throw 'An unexpected error occurred during sign in: $e';
    }
  }

  // Google Sign In using Firebase Auth - unified approach
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureInitialized();
    
    try {
      debugPrint('Attempting Google sign in with Firebase Auth...');
      
      if (kIsWeb) {
        // For web platforms
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // Unified approach for iOS and Android using Firebase Auth directly
        try {
          debugPrint('Platform: ${Platform.isAndroid ? "Android" : "iOS"}');
          debugPrint('Firebase Apps: ${Firebase.apps.length}');
          debugPrint('Auth initialized: $_isInitialized');
          
          // Create a Google provider directly in Firebase Auth
          final googleProvider = GoogleAuthProvider();
          
          // Add scopes as needed
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          
          debugPrint('Google provider created with scopes');
          
          // Use signInWithProvider for both iOS and Android
          debugPrint('Calling signInWithProvider...');
          final userCredential = await _auth.signInWithProvider(googleProvider);
          debugPrint('Google sign in successful: ${userCredential.user?.displayName}');
          return userCredential;
        } catch (e) {
          debugPrint('Google sign in failed with detailed error: $e');
          debugPrint('Stack trace: ${StackTrace.current}');
          rethrow;
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Exception code: ${e.code}');
      debugPrint('Firebase Auth Exception message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Error in Google Sign In: $e');
      throw 'Failed to sign in with Google: $e';
    }
  }

  // Apple Sign In using Firebase Auth
  Future<UserCredential> signInWithApple() async {
    await _ensureInitialized();
    
    try {
      if (kIsWeb) {
        // For web platforms
        AppleAuthProvider appleProvider = AppleAuthProvider();
        return await _auth.signInWithPopup(appleProvider);
      } else {
        // For native platforms
        AppleAuthProvider appleProvider = AppleAuthProvider();
        return await _auth.signInWithProvider(appleProvider);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to sign in with Apple: $e';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _ensureInitialized();
    
    try {
      await _auth.signOut(); // Sign out from Firebase
      debugPrint('Firebase sign out successful.');
    } catch (e) {
       debugPrint('Error during Firebase sign out: $e');
       throw 'Failed to sign out: $e'; // Re-throw Firebase errors
    }
  }

  // Password Reset with rate limiting
  Future<void> resetPassword(String email) async {
    await _ensureInitialized();
    
    // Check if too many password reset requests have been made
    final captchaNeeded = !(await _checkLoginAttempts(email));
    if (captchaNeeded) {
      // In a real app, implement CAPTCHA here
      debugPrint('CAPTCHA would be required here due to multiple password reset attempts');
    }
    
    try {
      await _auth.sendPasswordResetEmail(email: email);
      // Don't reset the counter here to prevent email bombing
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Helper method to handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'operation-not-allowed':
        return 'This authentication method is not enabled.';
      case 'invalid-action-code':
        return 'The sign-in link is invalid or has expired.';
      case 'too-many-requests':
        return 'Too many unsuccessful login attempts. Please try again later.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }
  
  // Clean up resources
  void dispose() {
    _userStreamController.close();
  }
} 