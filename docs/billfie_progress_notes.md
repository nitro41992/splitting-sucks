# Billfie - Progress Notes

## Overview
This document tracks the progress, decisions, and patterns established in the Billfie app to ensure consistency across both Android and iOS platforms.

## Workflow Steps
The app follows a five-step workflow:
1. **Upload** - Take or select receipt photo
2. **Review** - Review and edit parsed receipt items
3. **Assign** - Use voice to assign items to people
4. **Split** - View and adjust item assignments
5. **Summary** - View final payment summary

## UI/UX Requirements
- Clean, minimal UI prioritizing functionality
- Material You design language for consistency
- Clear navigation between workflow steps
- Preserve state across app restarts/backgrounding

## App-Wide Consistency Guidelines

### App Bar
- **Style**: White background with elevation of 1
- **Title**: Two-line title "Billfie" with "Smarter bill splitting" subtitle
- **Logo**: Small (32x32) logo in leading position
- **Actions**:
  - Reset button (refresh icon)
  - Logout button (logout icon)

### Notifications
- Use top-positioned overlay notifications for important updates
  - Position: Below app bar (70px from top + status bar height)
  - Style: Gold/warning color (AppColors.warning) for standard notifications
  - Style: Red/error color (AppColors.error) for error notifications
  - Content: Icon + message text
  - Duration: 2 seconds
- Use consistent notification API: showNotification(context, message, isError)
- Fallback to SnackBars only when overlay context is unavailable
- All notifications should be non-blocking (don't cover app bar or navigation elements)
- Toast notifications should have sufficient padding and margin from screen edges

### State Management
- Use Provider for app-wide state (SplitManager)
- Save state to SharedPreferences to handle app backgrounding
- Lifecycle management with WidgetsBindingObserver
- Clear separation between data storage and UI

### Navigation
- Bottom navigation bar for main workflow steps
- Disable navigation to steps that haven't been completed
- Back button should navigate back one step or show exit confirmation
- Each step should properly initialize the next step

## Critical Fixes

### iOS Compatibility
- Added proper iOS permissions in Info.plist
  - NSCameraUsageDescription
  - NSPhotoLibraryUsageDescription
  - NSMicrophoneUsageDescription

### Voice Assignment Screen Fixes
- Fixed audio recording permissions
- Improved transcription error handling
- Fixed assignment data structure for proper parsing

### State Management Fixes
- Fixed assignments not persisting after voice transcription
- Implemented one-time initialization when navigating between screens
- Properly tracking original receipt total for verification

### UI Fixes
- Fixed render overflow in assignment dialog with Expanded widgets
- Centered notifications at the top of the screen
- Fixed app bar reset button functionality
- Fixed spacing in button rows and overall layout

## SplitManager Structure
- **People**: List of people participating in the bill split
- **Shared Items**: Items that are shared among multiple people
- **Unassigned Items**: Items that haven't been assigned to anyone
- **Receipt Items**: Original items from the parsed receipt
- **Assignments**: Mapping from people to their assigned items

## Data Flow from Voice Assignment to Split View
1. Voice transcription is processed by audio_transcription_service.dart
2. The service returns structured JSON with assignments
3. These assignments are stored but not immediately applied
4. When navigating to the split view, assignments are applied once
5. Split view uses SplitManager to render and manage assignments

## Testing Guidelines
- Test app state preservation (backgrounding/foregrounding)
- Test workflow from start to finish
- Verify cross-platform UI consistency
- Ensure all receipts can be parsed correctly
- Verify all items are properly assigned and total matches

## Known Issues and Future Improvements
- Add delete confirmation for people and shared items
- Improve error handling for receipt parsing edge cases
- Add offline mode capabilities
- Improve voice recognition accuracy with additional context
- Add animation transitions between screens

## Recent Bug Fixes
- Fixed duplicate assignments in the split view
- Fixed app bar reset functionality with complete app reset approach:
  - Clears SharedPreferences storage 
  - Resets SplitManager state
  - Uses Navigator.pushAndRemoveUntil for complete navigation reset
  - Added emergency forceRefreshApp utility function
- Fixed rendering overflow in assignment dialog
- Replaced bottom SnackBars with top notifications for consistent UX
- Added a reusable top notification system that doesn't interfere with the app bar

## Emergency Reset Method
For situations where normal reset doesn't fully work, we've added a `forceRefreshApp` method that:
- Clears all SharedPreferences data
- Resets the SplitManager to its initial state
- Completely rebuilds the app by navigating back to the root with a new instance 
- Removes all previous navigation history

This provides a "panic button" that can reliably reset the app state in any situation.

## Rebuild Process
If hot reload isn't applying changes properly or for a complete app reset, run the rebuild script:
```bash
# For iOS build
./scripts/rebuild_ios.sh
```
This will:
1. Clean the Flutter build cache
2. Get packages
3. Rebuild the iOS app without code signing 
4. Allow you to run the app with all changes properly applied 

## Provider Scope Issues
When implementing reset functionality, care must be taken to avoid Provider scope issues:

1. **Problem**: Accessing a Provider while navigating to a different route can cause "Could not find the correct Provider" errors
2. **Solution**: 
   - Don't try to access Provider state just before navigation
   - Navigate directly to the root application widget (MyApp) to ensure all Providers are properly initialized
   - Use a two-step approach: try simpler reset first, then fall back to full navigation reset
   - Always handle exceptions during reset operations

This pattern ensures that Provider state is properly maintained during app resets and prevents scope issues. 