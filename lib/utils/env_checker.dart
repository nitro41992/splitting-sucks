import 'package:flutter/material.dart';
import '../env/env.dart';

/// EnvironmentChecker is a utility class that provides methods to verify
/// environment variable configuration throughout the app
class EnvironmentChecker {
  /// Validates the current environment configuration and returns a widget
  /// to display any issues or null if everything is okay
  static Widget? validateAndGetErrorWidget(BuildContext context) {
    final List<String> issues = [];
    
    // Check if environment is initialized
    if (!Env.isInitialized) {
      issues.add("Environment variables are not initialized");
    }
    
    // We no longer need to check for OpenAI API key in the History screen
    // The History functionality works without it

    // Return error widget if there are issues
    if (issues.isNotEmpty) {
      return Card(
        color: Colors.amber.shade100,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Text(
                    'Environment Configuration Warning',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...issues.map((issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(issue)),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              Text(
                'Using fallback values. Some features may be limited.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // No issues found
    return null;
  }
  
  /// Log environment status and configuration
  static void logStatus(String location) {
    debugPrint('[$location] Environment check:');
    debugPrint('- Initialized: ${Env.isInitialized}');
    debugPrint('- Debug mode: ${Env.debugMode}');
  }
} 