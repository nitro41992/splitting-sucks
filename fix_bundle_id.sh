#!/bin/bash
# Script to fix bundle identifier mismatch between Info.plist and Xcode project settings

set -e

# Define the target bundle ID from Info.plist
TARGET_BUNDLE_ID="com.billfie.app"
PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"

echo "🔍 Checking bundle identifiers..."
CURRENT_PLIST_ID=$(cd ios && /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Runner/Info.plist)
echo "- Info.plist bundle ID: $CURRENT_PLIST_ID"

# Use grep to find all PRODUCT_BUNDLE_IDENTIFIER lines in the project file
echo "🔎 Searching for bundle IDs in project file..."
grep -n "PRODUCT_BUNDLE_IDENTIFIER" "$PROJECT_FILE"

# Update the bundle ID in the project file using sed
echo "✏️ Updating bundle IDs in $PROJECT_FILE..."
sed -i '' "s/com\.example\.splittingSucks/$TARGET_BUNDLE_ID/g" "$PROJECT_FILE"
sed -i '' "s/com\.example\.splittingSucks\.RunnerTests/$TARGET_BUNDLE_ID.RunnerTests/g" "$PROJECT_FILE"

echo "✅ Bundle identifiers updated successfully."
echo "⚠️ Note: You may need to run 'flutter clean' and 'pod install' in the ios directory."
echo "   To do this, run:
   flutter clean
   cd ios && pod install && cd .." 