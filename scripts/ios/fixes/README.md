# iOS Fixes

This directory contains scripts for fixing common issues with iOS builds, particularly for M1/M2/M3 Mac computers.

## Available Scripts

- `fix_podfile_for_g_flag.sh` - Fixes the -G compiler flag issue in BoringSSL-GRPC
- `fix_plist_in_bundle.sh` - Verifies GoogleService-Info.plist location and inclusion
- `fix_g_option.sh` - Fixes compiler flag issues in project.pbxproj
- `fix_m1_pods.sh` - Comprehensive fix for CocoaPods on M1 Macs
- `fix_xcode_arch.sh` - Fixes architecture settings in Xcode for M1 Macs

## Usage

Run these scripts from the `ios` directory:

```bash
cd ios
sh ../scripts/ios/fixes/fix_podfile_for_g_flag.sh
```

## Documentation

For detailed information about iOS build issues, refer to:

- [M1 Firebase Setup Guide](../../../docs/m1_firebase_setup.md) - Comprehensive guide for Firebase on M1 Macs
- [Fix Firebase iOS Build](../../../docs/fix_firebase_ios_build.md) - Quick reference for fixing common Firebase build issues 