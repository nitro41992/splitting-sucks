#!/bin/bash
# Fix script for Flutter + Firebase + M1 Mac issues
# Based on solutions from https://stackoverflow.com/questions/68168869/error-when-trying-to-run-my-flutter-app-with-my-m1-mac

echo "Starting complete M1 Mac fix for Flutter+Firebase..."

# Clean Flutter project
echo "🧹 Cleaning Flutter project..."
flutter clean

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Remove Pods directory
echo "🗑️ Removing Pods directory and Podfile.lock..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock

# Make Podfile changes just in case
echo "📝 Making sure Podfile has proper M1 fixes..."
cd ios
sed -i '' 's/config.build_settings\["EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]"\] = "arm64"/config.build_settings\["EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]"\] = "arm64"/g' Podfile

# Run pod install with x86_64 architecture with repo update
echo "🔄 Installing pods with x86_64 architecture..."
arch -x86_64 pod install --repo-update

# Extra fix for potential GoogleSignIn issues
echo "🔧 Applying extra fixes for Google Sign In..."
cd Pods
grep -rl "s.dependency 'GoogleUtilities/AppDelegateSwizzler'" . | xargs sed -i '' 's/s.dependency '"'"'GoogleUtilities\/AppDelegateSwizzler'"'"'/s.dependency '"'"'GoogleUtilities\/AppDelegateSwizzler'"'"', '"'"'~> 7.11'"'"'/g'
cd ..

# Final pod install to apply changes
echo "🔄 Final pod install to apply fixes..."
arch -x86_64 pod install

echo "✅ Fix completed! Try running your app now."
cd .. 