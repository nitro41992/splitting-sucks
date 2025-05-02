# iOS Setup Guide for Billfie App

This guide will help you set up and run the Billfie app on iOS devices using the `ios-setup-local` branch.

## Prerequisites

1. macOS computer (preferably with M1/M2/M3 chip)
2. Xcode 14.0 or higher installed
3. Flutter SDK installed and configured
4. Firebase project set up with iOS app registered
5. CocoaPods installed: `sudo gem install cocoapods`

## Setup Steps

### 1. Clone and Switch to the Right Branch

```bash
git clone https://github.com/your-repo/splitting-sucks.git
cd splitting-sucks
git checkout ios-setup-local
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Set Up Firebase Configuration

1. Download `GoogleService-Info.plist` from your Firebase console
2. Place it in the `ios/Runner/` directory
3. Make sure it's added to your Xcode project (it's excluded from Git)

### 4. Fix iOS Build Issues on M1 Mac

We've created several scripts to address common iOS build issues on M1 Macs:

1. Fix Podfile for the `-G` compiler flag issue:
   ```bash
   cd ios
   chmod +x fix_podfile_for_g_flag.sh
   ./fix_podfile_for_g_flag.sh
   ```

2. Ensure GoogleService-Info.plist is properly included:
   ```bash
   chmod +x fix_plist_in_bundle.sh
   ./fix_plist_in_bundle.sh
   ```

3. Install CocoaPods with necessary fixes:
   ```bash
   pod install
   ```

### 5. Configure Xcode Settings

1. Open the Xcode workspace:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Update the Bundle Identifier:
   - Make sure the Bundle Identifier in Xcode matches the one in your `GoogleService-Info.plist` (`com.billfie.app`)

3. Set up Code Signing:
   - In Xcode, select the Runner project
   - Go to the Signing & Capabilities tab
   - Choose your development team
   - If developing for simulator only, you can select "Automatically manage signing" with any team

### 6. Run the App

Run the app on an iOS simulator:

```bash
flutter run -d "iPhone 15 Pro"
```

Or on a physical device (if connected):

```bash
flutter run
```

## App Structure

The app has been restructured to work properly on iOS with Firebase:

1. **main.dart**: Entry point with Firebase initialization
2. **firebase_options.dart**: Platform-specific Firebase configuration
3. **receipt_splitter_ui.dart**: Main UI that checks authentication and shows the appropriate screen
4. **services/auth_service.dart**: Handles authentication with Firebase Auth
5. **screens/login_screen.dart**: Login UI with email/password, Google, and Apple sign-in options
6. **functions/main.py**: Cloud Functions for receipt parsing and processing

## Troubleshooting

### Firebase Initialization Issues

If you encounter "FirebaseApp.configure() could not find a valid GoogleService-Info.plist":

1. Make sure `GoogleService-Info.plist` is in `ios/Runner/`
2. Verify it's added to the Xcode project (not just the folder)
3. Check the Bundle ID in Xcode matches the one in the plist file

### Compiler Errors

For BoringSSL-GRPC compiler errors or architecture issues:

1. Re-run the `fix_podfile_for_g_flag.sh` script
2. Clean the build:
   ```bash
   flutter clean && cd ios && pod deintegrate && pod install && cd ..
   ```

### Authentication Issues

If login functions aren't working:

1. Verify Firebase Auth is enabled in the Firebase console
2. Check that your app's Bundle ID matches the one registered in Firebase
3. For Google and Apple sign-in, verify you've set up the required configurations in the Firebase console

## Next Steps

Once the app is running successfully:

1. Test the login functionality
2. Upload receipt images
3. Connect to Firebase Cloud Functions
4. Test the bill splitting features

## References

For more detailed information, consult:

1. [m1_firebase_setup.md](m1_firebase_setup.md) - M1 Mac-specific Firebase issues and solutions
2. [Flutter Firebase Documentation](https://firebase.flutter.dev/docs/overview/)
3. [iOS Setup for Flutter](https://docs.flutter.dev/get-started/install/macos#ios-setup) 