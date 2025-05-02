# iOS Code Signing Guide for Billfie App

## Setting Up Code Signing in Xcode

Since Xcode is now open, follow these steps to set up code signing:

1. **Select the Runner Project in the Navigator**
   - In the left sidebar (Project Navigator), click on the "Runner" project (blue icon)

2. **Select the Runner Target**
   - In the center pane, select the "Runner" target
   - Ensure you're in the "Signing & Capabilities" tab

3. **Set Up Signing**
   - Under "Signing & Capabilities" > "Signing", check "Automatically manage signing"
   - Select your Apple Developer Team from the dropdown
   - If you don't see your team, click "Add Account..." and sign in with your Apple ID
   - Make sure the Bundle Identifier is `com.billfie.app` (matching your GoogleService-Info.plist)

4. **Handle Provisioning Profile Issues**
   - If you see a warning about provisioning profiles, click the "Register Device" button if prompted
   - Let Xcode automatically handle provisioning profile generation

5. **Verify Settings for Each Build Configuration**
   - At the top of the Signing section, check that signing is set up for Debug, Release, and Profile configurations
   - Use the dropdown to switch between them and ensure each is properly configured

## Running on a Simulator

To run on a simulator (no code signing required):

```bash
# Navigate back to the project root
cd ..

# Run on an iOS simulator
flutter run -d "iPhone 15 Pro"  # Replace with your preferred simulator name
```

## Running on a Physical Device

To run on a physical device (requires code signing):

1. **Connect your iOS device via USB**

2. **Trust your Development Certificate**
   - On your iOS device, go to Settings > General > Device Management
   - Select your Developer App certificate 
   - Tap "Trust"

3. **Run the app**
   ```bash
   # List available devices
   flutter devices
   
   # Run on your physical device
   flutter run -d "iPhone"  # Replace with your device ID if needed
   ```

## Troubleshooting

If you encounter code signing issues:

1. **Verify Team Selection**
   - Ensure your Apple Developer account is properly set up in Xcode Preferences > Accounts

2. **Check Bundle ID**
   - Verify the Bundle Identifier is unique and properly formatted
   - Ensure it matches what's in your GoogleService-Info.plist

3. **Reset Signing**
   - Sometimes it helps to uncheck and recheck "Automatically manage signing"

4. **Clean Build Folder**
   - In Xcode: Product > Clean Build Folder
   - Or run: `flutter clean && cd ios && pod install && cd ..`

5. **Update Provisioning Profiles**
   - In Xcode: Product > Clean Build Folder
   - Then: Xcode > Preferences > Accounts > [Your Account] > Download Manual Profiles

6. **Check Capabilities**
   - If you've added Firebase services that require specific capabilities (like Push Notifications), 
     make sure the appropriate capabilities are added in the "Signing & Capabilities" tab

## Next Steps After Code Signing

Once code signing is set up:

1. Build and run the app on your iOS device
2. Test Firebase functionality
3. Continue implementing your app's features 