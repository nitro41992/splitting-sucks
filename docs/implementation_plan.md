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

**In Progress:**
- None

**Pending:**
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
   - ✅ **Resolved:** Resuming draft now correctly displays the saved receipt image in Upload step (using download URL).
   - ⚠️ Thumbnail generation via `generate_thumbnail` cloud function fails with `INTERNAL` error (Needs investigation in Cloud Function logs).

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
        - **Further Solution:** Ensured correct SHA-1 fingerprint for the debug build (`B8:FB:62:9B:57:EA:A6:FF:1B:EE:1E:E3:C6:C7:74:58:2F:06:42:AD`) was registered in the correct Google Cloud Project ("billfie-dev") for an Android-type OAuth 2.0 Client ID.
        - **Further Solution:** Corrected `google-services.json` to be generated from the "billfie-dev" Firebase project, ensuring it contains the appropriate `project_id` and the Android client `certificate_hash` matching the debug SHA-1. Resolved issues with conflicting client configurations in `google-services.json` and incorrect OAuth Client ID setups in Google Cloud Console (ensuring Android Client ID with debug SHA-1 was in the `billfie-dev` GCP and not conflicting with the production "billfie" GCP).
    - ✅ **Resolved:** Sign-out navigation fixed.
        - **Solution:** Removed temporary `AuthService` instantiation from `main()`; ensured `AuthService` provided by `AppWithProviders` is used consistently. Added debug logging to `MyApp`'s `StreamBuilder` to verify state changes.
    - ✅ Anonymous sign-in via `autoSignInForEmulator` now working correctly with the emulator.
    - ✅ **Resolved:** Emulator sign-out persistence after clean rebuild.
        - **Solution:** Modified `AuthService.authStateChanges` getter to consistently use the main user stream (`_userStreamController.stream`) in emulator mode. This ensures the UI correctly reflects the null user state after sign-out, preventing a stale authenticated state (often the previously Google-signed-in user) from persisting due to the emulator's auth state bypass logic.
    - ⚠️ **Remaining Issue (High Priority):** Persistent `SecurityException: Unknown calling package name 'com.google.android.gms'` (seen in `GoogleApiManager` errors). Needs investigation and resolution; could indicate issues with Play Services integrity, device state, or deeper permission issues.
    - ⚠️ **New Issue (High Priority):** Logs now show `W/ManagedChannelImpl: Failed to resolve name. status={1}` errors. This indicates potential network/DNS resolution issues when connecting to Firebase backend services (e.g., Firestore, Functions) and needs immediate investigation.
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
    - ⚠️ **`generate_thumbnail` function deployment to `billfie-dev` is currently failing.** (Needs investigation via Cloud Function logs).
    - ⚠️ Noted an Artifact Registry permission warning during deployment; may need to grant `roles/artifactregistry.reader` to the Cloud Functions service agent.
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
- **Google Sign-In Play Services Error:**
    - ✅ **Resolved:** The primary Google Sign-In functionality is now working after extensive troubleshooting of SHA-1 fingerprints, `google-services.json` configurations, and Google Cloud Project OAuth 2.0 Client ID setups for the `billfie-dev` environment.
    - ⚠️ **Remaining Issue (High Priority):** Logs show repeated `E/GoogleApiManager: Failed to get service from broker. java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'`. Needs monitoring and investigation; could indicate issues with Play Services integrity, device state, or deeper permission issues if functional problems arise.
- **Network Connectivity to Firebase Backend:**
    - ⚠️ **New Issue (High Priority):** Logs show repeated `W/ManagedChannelImpl: Failed to resolve name. status={1}`. This suggests problems connecting to Firebase backend services and needs to be addressed urgently.

## Next Steps (Priority Order)

1.  **Investigate and Resolve `ManagedChannelImpl: Failed to resolve name` errors (High Priority):**
    - Check network connectivity on the test device.
    - Verify DNS settings.
    - Ensure Firebase backend services (Firestore, Functions) are correctly provisioned and accessible for the `billfie-dev` project.
    - Review any recent changes to network configuration or Firebase project settings.
2.  **Investigate and Resolve `GoogleApiManager SecurityException` (High Priority):**
    - Thoroughly clear Google Play Services cache/data and app cache/data on the test device.
    - Restart the test device.
    - Ensure Google Play Services and Android System are fully updated.
    - If persisting, explore if specific Google APIs need to be enabled in Google Cloud Console for the `billfie-dev` project.
3.  **Fix `generate_thumbnail` Cloud Function Deployment to `billfie-dev`:** 
    - Investigate and resolve the deployment failure for `generate_thumbnail` on `billfie-dev` by checking its specific Cloud Function and Cloud Build logs in the Google Cloud Console for that project. This is the immediate blocker for full backend functionality on `billfie-dev`.
4.  **Address Security Warnings:**
    - Implement Firebase App Check (`firebase_app_check` plugin, Play Integrity/Debug providers).
    - Verify SHA-1/SHA-256 keys in Firebase Console for Android.
    - Check for API key restrictions in Google Cloud Console.
    - Ensure Google Play Services are up-to-date on test devices/emulators.
5.  **Remove Diagnostic Delay:** 
    - Remove the `Future.delayed` call from `_loadReceipts` in `ReceiptsScreen.dart`.
6.  **Implement Receipt List Pagination:**
    - Modify `FirestoreService.getReceipts` to accept limit/startAfter.
    - Update `ReceiptsScreen` UI (infinite scroll or "Load More") to fetch in batches.
7.  **Create Comprehensive Testing Suite:**
    - Unit tests for services (`AuthService`, `FirestoreService`) and models.
    - Widget tests for UI components (especially `WorkflowModal`).
    - Integration tests for the full end-to-end workflow.
8.  **Enhance Error Handling:**
    - Improve user feedback for errors beyond basic Snackbars (e.g., thumbnail failure, network issues).
9.  **Handle Edge Cases (Completed Receipts):**
    - Define and implement behavior for editing/modifying already completed receipts.
10. **Code Cleanup/Refactoring:**
    - Review for potential code duplication (e.g., `SplitManager` instantiation).
    - Ensure consistent state management. 