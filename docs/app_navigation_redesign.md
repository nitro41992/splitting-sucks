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
   - A receipt is draft until the assignment and summary are created. Keep in mind that a summary is additional calculation on teh data produced in the assignment view so if assignemnt is avialable, consider it complete.
- Floating action button to add new receipt
- Search and filter capabilities
- Ability to select receipts for viewing details or editing

### Workflow Modal

- Contains the existing 5 steps (Upload, Review, Assign, Split, Summary)
- Step indicator at top (functions exactly like current tab navigation)
- Same progression logic as current app
- **Maintains existing in-memory caching between steps within the modal flow**
- Option to save and exit workflow and return to Receipts screen. If this happens, save the cache state in the data model below.

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
            {"name": "<item_name>", "quantity": <integer>}
          ]
        }
      - shared_items: List<Map> [
          {"name": "<item_name>", "quantity": <integer>, "people": ["person1", "person2"]}  // List of people sharing this item
        ]
      - unassigned_items: List<Map> [
          {"name": "<item_name>", "quantity": <integer>}
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
- Stores raw cloud function outputs directly without transformation. For `assign_people_to_items`, the structure shown above is the target detailed format. The current `assign_people_to_items` cloud function (which remains unchanged for now) might output a more generic `Map`. The client application may need to transform this raw data, or this detailed structure will be implemented in a future update of the cloud function.
- Maintains backward compatibility with existing functions
- Links data to the corresponding image and user
- Includes minimal metadata for list display and search
- Stores reference to a pre-generated thumbnail for fast loading in lists

### Guidance for `functions/main.py` (Pydantic Models)

Given the updated data model for `assign_people_to_items` and the requirement to keep existing Firebase Functions unchanged initially, consider the following for your Pydantic models in `functions/main.py`:

1.  **Existing Function Outputs (e.g., `assign_people_to_items` function):
    *   The current `assign_people_to_items` cloud function will continue to output its existing data structure (likely a generic `Map` or a simpler Pydantic model).
    *   Pydantic models used for the *response* of this specific function should *not* be changed yet to maintain compatibility with any current consumers.

2.  **Client-Side Handling (Flutter App):
    *   When the Flutter app saves receipt data to Firestore (either as a draft or a completed receipt), it will save the `assign_people_to_items` field in the *new, detailed structure* outlined in the data model above.
    *   When the app reads receipt data from Firestore, it should expect `assign_people_to_items` to be in this new, detailed structure.

3.  **New or Updated Functions Reading from Firestore:
    *   Any *new* Cloud Functions, or existing functions that are *updated* to process receipt documents from Firestore (e.g., a function for final processing, aggregation, or data migration), will need Pydantic models capable of parsing the *new, detailed structure* of the `assign_people_to_items` field as stored in Firestore by the app.
    *   For example, if a function reads a `/users/{userId}/receipts/{receiptId}` document, its Pydantic model for that document should reflect the new `assign_people_to_items` structure.

4.  **Pydantic Models for the New Structure:**
    *   When you are ready to update the `assign_people_to_items` function itself, or for new functions that will produce/consume this detailed structure, you can use Pydantic models like the following (conceptual example):

      ```python
      from typing import List, Dict, Any
      from pydantic import BaseModel, Field

      class ItemDetail(BaseModel):
          name: str
          quantity: int

      class SharedItemDetail(BaseModel):
          name: str
          quantity: int
          people: List[str]

      class AssignPeopleToItemsNewOutput(BaseModel): # New model for the detailed structure
          assignments: Dict[str, List[ItemDetail]] = Field(default_factory=dict)
          shared_items: List[SharedItemDetail] = Field(default_factory=list)
          unassigned_items: List[ItemDetail] = Field(default_factory=list)
      ```

This approach allows the Flutter app to immediately benefit from the richer data model for `assign_people_to_items` stored in Firestore, while existing Cloud Functions remain operational. Future updates to Cloud Functions can then adopt the new Pydantic models as they are developed or refactored.

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

3. **If the user exits the modal workflow (e.g., by navigating back to the Receipts screen or closing the app) before completion, the current cached state of the workflow will be persisted to Firestore. The `metadata.status` will be set to "draft", allowing the user to resume later.**

4. Use a consistent `receiptId` throughout the workflow to update the same document

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

## Cloud Function Development and Deployment Strategy

To manage changes to Cloud Functions effectively and avoid impacting the production environment, the following strategy is recommended:

1.  **Local Development and Testing (Firebase Emulator Suite):**
    *   Utilize the Firebase Emulator Suite for local development and testing of Cloud Functions ([Firebase Documentation](https://firebase.google.com/docs/functions/get-started#emulate_execution_of_your_functions)).
    *   This allows you to run and debug your functions, including those triggered by Firestore, Authentication, and HTTP requests, on your local machine.
    *   **Testing Prompts and Configuration:** If your functions fetch dynamic configurations (like prompts for AI services that dictate JSON structure, as managed by `config_helper.py`), you will also run the emulators for the services hosting this configuration (e.g., Firestore Emulator, Remote Config Emulator).
        *   You will need to **seed these emulated services with the development/test versions of your prompts/configurations**. These test configurations should align with any local changes to your Pydantic models or other code that expects specific structures.
        *   The Firebase SDKs used in your functions (and `config_helper.py`) will automatically connect to these emulated services when the emulators are active, ensuring your local tests use your local configurations.
    *   Testing locally significantly reduces the risk of errors that could affect live data or incur costs.

2.  **Dedicated Firebase Projects (Dev/Staging and Production):**
    *   **Production Project:** Your current live Firebase project.
    *   **Development/Staging Project:** Create a separate, new Firebase project dedicated to development and staging. This project will have its own isolated instances of Firestore, Cloud Functions, Authentication, etc.
    *   Your Flutter application can be configured with different Firebase project configurations (e.g., using different `google-services.json` or Flutter build flavors) to target the dev/staging project during development and testing, and the production project for release builds.

3.  **Development Workflow:**
    *   Develop new functions or changes to existing functions in your local environment, testing thoroughly with the Emulator Suite.
    *   Once locally tested, deploy the functions to your dedicated dev/staging Firebase project.
    *   Conduct integration testing with your app pointing to this dev/staging environment.

4.  **Promotion to Production:**
    *   After successful testing in the dev/staging environment, deploy the same function code to your production Firebase project.
    *   The Firebase CLI facilitates deployment to specific projects. You can use project aliases (`firebase use <project_alias>`) or specify the project ID directly during deployment (`firebase deploy --project <YOUR_PROJECT_ID> --only functions`).

5.  **Version Control (Git):**
    *   Maintain all your Cloud Function code in a Git repository.
    *   Use branches for developing new features or fixes (e.g., `feature/new-receipt-processing`, `fix/user-auth-bug`).
    *   Merge tested changes into a `develop` or `staging` branch for deployment to the dev/staging project.
    *   Merge thoroughly tested and approved changes into a `main` or `production` branch before deploying to the production project.
    *   **Consider versioning your prompt seed files or Remote Config templates alongside your function code if they are tightly coupled.**

6.  **Environment Configuration for Functions:**
    *   For any external API keys, service URLs, or other configuration values that differ between dev/staging and production, use Firebase's environment configuration for Functions (`functions.config()`).
    *   Set configuration using the Firebase CLI: `firebase functions:config:set someservice.key="API_KEY_FOR_DEV" myparam="dev_value"`.
    *   Access these in your functions via `functions.config().someservice.key`.
    *   This avoids hardcoding sensitive or environment-specific values directly in your function code. Remember to set the appropriate config for each Firebase project.
    *   **Distinction from Dynamic Prompts:** While `functions.config()` is excellent for secrets and stable environment-specific settings, dynamic prompts (especially those dictating evolving JSON structures tied to Pydantic models) are often better managed in Firestore or Remote Config. The key is that your *emulated* Firestore/Remote Config will hold the *development version* of these prompts, while your *deployed* dev/staging and production Firebase projects will hold their respective versions of the prompts.

7.  **Managing Function Changes (Avoiding Impact on Existing Functions):**
    *   **Non-Breaking Changes:** If a change is backward compatible, you can update the existing function.
    *   **Breaking Changes:** If you need to introduce a breaking change to a function's trigger, request signature, or response structure:
        *   Consider deploying the new logic as a *new* function (e.g., `myFunction_v2`) instead of modifying the existing one directly.
        *   Update your client application to call the new function version.
        *   The old function version can remain active to support older clients until they are deprecated.
    *   This is particularly important for the `assign_people_to_items` function, as you wish to keep the current version live while the new data model is adopted by the app.

This approach ensures that your production environment remains stable while allowing for iterative development and testing of Cloud Functions.

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