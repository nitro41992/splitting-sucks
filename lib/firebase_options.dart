// File generated based on settings from GoogleService-Info.plist
// Provides platform-specific Firebase configuration options

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDUTqsyv-85mZtCT5_M6HULAyp8_rN5z2I',
    appId: '1:700235738899:ios:5558c352c48abf031774e6',
    messagingSenderId: '700235738899',
    projectId: 'billfie',
    authDomain: 'billfie.firebaseapp.com',
    storageBucket: 'billfie.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDUTqsyv-85mZtCT5_M6HULAyp8_rN5z2I',
    appId: '1:700235738899:ios:5558c352c48abf031774e6', 
    messagingSenderId: '700235738899',
    projectId: 'billfie',
    storageBucket: 'billfie.firebasestorage.app',
    iosClientId: '700235738899-0i2bo7u0airk3vqsme7e2cgl2h101ggi.apps.googleusercontent.com',
    iosBundleId: 'com.billfie.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDUTqsyv-85mZtCT5_M6HULAyp8_rN5z2I',
    appId: '1:700235738899:android:placeholder',  // Replace with actual Android appId
    messagingSenderId: '700235738899',
    projectId: 'billfie',
    storageBucket: 'billfie.firebasestorage.app',
    androidClientId: '700235738899-pq86318m7pafrmqc6agi2qcu1g13c8vv.apps.googleusercontent.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDUTqsyv-85mZtCT5_M6HULAyp8_rN5z2I',
    appId: '1:700235738899:ios:5558c352c48abf031774e6',  // Using iOS appId for macOS
    messagingSenderId: '700235738899',
    projectId: 'billfie',
    storageBucket: 'billfie.firebasestorage.app',
    iosClientId: '700235738899-0i2bo7u0airk3vqsme7e2cgl2h101ggi.apps.googleusercontent.com',
    iosBundleId: 'com.billfie.app',
  );
} 