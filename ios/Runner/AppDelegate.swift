import Flutter
import UIKit
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase with error handling
    do {
      // Check if GoogleService-Info.plist exists in the main bundle
      if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
        // Configure Firebase if plist is found
        FirebaseApp.configure()
        print("Firebase initialized successfully")
      } else {
        print("Error: GoogleService-Info.plist not found in bundle")
        // Continue app initialization without Firebase
      }
    } catch {
      print("Error initializing Firebase: \(error.localizedDescription)")
      // Continue app initialization without Firebase
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
