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

### Receipts Screen (Main View)

- List of all saved receipts (both completed and drafts)
- Floating action button to add new receipt
- Search and filter capabilities
- Ability to select receipts for viewing details or editing

### Workflow Modal

- Contains the existing 5 steps (Upload, Review, Assign, Split, Summary)
- Step indicator at top (functions exactly like current tab navigation)
- Same progression logic as current app
- Auto-saves data after each cloud function returns results
- Option to cancel workflow and return to Receipts screen

## Data Model

```
users/{userId}/receipts/{receiptId}
  - image_uri: String  // Image reference for the receipt
  - thumbnail_uri: String  // Cached thumbnail reference for fast loading
  - parse_receipt: Map  // Direct output from parse_receipt function
  - transcribe_audio: Map  // Output from voice transcription function
  - assign_people_to_items: Map  // Output from item assignment function
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

## Implementation Approach

### Minimal Changes Strategy

1. **Reuse Existing Screens**: Keep all existing workflow screens with their current logic
2. **Simple Container Change**: Wrap workflow in a modal container instead of tabs
3. **Transform Navigation**: Convert bottom tabs to a step indicator with the same functionality
4. **Add Persistence**: Save function outputs to Firestore without transformations
5. **Update Receipts Screen**: Create a simple list view of stored receipts

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

2. After any user edits, update the corresponding data:
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
   
   These will all be captured in the `assign_people_to_items` field and the `split_manager_state`.

4. **Final Calculation Adjustments**: Any modifications to tax, tip, or other calculations will be reflected in the stored `split_manager_state`.

This ensures that all user input and customizations are preserved when resuming a draft or viewing a completed receipt.

## Key Implementation Tasks

1. **Navigation Structure**
   - Create 2-item bottom navigation (Receipts and Settings)
   - Add receipt list screen
   - Add floating action button

2. **Workflow Container**
   - Create modal container for the 5 existing workflow screens
   - Convert tab navigation to step indicator
   - Add save/cancel functionality

3. **Persistence**
   - Implement auto-save after each cloud function call
   - Create service methods to retrieve and update receipts
   - Add security rules for user data protection

4. **Receipt Management**
   - Implement receipt list and detail views
   - Add edit and delete functionality

## Security Considerations

1. **Firestore Rules**: Ensure users can only access their own receipts
2. **Secure Deletion**: Properly handle account and data deletion
3. **Authentication**: Maintain secure auth flow in Settings section

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

### Workflow Modal

```
┌─────────────────────────────────────────────────┐
│ ●───○───○───○───○                               │
│ Upload  Review  Assign  Split  Summary          │
├─────────────────────────────────────────────────┤
│                                                 │
│                                                 │
│            Current Step Content                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
├─────────────────────────────────────────────────┤
│    ← Back                        Next →         │
└─────────────────────────────────────────────────┘
```

## Summary

This redesign maintains all existing functionality while improving the user experience through:
1. A focused main screen showing all receipts
2. Easy access to create new receipts via FAB
3. A streamlined workflow experience in a modal container
4. Persistent storage of all receipt data
5. Minimal changes to existing code and cloud functions 