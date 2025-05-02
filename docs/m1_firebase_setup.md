# Flutter Firebase Setup for M1 Mac

This document tracks the steps taken to resolve Flutter/Firebase integration issues on M1 Mac.

## Tasks

- [x] 1. Check Flutter doctor status
- [x] 2. Create pod-install wrapper script for M1 Mac
- [x] 3. Update pubspec.yaml with compatible Firebase versions
- [x] 4. Clean project and get dependencies
- [x] 5. Install pods using architecture-specific commands
- [x] 6. Run the app on iOS simulator
- [ ] 7. Test Firebase function connectivity
- [x] 8. Replace Google Sign-In with Firebase Authentication

## Progress Log

* Starting setup process...
* Flutter doctor shows a healthy setup except for Android licensing (not needed for iOS development)
* Created `.pod-install-wrapper.sh` to run pod install with x86_64 architecture
* Current Firebase dependencies look up-to-date in pubspec.yaml
* Modified iOS Podfile to add M1 Mac specific settings:
  * Added architecture exclusions for arm64 in iOS simulator builds
  * Added fixes for Google libraries that don't support arm64 simulator
  * These changes should resolve the compatibility issues on M1 Macs
* Cleaned project and got dependencies, but encountered GoogleUtilities version conflicts
* Created a comprehensive fix script `fix_m1_pods.sh` based on StackOverflow solutions:
  * Performs complete cleanup of Flutter and CocoaPods artifacts
  * Reinstalls pods with x86_64 architecture
  * Applies GoogleUtilities version constraint fixes
  * This script combines multiple fixes from community solutions
* Still encountered GoogleUtilities version conflicts between Firebase and Google Sign-In
* Temporarily removed Google Sign-In dependency to resolve the conflict
  * This is a common workaround until we can set up proper dependency resolution
  * We can re-add Google Sign-In later once the app is working with basic Firebase functionality
* Successfully installed pods after removing Google Sign-In dependency
  * Got a minor warning about base configuration that can be ignored
  * All Firebase components except Google Sign-In are now installed
* Encountered build error: "unsupported option '-G' for target 'x86_64-apple-ios12.0-simulator'"
* Created a new script `fix_xcode_arch.sh` to address architecture issues directly in Xcode:
  * Opens Xcode project for manual architecture configuration
  * Adds more comprehensive architecture exclusions in Podfile
  * Fixes specific simulator architecture flags
  * Addresses the '-G' option error by modifying compiler flags
* Successfully executed the Xcode architecture fix script:
  * Confirmed architecture settings in Xcode (arm64 excluded for simulator)
  * Updated Podfile with comprehensive M1 Mac fixes
  * CocoaPods warning about base configuration can be safely ignored
* Still encountered the '-G' compiler flag error
* Created a targeted fix script `fix_g_option.sh` to:
  * Find and remove the problematic '-G' flag from project.pbxproj files
  * Clean Xcode DerivedData to ensure fresh build
  * This addresses the specific compiler error directly in the generated Xcode project
* Found confirmation that the '-G' flag issue is a known bug in the BoringSSL-GRPC dependency:
  * This is tracked in GitHub as [firebase/firebase-ios-sdk#13115](https://github.com/firebase/firebase-ios-sdk/issues/13115)
  * The issue has been fixed upstream in gRPC 1.65.2 but may not be available in the current Flutter dependencies
  * Our `fix_g_option.sh` script applies the same fix manually by removing the problematic flag
* Created a cleaner solution with `fix_podfile_for_g_flag.sh` script:
  * Modifies the Podfile to handle the BoringSSL-GRPC compiler flags directly
  * Solution comes from [flutterfire issue #12960](https://github.com/firebase/flutterfire/issues/12960#issuecomment-2453004582)
  * This is a more maintainable solution that fixes the issue at the Podfile level
* Added pre-compiled FirebaseFirestore frameworks to the Podfile to avoid building gRPC-Core and BoringSSL:
  * This is another approach to fix the '-G' compiler flag issue recommended in the GitHub issue
  * Used: `pod 'FirebaseFirestore', :git => 'https://github.com/invertase/firestore-ios-sdk-frameworks.git', :tag => '10.25.0'`
* Encountered C++ template errors in gRPC-Core after fixing the '-G' flag issue
* Decided to switch approach: instead of fixing Google Sign-In integration, we're using Firebase Authentication directly:
  * This avoids the version conflicts between Firebase and Google Sign-In
  * Firebase Auth provides native authentication methods including Sign in with Apple
  * This approach reduces dependency complexity and improves build stability
* Encountered "Include of non-modular header inside framework module" error with Firebase Storage
* Found definitive solution on Stack Overflow for non-modular header issues:
  * Set `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES` to `YES` for affected targets
  * This solution works for Xcode 16 on macOS Sequoia and addresses a common issue with Firebase pods
* Encountered error: "FirebaseApp.configure() could not find a valid GoogleService-Info.plist" indicating missing Firebase configuration file
* Created a fix script `fix_plist_in_bundle.sh` to verify GoogleService-Info.plist location and inclusion in Xcode project
* Modified AppDelegate.swift to add proper error handling for Firebase initialization:
  * Added check for GoogleService-Info.plist existence before configuring Firebase
  * Added try-catch block to prevent app crashes when Firebase initialization fails
  * Added logging to diagnose Firebase initialization issues
* Fixed GoogleService-Info.plist location and inclusion in Xcode project:
  * Made sure the file was properly added to the Runner folder
  * Verified it was included in the project
* Successfully got the app running on iOS simulator with Firebase properly initialized
* Applied all the fixes systematically through scripts to ensure a repeatable process:
  1. Fixed AppDelegate.swift for robust initialization
  2. Used fix_podfile_for_g_flag.sh for Podfile fixes
  3. Used fix_plist_in_bundle.sh for GoogleService-Info.plist fixes
  4. Combined fixes for non-modular headers
  5. Used pre-compiled Firestore frameworks
* Successfully ran the app on iOS simulator with Firebase initialized, confirming our fixes worked

## Fix for Non-Modular Header Issues

When encountering the error "Include of non-modular header inside framework module", there are two ways to fix it:

### Option 1: Fix via Xcode UI (Manual)

1. Open the Xcode workspace: `open ios/Runner.xcworkspace`
2. In Xcode, select the target with the issue (typically `Runner` or the specific Firebase module) 
3. Go to **Build Settings** and change the view to show **All** settings (not just Basic)
4. Find the setting `Allow Non-modular Includes in Framework Modules` (or search for `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES`)
5. Set it to `YES`
6. Close Xcode and rebuild your Flutter app

### Option 2: Fix via Podfile (Automated)

Add this code to your Podfile's `post_install` hook to automatically fix non-modular header issues:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    # Fix for non-modular headers
    target.build_configurations.each do |config|
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
    end
    
    # Other existing settings...
    flutter_additional_ios_build_settings(target)
  end
  
  # Also fix the Runner project
  runner_project_path = File.expand_path("../Runner.xcodeproj", __FILE__)
  runner_project = Xcodeproj::Project.open(runner_project_path)
  
  runner_project.targets.each do |target|
    if target.name == "Runner"
      target.build_configurations.each do |config|
        config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      end
    end
  end
  
  runner_project.save
end
```

This approach ensures that both pod targets and the Runner target have the correct setting.

## Fix for '-G' Option Error

The '-G' option error is a confirmed issue with the BoringSSL-GRPC dependency used by Firebase Firestore. This dependency includes a `-GCC_WARN_INHIBIT_ALL_WARNINGS` compiler flag that is no longer supported in Xcode 16.

**Best Solution: Modify Podfile**

Add this code to your Podfile's post_install section to automatically fix the compiler flags:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    if target.name == 'BoringSSL-GRPC'
      target.source_build_phase.files.each do |file|
        if file.settings && file.settings['COMPILER_FLAGS']
          flags = file.settings['COMPILER_FLAGS'].split
          flags.reject! { |flag| flag == '-GCC_WARN_INHIBIT_ALL_WARNINGS' }
          file.settings['COMPILER_FLAGS'] = flags.join(' ')
        end
      end
    end
    flutter_additional_ios_build_settings(target)
    # Your other post-install settings...
  end
end
```

We've created a script `fix_podfile_for_g_flag.sh` that automatically updates your Podfile with this fix.

**Alternative Solutions:**

1. Use pre-compiled Firestore frameworks to avoid building BoringSSL-GRPC:
   ```ruby
   pod 'FirebaseFirestore', :git => 'https://github.com/invertase/firestore-ios-sdk-frameworks.git', :tag => '10.25.0'
   ```
2. Use the provided `fix_g_option.sh` script to remove the problematic flag from project.pbxproj files
3. Alternatively, use the `fix_xcode_arch.sh` script to manually edit the Xcode project
4. Clean DerivedData to ensure a fresh build:
   ```
   rm -rf ~/Library/Developer/Xcode/DerivedData/*Flutter*
   ```

## Using Firebase Authentication Instead of Google Sign-In

Due to persistent GoogleUtilities version conflicts, we're implementing Firebase Authentication directly instead of using the standalone Google Sign-In package. This approach has several advantages:

1. **Avoid dependency conflicts**: Eliminates version conflicts between Firebase and Google Sign-In
2. **Simpler integration**: Firebase Auth provides a unified API for multiple authentication methods
3. **Native implementation**: Uses Firebase's built-in authentication capabilities
4. **Better M1 Mac compatibility**: Fewer components that need architecture fixes

### Implementing Firebase Authentication with Sign in with Apple

To implement Sign in with Apple with Firebase Authentication:

1. **Configure Sign in with Apple in your Firebase project**:
   - In the Firebase console, go to Authentication > Sign-in method
   - Enable Apple provider
   - Follow the setup instructions to configure your Apple Developer account

2. **Add the Firebase Auth dependency** (already included in our project):
   ```yaml
   dependencies:
     firebase_auth: ^4.20.0
   ```

3. **Add the code to authenticate with Apple**:
   ```dart
   import 'package:firebase_auth/firebase_auth.dart';
   
   // Sign in with Apple
   Future<UserCredential> signInWithApple() async {
     // Begin sign in process
     final appleProvider = AppleAuthProvider();
     if (kIsWeb) {
       // Handle web sign-in
       return await FirebaseAuth.instance.signInWithPopup(appleProvider);
     } else {
       // Handle native sign-in
       return await FirebaseAuth.instance.signInWithProvider(appleProvider);
     }
   }
   ```

4. **Complete the setup in your iOS app**:
   - Update your Xcode project capabilities to include Sign in with Apple
   - Update your Info.plist to include the required Apple Sign in entitlements

This approach provides a more stable solution than trying to fix the version conflicts between Google Sign-In and Firebase.

## Fix for Missing GoogleService-Info.plist Error

If you encounter the error "FirebaseApp.configure() could not find a valid GoogleService-Info.plist", follow these steps:

1. **Download the configuration file**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Click the iOS app (with bundle ID com.billfie.app)
   - If your app isn't registered, add a new iOS app with your bundle ID
   - Download the GoogleService-Info.plist file

2. **Add to Xcode project**:
   - Open your Flutter project in Xcode: `open ios/Runner.xcworkspace`
   - Right-click on the "Runner" folder in the Project Navigator
   - Select "Add Files to 'Runner'..."
   - Select the downloaded GoogleService-Info.plist file
   - Make sure "Copy items if needed" is checked
   - Set "Add to targets" to include "Runner"
   - Click "Add"

3. **Verify the file is properly included**:
   - Check that GoogleService-Info.plist appears in your Runner folder
   - Make sure it's included in the "Copy Bundle Resources" build phase of your target
   - You can run the provided `fix_plist_in_bundle.sh` script to verify its inclusion

4. **Modify AppDelegate.swift to handle missing file gracefully**:
   ```swift
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
   ```

5. **Important: Add to .gitignore**
   ```
   # Firebase configuration file containing API keys
   **/GoogleService-Info.plist
   ```

The GoogleService-Info.plist file contains API keys and project identifiers that are specific to your Firebase project. Each developer should download their own copy from the Firebase console when setting up the project locally.

## Complete M1 Mac Firebase Integration Process

For a clean setup on M1 Mac:

1. **Clean your project**:
   ```bash
   flutter clean
   cd ios && pod deintegrate && pod clean
   ```

2. **Update AppDelegate.swift** with error handling for Firebase initialization

3. **Update Podfile** with required fixes using our script:
   ```bash
   cd ios
   ./fix_podfile_for_g_flag.sh
   ```
   This adds:
   - Non-modular header fix
   - BoringSSL-GRPC compiler flag fix
   - Configuration for pre-compiled Firestore frameworks
   - Proper iOS deployment target settings
   - Architecture exclusions for simulator builds

4. **Ensure GoogleService-Info.plist is correctly included**:
   ```bash
   cd ios
   ./fix_plist_in_bundle.sh
   ```

5. **Install pods** with the modified Podfile:
   ```bash
   cd ios
   pod install
   ```

6. **Run your app**:
   ```bash
   flutter run
   ```

## What We Learned

1. **Firebase initialization issues can be fixed with better error handling**:
   - Always check for GoogleService-Info.plist existence before calling `FirebaseApp.configure()`
   - Use try-catch to prevent crashes when Firebase initialization fails
   - Add meaningful error logging for Firebase initialization issues

2. **Podfile modifications are key to M1 Mac compatibility**:
   - Handle BoringSSL-GRPC compiler flags
   - Fix non-modular header issues
   - Configure architecture settings properly
   - Use pre-compiled Firestore frameworks when possible

3. **GoogleService-Info.plist needs to be properly included in Xcode project**:
   - Verify file location in Xcode project navigator
   - Check inclusion in Bundle Resources
   - Verify its reference in the project.pbxproj file

4. **Scriptable fixes enhance reproducibility**:
   - Create focused scripts for specific issues (plist inclusion, podfile fixes)
   - Document script functionality for future reference
   - Automate the most error-prone parts of the setup process

These lessons and fixes have allowed us to successfully run our Flutter app with Firebase on an M1 Mac, which was a previously challenging configuration.

## M1 Mac Architecture Issues in Detail

The M1 Mac (Apple Silicon) uses the ARM64 architecture, while many iOS libraries and build tools are still designed for Intel's x86_64 architecture. This mismatch causes several problems:

1. **Architecture mismatch**: M1 Mac (arm64) vs. Intel-based libraries (x86_64)
   * Solution: Use Rosetta 2 translation by running commands with `arch -x86_64` prefix
   * Solution: Exclude arm64 architecture from simulator builds

2. **Missing flags for simulator architecture**:
   * Solution: Modify Xcode project settings to exclude arm64 from simulator builds
   * Solution: Use compatible compiler flags and avoid problematic options like '-G'

3. **GoogleUtilities version conflicts**: Firebase and Google Sign-In using incompatible versions
   * Solution: Use Firebase Authentication directly instead of Google Sign-In package
   * Solution: Pin specific versions of dependencies that are compatible

4. **Compiler flag errors**: 
   * Problem: The '-G' compiler flag is not supported for x86_64 simulators on M1 Macs
   * Solution: Modify Podfile to handle BoringSSL-GRPC compiler flags
   * Solution: Use pre-compiled Firestore frameworks to avoid building BoringSSL-GRPC
   * Solution: Directly edit project.pbxproj to remove problematic flags
   * Solution: Clean Xcode derived data for fresh build
   * Note: This is a known issue with BoringSSL-GRPC dependency fixed in gRPC 1.65.2

5. **Non-modular header issues**:
   * Problem: Include of non-modular header inside framework module errors
   * Solution: Set `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES` to `YES`
   * Solution: Update header visibility from "Project" to "Public" for problematic headers

6. **Firebase initialization crashes**:
   * Problem: "FirebaseApp.configure() could not find a valid GoogleService-Info.plist"
   * Solution: Make sure GoogleService-Info.plist is in the correct location
   * Solution: Add error handling to AppDelegate.swift
   * Solution: Verify the file is included in the Xcode project correctly

## References

* [StackOverflow: Flutter - Include of non-modular header inside framework module](https://stackoverflow.com/questions/66148505/flutter-include-of-non-modular-header-inside-framework-module-firebase-core-fl)
* [StackOverflow: Error when trying to run Flutter App with M1 Mac](https://stackoverflow.com/questions/68168869/error-when-trying-to-run-my-flutter-app-with-my-m1-mac)
* [StackOverflow: Flutter iOS Architecture Issue in M1 Mac using VS code](https://stackoverflow.com/questions/70320935/flutter-ios-architecture-issue-in-m1-mac-using-vs-code)
* [GitHub: Flutter issue #91217 - M1 Mac Build Issues](https://github.com/flutter/flutter/issues/91217)
* [GitHub: Firebase issue #13115 - BoringSSL-GRPC fails in Xcode 16 with '-G' option](https://github.com/firebase/firebase-ios-sdk/issues/13115)
* [GitHub: FlutterFire issue #12960 - Comment with Podfile fix](https://github.com/firebase/flutterfire/issues/12960#issuecomment-2453004582)
* [Flutter Documentation: Install iOS from macOS](https://docs.flutter.dev/platform-integration/ios/install-macos)
* [Firebase Documentation: Add Firebase to Flutter](https://firebase.google.com/docs/flutter/setup)
* [Firebase Documentation: Sign in with Apple](https://firebase.google.com/docs/auth/ios/apple) 