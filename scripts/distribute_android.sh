#!/bin/bash

# Script for distributing Android builds via Firebase App Distribution
# Usage: ./distribute_android.sh [OPTION]...
#
# Options:
#   -r, --release-notes "notes"   Release notes (defaults to "New release build")
#   -v, --version "x.y.z"         Version number (updates pubspec.yaml temporarily)
#   -g, --groups "group1,group2"  Comma-separated list of tester groups
#   -t, --testers "t1@mail,t2@mail" Comma-separated list of tester emails
#   -h, --help                    Display this help message

set -e  # Exit on error

# Figure out the project root directory
SCRIPT_DIR=$(dirname "$0")
if [[ "$SCRIPT_DIR" == "." ]]; then
  # Script is being run from the scripts directory
  PROJECT_ROOT=".."
elif [[ "$SCRIPT_DIR" == "./scripts" ]]; then
  # Script is being run from the project root
  PROJECT_ROOT="."
else
  # Handle absolute paths
  PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
fi

# Default values
RELEASE_NOTES="New release build"
VERSION=""
APP_ID="1:700235738899:android:f2b0756dfe3bca2f1774e6"
APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
TESTERS=""
GROUPS=""
GROUP_ID=""  # New variable for group ID
ORIGINAL_PUBSPEC=""
PUBSPEC_UPDATED=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--release-notes)
      RELEASE_NOTES="$2"
      shift 2
      ;;
    -v|--version)
      VERSION="$2"
      shift 2
      ;;
    -g|--groups)
      # Just store the exact groups string provided
      GROUPS="$2"
      shift 2
      ;;
    -t|--testers)
      TESTERS="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./distribute_android.sh [OPTION]..."
      echo "Distribute Android app to Firebase App Distribution"
      echo ""
      echo "Options:"
      echo "  -r, --release-notes \"notes\"   Release notes (defaults to \"New release build\")"
      echo "  -v, --version \"x.y.z\"         Version number (updates build version temporarily)"
      echo "  -g, --groups \"group1,group2\"  Comma-separated list of tester groups"
      echo "  -t, --testers \"t1@mail,t2@mail\" Comma-separated list of tester emails"
      echo "  -h, --help                    Display this help message"
      exit 0
      ;;
    *)
      # For backward compatibility, treat first positional arg as release notes
      if [[ "$RELEASE_NOTES" == "New release build" ]]; then
        RELEASE_NOTES="$1"
      fi
      shift
      ;;
  esac
done

# Navigate to project root
cd "$PROJECT_ROOT"

# If version specified, temporarily update pubspec.yaml
if [[ -n "$VERSION" && -f "pubspec.yaml" ]]; then
  echo "📝 Temporarily updating pubspec.yaml with version $VERSION..."
  
  # Save original content
  ORIGINAL_PUBSPEC=$(cat pubspec.yaml)
  
  # Extract current version with build number if present
  CURRENT_VERSION=$(grep -m 1 "version:" pubspec.yaml | sed 's/version: //')
  
  # Check if we have a build number (part after +)
  if [[ "$CURRENT_VERSION" == *"+"* ]]; then
    BUILD_NUMBER=$(echo "$CURRENT_VERSION" | sed 's/.*+//')
    echo "📊 Found build number: $BUILD_NUMBER"
    NEW_VERSION="$VERSION+$BUILD_NUMBER"
  else
    echo "⚠️ No build number found in current version, using version without build number"
    NEW_VERSION="$VERSION"
  fi
  
  echo "🔄 Updating version from $CURRENT_VERSION to $NEW_VERSION"
  
  # Use perl for more reliable in-place substitution
  perl -i -pe "s/^version: .*$/version: $NEW_VERSION/" pubspec.yaml
  
  # Verify the update worked
  UPDATED_VERSION=$(grep -m 1 "version:" pubspec.yaml | sed 's/version: //')
  if [[ "$UPDATED_VERSION" == "$NEW_VERSION" ]]; then
    echo "✅ Successfully updated pubspec.yaml to version $NEW_VERSION"
    PUBSPEC_UPDATED=true
  else
    echo "❌ Failed to update version in pubspec.yaml"
    echo "Current content:"
    cat pubspec.yaml | grep -m 3 "version:"
    echo "Restoring original pubspec.yaml..."
    echo "$ORIGINAL_PUBSPEC" > pubspec.yaml
    exit 1
  fi
elif [[ -n "$VERSION" ]]; then
  echo "⚠️ Warning: Could not find pubspec.yaml, version will not be updated"
fi

# If no version specified, extract it from pubspec.yaml for display
if [[ -z "$VERSION" && -f "pubspec.yaml" ]]; then
  VERSION=$(grep -m 1 "version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
  echo "📋 Using version from pubspec.yaml: $VERSION"
fi

# Option 1: If using testers directly (most reliable)
if [[ -n "$TESTERS" ]]; then
  echo "📧 Using testers: $TESTERS"
fi

# Option 2: If using a group
if [[ -n "$GROUPS" ]]; then
  echo "🔎 Using group name: $GROUPS"
  echo "⚠️ Group-based distribution is prone to errors with Firebase App Distribution."
  echo "💡 Consider using email addresses with -t instead if this doesn't work."
fi

# Clean the build to ensure version changes are picked up
echo "🧹 Cleaning previous builds..."
flutter clean

echo "📱 Building Android release APK..."
flutter build apk --release

echo "🔍 Checking APK path..."
if [ ! -f "$APK_PATH" ]; then
  echo "❌ Error: APK not found at $APK_PATH"
  
  # Restore original pubspec.yaml if it was modified
  if [[ "$PUBSPEC_UPDATED" == true ]]; then
    echo "🔄 Restoring original pubspec.yaml..."
    echo "$ORIGINAL_PUBSPEC" > pubspec.yaml
  fi
  
  exit 1
fi

# Verify the APK version by extracting it (optional but helps with debugging)
if which aapt >/dev/null; then
  echo "📦 Verifying APK version..."
  APK_VERSION=$(aapt dump badging "$APK_PATH" | grep versionName | sed "s/.*versionName='\([^']*\)'.*/\1/")
  echo "📱 APK version: $APK_VERSION (should be $VERSION)"
fi

echo "🚀 Distributing to Firebase App Distribution..."

# Start building the distribution command
DISTRIBUTE_CMD="firebase appdistribution:distribute \"$APK_PATH\" --app \"$APP_ID\" --release-notes \"$RELEASE_NOTES\""

# Add testers if specified
if [[ -n "$TESTERS" ]]; then
  DISTRIBUTE_CMD="$DISTRIBUTE_CMD --testers \"$TESTERS\""
fi

# Add groups if specified 
# Note: Not using groups directly anymore as it's unreliable
if [[ -n "$GROUPS" ]]; then
  # Try with the exact group name
  DISTRIBUTE_CMD="$DISTRIBUTE_CMD --groups \"$GROUPS\""
fi

# Execute the distribution command
echo "Executing: $DISTRIBUTE_CMD"
eval "$DISTRIBUTE_CMD"

# Restore original pubspec.yaml if it was modified
if [[ "$PUBSPEC_UPDATED" == true ]]; then
  echo "🔄 Restoring original pubspec.yaml..."
  echo "$ORIGINAL_PUBSPEC" > pubspec.yaml
fi

echo "✅ Distribution complete!"

# If there was an error with groups, show a helpful message
if [[ $? -ne 0 && -n "$GROUPS" ]]; then
  echo "
⚠️ ERROR: There was an issue with group-based distribution.

Firebase App Distribution has a common issue with group-based distribution.
Here are some alternative options:

1. Try running the command with testers instead of groups:
   ./scripts/distribute_android.sh -v \"$VERSION\" -r \"$RELEASE_NOTES\" -t \"kristiannaranjo@gmail.com,sawcasm@gmail.com\"

2. Upload the APK directly via the Firebase Console:
   - Go to https://console.firebase.google.com/project/billfie/appdistribution
   - Drag and drop the APK: $APK_PATH
   - Add your release notes and select testers/groups
"
fi 