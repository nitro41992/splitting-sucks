# iOS Setup

This directory contains scripts for setting up and configuring iOS builds.

## Available Scripts

- `install_pods.sh` - Sets up iOS environment with proper Firebase configuration
- `fix_bundle_id.sh` - Fixes bundle identifier mismatches between Info.plist and Xcode project settings

## Usage

Run these scripts from the `ios` directory:

```bash
cd ios
sh ../scripts/ios/setup/install_pods.sh
```

For detailed information about iOS setup, refer to the [iOS Setup Guide](../../../docs/ios_setup_guide.md). 