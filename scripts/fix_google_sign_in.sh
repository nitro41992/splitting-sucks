#!/bin/bash

# Script to fix Google Sign-In issues in the project
echo "🔨 Fixing Google Sign-In issues..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Clean pub cache to remove any cached package conflicts
echo "🧹 Cleaning pub cache for google_sign_in..."
flutter pub cache clean

# Clean the project
echo "🧹 Cleaning project..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# For iOS platform
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "🍎 Setting up iOS platform..."
  
  # Update AppDelegate.swift to remove GoogleSignIn references
  echo "📝 Updating AppDelegate.swift..."
  
  APPDELEGATE_PATH="ios/Runner/AppDelegate.swift"
  if [[ -f "$APPDELEGATE_PATH" ]]; then
    # Backup the file
    cp "$APPDELEGATE_PATH" "${APPDELEGATE_PATH}.bak"
    
    # Remove GoogleSignIn import
    sed -i '' 's/import GoogleSignIn/\/\/ Removed GoogleSignIn import/g' "$APPDELEGATE_PATH"
    
    # Replace GoogleSignIn implementation with Firebase Auth
    sed -i '' 's/if GIDSignIn.sharedInstance.handle(url)/if Auth.auth().canHandle(url)/g' "$APPDELEGATE_PATH"
    
    # Update comment
    sed -i '' 's/\/\/ Support for Google Sign-In/\/\/ Handle URL schemes for Firebase Auth/g' "$APPDELEGATE_PATH"
    sed -i '' 's/\/\/ Handle Google Sign-In authentication callback/\/\/ Let Firebase Auth handle the URL/g' "$APPDELEGATE_PATH"
    
    echo "✅ AppDelegate.swift updated successfully"
  else
    echo "❌ AppDelegate.swift file not found"
  fi
  
  cd ios
  
  # Remove Pods directory to ensure a clean install
  echo "🧹 Removing Pods directory..."
  rm -rf Pods
  rm -f Podfile.lock
  
  # Install pods
  echo "📦 Installing pods..."
  pod install --repo-update
  
  cd ..
fi

# For Android platform
echo "🤖 Setting up Android platform..."
cd android
if [[ -f "./gradlew" ]]; then
  ./gradlew clean
else
  echo "⚠️ Gradle wrapper not found, skipping Android clean"
fi
cd ..

echo "✅ Google Sign-In fix complete!"
echo "🚀 You can now run your app with 'flutter run'" 