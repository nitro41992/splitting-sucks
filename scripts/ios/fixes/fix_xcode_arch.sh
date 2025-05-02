#!/bin/bash
# Fix script for Xcode architecture settings for M1 Mac
# Based on solution from https://stackoverflow.com/questions/70320935/flutter-ios-architecture-issue-in-m1-mac-using-vs-code

echo "Starting Xcode architecture fix for M1 Mac..."

# Navigate to iOS folder
cd ios

# Open Xcode automatically and prompt to exclude arm64 architecture
echo "Opening Xcode project, please configure the build settings manually:"
echo "1. Select Runner target"
echo "2. Go to Build Settings tab"
echo "3. Search for 'Excluded Architectures'"
echo "4. Add 'arm64' to the value for 'Any iOS Simulator SDK'"
echo "5. Save and close Xcode"
open Runner.xcworkspace

# Wait for user to confirm changes
read -p "Press Enter after you've made the changes in Xcode... "

# Modify the Podfile to add explicit architecture flags
echo "Updating Podfile with additional architecture settings..."
cat > Podfile << 'EOL'
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

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # Add the Firebase pod for Google Analytics
  pod 'FirebaseAnalytics'
  
  # For Analytics without IDFA collection capability, use this pod instead
  # pod 'FirebaseAnalytics', '~> 10.17.0', :configurations => ['Debug', 'Release']

  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  # Flutter post install
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Start of the permission-related build settings
    target.build_configurations.each do |config|
      # You can enable the permissions needed here
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_MICROPHONE=1',
      ]
      
      # Enable code signing for all build configurations
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'YES'
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      
      # Set minimum iOS version to 12.0
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      
      # Comprehensive M1 Mac architecture fixes
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      
      # Fix for unsupported option '-G' for target 'x86_64-apple-ios-simulator'
      if config.name == 'Debug' && defined?(config.build_settings['OTHER_CFLAGS'])
        config.build_settings['OTHER_CFLAGS'] ||= ['$(inherited)']
        config.build_settings['OTHER_CFLAGS'] << '-fembed-bitcode'
      end
    end
  end
  
  # Fix for aggregate targets for simulator
  installer.aggregate_targets.each do |aggregate_target|
    aggregate_target.xcconfigs.each do |config_name, config_file|
      config_file.attributes['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      xcconfig_path = aggregate_target.xcconfig_path(config_name)
      config_file.save_as(xcconfig_path)
    end
  end
  
  # Fix for pods project configuration
  installer.pods_project.build_configurations.each do |config|
    config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
  end
  
  # Additional fix for preventing system warnings
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 12.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      end
    end
  end
end
EOL

# Run pod install with architecture flags
echo "Running pod install with architecture-specific settings..."
arch -x86_64 pod install --repo-update

echo "Architecture fix completed. Try running your app with:"
echo "flutter run --no-sound-null-safety"

cd .. 