# Cross-Platform Compatibility Guide

This document outlines compatibility considerations and tasks to ensure that the `ios-setup-local` branch can be safely merged into `main` with both iOS and Android functionality intact.

## Current Branch Differences Analysis

The `ios-setup-local` branch introduces several platform-specific changes:

1. **Firebase Implementation**
   - Added `firebase_options.dart` with platform-specific configurations
   - Changed Firebase initialization in `main.dart`
   - Downgraded Firebase packages to compatible versions
   - Removed `flutter_dotenv` dependency (environment variables)

2. **Authentication Changes**
   - Removed GoogleSignIn plugin dependency
   - Implemented platform-specific auth methods using Firebase Auth directly
   - Added Apple Sign-In support

3. **Platform-Specific UI Adjustments**
   - Added `platform_config.dart` for platform-specific UI settings
   - Added `toast_helper.dart` for standardized notifications

4. **iOS-Specific Scripts**
   - Added multiple build and configuration scripts for iOS

## Android Compatibility Tasks

Before merging to `main`, these tasks should be completed:

1. **Firebase Configuration**
   - [ ] Update `firebase_options.dart` with correct Android app ID (currently uses placeholder)
   - [ ] Test Firebase connection on Android device

2. **Authentication Testing**
   - [ ] Verify Google Sign-In works on Android using new implementation
   - [ ] Test email/password authentication on Android
   - [ ] Ensure auth state persistence works correctly

3. **UI Consistency**
   - [ ] Test platform-specific UI adjustments on Android
   - [ ] Verify toast notifications display correctly
   - [ ] Check all screens for layout issues

## iOS Compatibility Tasks

These tasks should be verified on iOS devices before merging:

1. **Build & Run Validation**
   - [ ] Verify app builds successfully on iOS
   - [ ] Run the complete scripts workflow to ensure iOS compatibility

2. **Authentication Testing**
   - [ ] Verify Google Sign-In works on iOS
   - [ ] Test Apple Sign-In is functional
   - [ ] Verify email/password authentication

3. **Platform Scripts**
   - [ ] Validate all script executions produce expected results

## Integration Plan

To safely merge the `ios-setup-local` branch to `main`:

1. **Pre-Merge Testing**
   - Thoroughly test on both iOS and Android devices
   - Fix any platform-specific issues discovered

2. **Merge Strategy**
   - Create a squashed commit with clear documentation
   - Include detailed comments about platform-specific considerations

3. **Post-Merge Verification**
   - Test the merged code on both platforms again
   - Verify CI/CD pipelines pass

## Android Setup Instructions

To run the app on Android from a Windows machine:

1. **Environment Setup**
   ```bash
   git checkout ios-setup-local
   flutter pub get
   ```

2. **Firebase Configuration**
   - Ensure `google-services.json` is in the `android/app/` directory
   - Verify the Android app ID in `firebase_options.dart` matches your Firebase project

3. **Run on Physical Device**
   ```bash
   flutter run -d <device-id>
   ```

4. **Troubleshooting**
   - If Firebase initialization fails, check Android configuration in Firebase console
   - For authentication issues, verify OAuth client ID is correct

## Potential Issues and Solutions

1. **Firebase App ID Placeholder**
   - **Issue**: The Android app ID in `firebase_options.dart` is a placeholder
   - **Solution**: Replace with actual app ID from Firebase console

2. **Authentication Method Compatibility**
   - **Issue**: The new unified auth approach might behave differently on Android
   - **Solution**: Test thoroughly and add platform-specific handling if needed

3. **Package Version Conflicts**
   - **Issue**: Downgraded Firebase packages might cause issues with other dependencies
   - **Solution**: Verify all dependencies are compatible with the specified Firebase versions

4. **Platform-Specific UI Issues**
   - **Issue**: Some UI adjustments might not look correct on Android
   - **Solution**: Test on multiple Android devices and adjust platform detection as needed 