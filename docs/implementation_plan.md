# Implementation Plan for App Navigation Redesign

> **Note:** This document tracks the implementation status of the app navigation redesign defined in `docs/app_navigation_redesign.md`

## Current Implementation Status

**Completed:**
- Firestore emulator seeded with configuration data using Python script
- Firebase emulator configuration in `firebase.json` with port conflicts resolved
- Updated Pydantic models for `assign_people_to_items` Cloud Function
- Created `FirestoreService` with **centralized conditional logic** to connect to Firebase Emulators (Auth, Firestore, Storage, Functions) based on `.env` flag (`USE_FIRESTORE_EMULATOR`), or live Firebase services otherwise.
- Implemented `Receipt` model with Firestore serialization/deserialization
- Implemented main navigation with bottom tabs (Receipts and Settings)
- Created Receipts screen with filters, search, and FAB
- Implemented restaurant name input dialog to start the workflow
- Created modal workflow controller with 5-step progress indicator
- Implemented automatic draft saving when exiting the workflow
- Integrated upload, review, voice assignment, and split screens
- Implemented proper data flow between steps with state management
- Connected final summary screen to modal workflow
- Fixed parameter type issues in workflow screens
- Implemented thumbnail generation placeholder
- Implemented proper thumbnail generation via Cloud Function
- Completed draft resume/edit functionality
- Implemented delete functionality with confirmation dialog
- Fixed component parameter mismatches in the workflow modal
- ✅ Fixed Provider usage error (used `ChangeNotifierProvider` for `WorkflowState` in modal)
- ✅ Fixed double restaurant name modal when creating new receipt
- ✅ Implemented sign-out functionality in Settings screen
- ✅ Addressed `setState() called after dispose()` in `ReceiptsScreen` by adding `mounted` checks
- ✅ Removed duplicate `WorkflowModal` file from `lib/screens`
- ✅ Added debug AndroidManifest to allow cleartext traffic for emulator communication.
- ✅ **Resolved:** Critical "Please select an image first" error when resuming drafts with images in the modal workflow by correcting logic in `lib/widgets/workflow_modal.dart`.
- ✅ **Resolved:** Integrated `ReceiptParserService.parseReceipt` call directly into the modal workflow's upload step in `lib/widgets/workflow_modal.dart` for both new and resumed draft images.
- ✅ **Resolved:** Item names are now correctly displayed on the Review screen after parsing in the modal workflow (fixed field name from `name` to `item` and added null safety in `_convertToReceiptItems` within `lib/widgets/workflow_modal.dart`).
- ✅ **Resolved:** Robust handling of `null` or unexpected data types for item fields (name, price, quantity) during conversion from raw parser output to `ReceiptItem` objects in `_convertToReceiptItems`.
- ✅ **Retry Button Disabled Post-Parse (Modal Workflow):**
  - Implemented logic in `lib/widgets/workflow_modal.dart` to pass an `isSuccessfullyParsed` flag to `ReceiptUploadScreen`.
  - Modified `lib/screens/receipt_upload_screen.dart` to accept `isSuccessfullyParsed` and disable its "Retry" (clear image) button if loading, if parsing is complete for the current image, or if no image is selected.
  - Ensured that selecting a new image or clearing the current image (via "Retry") in `lib/widgets/workflow_modal.dart` correctly resets the parsed items state, allowing the "Retry" button to become active again appropriately.
- ✅ **State Management (Non-Modal Workflow):**
  - Addressed linter errors in `lib/receipt_splitter_ui.dart` related to the new `isSuccessfullyParsed` parameter in `ReceiptUploadScreen`.
  - Passed `widget.uploadComplete` from `_ReceiptScreenWrapperState` as `isSuccessfullyParsed` to the `ReceiptUploadScreen` instance used in the non-modal flow.
  - Added `resetUploadStepStatus()` method to `_MainPageControllerState` to correctly reset `_isUploadComplete`, `_receiptItems`, and other dependent states.
  - Updated `_handleImageSelected` and `_handleRetry` in `_ReceiptScreenWrapperState` to call `resetUploadStepStatus()` on the parent `_MainPageControllerState`, ensuring better state consistency when the image is changed or cleared in the non-modal workflow.
- ✅ **URI Refactoring (Modal Client-Side):** Refactored `Receipt` model (`lib/models/receipt.dart`) and modal workflow (`lib/widgets/workflow_modal.dart` - `WorkflowState`, `_WorkflowModalBodyState`) to store/retrieve `imageUri` and `thumbnailUri` exclusively within the `metadata` map in Firestore documents. Removed URIs from root level and sub-maps like `parseReceiptResult`.
- ✅ **Optimistic Upload & Cleanup (Modal Client-Side):** Implemented background image uploads in the modal workflow triggered on image selection (`onImageSelected` in `_WorkflowModalBodyState`). Adapted save (`_saveDraft`) and parse (`onParseReceipt`) logic to handle pre-uploaded images or trigger synchronous uploads if needed. Added logic and `FirestoreService.deleteImage` method to queue and process deletion of orphaned images from Storage when selections are changed (`setImageFile`, `resetImageFile`) or drafts discarded (`_onWillPop`, modal close).
- ✅ **Faster Draft Image Loading (Modal Client-Side):** 
  - Implemented logic (`_loadReceiptData`, `ReceiptUploadScreen`) to fetch and display thumbnail download URLs as placeholders while the main image loads.
  - **Resolved loading delay:** Fixed issue where `ReceiptUploadScreen` didn't receive the updated `loadedThumbnailUrl` promptly after `_loadReceiptData` completed by wrapping `ReceiptUploadScreen` instantiation within a `Consumer<WorkflowState>` in `_WorkflowModalBodyState._buildStepContent`.

**In Progress:**
- None

**Pending:**
- **Data Model Refinement - Consolidate URIs to `metadata` map (Remaining Steps):**
  - **Cloud Functions:**
      - `generate_thumbnail`: Must be updated to read the main image URI from `event.data.data()['metadata']['image_uri']` and write the generated thumbnail URI to `event.data.ref.update({'metadata.thumbnail_uri': newThumbnailGsUri})`.
      - `parse_receipt`: If it reads/writes URIs, update to use `metadata` (review needed, likely no changes needed if it only receives URI as input).
      - Other functions: Review any other functions (e.g., `assign_people_to_items` if it erroneously stored URIs) and ensure they do not store URIs and read them from `metadata` if needed.
  - **Non-Modal Workflow (`lib/receipt_splitter_ui.dart`):**
      - Review `_MainPageControllerState` and related logic. If it saves/loads full `Receipt` objects or interacts directly with `imageUri`/`thumbnailUri` fields in Firestore, apply similar refactoring to use the `metadata` map.
  - **Data Migration:**
      - Develop and execute a one-time script (e.g., Python using `firebase-admin`) to migrate existing Firestore receipt documents. Script must:
          - Iterate through `users/{userId}/receipts/{receiptId}`.
          - For each doc, identify the canonical `image_uri` and `thumbnail_uri` (likely from root or `parse_receipt`).
          - Write these values into `doc.metadata.image_uri` and `doc.metadata.thumbnail_uri`.
          - Delete the old root-level `image_uri`/`thumbnail_uri` fields.
          - Delete redundant nested `image_uri`/`thumbnail_uri` fields from within `parse_receipt`, `assign_people_to_items`, `split_manager_state`, etc.
          - Handle potential errors and documents already in the new format gracefully.
  - **Testing:**
      - Thoroughly test all URI-related operations after Cloud Function changes and data migration:
          - New drafts (modal/non-modal).
          - Resuming drafts (old and new structure pre/post-migration).
          - Image changes, clearing, retries.
          - Thumbnail generation and display (modal/non-modal, `ReceiptsScreen`).
          - Orphaned image deletion logic.

- **Workflow Stability - Upload Screen (Old Issue - Resolved, Notes Kept for History):**
  - **Resolution Note:** Modal workflow stability issues related to image selection/parsing were resolved by fixes in `lib/widgets/workflow_modal.dart` (handling `loadedImageUrl`, integrating parser call, robust item conversion). Non-modal flow uses `_ReceiptScreenWrapperState`.

- **Code Cleanup & Refactoring - Parsing Logic Duplication:**
  - **Context:** Modal parsing uses `WorkflowState` and `_WorkflowModalBodyState`. Non-modal uses `_ReceiptScreenWrapperState` and `_MainPageControllerState`.
  - **Observation:** Potential legacy/unused parsing logic might exist (e.g., `_MainPageControllerState._directParseReceipt`).
  - **Action:** Review `_MainPageControllerState._directParseReceipt`. Clarify if non-modal flow requires separate parsing logic or if it can be consolidated/removed if the modal is the primary detailed workflow.

- **General Modal Workflow State Consistency Plan:** (Review if any further consistency checks are needed after recent refactors)
  - **Objective:** Ensure reliable data flow, state management, and UI consistency across all steps of the modal workflow.
  - **Principles:** Single source of truth (`WorkflowState`), clear data propagation, scoped state management (`Provider`, `SplitManager`), immutability.
  - **Action Plan:** Review data flow mapping, state restoration, callback integrity, and `SplitManager` initialization, especially focusing on edge cases or back navigation.

- **Performance Optimization:**
  - Optimize receipts list loading (currently fetches all receipts; needs pagination)
  - Implement image caching for better performance (`CachedNetworkImage` helps, review overall strategy)
  - Optimize state management to reduce unnecessary rebuilds (review `Provider` usage).

- **Testing (Comprehensive Suite):**
  - Create/expand testing suite for all components:
    - Unit tests for services (`AuthService`, `FirestoreService` including `deleteImage`) and models (`Receipt` including metadata URI handling).
    - Widget tests for UI components (especially `WorkflowModal`, `ReceiptUploadScreen`, `ReceiptsScreen`).
    - Integration tests for the full end-to-end workflow (modal and non-modal if applicable), including draft resume, image changes, deletion, completion.

- **Handle Edge Cases & Stability:**
  - Test and handle completed receipt modifications (what happens if user tries to edit?).
  - Further improve error handling and user feedback across the app (e.g., Storage deletion errors, parsing failures).

## Technical Implementation Details

### Screen Component Status

1. **Main Navigation:**
   - ✅ Bottom navigation bar with tabs
   - ✅ Tab-based routing to main screens
   - ✅ Settings screen with working Sign Out

2. **Receipts Screen:**
   - ✅ Filter tabs for All/Completed/Drafts
   - ✅ Search functionality with filtering
   - ✅ Receipt cards with thumbnails
   - ✅ FAB to create new receipts (fixed double modal issue)
   - ✅ Resume functionality with proper parameter passing
   - ✅ Delete functionality with confirmation dialog
   - ⚠️ Receipts list loading performance (fetches all, no pagination yet)
   - ✅ Fixed `setState` after dispose issue

3. **Workflow Modal:**
   - ✅ Full-page modal implementation
   - ✅ Step indicator with navigation
   - ✅ Navigation buttons with proper state management
   - ✅ Automatic draft saving (now faster with background uploads)
   - ✅ Parameter types between steps fixed
   - ✅ Component interface consistency ensured
   - ✅ Correctly uses `ChangeNotifierProvider` for `WorkflowState`
   - ✅ Retry button on Upload step disabled appropriately post-parse.
   - ✅ Orphaned image cleanup logic implemented.
   - ✅ Uses thumbnail placeholder for faster initial image display on resume.

4. **Individual Steps (Modal Workflow):**
   - ✅ Upload: Camera/gallery picker implemented. Retry/clear logic enhanced. Background uploads implemented.
   - ✅ Review: Item editing functionality working
   - ✅ Assign: Voice transcription and assignment working
   - ✅ Split: Item sharing and reassignment implemented
   - ✅ Summary: Tax/tip calculations implemented and properly connected

### Current Challenges (Focus on remaining issues)

1. **Data Persistence & Performance:**
   - ⚠️ Need to handle edge cases when modifying completed receipts
   - ⚠️ Receipts list loading can be slow due to lack of pagination.

2. **Image Processing:**
   - ✅ All previous image processing issues seem resolved. Requires testing with Cloud Function updates (metadata URI usage).

3. **Data Flow & State Management:**
   - ✅ Modal workflow state (`WorkflowState`) refactored for URI handling and background uploads.
   - ✅ Non-modal workflow state (`_MainPageControllerState`) improved with reset logic.
   - ⚠️ Non-modal workflow needs review for URI metadata refactoring.
   - ⚠️ Potential code duplication/refactoring opportunities remain (parsing logic, `SplitManager` init).

4. **Authentication & Emulator Connectivity:**
   - ✅ Most previous issues resolved.
   - ⚠️ **Remaining Issue (Highest Priority):** Persistent `GoogleApiManager SecurityException: Unknown calling package name 'com.google.android.gms'`. Needs urgent investigation (likely separate effort).
   - ⚠️ **Remaining Issue (High Priority):** Persistent `ManagedChannelImpl: Failed to resolve name` / Firestore `UNAVAILABLE` errors. Likely related to `GoogleApiManager` issue.
   - ⚠️ **Remaining Issue (Lower Priority):** App Check placeholder token warning reappears later. Monitor after fixing core issues.
   - ⚠️ **Remaining Issue (Lower Priority):** Google Sign-In sometimes fails initially (`ApiException: 10`). Likely related to `GoogleApiManager` issue.

## Environment Setup Status

### Multi-Project Firebase Setup (Dev/Prod)
   - ✅ Setup appears complete and functional for `billfie-dev`.

### Emulator Configuration
   - ✅ Setup appears complete and functional.

## Testing Status

1. **Unit Tests:**
   - Needs expansion for recent service changes (`FirestoreService.deleteImage`) and model changes (`Receipt` metadata).

2. **Widget Tests:**
   - Needs expansion for `WorkflowModal` (background uploads, cleanup), `ReceiptUploadScreen` (thumbnail placeholder).

3. **Integration Tests:**
   - Needs implementation, especially for URI refactoring, background uploads, and cleanup across full workflows.

## Known Issues (Consolidated)

- **Google Services Connectivity:**
    - ⚠️ **Remaining Issue (Highest Priority):** `E/GoogleApiManager: Failed to get service from broker. java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'`. Needs urgent investigation.
    - ⚠️ **Remaining Issue (High Priority):** `W/ManagedChannelImpl: Failed to resolve name` / Firestore `UNAVAILABLE` / `UnknownHostException` errors. Likely symptom of `GoogleApiManager` issue.
- **Cloud Function `generate_thumbnail` Behavior:**
    - ⚠️ **Potential Issue:** Previous logs indicated the `generate_thumbnail` Cloud Function might error internally (`[firebase_functions/internal] INTERNAL`) under some conditions.
    - ⚠️ **Potential Impact:** If this error occurs, the function *might* have flawed error handling (though client-side robustness added in `FirestoreService.generateThumbnail` mitigates some impact). Needs investigation for root cause and ensuring correct behavior upon failure (e.g., storing `null` for `metadata.thumbnail_uri`).
    - ⚠️ **Consequence:** While client-side modal loading is now fixed, an underlying function error could cause issues elsewhere or represent instability.
- **Firebase App Check:**
    - ⚠️ Placeholder token warning reappears later in session (Lower Priority).
- **Google Sign-In:**
    - ⚠️ Intermittent `ApiException: 10` on first attempt (Lower Priority).

## Next Steps (Priority Order)

1.  **Investigate and Fix/Verify `generate_thumbnail` Cloud Function (High Priority):**
    - Review Cloud Function logs for any recurring `INTERNAL` errors.
    - Verify the function's error handling: If thumbnail generation fails, ensure it results in `metadata.thumbnail_uri` being set to `null` or left untouched in Firestore (via the calling client logic in `FirestoreService`).
    - Ensure the function reads the main image URI from `metadata.image_uri` as originally planned.
2.  **Cloud Function Updates (URI Metadata - General Review):** Review `parse_receipt` and other functions to ensure they use the `metadata` field correctly for URIs if needed.
3.  **Data Migration Script:** Develop and test script to migrate existing Firestore documents to use `metadata` for URIs (handle potential `null` or incorrect `thumbnail_uri` values gracefully).
4.  **Non-Modal Workflow URI Refactoring:** Review `lib/receipt_splitter_ui.dart` and apply URI metadata changes if needed.
5.  **Comprehensive Testing (URI Refactor & Background Uploads):** Test modal/non-modal flows thoroughly, including draft resume, image changes, cleanup, thumbnail display, and post-migration data.
6.  **Investigate and Resolve `GoogleApiManager SecurityException` & Network Errors (High Priority - Separate Effort?):** Address core Google Play Services / Firebase connectivity issues.
7.  **Implement Receipt List Pagination:** Address performance for large numbers of receipts.
8.  **Address Remaining App Check/Sign-In Issues (Lower Priority):** Monitor and fix after core connectivity issues resolved.
9.  **Address Security Warnings (General Consolidation):** Verify all security best practices (App Check, API Keys, SHA keys) are correctly implemented.
10. **Remove Diagnostic Delay:** Remove the `Future.delayed` call from `_loadReceipts`.
11. **Create Comprehensive Testing Suite (General):** Expand unit, widget, and integration tests covering all features.
12. **Enhance Error Handling:** Improve user feedback for various error conditions.
13. **Handle Edge Cases (Completed Receipts):** Define and implement behavior for modifying completed receipts.
14. **Code Cleanup/Refactoring:** Address potential duplication (parsing, `SplitManager` init) and review state management consistency. 