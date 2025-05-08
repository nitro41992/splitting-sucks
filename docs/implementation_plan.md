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
- ✅ **Review Screen Data Persistence on Exit (Modal Client-Side):**
  - **Resolved:** Edits/additions made in `ReceiptReviewScreen` were not saved if the user exited the modal directly from the Review step.
  - **Fix:** Implemented a callback mechanism (`registerCurrentItemsGetter`) allowing `_WorkflowModalBodyState._saveDraft` to actively fetch the latest item list from `ReceiptReviewScreen`'s state immediately before saving, ensuring edits are persisted correctly.
  - **Fix:** Changed Firestore update logic in `FirestoreService.saveReceipt` for existing documents from `set(data, SetOptions(merge: true))` to `update(data)` for more reliable field updates.
- ✅ **Transcription Persistence & Loading (Modal Client-Side):**
  - **Resolved:** Transcription text was not consistently loaded or displayed when resuming a draft.
  - **Fix (`WorkflowState`):** Modified `WorkflowState.setParseReceiptResult` to no longer clear `_transcribeAudioResult`. Ensured `setImageFile` and `resetImageFile` correctly clear all subsequent step data, including transcription. Made setters in `WorkflowState` more robust to handle `null` inputs from loaded drafts, defaulting to empty/appropriate initial values.
  - **Fix (`_buildStepContent`):** Corrected a key mismatch (was looking for `'text'` instead of `'transcription'`) when accessing the transcription string for display in the Voice Assignment step.
- ✅ **Linter Error Resolution & Split Step Setup (Modal Client-Side):**
    - Resolved all linter errors in `lib/widgets/workflow_modal.dart` related to the "Split" step data handling.
    - Corrected `ReceiptItem.fromMap` to `ReceiptItem.fromJson`.
    - Addressed `ReceiptItem.id` vs `ReceiptItem.itemId` discrepancies.
    - Resolved `Person` class name collision by hiding `Person` from `audio_transcription_service.dart` import.
    - Updated `SplitManager` instantiation in `_WorkflowModalBodyState._buildStepContent` (case 3 for "Split"):
        - Removed outdated `isStatePreservedAcrossHotReload` and `restoreState` logic.
        - Ensured `parseResult['subtotal']` is passed as `originalReviewTotal` to `SplitManager`.
        - Defined `_initialSplitViewTabIndex` in `_WorkflowModalBodyState` and set it on `SplitManager`.
    - Removed undefined parameters from `SplitView` instantiation (`onSplitChanged`, `peopleArg`, etc.) as it consumes `SplitManager` via Provider.
- ✅ **SplitManager State Serialization & Propagation (Modal Client-Side):**
    - Added `toJson()` and `fromJson()` methods to `lib/models/person.dart`.
    - Added `toJson()` and `fromJson()` methods to `lib/models/split_manager.dart`.
    - Implemented a listener in `_WorkflowModalBodyState._buildStepContent` (case 3 for "Split") for the `SplitManager` instance. When `SplitManager` notifies changes, `workflowState.setSplitManagerState(manager.toJson())` is called, ensuring `WorkflowState` holds the latest `SplitManager` data for saving drafts or completing receipts.
- ✅ **Resolved Type Error in Summary Screen (Modal Client-Side):**
    - Fixed a `type 'Null' is not a subtype of type 'num' in type cast` error occurring when navigating to the Summary step.
    - **Fix:** Modified `_buildStepContent` (case 4 for Summary) to initialize `SplitManager` using `SplitManager.fromJson(workflowState.splitManagerState)` instead of creating a new empty manager. This ensures the Summary uses the up-to-date state from the Split step.
- ✅ **Strict Data Model Adherence - Removed `split_manager_state`:**
    - Modified `Receipt` model (`lib/models/receipt.dart`): Removed `splitManagerState` field, added `tip`, `tax` fields, updated `toMap`/`fromDocumentSnapshot` to handle `tip`/`tax` within `metadata` map.
    - Modified `WorkflowState` (`lib/widgets/workflow_modal.dart`): Removed `_splitManagerState` and associated logic, added `_tip`, `_tax` fields and setters, updated `toReceipt()`.
    - Modified `_loadReceiptData`: Loads `tip`/`tax` from `Receipt` metadata into `WorkflowState`.
    - Modified Split Step (`case 3`): Always initializes `SplitManager` fresh from `assign_people_to_items` result; sets initial tip/tax from `WorkflowState`; added listener to update `WorkflowState.tip`/`tax` when `SplitManager` changes.
    - Modified Summary Step (`case 4`): Initializes `SplitManager` fresh from `assign_people_to_items` and sets tip/tax from `WorkflowState`.
    - Modified `_completeReceipt`: Removed direct reading of tip/tax and arguments to `firestoreService.completeReceipt` (now relies on `receipt.toMap()`).
    - Modified `FirestoreService.completeReceipt`: Removed `tip`, `tax`, `restaurantName` parameters; now relies on the `data` map containing these within `metadata`.
- ✅ **Refined Split Step Data Handling & Persistence (Modal Client-Side):**
    - `SplitManager` (`lib/models/split_manager.dart`):
        - Added `generateAssignmentMap()` to convert its internal state (people, items, etc.) to the `assign_people_to_items` map format.
        - Added `currentPeopleNames` getter.
        - Removed `toJson()` and `fromJson()` as the entire manager state is no longer directly serialized.
    - `WorkflowState` (`lib/widgets/workflow_modal.dart`):
        - Added `_people` (List<String>) field, getter, and `setPeople()` method.
        - `_loadReceiptData` loads `receipt.people`.
        - Resets and `setAssignPeopleToItemsResult()` correctly update/extract `_people`.
        - `toReceipt()` uses `_people` for `Receipt.people`.
    - `_WorkflowModalBodyState._buildStepContent` (case 3 - Split):
        - `SplitManager` is now always initialized fresh using data from `workflowState.assignPeopleToItemsResult`, `workflowState.parseReceiptResult`, `workflowState.tip`, and `workflowState.tax`.
        - A listener attached to `SplitManager` updates:
            - `workflowState.assignPeopleToItemsResult` (by calling `manager.generateAssignmentMap()`).
            - `workflowState.people` (by calling `manager.currentPeopleNames`).
            - `workflowState.tip` and `workflowState.tax`.
    - This ensures modifications in `SplitView` (via `SplitManager`) are reflected in `WorkflowState` and persisted correctly to `assign_people_to_items` and `metadata` in Firestore.
- ✅ **Resolved Type Error after Re-Parse:**
    - Fixed `type 'Null' is not a subtype of type 'String' in type cast` error occurring in `ReceiptItem.fromJson` when navigating to Split step after a re-parse.
    - **Fix:** Made `ReceiptItem.fromJson` robust by handling potential nulls for `name`, `price`, `quantity`, `originalQuantity`, and `itemId` from JSON, providing sensible defaults.
- ✅ **Workflow Interruption Confirmations (Modal Client-Side):**
    - **Refined Logic:** Confirmation dialogs moved from navigation actions (back button, step taps) to specific data re-processing actions:
        1.  **Re-Parse (Upload Step):** Dialog added to `onParseReceipt` callback. Clears parse, transcribe, assign, people (keeps tip/tax) if confirmed.
        2.  **Re-Transcribe (Assign Step):** Dialog added to `_toggleRecording` (when starting record) via `onReTranscribeRequested` callback. Clears *only* transcription if confirmed.
        3.  **Re-Process Assignments (Assign Step):** Dialog added to "Start Splitting" button (`_processTranscription`) via `onConfirmProcessAssignments` callback. Clears assignments and people (keeps tip/tax) if confirmed.
    - Data clearing methods in `WorkflowState` updated to preserve tip/tax and clear specific data slices according to the action.
- ✅ **Navigation Button Disabling (Modal Client-Side):**
    - **Refined Logic:** Disabled the "Next" button based on whether the data required for the *next* step is available in `WorkflowState`:
        - Upload -> Review: Disabled if `!hasParseData`.
        - Assign -> Split: Disabled if `!hasAssignmentData`.
        - Split -> Summary: Disabled if `!hasAssignmentData`.
    - Placeholders remain in steps as a fallback.
- ✅ **UI Placeholders for Missing Data (Modal Client-Side):** Added placeholder widgets for Review, Assign, Split, and Summary steps shown if prerequisite data is missing. Button disabling provides primary UX feedback.

**In Progress / Pending Issues:**

- **UI/Functionality Bugs:**
    - ⚠️ **App Crash/Performance Issues:** User has reported general app crashes, skipped frames, EGL errors, and potential ANR (Application Not Responding) errors. These may or may not be related to the specific connectivity issues listed under "Authentication & Emulator Connectivity".
    - ⚠️ **Summary View Subtotal Calculation:** User reported the subtotal calculation in the final Summary view is incorrect. Needs investigation into `FinalSummaryScreen` and its `SplitManager` data source.
    - ⚠️ **Modal Launch Context:** Occasional `[WorkflowModal.show] Error: Context is not mounted before navigation.` error. Needs investigation into where/when `WorkflowModal.show` is called.
    - ⚠️ **Split View "Go To Summary" Button:** User reported this button (within the SplitView UI itself) is not navigating to the Summary step. Needs investigation into `SplitView`.
    - ⚠️ **Modal Exit (`X` Button):** The top-left 'X' button currently closes the modal without triggering the draft save logic (`_onWillPop`). Needs fix or removal.
    - ⚠️ **"Completed" Indicator:** No visual indicator on completed receipts (e.g., in Receipts list or within the summary). Needs implementation.
    - ⚠️ **Split View "Unassigned" Tab:** Potential issue where the "Unassigned" tab might display incorrectly. Needs testing.
- **Testing & Verification:**
    - ⚠️ **Split Step State Persistence:** Needs testing (Tip/Tax changes, Person/Item modifications persistence via listener).
    - ⚠️ **Assignment Data Propagation:** Needs end-to-end testing after recent confirmation/clearing changes.
- **Authentication & Emulator Connectivity:**
    - ⚠️ **Remaining Issue (Highest Priority):** Persistent `GoogleApiManager SecurityException: Unknown calling package name 'com.google.android.gms'`. Needs urgent investigation (likely separate effort).
    - ⚠️ **Remaining Issue (High Priority):** Persistent `ManagedChannelImpl: Failed to resolve name` / Firestore `UNAVAILABLE` errors. Likely related to `GoogleApiManager` issue.

**Pending (Longer Term / Other Areas):**
- **Data Model Refinement - Consolidate URIs to `metadata` map (Remaining Steps):**
  - Cloud Functions (`generate_thumbnail`, review others)
  - Non-Modal Workflow (`lib/receipt_splitter_ui.dart`)
  - Data Migration Script
  - Testing (URI Refactor)
- **Cloud Function `generate_thumbnail` Behavior:** Investigate potential internal errors.
- **Firebase App Check/Google Sign-In:** Monitor intermittent warnings/errors (Lower Priority).
- **Code Cleanup & Refactoring - Parsing Logic Duplication**
- **General Modal Workflow State Consistency Plan**
- **Performance Optimization (Pagination, Caching, Rebuilds)**
- **Testing (Comprehensive Suite)**
- **Handle Edge Cases & Stability (Completed Receipts, Error Handling)**

## Technical Implementation Details
(Consolidated Status)
- **Main Navigation:** ✅
- **Receipts Screen:** ✅ (except pagination ⚠️)
- **Workflow Modal Core:** ✅ (Navigation, State, Saving, Placeholders, Confirmations, Button Disabling)
- **Workflow Steps:**
    - Upload: ✅
    - Review: ✅
    - Assign: ✅
    - Split: ✅ (except Go To Summary button ⚠️, Unassigned tab display ⚠️)
    - Summary: ✅ (except Subtotal calculation ⚠️)

### Current Challenges (Focus on remaining issues)
(Moved details to Pending Issues above)

## Environment Setup Status
(No changes from previous state)

## Testing Status
(Needs expansion as noted above)

## Known Issues (Consolidated)
(Moved details to Pending Issues above)

## Next Steps (Priority Order)

1.  **Fix Summary View Subtotal Calculation (Modal Client-Side - High Priority):** Investigate `FinalSummaryScreen` and its data source (`SplitManager` via Provider).
2.  **Fix Modal Launch Context Error (Modal Client-Side - High Priority):** Investigate `WorkflowModal.show` call sites for potential `mounted` issues before navigation.
3.  **Fix/Remove Modal 'X' Button Save Behavior (Modal Client-Side - High Priority):** Either make 'X' trigger `_onWillPop` or remove it.
4.  **Fix Split View "Go To Summary" Button (Modal Client-Side - High Priority):** Investigate `SplitView` and connect button to navigate.
5.  **Implement "Completed" Indicator (UI - Medium Priority):** Add visual cues for completed receipts.
6.  **Test Split Step State Persistence & Data Flow (Modal Client-Side - Medium Priority):**
    - Test persistence of Tip/Tax, people, and item assignments made in Split step.
    - Verify correct initial population of `SplitManager`.
    - Test display of unassigned items in `SplitView`.
7.  **Investigate and Fix/Verify `generate_thumbnail` Cloud Function (Medium Priority):**
    - Review Cloud Function logs, verify error handling and URI usage (`metadata`).
8.  **Cloud Function Updates (URI Metadata - General Review):** Review `parse_receipt` etc.
9.  **Data Migration Script:** Develop and test script for URI metadata migration.
10. **Non-Modal Workflow URI Refactoring:** Review and apply URI metadata changes.
11. **Comprehensive Testing (URI Refactor & Background Uploads):** Test all flows post-migration.
12. **Investigate and Resolve `GoogleApiManager SecurityException` & Network Errors (High Priority - Separate Effort?):** Address core connectivity issues.
13. **Implement Receipt List Pagination:** Address performance.
14. **Address Remaining App Check/Sign-In Issues (Lower Priority).**
15. **Address Security Warnings (General Consolidation).**
16. **Remove Diagnostic Delay:** Remove the `Future.delayed` call from `_loadReceipts`.
17. **Create Comprehensive Testing Suite (General).**
18. **Enhance Error Handling.**
19. **Handle Edge Cases (Completed Receipts).**
20. **Code Cleanup/Refactoring (Parsing Logic).**

## Developer Notes / Knowledge Transfer (Updated)

Key learnings from recent debugging sessions regarding the modal workflow:

- **Modal State (`WorkflowState` & Provider):** Using a central `ChangeNotifier` (`WorkflowState`) provided via `Provider` is effective for managing state across the modal steps. However, careful attention must be paid to *when* state is updated and *when* listeners are notified.
- **Widget Rebuild Timing & `Consumer`:** When complex state updates happen asynchronously (like fetching URLs in `_loadReceiptData`), passing updated state values down as simple constructor parameters to child widgets can sometimes lead to the child building with stale data if the parent rebuilds too quickly. Using a `Consumer<StateType>` widget directly within the child's parent builder function (as done for `ReceiptUploadScreen` in `_buildStepContent`) ensures the child is built using the absolute latest state from the provider at the time of the build.
- **Saving State from Children on Parent Action:** When a parent action (like `_saveDraft` triggered by `_onWillPop`) needs the *most current* data from a child widget's internal state (like `_editableItems` in `ReceiptReviewScreen`), simply relying on the last known state in the central provider (`WorkflowState`) might not be sufficient if the child's state changed *after* the last update to the provider but *before* the parent action. Implementing a callback registration pattern (e.g., `registerCurrentItemsGetter`) allows the parent to actively *pull* the latest state from the child at the exact moment it's needed (e.g., just before saving).
- **Firestore `update` vs. `set(merge:true)`:** While `set(..., merge: true)` works for adding new documents or completely replacing existing ones, using `update(...)` is generally the more idiomatic and often more reliable method for applying partial updates to specific fields within an *existing* Firestore document. It explicitly signals the intent to modify, not replace.
- **Debugging State Flow:** Using targeted `debugPrint` statements at key points (state mutation in Provider, parent build function before child instantiation, child build function accessing properties) is invaluable for tracing data flow and pinpointing timing issues or stale state problems.
- **Data Model Alignment (Client-Backend):** When working with data from external sources (e.g., Cloud Functions returning JSON), it's crucial that client-side Dart models (`fromJson`/`toJson` methods) perfectly match the structure and field names of the incoming data. Mismatches, especially in nested lists, maps, or subtle naming differences (e.g., `person_name` vs `personName`), can lead to silent data loss during parsing or incorrect serialization. Always log the raw data received and the data after parsing into Dart models to quickly identify such discrepancies.
- **Scoped Notifier State Propagation & Initialization (SplitManager Example):**
    - **Persistence Model:** When a nested `ChangeNotifier` (like `SplitManager`) has its direct persistence field (e.g., `split_manager_state`) removed from the main data model (`Receipt`), its full state is no longer saved/loaded directly.
    - **Initialization:** The nested notifier (`SplitManager`) should always be initialized *fresh* when its step is built. It should be populated using data from *earlier* steps stored in the parent state (`WorkflowState`) – e.g., `assign_people_to_items` result, `parse_receipt` result (for original items/quantities), and specific persisted fields like `tip`/`tax` from `WorkflowState`.
    - **State Update (Listener Pattern):** To persist modifications made *within* the nested notifier's UI, a listener is added to it. This listener is responsible for:
        - Calling methods on the nested notifier to extract its current state in the desired format (e.g., `SplitManager.generateAssignmentMap()`, `SplitManager.currentPeopleNames`).
        - Updating the corresponding fields in the parent `WorkflowState` (e.g., `workflowState.setAssignPeopleToItemsResult(...)`, `workflowState.setPeople(...)`, `workflowState.setTip(...)`).
    - This ensures that while `SplitManager` itself isn't directly saved, the effects of its operations (assignments, people list, tip/tax changes) are captured in `WorkflowState` and subsequently persisted to Firestore.
- **Confirmation for Data Overwrite / Action Trigger:** Confirmation dialogs should be tied to specific user actions that *initiate* data processing or overwriting (e.g., clicking "Parse", "Start Recording", "Start Splitting"), rather than simple navigation (Back button, step taps, basic Next button). If confirmed, the relevant downstream data slice should be cleared in `WorkflowState` *before* the action proceeds. Tip/Tax should generally be preserved during these clears.
- **Button Disabling:** Disabling navigation buttons (like "Next") when prerequisite data for the target step is missing provides clearer UX than allowing navigation and then showing a placeholder. State checks (e.g., `hasParseData`, `hasAssignmentData`) should determine button enablement.
- **Mounted Checks:** Errors like `Context is not mounted before navigation` often occur when an `async` operation completes after a widget has been removed from the tree (e.g., user navigates away quickly). Check `if (mounted)` before accessing `context` or calling `setState` in `async` callbacks or `initState`/`addPostFrameCallback`.

</rewritten_file> 