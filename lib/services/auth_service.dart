import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Constants for rate limiting and security
  static const int _maxLoginAttemptsBeforeCaptcha = 3;
  static const int _maxLoginAttemptsBeforeTimeout = 5;
  static const int _loginTimeoutDurationMinutes = 15;
  
  // Keys for shared preferences
  static const String _loginAttemptsKey = 'login_attempts';
  static const String _lastLoginAttemptTimeKey = 'last_login_attempt_time';
  static const String _loginLockedUntilKey = 'login_locked_until';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email/Password Sign Up
  Future<UserCredential> signUpWithEmailPassword(String email, String password) async {
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
    // Check if login is allowed (not rate limited)
    final captchaNeeded = !(await _checkLoginAttempts(email));
    if (captchaNeeded) {
      // In a real app, implement CAPTCHA here
      debugPrint('CAPTCHA would be required here due to multiple login attempts');
      // For now, we'll allow the login but log a warning
    }
    
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Reset attempts counter on successful login
      await _resetLoginAttempts(email);
      return result;
    } on FirebaseAuthException catch (e) {
      // Record failed attempt
      await _recordFailedLoginAttempt(email);
      throw _handleAuthException(e);
    }
  }

  // Google Sign In with Firebase only
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Create a GoogleAuthProvider
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      
      // Add scopes if needed
      googleProvider.addScope('https://www.googleapis.com/auth/contacts.readonly');
      googleProvider.setCustomParameters({
        'login_hint': 'user@example.com'
      });

      // On mobile, use signInWithPopup
      if (defaultTargetPlatform == TargetPlatform.iOS || 
          defaultTargetPlatform == TargetPlatform.android) {
        return await _auth.signInWithPopup(googleProvider);
      } 
      // On web, use signInWithRedirect
      else {
        return await _auth.signInWithPopup(googleProvider);
        // Note: for web redirect flow, you'd use:
        // await _auth.signInWithRedirect(googleProvider);
        // and then later handle the redirect result
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to sign in with Google: $e';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('Sign out successful.');
    } catch (e) {
       debugPrint('Error during sign out: $e');
       throw 'Failed to sign out: $e';
    }
  }

  // Password Reset with rate limiting
  Future<void> resetPassword(String email) async {
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
} 