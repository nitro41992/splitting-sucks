# Implementation Plan for App Navigation Redesign

> **Note:** This document tracks the implementation status of the app navigation redesign defined in `docs/app_navigation_redesign.md`

## Current Implementation Status

**Completed:**

**I. Core Application Setup & Initial Features:**
- **Firebase Integration & Emulation:** Configured Firebase services (Auth, Firestore, Storage, Functions) with conditional emulator connections. Seeded emulator data. Resolved `firebase.json` port conflicts. Added AndroidManifest for cleartext traffic for emulators.
- **Core Models & Services:** Implemented `Receipt` model (with Firestore serialization/deserialization), `FirestoreService`, and Pydantic models for `assign_people_to_items` Cloud Function.
- **Main Navigation & UI Shell:** Established main navigation (bottom tabs: Receipts, Settings), basic Receipts screen (filters, search, FAB), Settings screen (with sign-out functionality).
- **Initial Modal Workflow Framework (Conceptual & Basic UI):**
    - Created the 5-step modal workflow controller (`WorkflowModal`, `WorkflowState` with Provider).
    - Implemented UI for upload, review, voice assignment, split, and summary steps.
    - Established basic data flow management between steps and restaurant name input dialog.
    - Implemented automatic draft saving on exit and basic draft resume/edit functionality.
    - Implemented basic delete functionality with confirmation dialog.
    - Initial thumbnail generation (placeholder then Cloud Function).

**II. Modal Workflow - Key Enhancements, Data Persistence & Stability:**
- **Data Handling & Persistence (Key Fixes & Refinements):**
    - ✅ **Critical Bug Fixes:**
        - Resolved "Please select an image first" error on draft resume.
        - Fixed issue where item names weren't displayed correctly after parsing (null safety, field name correction).
        - Addressed `NOT_FOUND` error when saving new drafts with client-generated IDs (`FirestoreService.saveReceipt` refactor).
    - Ensured robust handling of null/unexpected data types for `ReceiptItem` fields during parsing.
    - Corrected data persistence for `ReceiptReviewScreen` edits on modal exit (via `registerCurrentItemsGetter`).
    - Addressed persistence/loading issues for transcription text (state clearing logic, key mismatch fix).
    - Refined `SplitManager` state handling:
        - Removed direct serialization of `SplitManager` state from `Receipt` model; now stores `tip`, `tax`, and `people` directly.
        - `SplitManager` initialized fresh on Split step, using data from `WorkflowState`.
        - Listener on `SplitManager` updates `WorkflowState` (assignments, people, tip, tax).
        - Addressed type errors for `SplitManager` and `ReceiptItem.fromJson` in re-parse/summary scenarios.
    - Resolved subtotal calculation discrepancies in the Summary step.
    - Ensured tip/tax changes in `FinalSummaryScreen` persist to `WorkflowState`.
- **Image Handling & Upload (Modal):**
    - ✅ **URI Refactoring & Background Uploads:** Consolidated image URIs into `metadata` within Firestore. Implemented background image uploads on selection, with logic to handle pre-uploaded images and cleanup of orphaned images from Storage (`FirestoreService.deleteImage`).
    - ✅ **Draft Image Display & Loading:**
        - Fixed `ReceiptUploadScreen` not receiving `loadedThumbnailUrl` promptly (using `Consumer<WorkflowState>`).
        - Ensured `ReceiptUploadScreen` correctly uses `CachedNetworkImage` with `imageUrl`/`loadedThumbnailUrl` for resumed drafts.
        - Improved thumbnail-to-full-image transition in `ReceiptUploadScreen` (Stack placeholder, consistent `BoxFit`).
- **UI & UX Refinements (Modal):**
    - ✅ **Draft Resumption Logic:** Corrected target step logic for resuming drafts. Implemented a loading indicator to prevent UI flashes.
    - ✅ **Workflow Navigation & Confirmations:**
        - Implemented confirmation dialogs for data-altering actions (re-parse, re-transcribe, re-process assignments), preserving tip/tax.
        - Disabled "Next" button based on data readiness for the subsequent step.
        - Added UI placeholders for steps with missing prerequisite data.
        - Ensured step indicator taps respect data readiness.
        - Refined modal close button behavior for reliable draft saving.
        - Removed incorrect confirmation dialog from Assign step's "Next" button.
        - Fixed `SplitView` "Go To Summary" button navigation.
    - ✅ **Screen-Specific UI Cleanup (Modal):**
        - Removed redundant "Clear Image" and "Parse Receipt" buttons from `ReceiptUploadScreen`.
        - Removed the 'X' button from the modal `AppBar`.
- **Stability & Error Handling (Modal):**
    - Addressed various `setState() called after dispose()` errors with `mounted` checks.
    - ✅ **Modal Launch Context Safety:** Added `if (!mounted) return;` checks in `WorkflowModal.show` and `showRestaurantNameDialog`. Clarified debug log for `WorkflowModal.show` (safety checks are functional; underlying cause of context unmount remains an observation point).
    - Resolved async state error in `_completeReceipt` with careful `mounted` checks and operation sequencing.
- **State Management (Non-Modal Workflow - Initial Pass):**
    - Addressed linter errors and improved state consistency for the non-modal image upload flow.

**III. Receipts Screen - UI & Stability Enhancements:**
- ✅ **UI Simplification:** Removed filter `TabBar` from `ReceiptsScreen`.
- ✅ **State Preservation & Stream Loading:** Implemented `AutomaticKeepAliveClientMixin`.
- ✅ **Stability (Stream Initialization & Processing):** Fixed "weird loop" / flashing issues by correctly initializing the stream in `initState` and processing data (including thumbnail URL fetching) within the stream pipeline using `asyncMap`.

**In Progress / Pending Issues:**

- **UI/Functionality Bugs:**
    - ⚠️ **CRITICAL: Main Image Missing (404 Error) in Storage (Resume/Edit):** User reports that for some resumed drafts, the main image is missing from Firebase Storage, even though its thumbnail exists. **Detailed URI logging added to client for further diagnosis.**
    - ⚠️ **Blurry Thumbnail on Backtrack (Upload Screen):** When resuming a draft, navigating past Upload, then back to Upload, the thumbnail may remain blurry and the full image might not load. **Debug prints added to `ReceiptUploadScreen` to trace `CachedNetworkImage` behavior.**
    - ⚠️ **App Crash/Performance Issues (EGL Errors):** User has reported EGL errors, likely emulator-related. Other crash/ANR issues seem less frequent after context/state fixes.
    - ⚠️ **Investigate Root Cause of Calling Context Unmount in `WorkflowModal.show`:** If the 'Context unmounted' log (now clarified) for `WorkflowModal.show` appears frequently, investigate the calling screen's lifecycle to prevent its premature disposal during modal pre-flight async operations.
    - ⚠️ **"Completed" Indicator:** No visual indicator on completed receipts.
    - ⚠️ **Split View "Unassigned" Tab:** Potential display issue.
- **Performance & UX (Receipts List):**
    - ⚠️ **Pagination for Large Lists:** The current `StreamBuilder` in `ReceiptsScreen` loads all receipts. If the list becomes very large, performance may degrade. Implementing stream-based pagination (e.g., loading initial batch via stream, then manual "load more") will be necessary.
- **Performance & UX (Image Loading):**
    - ⚠️ **Image Load Time (Upload Screen - UX):** If main image load time in `ReceiptUploadScreen` remains a concern, consider adding `progressIndicatorBuilder` to `CachedNetworkImage` for better user feedback.
- **Testing & Verification:**
    - ⚠️ **Split Step State Persistence.**
    - ⚠️ **Assignment Data Propagation.**
- **Authentication & Emulator Connectivity:**
    - ⚠️ **Remaining Issue (Highest Priority - Separate Effort?):** Persistent `GoogleApiManager SecurityException`.
    - ⚠️ **Remaining Issue (High Priority - Separate Effort?):** Persistent Firestore `UNAVAILABLE` errors.
- **Storage Security Rules:**
    - ⚠️ Review and fix Storage Security Rules to allow users to delete their own images and associated thumbnails (related to 403 error on thumbnail delete).

**Pending (Longer Term / Backlog / Tabled):**
- **Google Photos direct integration:** (Tabled by user in favor of system picker).
- **Data Model Refinement - Consolidate URIs to `metadata` map (Remaining Steps):** (Cloud Functions, Non-Modal Workflow, Migration Script, Testing) - *Partially done for modal workflow.*
- **Cloud Function `generate_thumbnail` Behavior:** Further investigation based on main image missing issue.
- **Firebase App Check/Google Sign-In:** Monitor intermittent warnings/errors.
- **Code Cleanup & Refactoring - Parsing Logic Duplication**
- **General Modal Workflow State Consistency Plan**
- **Comprehensive Testing Suite**
- **Handle Edge Cases & Stability (Completed Receipts, Error Handling)**

## Technical Implementation Details
(Consolidated Status Summary - See 'Completed' for more detail)
- **Main Navigation & Core Screens:** ✅
- **Receipts Screen (List View):** ✅ (UI simplified, stream loading & stability improved. Pagination pending).
- **Workflow Modal Core:** ✅ (Navigation, state management (`WorkflowState`, Provider), saving logic, draft handling, context safety, UI consistency for confirmations & button states).
- **Workflow Steps (Modal):**
    - Upload: ✅ (Image display for new/resumed, background uploads, placeholder/loading UI improved. Key bugs: 404 image, blurry thumbnail ⚠️, potential load time UX ⚠️).
    - Review: ✅ (Data persistence fixed).
    - Assign: ✅ (Transcription persistence, confirmation flows improved).
    - Split: ✅ (Data model adherence, `SplitManager` re-initialization, state propagation to `WorkflowState` fixed. UI issues: Go To Summary button ⚠️, Unassigned tab ⚠️).
    - Summary: ✅ (Subtotal calculation, tip/tax persistence fixed).

### Current Challenges (Focus on remaining issues)
(Moved details to Pending Issues above)

## Environment Setup Status
(No changes from previous state - Assumed stable with emulator scripts and `firebase.json`)

## Testing Status
(Needs expansion as noted above - focus on end-to-end workflow, edge cases, and specific bug resolutions)

## Known Issues (Consolidated)
(Moved details to Pending Issues above)

## Next Steps (Priority Order)

1.  **Investigate & Fix Main Image Missing (404 Error) from Storage (CRITICAL):** Analyze client logs.
2.  **Investigate & Fix Blurry Thumbnail on Backtrack (Upload Screen - High Priority):** Analyze client logs.
3.  **Review & Fix Storage Security Rules (High Priority):** Ensure users can delete their own images/thumbnails.
4.  **Investigate and Resolve `GoogleApiManager SecurityException` & Network Errors (High Priority - Separate Effort?).**
5.  **Image Load Time (Upload Screen - UX - Medium Priority):** Consider `progressIndicatorBuilder` if still an issue.
6.  **Implement Stream-Based Pagination for Receipts List (Medium Priority):** Modify `getReceiptsStream` for initial limit and add "load more" functionality using `getReceiptsPaginated` for `ReceiptsScreen` if current stream-all approach is too slow for many receipts.
7.  **Implement "Completed" Indicator (UI - Medium Priority).**
8.  **Test Split Step State Persistence & Data Flow (Modal Client-Side - Medium Priority).**
9.  **Investigate Root Cause of Calling Context Unmount in `WorkflowModal.show` (Medium Priority - if recurrent).**
10. **Cloud Function Updates (URI Metadata - General Review).**
11. **Data Migration Script.**
12. **Non-Modal Workflow URI Refactoring.**
13. **Comprehensive Testing (URI Refactor & Background Uploads).**
14. **Address Remaining App Check/Sign-In Issues (Lower Priority).**
15. **Address Security Warnings (General Consolidation).**
16. **Create Comprehensive Testing Suite (General).**
17. **Enhance Error Handling.**
18. **Handle Edge Cases (Completed Receipts).**
19. **Code Cleanup/Refactoring (Parsing Logic).**

## Developer Notes / Knowledge Transfer (Updated)

Key learnings from recent debugging sessions regarding the modal workflow:

- **Modal State (`WorkflowState` & Provider):** Using a central `ChangeNotifier` (`WorkflowState`) provided via `Provider` is effective for managing state across the modal steps. However, careful attention must be paid to *when* state is updated and *when* listeners are notified.
- **Widget Rebuild Timing & `Consumer`:** When complex state updates happen asynchronously (like fetching URLs in `_loadReceiptData`), passing updated state values down as simple constructor parameters to child widgets can sometimes lead to the child building with stale data if the parent rebuilds too quickly. Using a `Consumer<StateType>` widget directly within the child's parent builder function (as done for `ReceiptUploadScreen` in `_buildStepContent`) ensures the child is built using the absolute latest state from the provider at the time of the build.
- **Saving State from Children on Parent Action:** When a parent action (like `_saveDraft` triggered by `_onWillPop`) needs the *most current* data from a child widget's internal state (like `_editableItems` in `ReceiptReviewScreen`), simply relying on the last known state in the central provider (`WorkflowState`) might not be sufficient if the child's state changed *after* the last update to the provider but *before* the parent action. Implementing a callback registration pattern (e.g., `registerCurrentItemsGetter`) allows the parent to actively *pull* the latest state from the child at the exact moment it's needed (e.g., just before saving).
- **Firestore `update` vs. `set(merge:true)` vs. `set`:** For `FirestoreService.saveReceipt`, if a `receiptId` is provided, check if the document exists. If not, use `docRef.set(data)` (create with specific ID). If it exists, use `docRef.set(data, SetOptions(merge: true))` (update/merge), ensuring `created_at` isn't overwritten. This handles new client-side IDs correctly and avoids `NOT_FOUND` errors.
- **Debugging State Flow:** Using targeted `debugPrint` statements at key points (state mutation in Provider, parent build function before child instantiation, child build function accessing properties) is invaluable for tracing data flow and pinpointing timing issues or stale state problems. Detailed URI tracing has been added to debug image persistence.
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
- **Mounted Checks & Async Navigation:**
    - Errors like `Context is not mounted before navigation` often occur when an `async` operation completes after a widget has been removed from the tree. Always check `if (!mounted) return;` before accessing `context` or calling `setState` in `async` callbacks or `initState`/`addPostFrameCallback`. This applies to both the calling widget and any static helper methods (like `WorkflowModal.show` or `showRestaurantNameDialog`) that receive and use a `BuildContext` across `await` boundaries.
    - The debug message `[WorkflowModal.show] Calling context for receiptId '...' unmounted after 'firestoreService.getReceipt()' await.` indicates the calling screen's context became unmounted during an `await` in `WorkflowModal.show` (before the modal route was pushed). The mounted checks correctly prevent a crash. If recurrent, the calling screen's lifecycle needs investigation.
- **Centralized Exit/Save Logic:** For modal dialogs or complex workflows with multiple exit points (e.g., system back button, custom close button, 'Save & Exit' button), consolidate the save, cleanup, and confirmation logic into a single shared method (like `_onWillPop`). Each exit trigger should then primarily call this method to ensure consistent behavior.
- **State Propagation Between Steps:** When navigating between steps in a workflow, ensure the data required by the destination step is correctly sourced. If a later step depends on the precise output of a previous step (e.g., Summary depending on the exact item assignments and quantities from Split), ensure the data is passed directly (e.g., via a shared state object like `WorkflowState`) without re-interpreting or reconciling it with even older states (like the initial parsed data from the Review step), as this can reintroduce inconsistencies.
- **Updating Central State from Step UI:** When a specific step's UI allows modification of data that is managed by a central state object (like `WorkflowState`), ensure that UI changes trigger updates back to the central state object (e.g., using `context.read<WorkflowState>().setSomeValue(...)` in `onChanged` handlers). This prevents the UI showing changes that aren't reflected in the underlying state used for saving or by other steps.
- **Notification Listeners for Cross-Widget Communication:** When a child widget needs to trigger an action in an ancestor (like navigation managed by a parent workflow controller), `Notification.dispatch(context)` and `NotificationListener` provide a decoupled way to communicate up the tree without passing direct callbacks down through multiple layers, especially useful when using `Provider` for state.
- **Handling Async Operations Before Navigation/Dispose:** When performing async operations (like API calls) before navigating away or disposing a widget/state object, ensure `mounted` checks are performed *after* each `await`. Capture `Navigator` or `ScaffoldMessenger` context *before* awaits if needed. Perform state updates and UI feedback (like `SnackBar`s) *after* awaits (and subsequent `mounted` checks) but *before* the final navigation call (`Navigator.pop`) to prevent using disposed objects.
- **Distinguish Navigation from Processing Actions:** Buttons that trigger data processing (like parsing, transcription, assignment generation) should be clearly distinct from buttons that purely handle navigation between steps. Confirmation dialogs for potential data overwrites should typically be tied to the processing actions, not simple navigation buttons like "Next".
- **Image Display on Draft Resume (`ReceiptUploadScreen`):** The screen now correctly uses `imageUrl` (for full image) and `loadedThumbnailUrl` (as fallback/placeholder) from `WorkflowState`, passed via `Consumer`, to display images using `CachedNetworkImage`.
- **Workflow Resumption Logic (`_loadReceiptData`):**
    - The method now correctly determines the `targetStep` based on `hasAssignmentData`, `hasTranscriptionData`, and `hasParseData` to navigate to the furthest completed logical step.
    - An `_isDraftLoading` flag in `_WorkflowModalBodyState` controls a loading indicator to prevent UI flashing during draft load.
- **Firebase Storage Object Not Found (404 for Main Image):** A new critical issue where the main image GS URI is present in Firestore, and its thumbnail exists in Storage, but the main image itself is missing from Storage. This points to potential issues in:
    - Client-side upload logic (durability, error handling that might still save a "bad" URI).
    - `generate_thumbnail` Cloud Function (though initial review shows no obvious deletion of source).
    - Other race conditions or data integrity issues in the save/upload/delete lifecycle.
    - Detailed URI logging has been added to the client to help trace this.
- **Error Handling for Background Uploads (`onImageSelected`):** Improved by explicitly clearing `actualImageGsUri` and `actualThumbnailGsUri` in `WorkflowState` if the upload for the *currently selected* image file fails, to prevent saving invalid URIs. Also attempts to queue URIs for deletion if an upload completes for an image that is no longer the active selection.
- **Receipts List Loading (`ReceiptsScreen`):**
    - Removed confusing `TabBar` from `AppBar`.
    - Implemented `AutomaticKeepAliveClientMixin` to preserve state between tab navigations (should prevent reloads when switching to/from Settings).
    - Refactored to use `StreamBuilder` with `_firestoreService.getReceiptsStream().asyncMap(...)` to process thumbnails within the stream pipeline. The stream is initialized in `initState` to prevent re-creation on build. This resolved flashing/rebuild issues.
    - **Future Enhancement:** If streaming all receipts is too slow/costly, stream-based pagination (stream initial batch, then manual "load more") will be the next step for list performance.
- **Button Redundancy (`ReceiptUploadScreen`):** Ensure that conditionally rendered buttons with similar actions (e.g., "Use This" vs. a separate "Parse Receipt") don't appear simultaneously, causing confusion. Consolidate actions into fewer, clearly purposed buttons.
- **Image Placeholder Layout (`ReceiptUploadScreen`):** When using `CachedNetworkImage` for a main image with a thumbnail displayed in its `placeholderBuilder`, use a `Stack` to correctly layer the thumbnail and a loading indicator. Ensure `BoxFit` properties are consistent between the placeholder thumbnail and the main image to prevent visual jumps and improve the loading experience.

</rewritten_file> 