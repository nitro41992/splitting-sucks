#!/bin/bash

# Script for distributing Android builds via Firebase App Distribution
# Usage: ./distribute_android.sh "Your release notes here"

set -e  # Exit on error

RELEASE_NOTES="${1:-New release build}"
APP_ID="1:700235738899:android:f2b0756dfe3bca2f1774e6"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

echo "📱 Building Android release APK..."
flutter build apk --release

echo "🔍 Checking APK path..."
if [ ! -f "$APK_PATH" ]; then
  echo "❌ Error: APK not found at $APK_PATH"
  exit 1
fi

echo "🚀 Distributing to Firebase App Distribution..."
firebase appdistribution:distribute "$APK_PATH" \
  --app "$APP_ID" \
  --groups "testers" \
  --release-notes "$RELEASE_NOTES"

echo "✅ Distribution complete!" 