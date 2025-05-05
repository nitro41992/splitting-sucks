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
- [ ] Update Firestore security rules to protect history data, including comprehensive validation rules.
- [ ] Design and implement history list view with filters (fetching summary data initially).
- [ ] Design and implement receipt detail view (loading full data on demand).
- [ ] Implement edit functionality for saved receipts (loading back into "Create" workflow).

### 4. Settings Section
- [ ] Design and implement settings screen
- [ ] Move logout functionality from current location to settings
- [ ] Implement account deletion with confirmation
- [ ] Add user profile display/management
- [ ] Implement any app-specific settings

### 5. Database Changes
- [ ] Create Firestore collections/documents for receipt history
- [ ] Update security rules to protect new collections
- [ ] Define and create necessary Firestore indexes to support required queries (e.g., filtering history by status, date, searching by people).
- [ ] Implement data migration plan if needed (Assumption: No existing user receipt data requires migration for this new feature).
- [ ] Add storage triggers or Cloud Functions to clean up orphaned files from Cloud Storage when associated receipt documents are deleted.
- [ ] Implement secure account deletion process using Cloud Functions triggered by Auth user deletion to ensure complete removal of user data (Firestore documents, Storage files).
- [ ] Add backup functionality for user data (Consider Firestore's built-in backup or scheduled exports).

### 6. Testing
- [ ] Test navigation flow in all screen sizes and orientations
- [ ] Verify history storage and retrieval functionality (including list view performance)
- [ ] Test account management functions (logout, secure deletion via Cloud Functions)
- [ ] Perform security testing on new features and Firestore rules

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
      {'id': 0, 'item': 'Item 1', 'quantity': 1, 'price': 10.99},
      {'id': 1, 'item': 'Item 2', 'quantity': 2, 'price': 8.50},
      {'id': 2, 'item': 'Item 3', 'quantity': 1, 'price': 8.99},
      {'id': 3, 'item': 'Item 4', 'quantity': 1, 'price': 12.99},
      {'id': 4, 'item': 'Item 5', 'quantity': 1, 'price': 15.99},
      {'id': 5, 'item': 'Item 6', 'quantity': 1, 'price': 5.99},
      {'id': 6, 'item': 'Item 7', 'quantity': 1, 'price': 9.49},
      {'id': 7, 'item': 'Item 8', 'quantity': 1, 'price': 7.50}
    ],
    'subtotal': 80.44
  },
  'transcription': 'Mock voice transcription data...',
  'people': ['Person 1', 'Person 2', 'Person 3'],
  'person_totals': [
    {'name': 'Person 1', 'total': 30.00}, // Example totals, replace with actual calculated values
    {'name': 'Person 2', 'total': 35.00},
    {'name': 'Person 3', 'total': 15.00}
  ],
  'split_manager_state': {
    'people': [
      {
        'id': 'Person 1',
        'name': 'Person 1',
        'assignedItems': [
          {'id': 0, 'item': 'Item 1', 'quantity': 1, 'price': 10.99},
          {'id': 2, 'item': 'Item 3', 'quantity': 1, 'price': 8.99}
        ]
      },
      {
        'id': 'Person 2',
        'name': 'Person 2',
        'assignedItems': [
          {'id': 1, 'item': 'Item 2', 'quantity': 2, 'price': 8.50},
          {'id': 3, 'item': 'Item 4', 'quantity': 1, 'price': 12.99}
        ]
      },
      {
        'id': 'Person 3',
        'name': 'Person 3',
        'assignedItems': [
          {'id': 6, 'item': 'Item 7', 'quantity': 1, 'price': 9.49}
        ]
      }
    ],
    'sharedItems': [
      {'id': 4, 'item': 'Item 5', 'quantity': 1, 'price': 15.99, 'shared_by': ['Person 1', 'Person 2']},
      {'id': 7, 'item': 'Item 8', 'quantity': 1, 'price': 7.50, 'shared_by': ['Person 1', 'Person 3']}
    ],
    'unassignedItems': [
      {'id': 5, 'item': 'Item 6', 'quantity': 1, 'price': 5.99}
    ],
    'tipAmount': 0.00,
    'taxAmount': 0.00,
    'subtotal': 00.00,
    'total': 00.00
  }
}
```

### Item Assignment Logic

The data structure now supports two complementary methods of tracking item assignments:

1. **`assignment_result`**: Follows the Pydantic model used by the backend API, with:
   - `person_assignments`: A list of people and their assigned items
   - `shared_items`: A list of items that are shared, including who shares them
   - `unassigned_items`: A list of items without assignments

2. **`split_manager_state`**: Maps directly to the app's SplitManager state, with:
   - `people`: A list of people with both their individual and shared items (with complete item details)
   - `sharedItems`: The global list of shared items with all metadata (price, quantity, shared_by)
   - `unassignedItems`: Items that haven't been assigned (with complete details)
   - Tax, tip, and total calculations for financial summaries

This dual structure ensures that:
- The backend API data format is preserved in `assignment_result`
- The app's internal state representation is captured in `split_manager_state`
- Each receipt can be fully restored to exactly how it was displayed in all views
- Shared items properly track who shares them and in what proportion

`split_manager_state` maps directly to the necessary app state, containing:
- `people`: A list of people with their individually assigned items and their shared items (including full details like price, quantity, and sharing count).
- `sharedItems`: The global list of shared items including who shares them.
- `unassignedItems`: The list of unassigned items with full details.
- Tax, tip, subtotal, and total calculations.

This structure ensures that each receipt's state can be fully restored for viewing or editing.

`person_totals` stores the final calculated amount owed by each person for easy display.

Using person IDs in `shared_by` avoids issues with renaming people.

`person_totals` stores the final calculated amount owed by each person (identified by name, could also use ID if needed for display consistency) for easy summary display.

### Item ID Explanation

In this data structure, "id" fields actually refer to the **array index** of an item in the original receipt items array. The app doesn't assign explicit ID fields to items, but instead uses their position in the array to identify them:

- When an item has `id: 0`, it means the first item in the receipt items array
- When an item has `id: 4`, it means the fifth item in the receipt items array
- This matches how the app internally references items in assignment functions

This approach is especially important when saving and retrieving receipt data, as it allows the app to connect assignments back to the original items without modifying the item objects themselves.

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
- Toggle to use mock data in development builds (e.g., via environment configuration or a developer menu).
- Visual indicator when viewing mock data
- Ability to delete individual mock receipts or all at once via the script or a debug tool.

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