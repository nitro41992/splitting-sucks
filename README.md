# splitting_sucks

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Project Structure

- `scripts/` - Utility scripts for setup and maintenance
  - `ios/` - iOS-specific scripts
  - `android/` - Android-specific scripts
  - `fix_google_sign_in.sh` - Script to fix Google Sign-In issues
  - `fix_google_sign_in_noprompt.sh` - Non-interactive version of the Google Sign-In fix
  - `fix_ios_deployment_target.sh` - Script to update iOS deployment target to 16.0
- `docs/` - Documentation files
  - `ios_setup_guide.md` - Guide for iOS setup
  - `ios_code_signing_guide.md` - Guide for iOS code signing
  - `google_sign_in_fix.md` - Documentation for Google Sign-In fix
  - `m1_firebase_setup.md` - Guide for Firebase setup on M1/M2/M3 Macs
  - `fix_firebase_ios_build.md` - Troubleshooting guide for Firebase iOS build issues
  - `cross_platform_compatibility.md` - Guide for ensuring iOS and Android compatibility

## Cross-Platform Development

The app is designed to run on both iOS and Android platforms. For platform-specific setup:

### iOS Setup
Follow the detailed guide at [iOS Setup Guide](docs/ios_setup_guide.md).

### Android Setup
For Android setup after iOS changes:

```bash
# Run the Android setup script to check for compatibility issues
./scripts/android/setup_android.sh
```

For comprehensive cross-platform compatibility information, see the [Cross-Platform Compatibility Guide](docs/cross_platform_compatibility.md).

## Authentication

The app uses Firebase Authentication with Google Sign-In. We've solved two significant issues:

1. **GoogleUtilities Version Conflict**: Resolved conflicts between Firebase (7.x) and GoogleSignIn (8.x) by implementing a unified authentication approach using Firebase Auth's direct provider methods.

2. **iOS Deployment Target Mismatch**: Fixed deployment target issues by updating the app to target iOS 16.0, matching Firebase's requirements.

These fixes enable consistent authentication across both iOS and Android platforms without platform-specific code paths.

### Applying Authentication Fixes

Run either of these scripts to fix Google Sign-In:

```bash
# Interactive version with prompts
./scripts/fix_google_sign_in.sh

# Non-interactive version (no prompts)
./scripts/fix_google_sign_in_noprompt.sh
```

For iOS deployment target issues:

```bash
./scripts/fix_ios_deployment_target.sh
```

For detailed information about the fixes, see [Google Sign-In Fix Documentation](docs/google_sign_in_fix.md).

## Dynamic AI Prompts

The app uses a dynamic prompt system for AI interactions, allowing the modification of prompts and model configurations without redeploying Cloud Functions.

### Setup

1. Deploy the Cloud Functions with the dynamic configuration support
2. Run the initialization script to populate Firestore with default configurations:

```bash
cd functions
python init_firestore_config.py
```

### Usage

You can update AI prompts directly in the Firestore database:

1. Navigate to your Firebase project console
2. Go to Firestore Database
3. Edit the documents in `configs/prompts/[service_name]/current`

For detailed instructions, see [Firestore Configuration Setup](requirements/firestore_config_setup.md)

### Services

The following services support dynamic prompts:

1. **Parse Receipt** - Parses receipt images using OpenAI's vision capabilities
2. **Assign People to Items** - Assigns people to receipt items based on voice transcription
3. **Transcribe Audio** - Transcribes audio using OpenAI's Whisper API

### Security

Only authenticated admin users can modify the prompts and model configurations in Firestore. The Cloud Functions service account has read-only access to the configurations.
