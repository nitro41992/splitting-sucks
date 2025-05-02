# Fixing Firebase iOS Build Issues for M1/M2 Macs

This guide addresses common Firebase iOS build issues, particularly the "-G" compiler flag error with BoringSSL-GRPC.

## Issue: unsupported option '-G' for target 'x86_64-apple-ios-simulator'

This occurs with Xcode 16+ when building Flutter apps with Firebase/Firestore for iOS simulators. The error happens because BoringSSL-GRPC uses a deprecated compiler flag (`-GCC_WARN_INHIBIT_ALL_WARNINGS`).

## Solution 1: Fix Podfile to Remove the Problematic Flag

Add this code to your `Podfile` in the `post_install` hook:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    # Fix for BoringSSL-GRPC compiler flag issue in Xcode 16+
    if target.name == 'BoringSSL-GRPC'
      target.source_build_phase.files.each do |file|
        if file.settings && file.settings['COMPILER_FLAGS']
          flags = file.settings['COMPILER_FLAGS'].split
          flags.reject! { |flag| flag == '-GCC_WARN_INHIBIT_ALL_WARNINGS' }
          file.settings['COMPILER_FLAGS'] = flags.join(' ')
        end
      end
    end
    
    # Other post-install settings
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

## Solution 2: Use Pre-compiled Firestore Frameworks

An alternative approach is to use pre-compiled Firestore frameworks to avoid building BoringSSL-GRPC altogether:

```ruby
# In your Podfile, inside the target 'Runner' do block
pod 'FirebaseFirestore', :git => 'https://github.com/invertase/firestore-ios-sdk-frameworks.git', :tag => '10.25.0'
```

Note: Make sure the tag version matches your Firebase SDK version (check your pubspec.yaml or run `flutter pub deps` to see the version).

## Complete Process to Fix

1. Clean the project:
   ```bash
   cd ios
   pod deintegrate
   pod clean
   rm Podfile.lock
   ```

2. Update your Podfile with one of the solutions above

3. Reinstall pods:
   ```bash
   pod install
   ```

4. Build and run:
   ```bash
   cd ..
   flutter run
   ```

## Additional Troubleshooting

If you encounter version conflicts, you may need to:

1. Make sure all Firebase plugins in your `pubspec.yaml` use the same version
2. Try using the exact same version for the pre-compiled FirebaseFirestore as your Firebase SDK
3. If you're using M1/M2 Macs, you might need to run pod commands with Rosetta:
   ```bash
   arch -x86_64 pod install
   ```

## Reference

- [GitHub Issue: unsupported option '-G' for target 'x86_64-apple-ios10.0-simulator'](https://github.com/firebase/flutterfire/issues/12960) 