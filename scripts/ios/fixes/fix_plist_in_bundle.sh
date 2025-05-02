#!/bin/bash

# Define paths
PLIST_SRC="GoogleService-Info.plist"
PLIST_DST="Runner/GoogleService-Info.plist"
PLIST_BACKUP="Runner/GoogleService-Info.plist.backup"

# Print current directory for debugging
echo "Current directory: $(pwd)"
echo "Files in current directory: $(ls -la)"

# Check if the file exists in the ios folder
if [ -f "$PLIST_SRC" ]; then
  echo "Found $PLIST_SRC in the iOS folder"
  
  # Verify file content
  echo "Verifying $PLIST_SRC content..."
  if grep -q "BUNDLE_ID" "$PLIST_SRC"; then
    echo "File content verification passed."
  else
    echo "Warning: $PLIST_SRC exists but may be invalid (BUNDLE_ID not found)"
  fi
  
  # Backup existing file if it exists
  if [ -f "$PLIST_DST" ]; then
    echo "Creating backup of existing $PLIST_DST"
    cp "$PLIST_DST" "$PLIST_BACKUP"
  fi
  
  # Copy to Runner folder
  echo "Copying $PLIST_SRC to $PLIST_DST"
  cp "$PLIST_SRC" "$PLIST_DST"
  
  # Verify copy succeeded
  if [ -f "$PLIST_DST" ]; then
    echo "Successfully copied to $PLIST_DST"
    echo "Contents of Runner directory: $(ls -la Runner)"
  else
    echo "Error: Failed to copy to $PLIST_DST"
  fi
else
  echo "Error: $PLIST_SRC not found in ios folder"
  
  # Check if it's in the Runner folder
  if [ -f "$PLIST_DST" ]; then
    echo "But $PLIST_DST exists in Runner folder, which is correct"
    # Verify file content
    echo "Verifying $PLIST_DST content..."
    if grep -q "BUNDLE_ID" "$PLIST_DST"; then
      echo "File content verification passed."
    else
      echo "Warning: $PLIST_DST exists but may be invalid (BUNDLE_ID not found)"
    fi
  else
    echo "Error: $PLIST_DST not found. Make sure to add GoogleService-Info.plist to your project"
    exit 1
  fi
fi

# Ensure the plist is included in the Xcode project
echo "Checking if GoogleService-Info.plist is included in Xcode project..."
pbxproj_file="Runner.xcodeproj/project.pbxproj"

if grep -q "GoogleService-Info.plist" "$pbxproj_file"; then
  echo "GoogleService-Info.plist is already included in the Xcode project"
else
  echo "Warning: GoogleService-Info.plist may not be included in Xcode project"
  echo "Please manually add it to your Xcode project by right-clicking the Runner folder,"
  echo "selecting 'Add Files to Runner...', and selecting GoogleService-Info.plist"
  echo "Make sure to check 'Copy items if needed' and add to target 'Runner'"
fi

echo "Done." 