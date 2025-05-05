# App Navigation Redesign Plan

## Overview

This document outlines the plan to redesign the app's navigation structure by:

1. Making "Receipts" the main view to display past and draft receipts
2. Adding a floating action button for "Add Receipt" to initiate the workflow
3. Converting the current 5-step workflow into a transient modal flow
4. Maintaining the existing backend/cloud function integration

## Current Structure

The app currently uses a bottom navigation bar with 5 items representing steps in the receipt splitting workflow:
- Upload
- Review
- Assign
- Split
- Summary

## New Structure

### Main Navigation

- **Bottom Navigation Bar**: Two items only - "Receipts" and "Settings"
- **Floating Action Button**: Add Receipt (initiates the workflow)
- **Receipt Workflow**: Becomes a transient modal flow rather than persistent tabs

### Visual Design Guidelines

- **Theme System**: Follow Material You design principles using the app's existing theme system
- **Color Palette**: 
  - Primary: Prussian Blue (#253D5B) - Used for navigation bar, primary buttons, and headers
  - Secondary: Puce (#C6878F) - Used for accents, floating action button
  - Tertiary: Rosy Brown (#B79D94) - Used for subtle accents and card borders
  - Surface: White - For background of cards and content areas
  - Text: Prussian Blue for headings, Dim Gray (#67697C) for body text
- **Typography**: Follow existing text theme with hierarchical styles
- **Component Consistency**: Reuse established design patterns for buttons, inputs, and cards
- **Elevation**: Use subtle elevation for cards (2dp) and modals (8dp) with consistent shadows

### Receipts Screen (Main View)

- List of all saved receipts (both completed and drafts)
- Floating action button to add new receipt
- Search and filter capabilities
- Ability to select receipts for viewing details or editing

### Workflow Modal

```
┌─────────────────────────────────────────────────┐
│ ●───○───○───○───○                      ✕        │
│ Upload  Review  Assign  Split  Summary          │
├─────────────────────────────────────────────────┤
│                                                 │
│                                                 │
│            Current Step Content                 │
│            (with existing navigation)           │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Design Notes:**
- Modal container with rounded corners (12dp radius) and surface color
- Step indicator uses Primary color (Prussian Blue) for active step
- Success color (green) for completed steps
- Close button (✕) to exit the workflow and return to Receipts screen
- Preserves existing in-screen navigation buttons and swipe gestures
- Content area maintains the styling of individual workflow steps

## Data Model

```
users/{userId}/receipts/{receiptId}
  - image_uri: String  // Image reference for the receipt
  - thumbnail_uri: String  // Cached thumbnail reference for fast loading
  - parse_receipt: Map  // Direct output from parse_receipt function
  - transcribe_audio: Map  // Output from voice transcription function
  - assign_people_to_items: Map {
      - assignments: Map<String, List<Map>> {  // Person name to items
          "<person_name>": [
            {"id": <item_id>, "quantity": <integer>}
          ]
        }
      - shared_items: List<Map> [
          {"id": <item_id>, "quantity": <integer>, "people": ["person1", "person2"]}  // List of people sharing this item
        ]
      - unassigned_items: List<Map> [
          {"id": <item_id>, "quantity": <integer>}
        ]
    }
  - split_manager_state: Map  // Final app state with all calculations
  - metadata: Map {
      - created_at: Timestamp
      - updated_at: Timestamp
      - status: String  // "draft" or "completed"
      - restaurant_name: String  // Required when completed
      - people: Array<String>  // List of people involved (for search)
    }
```

This model:
- Stores raw cloud function outputs directly without transformation
- Maintains backward compatibility with existing functions
- Links data to the corresponding image and user
- Includes minimal metadata for list display and search
- Stores reference to a pre-generated thumbnail for fast loading in lists
- **Explicitly tracks which people are sharing each shared item** through the "people" field in shared_items

## Implementation Approach

### Minimal Changes Strategy

1. **Reuse Existing Screens**: Keep all existing workflow screens with their current logic and navigation controls
2. **Simple Container Change**: Wrap workflow in a modal container instead of tabs
3. **Transform Navigation**: Convert bottom tabs to a step indicator with the same functionality
4. **Preserve Navigation Patterns**: Maintain existing in-screen buttons and swipe gestures
5. **Add Persistence**: Save function outputs to Firestore without transformations
6. **Update Receipts Screen**: Create a simple list view of stored receipts

### Efficient Image Handling

1. **Thumbnail Generation**:
   - Generate a smaller thumbnail version when the receipt image is first uploaded
   - Store the thumbnail in Firebase Storage alongside the original
   - Save reference to both original and thumbnail in the receipt document

2. **Image Caching**:
   - Implement local caching for thumbnails using Flutter's `cached_network_image` package
   - Pre-cache visible thumbnails in the receipt list for instant loading
   - Use a memory cache for recently viewed receipts to reduce storage operations

3. **Lazy Loading**:
   - Load thumbnails as needed when scrolling through the receipt list
   - Only load full-resolution images when viewing receipt details

### Auto-save Workflow

1. After each cloud function returns data, immediately store in Firestore:
   - Save `parse_receipt` results after OCR
   - Save `transcribe_audio` results after voice recording
   - Save `assign_people_to_items` results after assignments
   - Save final calculations in `split_manager_state`
   - Add subtle loading indicators or success checkmarks to indicate saving status

2. After any user edits, update the corresponding data in real-time or when moving between steps:
   - When user edits receipt items in the Review screen
   - When user modifies the transcription text
   - When user changes assignments (adding/removing people, changing item assignments)
   - When user adjusts shared items or unassigned items
   - When user modifies final calculations (tip, tax, etc.)

3. Use a consistent `receiptId` throughout the workflow to update the same document

### Preserving User Edits

The data model and persistence approach fully supports user edits at all workflow stages:

1. **Receipt Item Edits**: When a user edits items in the Review screen (names, prices, quantities), these changes will be saved to Firestore, updating the `parse_receipt` results with the user-modified values.

2. **Transcription Edits**: If a user corrects or modifies the transcription text, the updated text will be stored in the `transcribe_audio` field, preserving these changes.

3. **Assignment Modifications**: All changes to people and item assignments, including:
   - Adding or removing people
   - Changing which items are assigned to which people
   - Moving items between assigned, shared, and unassigned categories
   - Adjusting sharing proportions
   - **Specifying which people share each shared item** using the `people` field in `shared_items`
   
   These will all be captured in the `assign_people_to_items` field and the `split_manager_state`.

4. **Final Calculation Adjustments**: Any modifications to tax, tip, or other calculations will be reflected in the stored `split_manager_state`.

This ensures that all user input and customizations are preserved when resuming a draft or viewing a completed receipt.

### Improved Shared Item Handling

The enhanced data model provides significant improvements in how shared items are handled:

1. **Accurate Person Highlighting**: By explicitly tracking which people are sharing each item through the `people` field in `shared_items`, the UI can accurately highlight only the relevant people rather than assuming all people share every item.

2. **Precise Cost Distribution**: The application can calculate each person's portion of shared items correctly by looking at exactly who is sharing each item, improving the accuracy of the final bill split.

3. **Better UI Feedback**: In the Shared Items view, the app displays visual indicators showing exactly who is participating in each shared item, making it easier for users to verify that assignments are correct.

4. **Flexible Sharing Patterns**: Users can create varied sharing patterns where different subsets of people share different items, supporting more complex real-world scenarios like appetizers shared by some people but not others.

## Key Implementation Tasks

1. **Navigation Structure**
   - Create 2-item bottom navigation (Receipts and Settings)
   - Add receipt list screen
   - Add floating action button

2. **Workflow Container**
   - Create modal container for the 5 existing workflow screens
   - Convert tab navigation to step indicator
   - Add close button functionality
   - Maintain existing in-screen navigation controls
   - Preserve swipe gestures for back navigation

3. **Persistence**
   - Implement auto-save after each cloud function call
   - Add auto-save for user edits between steps
   - Create service methods to retrieve and update receipts
   - Add security rules for user data protection
   - Add subtle indicators to show save status

4. **Receipt Management**
   - Implement receipt list and detail views
   - Add edit and delete functionality

## Security Considerations

1. **Firestore Rules**: Ensure users can only access their own receipts
2. **Secure Deletion**: Properly handle account and data deletion
3. **Authentication**: Maintain secure auth flow in Settings section
4. **Data Validation**: 
   - Validate that people listed in shared items' "people" field exist in the receipt's people list
   - Ensure quantities across assignments, shared items, and unassigned items match original receipt quantities
   - Validate that calculations (tax, tip, total) are mathematically correct

## Data Integrity Checks

The application should implement the following data integrity checks to ensure consistent splitting:

1. **Person Reference Validation**: When processing the `people` field in shared items, verify that all referenced people exist in the assignments section.

2. **Quantity Accounting**: Ensure the sum of quantities for each item across assignments, shared items, and unassigned items equals the original quantity from the receipt.

3. **Shared Item Consistency**: Validate that each shared item has at least two people listed in its `people` field (otherwise it should be individually assigned or unassigned).

4. **Fallback Handling**: If the `people` field is missing in legacy data or from older cloud function responses, fall back to sharing the item among all people in the receipt.

## UI Mockups

### Main Receipts Screen with FAB

```
┌─────────────────────────────────────────────────┐
│  Receipts                         🔍 Search      │
├─────────────────────────────────────────────────┤
│ Filters: ○ All  ● Completed  ○ Drafts          │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ Restaurant Name           $75.50   03/15/23 │ │
│ │ [Receipt thumbnail]       4 people    ⋮     │ │
│ └─────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────┐ │
│ │ Grocery Store            $45.20   03/10/23  │ │
│ │ [Receipt thumbnail]       2 people    ⋮     │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│                      ⊕                         │
│                                                 │
└─────────────────────────────────────────────────┘
┌─────────────────────────┬─────────────────────────┐
│        Receipts         │        Settings         │
└─────────────────────────┴─────────────────────────┘
```

**Design Notes:**
- Navigation bar uses Primary color (Prussian Blue)
- FAB uses Secondary color (Puce) for emphasis
- Receipt cards use Surface color with subtle Tertiary (Rosy Brown) borders
- Typography follows hierarchical scale from app_theme.dart
- Filter chips use subtle surface variant background

### Workflow Modal

```
┌─────────────────────────────────────────────────┐
│ ●───○───○───○───○                      ✕        │
│ Upload  Review  Assign  Split  Summary          │
├─────────────────────────────────────────────────┤
│                                                 │
│                                                 │
│            Current Step Content                 │
│            (with existing navigation)           │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Design Notes:**
- Modal container with rounded corners (12dp radius) and surface color
- Step indicator uses Primary color (Prussian Blue) for active step
- Success color (green) for completed steps
- Close button (✕) to exit the workflow and return to Receipts screen
- Preserves existing in-screen navigation buttons and swipe gestures
- Content area maintains the styling of individual workflow steps

## Summary

This redesign maintains all existing functionality while improving the user experience through:
1. A focused main screen showing all receipts
2. Easy access to create new receipts via FAB
3. A streamlined workflow experience in a modal container
4. Persistent storage of all receipt data
5. Minimal changes to existing code and cloud functions 

## Implementation Progress

### Completed Tasks

1. **Data Model**
   - Created Receipt model in `lib/models/receipt.dart`
   - Created ReceiptMetadata model to store metadata for searching and display

2. **Services**
   - Created ReceiptService for CRUD operations in `lib/services/receipt_service.dart`
   - Implemented auto-save functionality for workflow steps
   - Added thumbnail generation for efficient loading

3. **UI Components**
   - Created ReceiptsScreen in `lib/screens/receipts_screen.dart`
   - Created SettingsScreen in `lib/screens/settings_screen.dart`
   - Created ReceiptWorkflowModal in `lib/widgets/receipt_workflow_modal.dart`
   - Created AppRoot component in `lib/app_root.dart` to replace ReceiptSplitterUI

4. **Navigation**
   - Implemented two-tab bottom navigation (Receipts and Settings)
   - Added floating action button for initiating new receipts
   - Created modal workflow container with step indicator

5. **Bug Fixes**
   - Added missing properties to SplitManager class:
     - Added `initialized` flag for tracking initialization state
     - Added `receiptItems` collection for storing receipt items
     - Added proper methods for `markAsShared` and `markAsUnassigned`
     - Added missing properties for restaurant name, subtotal, tax, tip, and tip percentage

6. **Visual Design**
   - Ensured consistent use of app theme from `app_theme.dart`
   - Applied Material You design principles throughout new components
   - Maintained color consistency using the palette from `app_colors.dart`:
     - Prussian Blue primary color for navigation and primary actions
     - Puce accent color for the floating action button and highlights
     - White surface color with consistent elevation for cards and containers
   - Used consistent text styles from the app's typography scale
   - Applied proper elevation and rounded corners to match existing components

### Remaining Tasks

1. **Bug Fixing**
   - Update existing workflow screens to work with the new modal container
   - Fix any issues with the AppRoot component

2. **Testing**
   - Test receipt creation
   - Test workflow steps with auto-saving
   - Test receipt search and filtering
   - Test receipt editing and deletion
   - Test thumbnail generation

3. **Deployment**
   - Update Firestore security rules for the new data structure
   - Test on various devices and screen sizes

### Notes for Future AI Sessions

- The implementation preserves all existing functionality while providing a more user-friendly navigation structure
- Existing cloud functions remain unchanged, we now simply store their output directly in Firestore
- The primary code changes involve reorganizing UI components rather than changing business logic
- The data model allows for efficient searching and filtering of receipts
- Auto-saving ensures that users never lose their progress
- **Required SplitManager Updates**: The SplitManager class needs several properties added or modified to match references in the ReceiptWorkflowModal:
  - Add `initialized` flag to track whether the manager has been initialized from saved state
  - Add `receiptItems` collection or use existing collection for receipt items
  - Add proper methods for `markAsShared` and `markAsUnassigned` or update the workflow modal to use existing methods
  - Ensure all necessary properties are properly defined in the SplitManager class
- **Security Considerations**: Make sure to implement proper Firestore security rules to protect user receipt data and enforce ownership
- **Design Consistency**: All new components must maintain the Material You design aesthetic:
  - Use the color constants from `AppColors` rather than hardcoded values
  - Apply the text styles from the theme's `TextTheme`
  - Use the predefined button styles from the theme for actions
  - Follow the elevation and corner radius conventions from the card and modal themes 