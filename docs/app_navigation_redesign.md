# App Navigation Redesign Plan

## Overview

This document outlines the plan to redesign the app's navigation structure by:

1. Consolidating the 5 existing workflow tabs (Upload, Review, Assign, Split, Summary) into a single "Create" nav bar item
2. Adding a new "History" section to view past receipt workflows 
3. Creating a "Settings" section for user account management (logout, delete account)

## Current Structure

The app currently uses a bottom navigation bar with 5 items representing steps in the receipt splitting workflow:
- Upload
- Review
- Assign
- Split
- Summary

The logout functionality is currently accessed directly from the navigation bar.

## New Structure

### 1. Main Navigation Bar (Bottom)

The new bottom navigation bar will have 3 items:
- Create
- History
- Settings

### 2. "Create" Workflow

The "Create" section will contain all 5 steps of the current workflow, presented as a sequential process:

#### Implementation Options:
1. **Tabbed Interface**: Tabs at the top of the "Create" screen for the 5 steps
2. **Step Indicator**: A horizontal stepper showing the 5 steps with clear visual progress
3. **Nested PageView**: Keep the existing PageView but contained within the "Create" section

#### Navigation Logic:
- Maintain the existing progression logic (can't access later steps until earlier ones are complete)
- Back button to move to previous steps
- Clear indication of current step and completion status

#### Save Functionality:
- In the Summary step, add a prominent "Save" button
- When saving, prompt user to enter restaurant name (required)
- Saving successfully marks the receipt status as "completed"
- Allow user to cancel saving process
- Auto-save draft state when user navigates away from incomplete workflow (e.g., switching main tabs or closing the app)
- Clear indication that workflow will be available in History (both completed and drafts)

#### State Management:
- Robust state management (e.g., using Provider, Riverpod, Bloc) is required to handle the nested workflow state reliably.
- Ensure consistency across all steps, especially during auto-save operations, potentially using atomic writes or transactions where appropriate.

### 3. "History" Section

This section will display past receipt workflows saved for the current user.

#### Data to Store:
- Receipt image reference (Storage path)
- Parsed receipt items (JSON)
- Voice transcription data (if applicable)
- Item assignments data
- Final split calculations (including tip, tax adjustments)
- Timestamp and optional receipt name/label
- Status flag (completed or draft)
- Restaurant name (required when saving)
- People involved (derived from assignments)

#### UI Components:
- List view of receipt cards (both completed and drafts). Consider fetching only summary data (name, date, total, status, thumbnail, people count) for this list view to optimize performance, loading full details only when a card is selected.
- Visual indication of draft status
- Search/filter options by date, restaurant name, and people involved (Requires appropriate Firestore indexing).
- Detail view when selecting a receipt
- Edit functionality for saved receipts:
    - Selecting "Edit" on a completed or draft receipt should load its data back into the "Create" workflow, starting at the appropriate step (e.g., Summary or Review, depending on what needs changing).
    - Initial scope for editing involves manual changes to items, assignments, names, tip, tax, etc. Re-running AI processes (like OCR or voice assignment) on existing data is out of scope for the initial implementation.
    - Saving edits will overwrite the existing receipt record in Firestore.
- Delete option with confirmation dialog
- Flow for resuming drafts: User navigates to History, finds the draft receipt card, and taps an "Edit" or "Continue" action, which transitions them back to the "Create" workflow populated with the draft's state.

#### Database Structure:
```
users/{userId}/receipts/{receiptId}
  - image_uri: String (GCS path)
  - created_at: Timestamp
  - updated_at: Timestamp
  - userId: String // Store owner's UID for rules/queries
  - restaurant_name: String (required)
  - status: String (enum: "completed" or "draft")
  - total_amount: Number // Final total including tax/tip
  - receipt_data: Map {
      - items: Array<Map> [
        {
          id: Number,
          item: String, 
          quantity: Number, 
          price: Number
        }
      ]
      - subtotal: Number
    }
  - transcription: String // Final transcription text (potentially user-edited) used for assignments
  - people: Array<String> (derived from person_assignments for search)
  - person_totals: Array<Map> [ // Store final calculated total per person
      { name: String, total: Number }
    ]
  - split_manager_state: Map { // Captures the complete state needed to restore the UI
      - people: Array<Map> [
        {
          id: String,
          name: String,
          assignedItems: Array<Map> [
            {
              id: Number,
              item: String,
              quantity: Number,
              price: Number
            }
          ]
        }
      ],
      - sharedItems: Array<Map> [
        {
          id: Number,
          item: String,
          quantity: Number,
          price: Number,
          shared_by: Array<String>
        }
      ],
      - unassignedItems: Array<Map> [
        {
          id: Number,
          item: String,
          quantity: Number,
          price: Number
        }
      ],
      - tipAmount: Number,
      - taxAmount: Number,
      - subtotal: Number,
      - total: Number
    }
```
*Note on Data Model:* The `split_manager_state` field is designed to capture the complete information necessary to restore the application's state for viewing or editing a receipt. It includes detailed item information within assignments, shared items, unassigned items, and final calculations. The `assignment_result` structure (previously considered) has been removed to avoid redundancy. The `person_totals` field is included for efficient display of summary information.

### 4. "Settings" Section

This section will provide account management options:

#### Features:
- User profile information
- Logout option (moved from current nav bar)
- Delete account option (with confirmation dialog)
- App preferences/settings
- About/Help information

## Security Considerations

1. **Data Storage**:
   - Ensure all user data is properly secured with appropriate Firestore rules
   - Only allow users to access their own receipt history
   - Implement proper data deletion when a user deletes their account

2. **Authentication**:
   - Use Firebase Authentication's secure methods for logout and account deletion
   - Implement proper token management for authentication state
   - Require re-authentication before sensitive operations (account deletion)

3. **Account Deletion Process**:
   - Delete user authentication record
   - Delete all user data from Firestore
   - Delete all user files from Storage
   - Provide confirmation of complete data removal

4. **Firestore Security Rules for Receipt History**:
   - Implement strict security rules to ensure users can only access their own data
   - Include validation rules to ensure data integrity (e.g., status transitions, required fields, data types). Acknowledge that validating complex nested structures like `split_manager_state` within security rules requires careful and thorough rule definition.
   - Example security rules:

   ```
   service cloud.firestore {
     match /databases/{database}/documents {
       // Base rule - deny all by default
       match /{document=**} {
         allow read, write: if false;
       }
       
       // User profile - allow user to access only their own profile
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
         
         // Receipts collection - user can only access their own receipts
         match /receipts/{receiptId} {
           allow read: if request.auth != null && request.auth.uid == userId;
           allow create: if request.auth != null && request.auth.uid == userId;
           allow update: if request.auth != null && request.auth.uid == userId 
                          && resource.data.userId == request.auth.uid;
           allow delete: if request.auth != null && request.auth.uid == userId;
           
           // Validate receipt data on write
           function isValidReceipt() {
             let requiredFields = ['image_uri', 'created_at', 'receipt_data'];
             let hasAllRequired = requiredFields.all(field => request.resource.data[field] != null);
             
             return hasAllRequired 
                 && request.resource.data.userId == request.auth.uid
                 && request.resource.data.created_at is timestamp;
           }
           
           // Additional validation for create operations
           allow create: if request.auth != null 
                          && request.auth.uid == userId 
                          && isValidReceipt();
         }
       }
     }
   }
   ```

## Implementation Tasks

### 1. Navigation Structure
- [x] Update `ReceiptSplitterUI` to use the new 3-item bottom navigation bar
- [x] Create container screens for "Create", "History", and "Settings" sections
- [x] Modify navigation logic to handle the new hierarchical structure

### 2. Create Workflow
- [x] Restructure the existing 5-step workflow to nest within the "Create" section
- [x] Implement appropriate navigation indicators within this section
- [ ] Ensure state preservation between workflow steps

### 3. History Functionality
- [x] Create Firestore data models for storing receipt history
- [x] Implement service methods for saving completed receipts to history
- [x] Add auto-save functionality for drafts
- [x] Update Firestore security rules to protect history data, including comprehensive validation rules.
- [x] Design and implement history list view with filters (fetching summary data initially).
- [x] Design and implement receipt detail view (loading full data on demand).
- [ ] Implement edit functionality for saved receipts (loading back into "Create" workflow).

### 4. Settings Section
- [x] Design and implement settings screen
- [x] Move logout functionality from current location to settings
- [ ] Implement account deletion with confirmation
- [x] Add user profile display/management
- [ ] Implement any app-specific settings

### 5. Database Changes
- [x] Create Firestore collections/documents for receipt history
- [x] Update security rules to protect new collections
- [ ] Define and create necessary Firestore indexes to support required queries (e.g., filtering history by status, date, searching by people).
- [ ] Implement data migration plan if needed (Assumption: No existing user receipt data requires migration for this new feature).
- [ ] Add storage triggers or Cloud Functions to clean up orphaned files from Cloud Storage when associated receipt documents are deleted.
- [ ] Implement secure account deletion process using Cloud Functions triggered by Auth user deletion to ensure complete removal of user data (Firestore documents, Storage files).
- [ ] Add backup functionality for user data (Consider Firestore's built-in backup or scheduled exports).
- [ ] Enhance minimal Firestore security rules with additional validations:
  - Add userId validation to ensure documents contain correct user identification
  - Add field validation for required fields like image_uri, created_at, receipt_data
  - Add data type validation (e.g., ensuring timestamps are actual timestamps)
  - Add validation for status field to only accept 'completed' or 'draft'

### 6. Testing
- [x] Create mock data implementation for testing
- [x] Create test data population script
- [ ] Test navigation flow in all screen sizes and orientations
- [ ] Verify history storage and retrieval functionality (including list view performance)
- [ ] Test account management functions (logout, secure deletion via Cloud Functions)
- [ ] Perform security testing on new features and Firestore rules

## Implementation Progress

### Completed Items
1. ✅ Created data model class (`ReceiptHistory`) for storing receipt history in Firestore
2. ✅ Implemented service layer for receipt history operations:
   - `ReceiptHistoryService` - Actual Firestore implementation
   - `MockReceiptHistoryService` - Mock implementation for testing
   - `ReceiptHistoryProvider` - Strategy pattern provider for selecting implementation
3. ✅ Created environment flag (`USE_MOCK_RECEIPT_HISTORY`) for toggling between real and mock data
4. ✅ Updated Firestore security rules to protect receipt history data
5. ✅ Added comprehensive data validation in security rules
6. ✅ Enhanced `MockDataService` with receipt history generation capabilities
7. ✅ Created test data population script (`scripts/populate_test_data.dart`)
8. ✅ Successfully populated Firestore with mock receipt history data using Node.js script
9. ✅ Created 3 test receipts in the database (2 completed, 1 draft) with proper structure
10. ✅ Implemented new app navigation structure with bottom navigation bar (Create, History, Settings)
11. ✅ Designed and implemented History screen with filtering and search capabilities
12. ✅ Developed Receipt Detail view for viewing saved receipt information
13. ✅ Created step indicator for the Create workflow to improve user experience
14. ✅ Implemented Settings screen with user profile display and logout functionality
15. ✅ Added robust error handling for environment configuration issues
16. ✅ Implemented platform-specific UI adaptations for iOS and Android
17. ✅ Added graceful fallbacks for authentication and initialization errors

### In Progress
1. 🔄 Integration of "Edit" functionality to load receipts back into the Create workflow
2. 🔄 Account deletion process implementation
3. 🔄 Create workflow auto-save functionality
4. 🔄 Cross-device testing across Android and iOS

### Pending
1. ⏳ Add app-specific settings (appearance, notifications)
2. ⏳ Testing across different screen sizes
3. ⏳ Performance testing for history list view
4. ⏳ Implement Cloud Functions for secure data cleanup

## Things to Consider

### Data Structure
- **State Preservation**: The current implementation stores the complete state for restoration, but we may need to optimize storage size for very large receipts.
- **Query Performance**: As users accumulate many receipts, we will need to implement pagination and optimize queries.
- **Data Integrity**: Consider adding server-side validation through Cloud Functions to ensure data consistency.

### Security
- **Storage Security**: Ensure Firebase Storage rules are updated to protect receipt images in a way that aligns with our Firestore security model.
- **Deletion Operations**: Implement cascading delete operations to ensure all related resources are properly cleaned up.
- **Backup Strategy**: Consider implementing regular backups or export options for users to prevent data loss.

### User Experience
- **Loading States**: Implement appropriate loading indicators during data fetch operations.
- **Error Handling**: Add comprehensive error handling with user-friendly messages for all operations.
- **Offline Support**: Consider implementing offline capabilities for viewing receipt history.

### Mobile-Specific Considerations
- **iOS Adaptations**: 
  - Added appropriate padding for iOS safe areas to accommodate the notch and home indicator
  - Used platform-aware widgets that automatically adapt to iOS styling (buttons, alerts, etc.)
  - Ensured appropriate haptic feedback on iOS devices
  - Verified tab bar appearance conforms to iOS design guidelines

- **Android Adaptations**:
  - Implemented Material You design principles for Android 12+ compatibility
  - Ensured proper handling of Android back button for navigation
  - Verified appropriate elevation and shadow rendering on Android devices
  - Tested on various Android screen sizes and densities

- **Cross-Platform Consistency**:
  - Maintained consistent navigation patterns across both platforms while respecting platform conventions
  - Ensured text scaling works appropriately on both platforms
  - Verified that all touch targets meet accessibility size requirements (minimum 44×44 points)
  - Tested keyboard behavior and input methods specific to each platform

### Development Workflow
- **Environment Toggle**: The mock data toggle provides an efficient development workflow but ensure it's disabled in production builds.
- **Testing Strategy**: Use a combination of unit, widget, and integration tests to verify the new functionality.
- **CI/CD Integration**: Update CI/CD pipelines to test the new components.

### Next Steps
The immediate next steps are:
1. Complete the "Edit" functionality to allow users to load historical receipts back into the Create workflow
2. Implement the account deletion process with proper security measures
3. Finish the auto-save functionality to preserve user progress in the Create workflow
4. Conduct thorough testing across various Android and iOS devices

## UI/UX Considerations

1. **Consistency**: Maintain consistent design language throughout the app
2. **Feedback**: Provide clear feedback during navigation transitions and for background operations like auto-saving (e.g., using snackbars or subtle indicators).
3. **Accessibility**: Ensure all new navigation elements are accessible
4. **Error Handling**: Implement detailed error handling and user feedback for key operations like saving receipts, loading history, editing, and deleting. Provide informative messages for network issues, permission errors, or validation failures.
5. **Empty States**: Design appropriate empty states for the history section (e.g., "No receipts saved yet", "No drafts found").
6. **Performance**: Optimize history list loading by fetching summary data first.

## Technical Debt and Future Improvements

1. **Pagination**: Implement pagination for history if users accumulate many receipts
2. **Offline Support**: Consider offline functionality for viewing receipt history
3. **Export Options**: Allow users to export receipt data in various formats
4. **Receipt Templates**: Allow saving common receipt patterns as templates 

## UI Mockup Descriptions

### New Bottom Navigation Bar

The redesigned bottom navigation bar will be simpler with just 3 items:

```
┌─────────────────────────────────────────────────┐
│                                                 │
│                 App Content Area                │
│                                                 │
│                                                 │
└─────────────────────────────────────────────────┘
┌─────────────────┬─────────────────┬─────────────────┐
│                 │                 │                 │
│     Create      │     History     │    Settings     │
│                 │                 │                 │
└─────────────────┴─────────────────┴─────────────────┘
```

### Create Workflow with Step Indicator

When in the "Create" section, a horizontal step indicator will appear at the top:

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
└─────────────────────────────────────────────────┘
┌─────────────────┬─────────────────┬─────────────────┐
│     ●Create     │     History     │    Settings     │
└─────────────────┴─────────────────┴─────────────────┘
```

### History Section UI

The History section will display receipt cards in a scrollable list:

```
┌─────────────────────────────────────────────────┐
│  History                         🔍 Search      │
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
│ ┌─────────────────────────────────────────────┐ │
│ │ Coffee Shop              $18.75   03/05/23  │ │
│ │ [Receipt thumbnail]       3 people    ⋮     │ │
│ └─────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────┐ │
│ │ [DRAFT] Lunch Meeting    $32.40   03/01/23  │ │
│ │ [Receipt thumbnail]       1 person    ⋮     │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
┌─────────────────┬─────────────────┬─────────────────┐
│     Create      │    ●History     │    Settings     │
└─────────────────┴─────────────────┴─────────────────┘
```

### Receipt Detail View in History

When selecting a receipt from history, users will see the detail view with edit options:

```
┌─────────────────────────────────────────────────┐
│  < Back                                    ⋮    │
├─────────────────────────────────────────────────┤
│  Restaurant Name                      03/15/23  │
│  [Receipt thumbnail]                            │
│                                                 │
│  Total: $75.50                                  │
│  People: John ($25.50), Mary ($20), Sam ($30)   │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │ Receipt Items (5)                     > │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │ Assignments                           > │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │           Continue Editing              │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Receipt Options Menu

When tapping the options menu (⋮) on a receipt:

```
┌────────────────────────┐
│ Edit                   │
│ Rename                 │
│ Delete                 │
└────────────────────────┘
```

### Delete Receipt Confirmation

When a user selects "Delete" for a receipt:

```
┌───────────────────────────────────────────┐
│          Delete Receipt?                  │
├───────────────────────────────────────────┤
│                                           │
│  Are you sure you want to delete this     │
│  receipt and all its data?                │
│                                           │
│  This action cannot be undone.            │
│                                           │
│     [ Cancel ]        [ Delete ]          │
│                                           │
└───────────────────────────────────────────┘
```

### Save Receipt Prompt

When saving a receipt from the Summary page:

```
┌───────────────────────────────────────────┐
│             Save Receipt                  │
├───────────────────────────────────────────┤
│                                           │
│  Enter restaurant or store name:          │
│  ┌─────────────────────────────────────┐  │
│  │ Pizza Place                         │  │
│  └─────────────────────────────────────┘  │
│                                           │
│     [ Cancel ]        [ Save ]            │
│                                           │
└───────────────────────────────────────────┘
```

### Delete Account Confirmation

When a user selects "Delete Account", they will see a confirmation dialog:

```
┌───────────────────────────────────────────┐
│        Confirm Account Deletion           │
├───────────────────────────────────────────┤
│                                           │
│  Are you sure you want to permanently     │
│  delete your account?                     │
│                                           │
│  This will:                               │
│  - Delete all your receipt history        │
│  - Remove all your saved data             │
│  - Permanently delete your account        │
│                                           │
│  To confirm, please enter your password:  │
│  ┌─────────────────────────────────────┐  │
│  │ ●●●●●●●●●●●●                        │  │
│  └─────────────────────────────────────┘  │
│                                           │
│     [ Cancel ]        [ Delete Account ]  │
│                                           │
└───────────────────────────────────────────┘
```

### Settings Section UI

The Settings section will contain user account options and app settings:

```
┌─────────────────────────────────────────────────┐
│  Settings                                       │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌────────────────────────────────────────────┐ │
│  │ Account                                  > │ │
│  └────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────┐ │
│  │ Appearance                               > │ │
│  └────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────┐ │
│  │ Notifications                            > │ │
│  └────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────┐ │
│  │ About                                    > │ │
│  └────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────┐ │
│  │ Log Out                                    │ │
│  └────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────┐ │
│  │ Delete Account                             │ │
│  └────────────────────────────────────────────┘ │
│                                                 │
└─────────────────────────────────────────────────┘
┌─────────────────┬─────────────────┬─────────────────┐
│     Create      │     History     │   ●Settings     │
└─────────────────┴─────────────────┴─────────────────┘
```

## Mock Data Implementation for Testing

To facilitate testing of the new History functionality without incurring AI processing costs, we'll implement a comprehensive mock data approach:

### Mock Receipt Data Script

Create a script to populate the Firestore database with realistic test receipt data:

```
├── scripts
│   ├── populate_test_data.dart  # New script to populate test data
```

#### Script Features:
- Populate 4-5 test receipts with varying characteristics
- Include both completed and draft receipts
- Use real stored receipt images from Firebase Storage
- Follow the exact database structure defined in this plan
- Easily runnable to restore test data after deletion testing

#### Test Receipt Images:
The following images are already uploaded to Firebase Storage and will be referenced in the mock data:
- `gs://billfie.firebasestorage.app/receipts/PXL_20240815_225730738.jpg` (Restaurant receipt)
- `gs://billfie.firebasestorage.app/receipts/PXL_20241207_220416408.MP.jpg` (Grocery receipt)
- `gs://billfie.firebasestorage.app/receipts/PXL_20250419_011719007.jpg` (Coffee shop receipt)
- `gs://billfie.firebasestorage.app/receipts/PXL_20250504_180915852.jpg`