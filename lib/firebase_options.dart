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
    apiKey: 'AIzaSyARiiMNhNHGhmLXkh0PQBRrn9AXtwY_dc',
    appId: '1:700235738899:web:5558c352c48abf031774e6',
    messagingSenderId: '700235738899',
    projectId: 'billfie',
    authDomain: 'billfie.firebaseapp.com',
    storageBucket: 'billfie.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDO7J9bVAhIrnNNXoXhptSure6LoU9OBSw',
    appId: '1:700235738899:ios:5558c352c48abf031774e6', 
    messagingSenderId: '700235738899',
    projectId: 'billfie',
    storageBucket: 'billfie.firebasestorage.app',
    iosClientId: '700235738899-0i2bo7u0airk3vqsme7e2cgl2h101ggi.apps.googleusercontent.com',
    iosBundleId: 'com.billfie.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDTvGYCjKJ9-6mX3cC9xqZ9xkEZUR9IUmg',
    appId: '1:700235738899:android:f2b0756dfe3bca2f1774e6',
    messagingSenderId: '700235738899',
    projectId: 'billfie',
    storageBucket: 'billfie.firebasestorage.app',
    androidClientId: '700235738899-krhi4m6jic3p2poq36tpiag5eqr1ev46.apps.googleusercontent.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDO7J9bVAhIrnNNXoXhptSure6LoU9OBSw',
    appId: '1:700235738899:ios:5558c352c48abf031774e6',  // Using iOS appId for macOS
    messagingSenderId: '700235738899',
    projectId: 'billfie',
    storageBucket: 'billfie.firebasestorage.app',
    iosClientId: '700235738899-0i2bo7u0airk3vqsme7e2cgl2h101ggi.apps.googleusercontent.com',
    iosBundleId: 'com.billfie.app',
  );
} 