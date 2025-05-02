#!/bin/bash

# Android Setup Script for Cross-Platform Compatibility
# This script assists in configuring Android build after iOS-specific changes

echo "========================================"
echo "Android Setup Script"
echo "========================================"

# Check if running from project root
if [ ! -d "android" ]; then
  echo "Error: Please run this script from the project root (where pubspec.yaml is located)"
  exit 1
fi

# Make sure Flutter is up to date
echo "Updating Flutter packages..."
flutter pub get

# Check if google-services.json exists
if [ ! -f "android/app/google-services.json" ]; then
  echo "Warning: google-services.json not found in android/app directory"
  echo "You need to download it from Firebase console and place it in android/app/"
  echo ""
  echo "Steps:"
  echo "1. Go to Firebase console > Project settings > Your apps > Android app"
  echo "2. Download google-services.json"
  echo "3. Place it in the android/app/ directory"
  echo ""
  read -p "Continue anyway? (y/n): " CONTINUE
  if [ "$CONTINUE" != "y" ]; then
    exit 1
  fi
fi

# Check Firebase options file
if grep -q "placeholder" "lib/firebase_options.dart"; then
  echo "Warning: Found placeholder in firebase_options.dart"
  echo "You need to update the Android appId in firebase_options.dart"
  echo ""
  echo "Open lib/firebase_options.dart and replace:"
  echo "  appId: '1:700235738899:android:placeholder'"
  echo "with the actual Android app ID from Firebase console"
  echo ""
fi

# Check platform-specific code
echo "Checking platform-specific code..."
PF_FILES=$(grep -r "Platform.isIOS" --include="*.dart" lib)
if [ ! -z "$PF_FILES" ]; then
  echo "Found platform-specific code that might need testing on Android:"
  echo "$PF_FILES"
  echo ""
fi

# Test build for Android
echo "Building Android app to check for compatibility issues..."
flutter build apk --debug

if [ $? -eq 0 ]; then
  echo "✅ Android build successful!"
  echo ""
  echo "Next steps:"
  echo "1. Test the app on your Android device:"
  echo "   flutter run -d <device-id>"
  echo ""
  echo "2. Test authentication methods:"
  echo "   - Email/Password"
  echo "   - Google Sign-In"
  echo ""
  echo "3. Check UI for any platform-specific issues"
  echo ""
  echo "After successful testing, you can merge ios-setup-local to main"
else
  echo "❌ Android build failed!"
  echo "Please fix the errors before continuing."
fi 