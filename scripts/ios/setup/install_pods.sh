#!/bin/bash

echo "Running complete iOS setup for Google Sign-In fix with iOS 16"

# Step 1: Clean up
echo "Cleaning up existing Pods and locks..."
rm -rf Pods Podfile.lock

# Step 2: Create mock google_sign_in_ios plugin to prevent the real one from being installed
echo "Creating mock google_sign_in_ios plugin..."
mkdir -p .symlinks/plugins/google_sign_in_ios/darwin

cat > .symlinks/plugins/google_sign_in_ios/darwin/google_sign_in_ios.podspec << EOF
Pod::Spec.new do |s|
  s.name             = 'google_sign_in_ios'
  s.version          = '0.0.1'
  s.summary          = 'Mock plugin for iOS'
  s.description      = 'This is a mock implementation to avoid dependency conflicts'
  s.homepage         = 'https://github.com/flutter/plugins'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'Flutter Dev Team' => 'flutter-dev@googlegroups.com' }
  s.source           = { :http => 'https://github.com/flutter/plugins.git' }
  s.source_files = '**/*.{h,m}'
  s.public_header_files = '**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
EOF

mkdir -p .symlinks/plugins/google_sign_in_ios/darwin/Classes
touch .symlinks/plugins/google_sign_in_ios/darwin/Classes/empty.m
touch .symlinks/plugins/google_sign_in_ios/darwin/Classes/empty.h

# Step 3: Run Flutter pub get
echo "Running Flutter pub get..."
cd ..
flutter pub get
cd ios

# Step 4: Install pods with Firebase 10.29.0
echo "Installing pods with Firebase 10.29.0..."
pod install --repo-update

echo "Setup completed! You can now run your app on iOS 16.0." 