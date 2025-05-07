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
   - ✅ Deletion with confirmation dialog implemented
   - ⚠️ Need to handle edge cases when modifying completed receipts
   - ⚠️ Receipts list loading can be slow due to lack of pagination.

2. **Image Processing:**
   - ✅ Image upload to Firebase Storage working
   - ✅ Proper thumbnail generation via cloud function implemented

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
    - ✅ **Resolved:** Sign-out navigation fixed.
        - **Solution:** Removed temporary `AuthService` instantiation from `main()`; ensured `AuthService` provided by `AppWithProviders` is used consistently. Added debug logging to `MyApp`'s `StreamBuilder` to verify state changes.
    - ✅ Anonymous sign-in via `autoSignInForEmulator` now working correctly with the emulator.
    - ⚠️ **Remaining Issue:** Persistent `SecurityException: Unknown calling package name 'com.google.android.gms'` during Google Sign-In, although sign-in flow now completes successfully. Potentially related to Play Services state on the device or SHA-1/API key configuration.
    - ✅ Firebase services correctly connect to emulators using the host PC's LAN IP.

## Environment Setup Status

### Emulator Configuration

1. **Setup Working (for Physical Device & Emulators):**
   - ✅ `.env` file with `USE_FIRESTORE_EMULATOR=true` toggles emulator use.
   - ✅ `main.dart` configures emulators using the host PC's LAN IP (`192.168.0.152`) for physical device testing.
   - ✅ Host machine firewall configured to allow inbound connections on emulator ports.
   - ✅ `firebase.json` configures emulators to listen on `host: "0.0.0.0"`.
   - ⚠️ **Rules Workaround:**
       - Due to suspected issue in `firebase-tools` v14.2.1, the Firestore emulator currently ignores the `emulators.firestore.rules` setting in `firebase.json`.
       - **WORKAROUND:** The **`firestore.rules`** file (used for production) is temporarily configured with permissive rules (`allow read, write: if true;`) during development to allow the Firestore emulator to function correctly.
       - The `firestore.emulator.rules` file exists with permissive rules but is **not** being loaded by the Firestore emulator.
       - The Storage emulator **correctly** loads and uses the permissive `storage.emulator.rules` file as configured in `firebase.json`.
       - **CRITICAL:** The secure production rules **MUST** be restored to `firestore.rules` before committing code or deploying.
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

- **Firestore Permission Denied:**
    - ✅ **Resolved (via Workaround):** The Firestore emulator was incorrectly loading the production `firestore.rules` file instead of `firestore.emulator.rules` as specified in `firebase.json` (suspected `firebase-tools` v14.2.1 issue). 
    - **Workaround Applied:** The `firestore.rules` file now temporarily contains permissive rules (`allow read, write: if true;`) for local development using the emulator.
    - **CRITICAL CAVEAT:** Secure production rules MUST be restored to `firestore.rules` before committing or deploying.
- **Google Sign-In Play Services Error:**
    - Although Google Sign-In now works, logs show repeated `SecurityException: Unknown calling package name 'com.google.android.gms'`. Needs monitoring; could indicate issues with Play Services, SHA-1, or API keys if functional problems arise.

## Next Steps (Priority Order)

1.  **(Low Priority / Background):** Investigate/Report Firestore Emulator Rules Bug in `firebase-tools`.
2.  **Performance Optimization (Receipts Loading):**
    - Implement pagination for the receipts list in `ReceiptsScreen` and `FirestoreService`.
3. **Create Comprehensive Testing Suite:**
   - Unit tests for all services and models
   - Widget tests for all UI components
   - Integration tests for full workflow
4. **Performance Optimization (Other):**
   - Implement image caching for better performance
   - Optimize state management to reduce rebuilds
5. **Handle Edge Cases & Further Stability:**
   - Test and handle completed receipt modifications
   - Improve error handling and recovery generally
   - Investigate and resolve any further latent null check issues. 