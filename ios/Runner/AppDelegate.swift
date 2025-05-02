import Flutter
import UIKit
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase with robust error handling
    do {
      // Check if GoogleService-Info.plist exists in the main bundle
      if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
        // Verify the file exists and is readable
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: filePath) && fileManager.isReadableFile(atPath: filePath) {
          // Configure Firebase if plist is found and valid
          FirebaseApp.configure()
          print("Firebase initialized successfully")
        } else {
          print("Error: GoogleService-Info.plist exists but is not readable")
        }
      } else {
        print("Error: GoogleService-Info.plist not found in bundle")
        
        // Check if the file exists in the main directory but wasn't bundled correctly
        let mainBundlePath = Bundle.main.bundlePath
        print("Checking for plist in main bundle path: \(mainBundlePath)")
        
        // List files in bundle to help with debugging
        if let files = try? FileManager.default.contentsOfDirectory(atPath: mainBundlePath) {
          print("Files in main bundle: \(files)")
        }
      }
    } catch {
      print("Error initializing Firebase: \(error.localizedDescription)")
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle URL schemes for Firebase Auth
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Let Firebase Auth handle the URL
    if Auth.auth().canHandle(url) {
      return true
    }
    
    // Fall back to default handler
    return super.application(app, open: url, options: options)
  }
}
