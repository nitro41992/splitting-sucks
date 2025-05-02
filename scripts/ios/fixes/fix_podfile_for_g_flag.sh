#!/bin/bash

# Path to your Podfile
PODFILE="./Podfile"

# Check if Podfile exists
if [ ! -f "$PODFILE" ]; then
  echo "Error: Podfile not found at $PODFILE"
  exit 1
fi

# Backup the original Podfile
cp "$PODFILE" "${PODFILE}.bak"
echo "Created backup at ${PODFILE}.bak"

# Add post_install hook to fix BoringSSL-GRPC compiler flags
cat > "$PODFILE" << 'EOT'
# Uncomment this line to define a global platform for your project
platform :ios, '12.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  # Flutter-specific pods
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # Use pre-compiled Firestore frameworks to avoid building BoringSSL-GRPC
  pod 'FirebaseFirestore', :git => 'https://github.com/invertase/firestore-ios-sdk-frameworks.git', :tag => '10.25.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    # Fix for non-modular headers
    target.build_configurations.each do |config|
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
    end

    # Fix for BoringSSL-GRPC compiler flags - removes problematic '-G' flag
    if target.name == 'BoringSSL-GRPC'
      target.source_build_phase.files.each do |file|
        if file.settings && file.settings['COMPILER_FLAGS']
          flags = file.settings['COMPILER_FLAGS'].split
          flags.reject! { |flag| flag == '-GCC_WARN_INHIBIT_ALL_WARNINGS' }
          file.settings['COMPILER_FLAGS'] = flags.join(' ')
        end
      end
    end
    
    # Fix for M1 Mac architecture issues
    flutter_additional_ios_build_settings(target)
    
    # Exclude arm64 architecture for simulator builds on Apple Silicon
    target.build_configurations.each do |config|
      if config.name == 'Debug' && config.build_settings['ARCHS'] == nil
        config.build_settings['ARCHS'] = '${ARCHS_STANDARD_64_BIT}'
      end
      
      # Set the deployment target to match the Flutter project
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      
      # Set iOS architectures
      if config.build_settings['SDKROOT'] == 'iphoneos' && target.platform_name == :ios
        config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
      end
    end
  end
end
EOT

echo "Updated Podfile with fixes for:
- BoringSSL-GRPC compiler flags
- Non-modular headers
- M1 Mac architecture issues
- Pre-compiled Firestore frameworks"

echo "Now run 'pod install' to apply changes" 