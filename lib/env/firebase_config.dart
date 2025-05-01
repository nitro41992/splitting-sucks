/// Firebase Configuration Constants
/// 
/// This file contains constants for Firebase configuration.
/// Values can be overridden by environment variables in .env file.

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// The URL for the Firebase Cloud Functions.
/// This is used for direct HTTP calls to functions if needed.
final String kFirebaseFunctionsUrl = dotenv.env['FIREBASE_FUNCTIONS_URL'] ?? 
    'https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net';

/// The region for Firebase Cloud Functions.
/// Default is 'us-central1'.
final String kFunctionsRegion = dotenv.env['FIREBASE_FUNCTIONS_REGION'] ?? 'us-central1';

/// Configure FirebaseFunctions region.
/// Call this during app initialization.
void configureFirebase() {
  // Any Firebase global configurations can be done here
} 