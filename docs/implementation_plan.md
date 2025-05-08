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

**In Progress:**
- None

**Pending:**
- **Workflow Stability - Upload Screen (Revised Investigation & Fix Plan):**
  - **Resolution Note (Important for Future Development):**
    The primary cause of the "Please select an image first" error and subsequent parsing issues when resuming drafts within the **modal workflow** was identified and resolved by focusing on `lib/widgets/workflow_modal.dart`. Initial troubleshooting efforts were misdirected towards `lib/receipt_splitter_ui.dart` (`MainPageController` and `ReceiptScreenWrapper`), which, while relevant for other potential app flows, does not handle the "Use This" button's action in the primary modal receipt processing.

    The key fixes involved:
    1.  Correcting the `onParseReceipt` callback in `_WorkflowModalBodyState` (within `lib/widgets/workflow_modal.dart`) to properly check for both local image files (`workflowState.imageFile`) and existing remote image URLs (`workflowState.loadedImageUrl`).
    2.  Integrating the call to `ReceiptParserService.parseReceipt(gsUri)` directly within this `onParseReceipt` callback, ensuring the correct `gs://` URI is used.
    3.  Making `_WorkflowModalBodyState._convertToReceiptItems` robust by correctly handling the data structure returned by the parser (e.g., using `rawItem['item']` for names and providing defaults for null/missing fields).

    **Future developers working on the modal receipt upload, parsing, and item review steps should primarily look at `lib/widgets/workflow_modal.dart` (specifically `_WorkflowModalBodyState`) and its `WorkflowState` for the relevant logic.** The parsing logic in `MainPageController` (`lib/receipt_splitter_ui.dart`) might be for a different context or could be a candidate for refactoring if the modal is the sole entry point for this detailed workflow.

  - **Issue (Resolved):** "Please select an image first" error *was occurring* on the Upload screen in the modal workflow when "Use This" is pressed, even if an image (especially from a resumed draft) was visible.
  - **Core Problem (Identified & Resolved):** The `onParseReceipt` callback in `_WorkflowModalBodyState` was not correctly handling resumed drafts with remote images (it primarily checked for a local `imageFile`) and was not robustly calling the parser or handling its results for item display.
  - **Investigation & Solution Strategy (Superseded for Modal Context):** Original investigation focused on `receipt_splitter_ui.dart`. The successful solution was applied directly in `lib/widgets/workflow_modal.dart`.
  - **Verification (Modal Workflow Scenarios - Confirmed Working):**
    - ✅ New Upload: Pick image -> "Use This" -> Parse & Navigate to Review with correct items.
    - ✅ Draft Resume (with unparsed image): Open draft with image -> "Use This" -> Parse & Navigate to Review with correct items.
    - ✅ Retry logic within modal upload screen appears functional for clearing local selections.

- **Code Cleanup & Refactoring - Parsing Logic Duplication:**
  - **Context:** The primary parsing initiation and item data handling for the **modal workflow** is now correctly implemented in `lib/widgets/workflow_modal.dart` (within `_WorkflowModalBodyState`).
  - **Observation:** Parsing-related logic also exists in `lib/receipt_splitter_ui.dart` within `_MainPageControllerState` (e.g., `_directParseReceipt`) and `_ReceiptScreenWrapperState` (`_parseReceipt`).
  - **Action:** Review this potentially duplicated/unused code.
    - If the modal workflow is the *sole* pathway for detailed receipt processing, refactor to remove the redundant parsing logic from `receipt_splitter_ui.dart` to simplify the codebase.
    - If the logic in `receipt_splitter_ui.dart` serves a different, non-modal purpose, clearly document its specific use case to avoid confusion.
    - **Key files for current modal parsing:** `lib/widgets/workflow_modal.dart`, `lib/services/receipt_parser_service.dart`.

- **Data Model Refinement - Receipt URIs:**
  - **Objective:** Consolidate `image_uri` and `thumbnail_uri` into the `metadata` map for each receipt document to improve data structure clarity and reduce redundancy, aligning with the updated `app_navigation_redesign.md`.
  - **Current State (as per Firestore screenshot & potential legacy):** URIs might be at the root or redundantly nested within process-specific maps (`parse_receipt`, `assign_people_to_items`, `split_manager_state`).
  - **Target State:** Single `metadata.image_uri` and `metadata.thumbnail_uri` per receipt.
  - **Impact & Implementation Steps:**
    1.  **Flutter App (`Receipt` Model):**
        *   Modify `lib/models/receipt.dart` (`Receipt.fromJson`, `toJson/toMap`).
        *   Update all parts of the app that read/write these URIs to use the new path (e.g., `metadata['image_uri']`). This includes: `ReceiptsScreen` (for thumbnails), `WorkflowModal` and its constituent screens when handling draft images or displaying parsed/thumbnail data.
    2.  **Cloud Functions:**
        *   **`parse_receipt`:** If it currently writes `image_uri` or `thumbnail_uri` to its own map, it should now write them to `metadata.image_uri` and `metadata.thumbnail_uri` (or just `image_uri` if `generate_thumbnail` is separate).
        *   **`generate_thumbnail`:** Should read the main image URI from `metadata.image_uri` and write the generated thumbnail URI to `metadata.thumbnail_uri`.
        *   **Other Functions (`assign_people_to_items`, etc.):** If they previously referenced nested URIs, they must now reference `metadata.image_uri` or `metadata.thumbnail_uri`.
        *   Remove redundant URI fields from the data structures these functions expect or produce.
    3.  **Data Migration (One-time script or manual for few documents):**
        *   For each existing receipt document in Firestore:
            *   Identify the canonical `image_uri` (likely from the most recent or primary source like `parse_receipt.image_uri` or a root field if it exists).
            *   Identify the canonical `thumbnail_uri` (similarly).
            *   Write these values to `doc.metadata.image_uri` and `doc.metadata.thumbnail_uri`.
            *   Delete the old root-level `image_uri`/`thumbnail_uri` fields (if they exist).
            *   Delete the redundant nested `image_uri` and `thumbnail_uri` fields from within `parse_receipt`, `assign_people_to_items`, `split_manager_state`, etc.
    4.  **Testing:**
        *   Verify new receipts correctly store URIs in `metadata`.
        *   Verify drafts with images (old and new structure post-migration) load correctly.
        *   Verify thumbnail generation and display works with the new structure.
        *   Verify all functions relying on these URIs operate correctly.

- **General Modal Workflow State Consistency Plan:**
  - **Objective:** Ensure reliable data flow, state management, and UI consistency across all steps of the modal workflow (Upload, Review, Assign, Split, Summary), whether it's a new receipt or a resumed draft.
  - **Principles:**
    - **Single Source of Truth:** For any piece of data relevant to a step (e.g., image URI, parsed items, transcription, assignments), identify a single, authoritative source (`MainPageController` for cross-step persistent/draft state, or the current step's controller/wrapper for transient state).
    - **Clear Data Propagation:** Use widget constructors (props) for passing initial/static data down and callbacks (`onComplete`, `onUpdate`) for sending data/events up.
    - **Scoped State Management:** Leverage `Provider` or `ChangeNotifier` (like `WorkflowState` or `SplitManager`) appropriately for state that needs to be shared or mutated across a limited scope of the workflow, but ensure clear interaction with `MainPageController` for overall persistence.
    - **Immutability where Possible:** When passing data objects (like lists of items), consider using immutable patterns or creating copies to prevent unintended side-effects if child widgets modify them.
  - **Action Plan:**
    1.  **Data Flow Mapping (for each step - Review, Assign, Split, Summary):**
        *   **Inputs:** What data does this screen (`ReceiptReviewScreen`, `VoiceAssignmentScreen`, etc.) require to initialize (e.g., `_receiptItems` for Review, `_savedTranscription` for Assign)?
        *   **Source:** How does it receive these inputs from `MainPageController` (or the preceding step's completion callback)?
        *   **Internal State:** Does the screen manage its own temporary state related to these inputs? How is it synchronized if the inputs change?
        *   **Actions & Outputs:** What actions can the user perform (e.g., edit item, confirm transcription, adjust split)? How are the results of these actions (e.g., updated items, `_assignments`) communicated back to `MainPageController` (e.g., via `onReviewComplete`, `onAssignmentProcessed`) to update the central state and mark step completion (`_isReviewComplete`, `_isAssignmentComplete`)?
    2.  **State Restoration Review (for each step):**
        *   Verify `_MainPageControllerState._loadSavedState()` correctly loads all relevant data for each step (e.g., `_receiptItems`, `_savedTranscription`, `_assignments`).
        *   Ensure this loaded data is correctly passed as initial props to the respective screen widgets when resuming a draft.
        *   Confirm the screen widgets initialize their UI and internal state correctly based on these restored props.
    3.  **Callback Integrity:**
        *   Ensure all `onSomethingComplete` or `onDataUpdated` callbacks from screen widgets correctly update the state in `_MainPageControllerState` (e.g., `_receiptItems`, `_isUploadComplete`, `_savedTranscription`, `_assignments`, `_isReviewComplete`, `_isAssignmentComplete`).
        *   Verify that `_navigateToPage()` is called with the correct next page index *after* the relevant state updates have been committed.
    4.  **`SplitManager` Initialization:**
        *   Re-confirm that `SplitManager` is correctly reset and initialized in `_navigateToPage()` specifically when navigating from Assign (page 2) to Split (page 3) using the `_assignments` data.
        *   Verify its behavior when restoring a draft directly onto the Split or Summary page (post-build state restoration logic in `MainPageController`).
        *   **Defensive UI:** Ensure buttons that trigger actions (e.g., "Next," "Confirm," "Process") are appropriately enabled/disabled based on the current valid state of required data for that step.
  - **Testing Strategy (General Workflow):**
    - **End-to-End Fresh:** Complete workflow from new upload to summary.
    - **Draft Resume at Each Step:**
        - Upload -> Save/Exit -> Resume -> Continue.
        - Upload -> Review -> Save/Exit -> Resume -> Continue.
        - Upload -> Review -> Assign -> Save/Exit -> Resume -> Continue.
        - (And so on for Split and Summary).
    - **"Back" Navigation:** Navigate forward, then back, then forward again, ensuring state is preserved or correctly reloaded/recalculated.
    - **"Retry" (where applicable):** Test retry/reset mechanisms within steps.

- **Performance Optimization:**
  - Optimize receipts list loading (currently fetches all receipts; needs pagination)
  - Implement image caching for better performance
  - Optimize state management to reduce rebuilds
- **Testing:**
  - Create comprehensive testing suite for all components (Unit, Widget, Integration)
- **Handle Edge Cases & Stability:**
  - Test and handle completed receipt modifications
  - Further improve error handling and recovery across the app
  - Investigate any remaining `Null check operator used on a null value` errors (e.g., in `WorkflowModal.show`, though recent fixes might have resolved it)

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
   - ✅ Automatic draft saving
   - ✅ Parameter types between steps fixed
   - ✅ Component interface consistency ensured
   - ✅ Correctly uses `ChangeNotifierProvider` for `WorkflowState`

4. **Individual Steps:**
   - ✅ Upload: Camera/gallery picker implemented
   - ✅ Review: Item editing functionality working
   - ✅ Assign: Voice transcription and assignment working
   - ✅ Split: Item sharing and reassignment implemented
   - ✅ Summary: Tax/tip calculations implemented and properly connected

### Current Challenges

1. **Data Persistence & Performance:**
   - ✅ Draft saving and resuming functionality working
   - ✅ **Resolved:** Draft now correctly saves image URI even if exiting modal before confirming upload.
   - ✅ **Resolved:** Image preview now shows in Upload step before confirming. Logic moved from `onImageSelected` to `onParseReceipt`.
   - ✅ **Resolved:** Receipts list now auto-refreshes after saving/completing a receipt from the workflow modal.
   - ✅ **Resolved:** Drafts list visibility after sign-out/sign-in corrected (required emulator state clear).
   - ✅ Deletion with confirmation dialog implemented
   - ⚠️ Need to handle edge cases when modifying completed receipts
   - ⚠️ Receipts list loading can be slow due to lack of pagination.

2. **Image Processing:**
   - ✅ Image upload to Firebase Storage working
   - ✅ **Resolved:** Resuming draft now correctly displays the saved receipt image in Upload step (using download URL, storage read rules fixed).
   - ✅ **Resolved:** `generate_thumbnail` function deployment to `billfie-dev` (Artifact Registry permission for service agent fixed).
   - ✅ **Resolved:** Calling `generate_thumbnail` Cloud Function from app no longer results in `UNAUTHENTICATED` error (Cloud Run service set to "Allow unauthenticated invocations").
   - ✅ **Resolved:** `generate_thumbnail` function `INTERNAL` error (due to incorrect client payload) fixed by sending `{'imageUri': ...}` directly.
   - ✅ **Functionality Confirmed:** `generate_thumbnail` now successfully creates and stores thumbnail, returning its `gs://` URI to the client.
   - ✅ **Resolved:** Client app `[firebase_storage/unauthorized]` (403 error) when getting thumbnail download URL fixed by correcting storage rule path to `match /thumbnails/receipts/{userId}/{filename}`.
   - ✅ **Thumbnail Generation & Display Fully Working.**

3. **Data Flow & State Management:**
   - ✅ WorkflowState maintains data between steps
   - ✅ SplitManager properly handles tax/tip values
   - ✅ Tax and tip values properly propagate between split view and summary
   - ✅ Component interfaces aligned for consistent data passing
   - ✅ Addressed Provider/ChangeNotifierProvider issue in workflow.

4. **Authentication & Emulator Connectivity:**
    - ✅ **Resolved:** Physical Device Emulator Connectivity issues resolved.
        - **Solution:** Configured emulators to listen on `0.0.0.0` via `firebase.json`. Configured Flutter app (`main.dart`) to use the host PC's local Wi-Fi IP (e.g., `192.168.0.152`) for `emulatorHost` when `USE_FIRESTORE_EMULATOR=true`. Ensured Windows Firewall allows incoming TCP connections on emulator ports for the private network.
    - ✅ **Resolved:** Google Sign-In flow fixed.
        - **Solution:** Refactored `AuthService.signInWithGoogle` to use the `google_sign_in` plugin first to get credentials directly from Google, then pass the resulting credential to `FirebaseAuth.instance.signInWithCredential()`. This decouples the Google OAuth web flow from the emulator connection.
        - **Further Solution:** Ensured correct SHA-1 fingerprint (`B8:FB:...:AD`) was registered in the correct Google Cloud Project ("billfie-dev") for an Android-type OAuth 2.0 Client ID. Addressed "already in use" error by deleting conflicting ID from production GCP.
        - **Further Solution:** Added SHA-256 fingerprint (`EE:92:...:98`) to Firebase Project settings for the Android app.
        - **Further Solution:** Corrected `google-services.json` to be generated from the "billfie-dev" Firebase project, ensuring it contains the appropriate `project_id` and the Android client `certificate_hash` matching the debug SHA-1. Resolved issues with conflicting client configurations in `google-services.json`.
        - **Further Solution:** Corrected API Key Application Restrictions in Google Cloud Console to include the Android package name and debug SHA-1 fingerprint.
    - ✅ **Resolved:** Sign-out navigation fixed.
        - **Solution:** Removed temporary `AuthService` instantiation from `main()`; ensured `AuthService` provided by `AppWithProviders` is used consistently. Added debug logging to `MyApp`'s `StreamBuilder` to verify state changes.
    - ✅ Anonymous sign-in via `autoSignInForEmulator` now working correctly with the emulator.
    - ✅ **Resolved:** Emulator sign-out persistence after clean rebuild.
        - **Solution:** Modified `AuthService.authStateChanges` getter to consistently use the main user stream (`_userStreamController.stream`) in emulator mode. This ensures the UI correctly reflects the null user state after sign-out, preventing a stale authenticated state (often the previously Google-signed-in user) from persisting due to the emulator's auth state bypass logic.
    - ✅ **Firebase App Check Setup (Debug):**
        - Added `firebase_app_check` dependency and initialization code to `main.dart`.
        - Registered Play Integrity provider (with SHA-256) and Debug provider in Firebase Console.
        - ✅ Debug token from app logs is now being generated on emulator runs.
        - ✅ `generate_thumbnail` callable function is now being invoked (no longer `UNAUTHENTICATED`).
    - ⚠️ **Dependency Updates Attempted:** Relaxed constraints in `pubspec.yaml`, ran `flutter pub get` (updated several Firebase packages), explicitly added `play-services-auth` to `android/app/build.gradle`. These steps did not resolve the core remaining issues.
    - ⚠️ **Remaining Issue (Highest Priority):** Persistent `SecurityException: Unknown calling package name 'com.google.android.gms'` (seen in `GoogleApiManager` errors). Occurs on both physical device and emulator, even after configuration fixes and dependency updates. Needs urgent investigation.
    - ⚠️ **Remaining Issue (High Priority):** Persistent `W/ManagedChannelImpl: Failed to resolve name. status={1}` errors and Firestore `UNAVAILABLE` errors (e.g., `UnknownHostException: Unable to resolve host "firestore.googleapis.com"`). Likely a symptom of the `GoogleApiManager` issue, preventing reliable network connections. Needs urgent investigation.
    - ⚠️ **Remaining Issue (Lower Priority):** App Check placeholder token warning (`No AppCheckProvider installed`) reappears later in the app lifecycle, potentially due to the `GoogleApiManager` issue disrupting App Check communication.
    - ⚠️ **Remaining Issue (Lower Priority):** Google Sign-In sometimes fails initially with `ApiException: 10` before succeeding on a subsequent attempt. Likely related to the `GoogleApiManager` issue or propagation delays.
    - ✅ Firebase services correctly connect to emulators using the host PC's LAN IP.

## Environment Setup Status

### Multi-Project Firebase Setup (Dev/Prod)
- ✅ **Development Firebase Project (`billfie-dev`):**
    - A separate Firebase project (`billfie-dev`) has been created for development and staging, distinct from the `billfie` production project.
    - The Flutter app's Android configuration (`google-services.json`) has been updated to point to `billfie-dev`. Production `google-services.json` backed up as `google-services.json.prod` for manual swapping.
- ✅ **Firebase CLI Configuration:**
    - Project aliases `dev` (for `billfie-dev`) and `prod` (for `billfie`) configured in `.firebaserc`.
    - `billfie-dev` set as the default project in `.firebaserc` for the local workspace.
- ✅ **Deployment Configuration (`firebase.json`):**
    - Updated `firebase.json` so that `firestore.rules` and `storage.rules` (production rules) are deployed to cloud environments (like `billfie-dev`).
    - Emulator configuration in `firebase.json` remains pointed to `*.emulator.rules` for local emulator testing.
- ✅ **Deployment to `billfie-dev`:**
    - Firestore rules (`firestore.rules`) and indexes (`firestore.indexes.json`) successfully deployed.
    - Storage rules (`storage.rules`) successfully deployed.
    - Cloud Functions (`assign_people_to_items`, `parse_receipt`, `transcribe_audio`) deployed to `billfie-dev` after resolving Secret Manager setup.
    - ✅ **`generate_thumbnail` function deployment to `billfie-dev` resolved.** Root cause was missing `Artifact Registry Reader` permissions for the Cloud Functions service agent (`service-<PROJECT_NUMBER>@gcf-admin-robot.iam.gserviceaccount.com`). Granting this role fixed the deployment failure.
    - ⚠️ Noted an Artifact Registry permission warning during deployment; may need to grant `roles/artifactregistry.reader` to the Cloud Functions service agent. (This note can be considered resolved by the above point if no other warnings appear).
- ✅ **Secret Manager for `billfie-dev`:**
    - `OPENAI_API_KEY` and `GOOGLE_API_KEY` secrets have been created and configured in the Secret Manager for the `billfie-dev` project, resolving initial deployment failures for most functions.

### Emulator Configuration

1. **Setup Working (for Physical Device & Emulators):**
   - ✅ `.env` file with `USE_FIRESTORE_EMULATOR=true` toggles emulator use.
   - ✅ `main.dart` configures emulators using the host PC's LAN IP (e.g., `192.168.0.152`) for physical device testing.
   - ✅ Host machine firewall configured to allow inbound connections on emulator ports.
   - ✅ `firebase.json` configures emulators to listen on `host: "0.0.0.0"`.
   - ✅ **Firestore Emulator Rules Fix:**
     - The Firestore emulator now correctly loads `firestore.emulator.rules`.
     - **Solution:** The **top-level** `"firestore": { "rules": ... }` entry in `firebase.json` has been changed to point to `"firestore.emulator.rules"`.
     - The `emulators.firestore.rules` key in `firebase.json` was found to be unreliable for specifying the rules file for the Firestore emulator and has been removed for clarity.
     - The `firestore.rules` file now contains the secure **production** rules.
     - The `firestore.emulator.rules` file contains permissive rules for development (`allow read, write: if true;`).
     - The Storage emulator **correctly** loads and uses the permissive `storage.emulator.rules` file as configured in `firebase.json` (via `emulators.storage.rules`).
     - **IMPORTANT FOR DEPLOYMENT:** Before deploying to production, the top-level `"firestore": { "rules": ... }` in `firebase.json` **MUST** be changed back to point to `"firestore.rules"`.
   - ✅ **Resolved:** Storage Emulator permissions issue fixed by aligning top-level `storage.rules` key in `firebase.json` with emulator rules during development (similar to Firestore setup).
   - ✅ Seeding script creates test data in emulator.
   - ✅ Android debug manifest allows cleartext traffic.

2. **Ports Configured (in `firebase.json`):**
   - Firestore on port 8081
   - Storage on port 9199
   - Auth on port 9099
   - Functions on port 5001
   - Emulator UI on port 4000

## Testing Status

1. **Unit Tests:**
   - Basic service unit tests implemented
   - Need comprehensive testing for FirestoreService
   - Need Receipt model serialization/deserialization tests

2. **Widget Tests:**
   - Basic widget tests for common components
   - Need workflow modal navigation tests
   - Need to test screen transitions and state preservation

3. **Integration Tests:**
   - Not yet implemented
   - Need full end-to-end workflow testing
   - Need to test with emulator integration

## Known Issues (Beyond specific component challenges)

- **Firestore Permission Denied (during development with emulator):**
    - ✅ **Resolved:** The Firestore emulator was incorrectly loading the production `firestore.rules` file instead of `firestore.emulator.rules`.
    - **Solution:** The top-level `"firestore": { "rules": ... }` entry in `firebase.json` was updated to point to `"firestore.emulator.rules"` for local development. The secure production rules are maintained in `firestore.rules`, and permissive rules for the emulator are in `firestore.emulator.rules`. This configuration needs to be managed for production deployment (top-level `rules` key in `firebase.json` should point to `firestore.rules` for production builds/deployments).
- **Firebase Storage Permission Denied (for reading images for display):**
    - ✅ **Resolved:** The `storage.rules` for `receipts/{userId}/{filename}` were updated to allow reads if `request.auth != null && request.auth.uid == userId`, separating it from more restrictive write conditions. This fixed 403 errors when generating download URLs for display.
- **Google Sign-In Play Services Error:**
    - ✅ **Resolved:** The primary Google Sign-In functionality is now working (though sometimes intermittently fails on first try) after extensive troubleshooting of SHA-1/SHA-256 fingerprints, `google-services.json` configurations, Google Cloud Project OAuth 2.0 Client ID setups, and API Key restrictions for the `billfie-dev` environment.
    - ⚠️ **Remaining Issue (Highest Priority):** Logs persistently show `E/GoogleApiManager: Failed to get service from broker. java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'`. This occurs on multiple environments and needs urgent investigation as it likely causes downstream network failures.
- **Network Connectivity to Firebase Backend:**
    - ⚠️ **Remaining Issue (High Priority):** Logs persistently show repeated `W/ManagedChannelImpl: Failed to resolve name. status={1}` and Firestore `UNAVAILABLE` / `UnknownHostException` errors. This suggests problems connecting reliably to Firebase backend services, likely stemming from the `GoogleApiManager` issue.
- **Firebase App Check:**
    - ✅ Debug provider setup completed correctly.
    - ⚠️ App Check placeholder token warning reappears later in the session, needs monitoring after core issues are fixed.

## Next Steps (Priority Order)

1.  **~~Deploy Corrected Storage Rules and Test Thumbnail Display (High Priority):~~ (RESOLVED)**
    - ✅ Cloud Function invoker permissions for `generate_thumbnail` correctly set.
    - ✅ Firebase Auth user present on client-side.
    - ✅ App Check debug token logged.
    - ✅ Client-side payload for `generate_thumbnail` corrected.
    - ✅ `generate_thumbnail` function successfully creates and returns thumbnail URI.
    - ✅ Storage rule in `storage.rules` corrected to `allow read: if request.auth.uid == userId;` for the path `thumbnails/receipts/{userId}/{filename}` and deployed.
    - ✅ Thumbnail generation and display in app now working.

2.  **Investigate and Resolve `GoogleApiManager SecurityException` (High Priority):**
    - Re-test on a clean, known-good Play Store emulator AVD (cold boot, signed in) to definitively rule out environment issues.
    - Review `android/build.gradle` and `android/app/build.gradle` for any non-standard configurations (signing, dependencies, plugins).
    - Consider creating a minimal reproducible example project with just Firebase Core, Auth, and App Check to see if the error occurs there.
    - Explore potential tooling issues (Flutter SDK, Android SDK/NDK versions, Gradle version).
3.  **Investigate and Resolve `ManagedChannelImpl: Failed to resolve name` / Firestore `UNAVAILABLE` errors (High Priority, likely related to #2):**
    - Primarily focus on resolving the `GoogleApiManager` issue, as it's the most likely cause.
    - If the `GoogleApiManager` issue is fixed but network errors persist, investigate device/emulator DNS and network settings more deeply.
4.  **Address App Check Placeholder Token Reappearance (Lower Priority):**
    - Monitor after fixing `GoogleApiManager` issue.
5.  **Address Security Warnings:**
    - Implement Firebase App Check (`firebase_app_check` plugin, Play Integrity/Debug providers).
    - Verify SHA-1/SHA-256 keys in Firebase Console for Android.
    - Check for API key restrictions in Google Cloud Console.
    - Ensure Google Play Services are up-to-date on test devices/emulators.
6.  **Remove Diagnostic Delay:** 
    - Remove the `Future.delayed` call from `_loadReceipts` in `ReceiptsScreen.dart`.
7.  **Implement Receipt List Pagination:**
    - Modify `FirestoreService.getReceipts` to accept limit/startAfter.
    - Update `ReceiptsScreen` UI (infinite scroll or "Load More") to fetch in batches.
8.  **Create Comprehensive Testing Suite:**
    - Unit tests for services (`AuthService`, `FirestoreService`) and models.
    - Widget tests for UI components (especially `WorkflowModal`).
    - Integration tests for the full end-to-end workflow.
9.  **Enhance Error Handling:**
    - Improve user feedback for errors beyond basic Snackbars (e.g., thumbnail failure, network issues).
10. **Handle Edge Cases (Completed Receipts):**
    - Define and implement behavior for editing/modifying already completed receipts.
11. **Code Cleanup/Refactoring:**
    - Review for potential code duplication (e.g., `SplitManager` instantiation).
    - Ensure consistent state management. 