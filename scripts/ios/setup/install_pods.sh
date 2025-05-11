#!/bin/bash

echo "Running complete iOS setup for Google Sign-In fix"

# Ensure we are in the project root
# This script assumes it's being run from the project root e.g., ./scripts/ios/setup/install_pods.sh
PROJECT_ROOT=$(pwd)
IOS_DIR="${PROJECT_ROOT}/ios"

# Step 1: Clean up in the ios directory
echo "Cleaning up existing Pods and locks in ${IOS_DIR}..."
rm -rf "${IOS_DIR}/Pods" "${IOS_DIR}/Podfile.lock"

# Step 2: Create mock google_sign_in_ios plugin
# Paths for symlinks should be relative to where Podfile is, or use absolute paths
# Assuming Podfile is in ${IOS_DIR}
MOCK_PLUGIN_DIR="${IOS_DIR}/.symlinks/plugins/google_sign_in_ios/darwin"
echo "Creating mock google_sign_in_ios plugin in ${MOCK_PLUGIN_DIR}..."
mkdir -p "${MOCK_PLUGIN_DIR}"

# Ensure EOF is on a line by itself with no whitespace
cat > "${MOCK_PLUGIN_DIR}/google_sign_in_ios.podspec" <<EOF
Pod::Spec.new do |s|
  s.name             = 'google_sign_in_ios'
  s.version          = '0.0.1'
  s.summary          = 'Mock plugin for iOS'
  s.description      = 'This is a mock implementation to avoid dependency conflicts'
  s.homepage         = 'https://github.com/flutter/plugins'
  s.license          = { :type => 'BSD', :file => '../../../LICENSE' }
  s.author           = { 'Flutter Dev Team' => 'flutter-dev@googlegroups.com' }
  s.source           = { :http => 'https://github.com/flutter/plugins.git' }
  s.source_files = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
EOF

mkdir -p "${MOCK_PLUGIN_DIR}/Classes"
touch "${MOCK_PLUGIN_DIR}/Classes/empty.m"
touch "${MOCK_PLUGIN_DIR}/Classes/empty.h"

# Step 3: Run Flutter pub get from project root
echo "Running Flutter pub get from ${PROJECT_ROOT}..."
flutter pub get

# Step 4: Install pods from ios directory
echo "Installing pods from ${IOS_DIR}..."
cd "${IOS_DIR}" || exit
pod install --repo-update
cd "${PROJECT_ROOT}"

echo "Setup completed!" 