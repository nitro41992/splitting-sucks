#!/bin/bash

# Script to fix iOS deployment target issues

echo "🔨 Fixing iOS deployment target issues..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Step 1: Clean flutter project
echo "🧹 Cleaning Flutter project..."
flutter clean

# Step 2: Update Flutter app framework info
echo "📝 Updating Flutter AppFrameworkInfo.plist..."
cat > ios/Flutter/AppFrameworkInfo.plist << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>App</string>
  <key>CFBundleIdentifier</key>
  <string>io.flutter.flutter.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>App</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>MinimumOSVersion</key>
  <string>16.0</string>
</dict>
</plist>
EOL

# Step 3: Update Xcode project deployment target
echo "📝 Updating Xcode project deployment target..."
cat > ios/update_ios_version.sh << EOL
#!/bin/bash
PBXPROJ_FILE="Runner.xcodeproj/project.pbxproj"
if [[ -f "\$PBXPROJ_FILE" ]]; then
    cp "\$PBXPROJ_FILE" "\${PBXPROJ_FILE}.bak"
    sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9]*\.[0-9]*/IPHONEOS_DEPLOYMENT_TARGET = 16.0/g' "\$PBXPROJ_FILE"
    echo "Successfully updated iOS deployment target in \$PBXPROJ_FILE"
else
    echo "Error: \$PBXPROJ_FILE not found"
    exit 1
fi
EOL
chmod +x ios/update_ios_version.sh
cd ios && ./update_ios_version.sh && cd ..

# Step 4: Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Step 5: Clean and rebuild iOS pods
echo "🧹 Cleaning and rebuilding iOS pods..."
cd ios
if [ -d "Pods" ]; then
    rm -rf Pods
fi
if [ -f "Podfile.lock" ]; then
    rm Podfile.lock
fi
pod install
cd ..

echo "✅ iOS deployment target fix complete!"
echo "🚀 You can now run your app with 'flutter run'" 