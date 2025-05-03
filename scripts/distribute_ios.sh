#!/bin/bash

# Script for distributing iOS builds via Firebase App Distribution
# Usage: ./distribute_ios.sh "Your release notes here"

set -e  # Exit on error

RELEASE_NOTES="${1:-New iOS release build}"

# You need to replace this with your iOS app ID from Firebase
# Format is different from Android: iOS uses just the number
IOS_APP_ID="YOUR_IOS_APP_ID"  # Replace with actual iOS app ID from Firebase console

echo "📱 Building iOS release..."
# Build the iOS app in release mode
flutter build ios --release --no-codesign

# Change to iOS directory
cd ios

echo "📦 Creating .ipa file..."
# Create a temporary directory for the build
mkdir -p build/archive

# Archive the app using xcodebuild
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
  -archivePath build/archive/Runner.xcarchive archive

# Export the archive to an IPA
xcodebuild -exportArchive -archivePath build/archive/Runner.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/ios/ipa

IPA_PATH="build/ios/ipa/Runner.ipa"

echo "🔍 Checking IPA path..."
if [ ! -f "$IPA_PATH" ]; then
  echo "❌ Error: IPA not found at $IPA_PATH"
  exit 1
fi

echo "🚀 Distributing to Firebase App Distribution..."
firebase appdistribution:distribute "$IPA_PATH" \
  --app "$IOS_APP_ID" \
  --groups "testers" \
  --release-notes "$RELEASE_NOTES"

echo "✅ Distribution complete!"

# Return to original directory
cd .. 