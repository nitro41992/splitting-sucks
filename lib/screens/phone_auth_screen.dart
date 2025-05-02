import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/toast_helper.dart';
import 'dart:io';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController(text: '+1 ');
  final _codeController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  String? _verificationId;
  bool _codeSent = false;
  
  // Max length for a phone number with country code and formatting
  static const int _maxPhoneLength = 16; // +1 XXX XXX XXXX format

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // Format phone number as user types
  String _formatPhoneNumber(String text) {
    // Keep the +1 prefix
    if (!text.startsWith('+')) {
      text = '+$text';
    }
    
    // If just +1, add a space
    if (text == '+1') {
      return '+1 ';
    }

    // Remove all non-digit characters except the plus sign
    final digitsOnly = text.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Enforce maximum digit length (country code + 10 digits for US)
    final limitedDigits = digitsOnly.length <= 12 
        ? digitsOnly 
        : digitsOnly.substring(0, 12);
    
    // Format: +1 XXX XXX XXXX
    final buffer = StringBuffer();
    
    // Add the country code
    buffer.write(limitedDigits.substring(0, limitedDigits.length >= 2 ? 2 : limitedDigits.length));
    
    // Add spaces and groups of digits
    if (limitedDigits.length > 2) {
      buffer.write(' ');
      
      // Area code (next 3 digits)
      final areaCodeEnd = limitedDigits.length >= 5 ? 5 : limitedDigits.length;
      buffer.write(limitedDigits.substring(2, areaCodeEnd));
      
      // Next 3 digits
      if (limitedDigits.length > 5) {
        buffer.write(' ');
        final secondGroupEnd = limitedDigits.length >= 8 ? 8 : limitedDigits.length;
        buffer.write(limitedDigits.substring(5, secondGroupEnd));
        
        // Last 4 digits
        if (limitedDigits.length > 8) {
          buffer.write(' ');
          buffer.write(limitedDigits.substring(8, limitedDigits.length));
        }
      }
    }
    
    return buffer.toString();
  }

  // Clean phone number before sending to backend
  String _cleanPhoneNumber(String phoneNumber) {
    // Keep only digits and plus sign
    return phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  // Validate phone number
  bool _isValidPhoneNumber(String phoneNumber) {
    final cleanNumber = _cleanPhoneNumber(phoneNumber);
    // Basic validation - must be +1 followed by 10 digits for US numbers
    return cleanNumber.startsWith('+1') && 
           cleanNumber.length >= 12 && 
           RegExp(r'^\+1\d{10}$').hasMatch(cleanNumber);
  }

  Future<void> _sendVerificationCode() async {
    final phoneText = _phoneController.text.trim();
    
    if (!_isValidPhoneNumber(phoneText)) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit phone number with country code (+1)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Clean phone number before sending
      String phoneNumber = _cleanPhoneNumber(phoneText);
      
      try {
        final verificationId = await _authService.sendPhoneVerificationCode(phoneNumber);
        
        if (verificationId == 'auto') {
          // Auto verification happened on Android, no need to enter code
          debugPrint('Auto verified, user should be signed in');
          // The StreamBuilder in main.dart should handle navigation
          if (mounted) {
            Navigator.pop(context); // Close this screen to reveal the main app
          }
          return;
        }
        
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _errorMessage = null;
        });
      } catch (e) {
        // Handle the special Android bypass error code
        if (e.toString().contains('ANDROID_VERIFICATION_BYPASS_NEEDED')) {
          debugPrint('Android verification bypass needed, using test verification');
          
          // Set a special verification ID that our verify method will recognize
          setState(() {
            _verificationId = 'android_test_bypass';
            _codeSent = true;
            _errorMessage = null;
          });
          
          return;
        }
        
        throw e; // Rethrow other errors
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

  Future<void> _verifyCode() async {
    if (_codeController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }
    
    if (_verificationId == null) {
      setState(() {
        _errorMessage = 'No verification ID found';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.verifyPhoneCode(
        _verificationId!,
        _codeController.text.trim(),
      );
      
      // Show a success toast directly
      if (mounted) {
        ToastHelper.showToast(
          context,
          'Welcome! Phone verification successful',
          isSuccess: true,
        );
      }
      
      // Explicitly navigate back to trigger the auth state listener
      if (mounted) {
        Navigator.pop(context); // Go back to login screen which will then redirect to main app
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('try using Google Sign-In instead') || 
            e.toString().contains('Try Google Sign-In')) {
          // Show error with action button
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phone authentication failed on this device'),
              action: SnackBarAction(
                label: 'Try Google Sign-In',
                onPressed: () {
                  Navigator.pop(context); // Go back to login screen
                },
              ),
              duration: const Duration(seconds: 10),
            ),
          );
          
          // Add a short delay before popping the screen
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context); // Go back to login screen
            }
          });
        } else {
          setState(() {
            _errorMessage = e.toString();
          });
        }
      }
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Phone Authentication',
          style: textTheme.titleLarge?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.text),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),

                if (!_codeSent) 
                  // Phone number input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'logo.png',
                        height: 100,
                        width: 100,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Sign in with your phone',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We\'ll send you a code to verify your phone number',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: _maxPhoneLength,
                        onChanged: (value) {
                          // Format as they type
                          final formattedText = _formatPhoneNumber(value);
                          
                          // Only update if formatting changed something
                          if (formattedText != value) {
                            _phoneController.value = TextEditingValue(
                              text: formattedText,
                              selection: TextSelection.collapsed(offset: formattedText.length),
                            );
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '+1 234 567 8900',
                          counterText: '', // Hide the counter
                          helperText: 'Format: +1 XXX XXX XXXX',
                          helperStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: _isLoading ? null : _sendVerificationCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Send Code', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  )
                else
                  // Verification code input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'logo.png',
                        height: 100,
                        width: 100,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Enter verification code',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a code to ${_phoneController.text}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall,
                        maxLength: 6,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '• • • • • •',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: _isLoading ? null : _verifyCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Verify', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _codeSent = false;
                                _verificationId = null;
                              });
                            },
                            child: Text(
                              'Change Number',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: _isLoading ? null : _sendVerificationCode,
                            child: Text(
                              'Resend Code', 
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 