# Scripts Directory

This directory contains utility scripts for project setup and maintenance.

## Structure

- `core/` - Core utility scripts
  - `.pod-install-wrapper.sh` - Architecture-specific pod installer for M1 Macs

- `ios/` - iOS-specific utility scripts
  - `setup/` - Setup and configuration scripts
    - `install_pods.sh` - Sets up iOS environment with proper Firebase configuration
    - `fix_bundle_id.sh` - Fixes bundle identifier mismatches between Info.plist and Xcode project settings
  - `fixes/` - Scripts to fix common issues 
    - `fix_podfile_for_g_flag.sh` - Fixes the -G compiler flag issue in BoringSSL-GRPC
    - `fix_plist_in_bundle.sh` - Verifies GoogleService-Info.plist location and inclusion
    - `fix_g_option.sh` - Fixes compiler flag issues in project.pbxproj
    - `fix_m1_pods.sh` - Comprehensive fix for CocoaPods on M1 Macs
    - `fix_xcode_arch.sh` - Fixes architecture settings in Xcode for M1 Macs

- `fix_google_sign_in.sh` - Fixes Google Sign-In issues by removing GoogleSignIn plugin dependencies and updating AppDelegate.swift to use Firebase Auth directly
- `fix_google_sign_in_noprompt.sh` - Non-interactive version of the Google Sign-In fix (no confirmation prompts)
- `fix_ios_deployment_target.sh` - Updates iOS deployment target to 16.0 across all project files to be compatible with Firebase SDK requirements

## Authentication Fix Scripts

These scripts solve two main issues that were preventing Google Sign-In from working:

1. **GoogleUtilities Version Conflict**
   - `fix_google_sign_in.sh` and `fix_google_sign_in_noprompt.sh` remove the GoogleSignIn plugin and configure the app to use Firebase Auth's provider methods directly
   - The scripts modify AppDelegate.swift to remove GoogleSignIn imports and update URL handling

2. **iOS Deployment Target Mismatch**
   - `fix_ios_deployment_target.sh` updates the iOS minimum deployment target to 16.0 in:
     - AppFrameworkInfo.plist
     - Xcode project.pbxproj
     - Podfile (configuration settings)

## Usage

Scripts are organized by their purpose and platform:

```bash
# For iOS setup
flutter pub get
cd ios
sh ../scripts/ios/setup/install_pods.sh

# For iOS fixes
sh ../scripts/ios/fixes/fix_podfile_for_g_flag.sh
sh ../scripts/ios/fixes/fix_plist_in_bundle.sh

# For Google Sign-In issues
./scripts/fix_google_sign_in.sh
# OR (non-interactive version)
./scripts/fix_google_sign_in_noprompt.sh

# For iOS deployment target issues
./scripts/fix_ios_deployment_target.sh
```

All paths in documentation have been updated to reference these new script locations. 