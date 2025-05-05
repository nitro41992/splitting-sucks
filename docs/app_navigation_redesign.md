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
- Allow user to cancel saving process
- Auto-save draft state when user navigates away from incomplete workflow
- Clear indication that workflow will be available in History

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
- List view of receipt cards (both completed and drafts)
- Visual indication of draft status
- Search/filter options by date, restaurant name, and people involved
- Detail view when selecting a receipt
- Edit functionality to modify any aspect of a saved receipt (except re-uploading images)
- Delete option with confirmation dialog

#### Database Structure:
```
users/{userId}/receipts/{receiptId}
  - image_uri: String (GCS path)
  - created_at: Timestamp
  - updated_at: Timestamp
  - restaurant_name: String (required)
  - status: String (enum: "completed" or "draft")
  - total_amount: Number
  - receipt_data: Map {
      - items: Array<Map>
      - subtotal: Number
    }
  - transcription: String
  - assignments: Map {
      - person_name: Array<Map> [
        {
          id: Number,
          quantity: Number,
          ownership_type: String (enum: "individual" or "shared"),
          shared_with: Array<String> (only present if ownership_type is "shared")
        }
      ]
    }
  - unassigned_items: Array<Map> [
      {
        id: Number,
        quantity: Number
      }
    ]
  - people: Array<String> (derived from assignments for search)
  - split_results: Map {
      - person_totals: Map<String, Number>
      - tip_amount: Number
      - tax_amount: Number
      - subtotal: Number
      - total_with_tax_tip: Number
    }
```

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
   - Include validation rules to ensure data integrity
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
- [ ] Update `ReceiptSplitterUI` to use the new 3-item bottom navigation bar
- [ ] Create container screens for "Create", "History", and "Settings" sections
- [ ] Modify navigation logic to handle the new hierarchical structure

### 2. Create Workflow
- [ ] Restructure the existing 5-step workflow to nest within the "Create" section
- [ ] Implement appropriate navigation indicators within this section
- [ ] Ensure state preservation between workflow steps

### 3. History Functionality
- [ ] Create Firestore data models for storing receipt history
- [ ] Implement service methods for saving completed receipts to history
- [ ] Add auto-save functionality for drafts
- [ ] Update Firestore security rules to protect history data
- [ ] Design and implement history list view with filters
- [ ] Design and implement receipt detail view
- [ ] Implement edit functionality for saved receipts
- [ ] Add delete functionality with confirmation
- [ ] Implement search by date, restaurant name, and people
- [ ] Create draft indicator and UI treatment

### 4. Settings Section
- [ ] Design and implement settings screen
- [ ] Move logout functionality from current location to settings
- [ ] Implement account deletion with confirmation
- [ ] Add user profile display/management
- [ ] Implement any app-specific settings

### 5. Database Changes
- [ ] Create Firestore collections/documents for receipt history
- [ ] Update security rules to protect new collections
- [ ] Implement data migration plan if needed
- [ ] Add storage triggers to clean up orphaned files when receipts are deleted
- [ ] Add backup functionality for user data

### 6. Testing
- [ ] Test navigation flow in all screen sizes and orientations
- [ ] Verify history storage and retrieval functionality
- [ ] Test account management functions
- [ ] Perform security testing on new features

## UI/UX Considerations

1. **Consistency**: Maintain consistent design language throughout the app
2. **Feedback**: Provide clear feedback during navigation transitions
3. **Accessibility**: Ensure all new navigation elements are accessible
4. **Error Handling**: Implement proper error states for history loading/viewing
5. **Empty States**: Design appropriate empty states for the history section

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
- `gs://billfie.firebasestorage.app/receipts/PXL_20250504_180915852.jpg` (Takeout receipt)

#### Mock Data Structure
Each test receipt will contain:

```dart
{
  'image_uri': 'gs://billfie.firebasestorage.app/receipts/PXL_XXXXXXX.jpg',
  'created_at': Timestamp,
  'updated_at': Timestamp,
  'restaurant_name': 'Restaurant Name',
  'status': 'completed' or 'draft',
  'total_amount': 00.00,
  'receipt_data': {
    'items': [
      {'item': 'Item 1', 'quantity': 1, 'price': 10.99},
      {'item': 'Item 2', 'quantity': 2, 'price': 8.50},
      // Additional items...
    ],
    'subtotal': 00.00
  },
  'transcription': 'Mock voice transcription data...',
  'assignments': {
    'Person 1': [
      {'id': 0, 'quantity': 1, 'ownership_type': 'individual'},
      {'id': 4, 'quantity': 1, 'ownership_type': 'shared', 'shared_with': ['Person 2']}
    ],
    'Person 2': [
      {'id': 1, 'quantity': 2, 'ownership_type': 'individual'},
      {'id': 4, 'quantity': 1, 'ownership_type': 'shared', 'shared_with': ['Person 1']}
    ],
    'Person 3': [
      {'id': 3, 'quantity': 1, 'ownership_type': 'individual'}
    ]
  },
  'unassigned_items': [
    {'id': 5, 'quantity': 1}
  ],
  'people': ['Person 1', 'Person 2', 'Person 3'],
  'split_results': {
    'person_totals': {
      'Person 1': 00.00,
      'Person 2': 00.00,
      'Person 3': 00.00
    },
    'tip_amount': 0.00,
    'tax_amount': 0.00,
    'subtotal': 00.00,
    'total_with_tax_tip': 00.00
  }
}
```

### Item Ownership Logic

The data structure clearly distinguishes between individual and shared items:

1. **Individual Items**: An item assigned to a person with `ownership_type: 'individual'` is only owned by that person.

2. **Shared Items**: An item with `ownership_type: 'shared'` appears in multiple people's assignment lists. 
   - Each assignment includes a `shared_with` array listing the other people who share it.
   - This avoids duplication while making it clear who shares each item.

3. **Unassigned Items**: Items not assigned to anyone are in the top-level `unassigned_items` array.

This approach provides a single source of truth for item assignments while making it easy to:
- Determine what items each person has
- Filter items by ownership type (individual vs. shared)
- Calculate accurate split costs
- Support editing assignments when loading a receipt from history

### Integration with Testing Workflow

#### Running the Script:
```
flutter run scripts/populate_test_data.dart
```

This will:
1. Clear any existing test data (optional with confirmation)
2. Create new mock receipts in Firestore
3. Verify and display created data IDs
4. Provide a summary of created test data

#### Usage in Development:
- Separate test user account for mock data testing 
- Toggle to use mock data in development builds
- Visual indicator when viewing mock data
- Ability to delete individual mock receipts or all at once

### Implementation Tasks

1. **Create Mock Data Script**
   - [ ] Create `scripts/populate_test_data.dart` with Firebase connection
   - [ ] Implement test data generation following database schema
   - [ ] Add command-line options for customizing test data (count, types)
   - [ ] Document script usage in README

2. **Enhance Existing MockDataService**
   - [ ] Update `lib/services/mock_data_service.dart` to work with new history structure
   - [ ] Add methods to retrieve mock history data
   - [ ] Connect mock service to new History UI components
   - [ ] Implement simulated operations (edit, delete, filter)

3. **Integration Testing Support**
   - [ ] Add integration tests using mock data
   - [ ] Create testing scenarios for history functionality
   - [ ] Document testing approaches for the history feature