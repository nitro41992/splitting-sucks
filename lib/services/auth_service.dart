import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../utils/toast_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Remove conditional GoogleSignIn import
// import 'package:google_sign_in/google_sign_in.dart' if (dart.library.html) 'dart:core';

class AuthService {
  late FirebaseAuth _auth;
  bool _isInitialized = false;
  final StreamController<User?> _userStreamController = StreamController<User?>.broadcast();
  
  // For success toasts
  final StreamController<String> _successMessageController = StreamController<String>.broadcast();
  
  // Track active auth methods to show toasts on completion
  String? _lastSignInMethod;
  
  // Stream to listen for success messages
  Stream<String> get onLoginSuccess => _successMessageController.stream;
  
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
  
  // Auto sign-in for emulator mode
  Future<User?> autoSignInForEmulator() async {
    await _ensureInitialized();
    
    // Check if we're using emulator
    final useEmulator = dotenv.env['USE_FIRESTORE_EMULATOR'] == 'true';
    if (!useEmulator) {
      debugPrint('Not using emulator, skipping auto sign-in');
      return null;
    }
    
    try {
      debugPrint('🔧 Auto-signing in test user for emulator mode');
      
      // Check if already signed in
      if (_auth.currentUser != null) {
        debugPrint('Already signed in as ${_auth.currentUser!.email}');
        return _auth.currentUser;
      }
      
      // Create test user credentials
      const testEmail = 'test@example.com';
      const testPassword = 'password123';
      
      // Try to sign in, if fails, create the account
      try {
        final userCred = await _auth.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
        debugPrint('✅ Auto-signed in as test user: ${userCred.user!.email}');
        return userCred.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          // Create the test user
          final userCred = await _auth.createUserWithEmailAndPassword(
            email: testEmail,
            password: testPassword,
          );
          // Update profile
          await userCred.user!.updateDisplayName('Test User');
          debugPrint('✅ Created and signed in as test user: ${userCred.user!.email}');
          return userCred.user;
        } else {
          debugPrint('❌ Error auto-signing in: ${e.message}');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('❌ Auto sign-in error: $e');
      return null;
    }
  }
  
  // Show success message helper
  void _showSuccessMessage(String message) {
    // Emit the message with a delay to ensure listeners are ready
    Future.delayed(Duration(milliseconds: 800), () {
      if (!_successMessageController.isClosed) {
        _successMessageController.add(message);
        debugPrint('Success message emitted: $message');
      }
    });
  }
  
  // Method to manually trigger a success toast (for use after navigation completes)
  void showLoginSuccessToast(BuildContext context) {
    String message = 'Welcome back!';
    
    // Customize based on last sign-in method
    if (_lastSignInMethod == 'google') {
      message = 'Welcome! Signed in with Google';
    } else if (_lastSignInMethod == 'phone') {
      message = 'Welcome! Phone verification successful';
    } else if (_lastSignInMethod == 'apple') {
      message = 'Welcome! Signed in with Apple';
    }
    
    // Directly show the toast using ToastHelper
    ToastHelper.showToast(context, message, isSuccess: true);
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
      
      // Attempt to handle potential sessionStorage errors during initialization
      await _handlePotentialStorageIssues();
      
      // Start listening to auth state changes and forward to our stream
      _auth.authStateChanges().listen((User? user) {
        _userStreamController.add(user);
        
        // When user signs in (not on initial stream setup)
        if (user != null) {
          String displayName = user.displayName ?? 'User';
          if (displayName.isEmpty) {
            if (user.email != null && user.email!.isNotEmpty) {
              displayName = user.email!.split('@')[0];
            } else if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
              displayName = 'Phone User';
            } else {
              displayName = 'User';
            }
          }
        }
      });
      
      // Set verification settings for Android to bypass the reCAPTCHA requirement
      if (Platform.isAndroid) {
        try {
          // This is for testing only and should be removed in production
          await _auth.setSettings(appVerificationDisabledForTesting: true);
          debugPrint('Disabled app verification for testing on Android');
        } catch (e) {
          debugPrint('Error setting auth settings: $e');
        }
      }
      
      debugPrint('AuthService connected to Firebase Auth successfully');
    } catch (e) {
      debugPrint('Error connecting to Firebase Auth: $e');
      _userStreamController.add(null);
    }
  }

  // Method to handle and recover from potential storage issues
  Future<void> _handlePotentialStorageIssues() async {
    try {
      // If we're on Android or web, ensure persistence is set to LOCAL
      if (kIsWeb || Platform.isAndroid) {
        // Try to explicitly set the persistence to LOCAL to fix storage issues
        await _auth.setPersistence(Persistence.LOCAL);
        debugPrint('Auth persistence explicitly set to LOCAL');
      }
      
      // If we're running in Firebase App Distribution test environment
      // Get and check the current user to force a reload of auth state
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        try {
          // Force a token refresh to ensure we have a valid session
          await currentUser.getIdToken(true);
          debugPrint('Successfully refreshed auth token for current user');
        } catch (e) {
          if (e.toString().contains('missing initial state') || 
              e.toString().contains('sessionStorage')) {
            debugPrint('Detected storage issue during token refresh, signing out to recover');
            await _auth.signOut();
          } else {
            debugPrint('Error refreshing token, not related to storage: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error during storage issue handling: $e');
    }
  }

  // Get current user with safety check
  User? get currentUser {
    // Check if using emulator - in emulator mode we can return a fake user
    final useEmulator = dotenv.env['USE_FIRESTORE_EMULATOR'] == 'true';
    if (useEmulator && _auth.currentUser == null) {
      debugPrint('Using emulator mode - returning fake user');
      // Return a fake user for emulator mode
      return _createFakeUser();
    }
    
    if (!_isInitialized) return null;
    return _auth.currentUser;
  }

  // Create a fake user for emulator mode
  User? _createFakeUser() {
    try {
      // Unfortunately we can't easily create a fake User object 
      // since it's an internal Firebase class without public constructors
      debugPrint('Cannot create fake user directly, returning null');
      return null;
    } catch (e) {
      debugPrint('Error creating fake user: $e');
      return null;
    }
  }

  // Auth state changes stream with safety check
  Stream<User?> get authStateChanges {
    // In emulator mode, immediately emit a "signed in" state
    final useEmulator = dotenv.env['USE_FIRESTORE_EMULATOR'] == 'true';
    if (useEmulator) {
      debugPrint('🔧 Emulator mode: bypassing auth state changes');
      // We can't create a fake User, but we can check if already signed in
      // If signed in, use that, otherwise just let the app handle null user
      if (_auth.currentUser != null) {
        return Stream.value(_auth.currentUser);
      }
    }
    
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
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Track sign-in method
      _lastSignInMethod = 'email';
      
      // Trigger success toast
      _showSuccessMessage('Account created successfully!');
      
      return userCredential;
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
          
          // Track sign-in method
          _lastSignInMethod = 'email';
          
          // Trigger success toast
          _showSuccessMessage('Welcome back!');
          
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
        
        // Track sign-in method
        _lastSignInMethod = 'email';
        
        // Trigger success toast
        _showSuccessMessage('Welcome back!');
        
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
        final result = await _auth.signInWithPopup(googleProvider);
        
        // Track sign-in method
        _lastSignInMethod = 'google';
        
        // Trigger success toast
        _showSuccessMessage('Welcome! Signed in with Google');
        
        return result;
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
          
          // Track sign-in method
          _lastSignInMethod = 'google';
          
          // Trigger success toast with a longer delay for Google auth
          Future.delayed(Duration(seconds: 1), () {
            _showSuccessMessage('Welcome! Signed in with Google');
          });
          
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
        final result = await _auth.signInWithPopup(appleProvider);
        
        // Track sign-in method
        _lastSignInMethod = 'apple';
        
        // Trigger success toast
        _showSuccessMessage('Welcome! Signed in with Apple');
        
        return result;
      } else {
        // For native platforms
        AppleAuthProvider appleProvider = AppleAuthProvider();
        final result = await _auth.signInWithProvider(appleProvider);
        
        // Track sign-in method
        _lastSignInMethod = 'apple';
        
        // Trigger success toast
        _showSuccessMessage('Welcome! Signed in with Apple');
        
        return result;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to sign in with Apple: $e';
    }
  }

  // Phone Authentication
  // Step 1: Send verification code
  Future<String> sendPhoneVerificationCode(String phoneNumber) async {
    await _ensureInitialized();
    final completer = Completer<String>();
    String verificationId = '';
    
    // Ensure app verification is disabled for testing on Android
    if (Platform.isAndroid) {
      debugPrint('Setting appVerificationDisabledForTesting = true for phone auth on Android');
      await _auth.setSettings(appVerificationDisabledForTesting: true);
    }
    
    try {
      debugPrint('Sending verification code to $phoneNumber');
      
      // For Android testing, handle the phone number format
      if (Platform.isAndroid && phoneNumber.startsWith('+1') && 
          (phoneNumber.contains('555') || phoneNumber == '+16565551234')) {
        // Use a test phone number for Firebase Auth testing
        debugPrint('Using a test phone number format for Android');
      }
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 120), // Increase timeout for verification
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android 
          debugPrint('Auto-verification completed');
          try {
            await _auth.signInWithCredential(credential);
            
            // Track sign-in method
            _lastSignInMethod = 'phone';
            
            // Trigger success toast
            _showSuccessMessage('Welcome! Phone verification completed automatically');
            
            if (!completer.isCompleted) {
              completer.complete('auto');
            }
          } catch (e) {
            debugPrint('Error in auto-verification: $e');
            if (!completer.isCompleted) {
              completer.completeError('Failed to sign in with auto-verification: $e');
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Verification failed: ${e.message}');
          
          // Handle Play Integrity and reCAPTCHA errors specifically
          if (e.message?.contains('Play Integrity') == true || 
              e.message?.contains('reCAPTCHA') == true) {
            debugPrint('Play Integrity or reCAPTCHA verification failed - this is an Android-specific issue');
            
            // For development, we'll bypass this with a fake verification ID
            // In production, you should implement proper SafetyNet integration
            if (!completer.isCompleted) {
              // Return a special error code that our UI can handle
              completer.completeError('ANDROID_VERIFICATION_BYPASS_NEEDED');
            }
            return;
          }
          
          if (!completer.isCompleted) {
            completer.completeError(_handleAuthException(e));
          }
        },
        codeSent: (String vId, int? resendToken) {
          debugPrint('Verification code sent');
          verificationId = vId;
          if (!completer.isCompleted) {
            completer.complete(vId);
          }
        },
        codeAutoRetrievalTimeout: (String vId) {
          debugPrint('Auto retrieval timeout');
          verificationId = vId;
          // Don't complete here as it might have already been completed
        },
      );
      
      return await completer.future;
    } catch (e) {
      debugPrint('Error sending verification code: $e');
      throw 'Failed to send verification code: $e';
    }
  }
  
  // Step 2: Verify code and sign in
  Future<UserCredential> verifyPhoneCode(String verificationId, String smsCode) async {
    await _ensureInitialized();
    
    try {
      debugPrint('Verifying code...');
      
      // For Android bypass scenario (development only)
      if (verificationId == 'android_test_bypass' && Platform.isAndroid) {
        debugPrint('Using test verification for Android');
        
        try {
          // Try creating a test phone credential
          // For development purposes only
          PhoneAuthCredential credential = PhoneAuthProvider.credential(
            verificationId: 'ANDROID-MOCK-VERIFICATION-ID',
            smsCode: '123456'
          );
          
          final result = await _auth.signInWithCredential(credential);
          
          // Track sign-in method
          _lastSignInMethod = 'phone';
          
          // Trigger success toast
          _showSuccessMessage('Welcome! Phone verification successful');
          
          return result;
        } catch (e) {
          if (e.toString().contains('admin-restricted-operation') || 
              e.toString().contains('invalid-verification-id')) {
            debugPrint('Normal phone auth failed, trying Google sign-in as fallback');
            
            // Try Google sign-in as fallback
            final googleCredential = await signInWithGoogle();
            if (googleCredential != null) {
              // Google sign-in already shows its own success toast
              return googleCredential;
            }
            
            throw 'Unable to verify phone on this device. Please try using Google Sign-In instead.';
          }
          rethrow;
        }
      }
      
      // Create credential
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      // Sign in
      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('Phone authentication successful');
      
      // Track sign-in method
      _lastSignInMethod = 'phone';
      
      // Trigger success toast with a longer delay to ensure UI navigation has completed
      Future.delayed(Duration(seconds: 1), () {
        _showSuccessMessage('Welcome! Phone verification successful');
      });
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Exception: ${e.code} - ${e.message}');
      
      // Handle specific error cases
      if (e.code == 'admin-restricted-operation') {
        debugPrint('Admin restricted operation - likely anonymous auth is disabled');
        throw 'Phone authentication is not available on this device. Please try Google Sign-In instead.';
      }
      
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Error in phone verification: $e');
      throw 'Failed to verify phone: $e';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _ensureInitialized();
    
    try {
      // Sign out from Firebase without clearing app state
      await _auth.signOut();
      debugPrint('Firebase sign out successful.');
      
      // No need for a toast here as it's handled in the UI
    } catch (e) {
       debugPrint('Error during Firebase sign out: $e');
       throw 'Failed to sign out: $e'; // Re-throw Firebase errors
    }
  }
  
  // Method to clear all app state (can be called separately when needed)
  Future<void> clearAllAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys
      final allKeys = prefs.getKeys();
      
      // Keep auth-related preferences (like login attempts) but remove app state
      final keysToRemove = allKeys.where((key) => 
        !key.contains(_loginAttemptsKey) && 
        !key.contains(_lastLoginAttemptTimeKey) && 
        !key.contains(_loginLockedUntilKey)
      ).toList();
      
      // Remove each key individually
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      debugPrint('Cleared ${keysToRemove.length} app state preferences');
    } catch (e) {
      debugPrint('Error clearing app state: $e');
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
      
      // Trigger success toast
      _showSuccessMessage('Password reset email sent. Please check your inbox.');
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
      case 'invalid-verification-code':
        return 'The verification code you entered is invalid. Please try again.';
      case 'invalid-verification-id':
        return 'The verification session has expired. Please request a new code.';
      case 'app-not-authorized':
        return 'This app is not authorized to use Firebase Authentication with your key.';
      default:
        // Check for "missing initial state" error in the message
        if (e.message != null && 
            (e.message!.contains('missing initial state') || 
             e.message!.contains('sessionStorage is inaccessible'))) {
          debugPrint('Caught missing initial state error, handling gracefully');
          // Attempt to recover by clearing Firebase auth state
          try {
            FirebaseAuth.instance.signOut().then((_) {
              debugPrint('Signed out to reset auth state after missing initial state error');
            });
          } catch (innerError) {
            debugPrint('Error during recovery signout: $innerError');
          }
          
          return 'There was a temporary authentication issue. Please try again.';
        }
        return 'An error occurred: ${e.message}';
    }
  }
  
  // Clean up resources
  void dispose() {
    _userStreamController.close();
    _successMessageController.close();
  }
} 