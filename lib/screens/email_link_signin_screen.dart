import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';
import '../services/auth_service.dart';

class EmailLinkSignInScreen extends StatefulWidget {
  const EmailLinkSignInScreen({super.key});

  @override
  State<EmailLinkSignInScreen> createState() => _EmailLinkSignInScreenState();
}

class _EmailLinkSignInScreenState extends State<EmailLinkSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _linkSent = false;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _checkInitialLink();
    _initDeepLinkListener();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialLink() async {
    try {
      // Check for initial link from both regular URLs and custom scheme
      final initialLink = await getInitialLink();
      if (initialLink != null) {
        _handleEmailLink(initialLink);
      }
      
      // Also try to get the intent (for custom scheme)
      final Uri? initialUri = await getInitialUri();
      if (initialUri != null && initialUri.scheme == 'billfie') {
        // Extract the actual auth link from the URI
        final linkParams = initialUri.queryParameters;
        if (linkParams.containsKey('link')) {
          _handleEmailLink(Uri.decodeComponent(linkParams['link']!));
        } else {
          debugPrint('Deep link received but no auth link found in parameters');
        }
      }
    } catch (e) {
      debugPrint('Error checking initial link: $e');
      // Don't show error to user, just log it
    }
  }

  void _initDeepLinkListener() {
    try {
      _linkSubscription = linkStream.listen((String? link) {
        if (link != null) {
          _handleEmailLink(link);
        }
      }, onError: (err) {
        debugPrint('Error listening to links: $err');
      });
      
      // Also listen for URI scheme links
      uriLinkStream.listen((Uri? uri) {
        if (uri != null && uri.scheme == 'billfie') {
          // Extract the actual auth link from the URI
          final linkParams = uri.queryParameters;
          if (linkParams.containsKey('link')) {
            _handleEmailLink(Uri.decodeComponent(linkParams['link']!));
          } else {
            debugPrint('Deep link received but no auth link found in parameters');
          }
        }
      }, onError: (err) {
        debugPrint('Error listening to URI links: $err');
      });
    } catch (e) {
      debugPrint('Error setting up deep link listener: $e');
      // Deep linking might not be available, but we can continue without it
    }
  }

  Future<void> _handleEmailLink(String link) async {
    if (_authService.isSignInWithEmailLink(link)) {
      String? email;
      
      // Try to get email from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        email = prefs.getString('emailForSignIn');
      } catch (e) {
        debugPrint('Error retrieving email from SharedPreferences: $e');
        // Will continue with null email
      }

      // If we don't have the email in storage and the user hasn't entered it yet,
      // we need to ask for it
      if (email == null && _emailController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter your email to complete sign in';
        });
        return;
      }

      email ??= _emailController.text.trim();

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await _authService.signInWithEmailLink(email, link);
        
        // Try to clear the stored email
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('emailForSignIn');
        } catch (e) {
          debugPrint('Error removing email from SharedPreferences: $e');
          // Continue regardless of this error
        }

        if (mounted) {
          // Show success message before navigating
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully signed in!'),
              backgroundColor: Colors.green,
            ),
          );
          
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _sendSignInLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      await _authService.sendSignInLinkToEmail(email);
      
      // Save the email address for later use
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('emailForSignIn', email);
      } catch (e) {
        debugPrint('Error saving email to SharedPreferences: $e');
        // We'll continue without storing the email
        // The user will need to enter their email again when clicking the link
      }

      setState(() {
        _linkSent = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Check your email for the sign-in link. Be sure to use the same device to open the link.',
            ),
            duration: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In with Email Link'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                const Text(
                  'Passwordless Sign In',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (!_linkSent) ...[
                  // Instructions
                  const Text(
                    'No password needed! We\'ll send a secure link to your email that you can click to sign in instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Send Link Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendSignInLink,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send Sign In Link'),
                  ),
                ] else ...[
                  // Success Message
                  const Icon(
                    Icons.email_outlined,
                    color: Colors.green,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign in link sent!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ve sent a sign-in link to ${_emailController.text}\n\nPlease check your email (including the spam folder) and click the link to sign in.\n\nIMPORTANT: Use the same device to open the link.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Back to Login Button
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 