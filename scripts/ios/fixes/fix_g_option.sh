#!/bin/bash
# Specific fix for the '-G' option error in Xcode builds
# This script modifies the Flutter-generated Pods project

echo "Starting fix for '-G' option error in Xcode builds..."

# Navigate to iOS folder
cd ios

echo "Creating a backup of any existing project.pbxproj files..."
cp Pods/Pods.xcodeproj/project.pbxproj Pods/Pods.xcodeproj/project.pbxproj.bak 2>/dev/null || true

echo "Removing problematic '-G' compiler flag from project.pbxproj..."
# Find and replace any compiler flags containing -G
find Pods -name "project.pbxproj" -exec sed -i '' 's/-G //g' {} \;

echo "Clean the DerivedData folder for a fresh build..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*Flutter*

echo "Fix completed! Try running your Flutter app again with:"
echo "flutter run"
echo ""
echo "If that doesn't work, try clean build:"
echo "flutter clean && flutter pub get && flutter run"

cd .. 