# Test Coverage Plan for Billfie App

**Note: Completed test items are moved to [docs/test_coverage_completed.md](test_coverage_completed.md) to maintain this document as a focused task list.**

## Test Status Overview

### Completed ✅
- **Python Cloud Functions:** All tests for `generate_thumbnail`, `parse_receipt`, `assign_people_to_items`, and `transcribe_audio` functions
- **Model Unit Tests:** All tests for `Receipt`, `ReceiptItem`, `Person`, and `SplitManager` models (including advanced bill splitting scenarios)
- **Dialog Widget Tests:** Tests for `AddItemDialog`
- **Widget Tests:** `WorkflowStepIndicator` (including tap interaction), `UploadStepWidget`/`ReceiptUploadScreen`, `ReceiptReviewScreen`/`ReviewStepWidget`, `WorkflowNavigationControls`
- **Provider Tests:** `WorkflowState` and `ImageStateManager`
- **Shared Utility Widgets:** `QuantitySelector`
- **Flutter Services:** Tests for `FirestoreService` methods including receipt CRUD operations (saveReceipt, saveDraft, completeReceipt, getReceiptsStream, getReceipts, getReceipt, deleteReceipt)

### Critical Tests with Implementation Issues ⚠️
- **Core Workflow Logic:** Tests for the following have been written but require fixes for Firebase initialization:
  - `AssignPeopleScreen`/`AssignStepWidget` UI and assignment logic
  - `SplitStepWidget` UI and split calculation logic

> **Note:** Widget tests for AssignStepWidget and SplitStepWidget have been written but are failing due to Firebase initialization issues. Only the SplitManager advanced tests are running successfully. These tests need to be updated with proper Firebase mocking to run correctly.

### High Priority Pending ⏳
- **Flutter Services:** Tests for Firebase Storage methods in `FirestoreService`:
  - `uploadReceiptImage` (test scaffold created, needs advanced mocking)
  - `generateThumbnail`
  - `deleteReceiptImage`
  - `deleteImage`
  
  > **Note:** Test scaffolding for Firebase Storage tests has been added. Complete implementation requires advanced mocking of Firebase Storage and Functions, possibly using a more sophisticated mocking approach than currently available in the test environment.
  
- **Core Workflow Logic:** Tests for workflow steps and saving behaviors
  - `_WorkflowModalBody` `_onWillPop` behavior (to ensure data saving when app is closed)
  - `SummaryStepWidget` final display and calculations

- **Dialog Widget Tests:** Tests for `EditItemDialog`, `showRestaurantNameDialog`, and `showConfirmationDialog`

## Next Steps for Test Implementation

Based on architectural priorities (supporting local caching and UI redesign), we've made significant progress on our high-priority test coverage:

✅ **SplitManager Advanced Tests Completed**
- Verifies complex bill splitting scenarios with mixed assignments and shares
- Confirms handling of floating point precision in calculations
- Tests edge cases like person removal after assignments
- Validates tax and tip distribution logic

⚠️ **AssignStepWidget and SplitStepWidget Test Implementation**
- Tests have been written but need fixes for Firebase initialization issues
- Need to update tests with proper mocking for Firebase services

The next areas to focus on:

1. **Fix Firebase Initialization in Widget Tests**
   - Update test environment to properly initialize or mock Firebase services
   - Set up test bootstrapping to handle Firebase dependencies

2. **Complete tests for `_WorkflowModalBody` `_onWillPop` behavior**
   - Ensure proper data saving when app is closed
   - Verify appropriate dialog display and response to user actions
   
3. **Implement tests for `SummaryStepWidget`**
   - Verify final summary display is accurate
   - Confirm total calculations are correct
   - Validate data consistency with previous workflow steps

4. **Implement dialog widget tests**
   - Verify proper functioning of `EditItemDialog` with existing items
   - Test confirmation and input dialogs for proper rendering and response

These remaining tests will complete our coverage of the core workflow logic, ensuring a solid foundation for both the caching implementation and UI redesign.

## Priority Framework

Tests are prioritized to support two upcoming major architectural changes:
1. **Local caching implementation**
2. **Significant UI redesign**

The priority groups below reflect this focus, with Group 1 containing tests critical for ensuring core logic, data integrity, and key workflows remain stable during these changes.

## Priority Group 1: Foundational Logic & Data Integrity (Essential)

These tests are critical for ensuring the application's core business logic and data handling remain robust during significant architectural changes.

### 1.1 Critical Service Logic Unit Tests

*   **`FirestoreService` methods:**
    *   **Objective:** Verify correct data transformation logic within services that will be affected by caching.
    *   **Test Cases:**
        *   ✅ `Future<String> saveReceipt({String? receiptId, required Map<String, dynamic> data})`
        *   ✅ `Future<String> saveDraft({String? receiptId, required Map<String, dynamic> data})`
        *   ✅ `Future<String> completeReceipt({required String receiptId, required Map<String, dynamic> data})`
        *   ✅ `Stream<QuerySnapshot> getReceiptsStream()`
        *   ✅ `Future<QuerySnapshot> getReceipts({String? status})`
        *   ✅ `Future<DocumentSnapshot> getReceipt(String receiptId)`
        *   ✅ `Future<void> deleteReceipt(String receiptId)`
        *   `Future<String> uploadReceiptImage(File imageFile)` (Interacts with Firebase Storage)
            *   (⏳) Mock `FirebaseStorage`, `Reference`, `UploadTask`, `TaskSnapshot`.
            *   (⏳) Verify correct GCS path generation (includes user ID, timestamp).
            *   (⏳) Verify `putFile()` is called with correct `File` and `SettableMetadata`.
            *   (⏳) Verify correct `gs://` URI is constructed and returned from mocked `TaskSnapshot`.
        *   `Future<String?> generateThumbnail(String originalImageUri)` (Interacts with Firebase Functions)
            *   (⏳) Mock `FirebaseFunctions` and `HttpsCallable`.
            *   (⏳) Verify correct call parameters.
            *   (⏳) Test error handling paths.
        *   `Future<void> deleteReceiptImage(String imageUri)` and `Future<void> deleteImage(String gsUri)`
            *   (⏳) Verify correct reference extraction from gs:// URI.
            *   (⏳) Test error handling for invalid URIs and Firebase exceptions.
        *   **(Consider if `_userId` getter needs specific tests, especially around emulator/prod logic if complex, though it's more internal state management).**
    *   **Placeholder for other Flutter Services with external dependencies that will need testing:**
        *   (⏳) Identify and test any other services that will be affected by caching implementation.

### 1.2 Core Workflow Logic & Data Flow Widget Tests

*   **`WorkflowModalBody` / `_WorkflowModalBodyState` (`lib/widgets/workflow_modal.dart`)**
    *   **Objective:** Test critical UI interaction paths and state transitions that need to remain intact during redesign.
    *   **Test Cases:**
        *   ✅ **Step Indicator Tap Logic:** 
            *   Tapping a previous step calls `workflowState.goToStep()` with the correct `tappedStep`.
            *   Tapping a future step (allowed by data) calls `workflowState.goToStep()`.
            *   Tapping a future step (blocked by data prerequisites) shows a toast and does NOT call `goToStep()`.
        *   ⏳ **`_onWillPop` behavior:** 
            *   With no data: Returns true (allows navigation)
            *   With data: Calls `_saveDraft` (verify mock called)
            *   With `_saveDraft` error: Shows confirmation dialog

*   **`AssignPeopleScreen` / `AssignStepWidget` (`lib/widgets/workflow_steps/assign_step_widget.dart`)**
    *   **Objective:** Verify the critical UI for assigning people to items, focusing on data flow that must be preserved.
    *   ✅ **Test Cases:**
        *   **Initial Display:** Verified correct rendering of items, people, and assignment UI from `WorkflowState`.
        *   **Person Management:** Tested adding, removing, renaming people with correct `WorkflowState` updates.
        *   **Item Assignment:** Tested assigning and unassigning items to people, shared item marking.
        *   **Button Logic:** Verified Next/Confirm is conditionally enabled based on assignments.

*   **`SplitStepWidget` (`lib/widgets/workflow_steps/split_step_widget.dart`)**
    *   **Objective:** Verify UI for displaying split amounts and handling adjustments (critical for caching/redesign).
    *   ✅ **Test Cases:**
        *   **Initial Display:** Verified correct loading of people, items, and amounts from `WorkflowState`.
        *   **Tip/Tax Entry:** Tested entry of tip and tax amounts with proper `WorkflowState` updates.
        *   **Split Calculations:** Verified correct calculation and display of individual and total amounts.
        *   **Button Logic:** Verified Next/Confirm is properly enabled/disabled.

*   **`SummaryStepWidget` (`lib/widgets/workflow_steps/summary_step_widget.dart`)**
    *   ⏳ **Objective:** Verify final summary display, including individual totals, grand total (Phase 0 Priority). Ensure correct data is pulled from `WorkflowState` and accurately reflects prior steps.
    *   **(⏳ To be detailed, focusing on data accuracy)**

### 1.3 Advanced Model Tests

*   **`SplitManager` Advanced Tests**
    *   ✅ **Objective:** Verify complex bill-splitting scenarios and edge cases.
    *   **Test Cases:**
        *   **Complex Scenarios:** Tested mixed assignments with multiple people sharing items.
        *   **Floating Point Precision:** Verified accurate handling of decimal values in calculations.
        *   **Person Removal:** Tested correct behavior when removing a person after assignments.
        *   **Tax and Tip Distribution:** Verified proper distribution of tax and tip among assigned and unassigned items.
        *   **State Preservation:** Confirmed state is correctly maintained during transfer operations.

### 1.4 Integration Test Planning (Core Workflow)

*   **Objective:** Ensure the main user flow through the `WorkflowModal` functions end-to-end, validating that all core components, including new caching mechanisms, work together.
*   **Key User Flows:**
    *   Full `WorkflowModal` lifecycle (new, resume, complete).
        *   [ ] Plan detailed test scenarios for this flow (Phase 0 Priority). Scenarios should verify data persistence (drafts), state progression, and final output, being as resilient to UI changes as possible by focusing on high-level interactions and results.

## Priority Group 2: Supporting Workflow Components & Interactions

**Rationale:** These tests cover components that are part of the workflow or common interactions. While important for a fully functional and polished user experience, they are often more susceptible to UI changes or address risks that are secondary to the fundamental data/logic integrity covered in Group 1. They become particularly crucial for validating UI changes and deeper caching integrations once the Group 1 foundation is stable.

### 2.1 Other Workflow Step Widget Tests & Core UI Logic

*   **`WorkflowStepIndicator` (`lib/widgets/workflow_steps/workflow_step_indicator.dart`)**
    *   **Objective:** Verify correct rendering based on `currentStep` and `stepTitles`. (Tap logic covered by `_WorkflowModalBodyState` tests in Group 1).
    *   **Test Cases (Completed for rendering - see `test_coverage_completed.md`)**

*   **`SplitViewWidget` (`lib/widgets/split_view.dart`)**
    *   **(⏳ To be tested)** **Objective:** Verify the overall split view renders correctly, including person assignment, item allocation, and summary calculations. This is a potentially complex widget that might be used within `SplitStepWidget` or other places. (Consider its priority based on how much logic it contains vs. `SplitStepWidget` itself).

### 2.2 Dialog Widget Tests

*   **Objective:** Verify dialogs appear, display correct content, buttons can be interacted with, and return expected values on button presses. (Phase 0 Priority for these dialogs). These are key for user interaction consistency, especially during/after UI redesign.
*   **Dialog Helpers (`lib/utils/dialog_helpers.dart`) based Dialogs:**
    *   **Test Cases (`showRestaurantNameDialog`):**
        *   ⏳ Dialog appears when called.
        *   ⏳ Displays title "Restaurant Name".
        *   ⏳ `TextField` is present, accepts input, shows `initialName`.
        *   ⏳ "CANCEL" button returns `null`.
        *   ⏳ "CONFIRM" button returns entered text (or `initialName` if unchanged).
        *   ⏳ Handles empty input on confirm (should it be allowed or show error/disable button?).
    *   **Test Cases (`showConfirmationDialog`):**
        *   ⏳ Dialog appears with given `title` and `content`.
        *   ⏳ "CANCEL" (or negative action) button returns `false`.
        *   ⏳ "CONFIRM" (or positive action) button returns `true`.
*   **Custom Dialog Widgets from `lib/widgets/dialogs/`**
    *   **`AddItemDialog` (`lib/widgets/dialogs/add_item_dialog.dart`)**
        *   ✅ Verify dialog renders with all required elements.
        *   ✅ Verify dialog returns null when canceled.
        *   ✅ Verify quantity controls (increment/decrement) work with proper limits.
        *   ✅ Verify dialog returns ReceiptItem with correct values when valid input is provided.
        *   ✅ Verify validation (shows error for empty name, invalid price, negative price).
    *   **`EditItemDialog` (`lib/widgets/dialogs/edit_item_dialog.dart`)**
        *   **(⏳ To be tested)** **Objective:** Verify pre-fill with existing item data; field updates; and correct data returned on save.

### 2.3 Utility Function Unit Tests (Internal Logic)

*   **`Dialog Helpers` (`lib/utils/dialog_helpers.dart`)**
    *   **Objective:** Verify any internal logic independent of UI rendering (Phase 0 Priority). Widget tests (Section 2.2) cover UI interaction.
    *   **(⏳ To be identified and detailed if complex non-UI logic exists)**

*   **`Toast Utils` (`lib/utils/toast_utils.dart`)**
    *   **Objective:** Verify any complex message formatting or internal logic independent of UI rendering (Phase 0 Priority). Widget tests would cover appearance if needed.
    *   **(⏳ To be identified and detailed if complex non-UI logic exists)**

## Priority Group 3: General UI Components & Broader Application Coverage

These components and areas are important for overall application quality but are either more likely to be significantly changed by a UI redesign or are broader in scope than the immediate needs for caching/core redesign stability.

### 3.1 Reusable UI Components (Used within Workflow and potentially elsewhere)

*   **Objective:** Ensure these reusable components function correctly in isolation. Tests here might need significant rework after UI redesign.
*   **`FullImageViewer` (`lib/widgets/receipt_upload/full_image_viewer.dart`)**
    *   **(⏳ To be tested)** **Objective:** Verify correct display of local or network images, zoom/pan functionalities if any. (Currently indirectly tested via `ReceiptUploadScreen`)
*   **`PersonSummaryCard` (`lib/widgets/final_summary/person_summary_card.dart`)**
    *   **(⏳ To be tested)** **Objective:** Verify correct display of person's name, total amount, and potentially assigned items. (Likely part of `SummaryStepWidget` but consider dedicated tests if complex).
*   **Cards from `lib/widgets/cards/`**
    *   `SharedItemCard` (⏳ To be tested)
    *   `PersonCard` (⏳ To be tested)
    *   `UnassignedItemCard` (⏳ To be tested)
    *   **Objective:** Verify correct rendering based on input data and handling of any interactions.
*   **Shared Utility Widgets from `lib/widgets/shared/`**
    *   `WaveDividerPainter` (⏳ To be tested - verify no paint errors, visual inspection or specific paint call verification).
    *   `QuantitySelector` (⏳ To be tested - verify increment/decrement logic, callbacks, min/max constraints).
    *   `ItemRow` (⏳ To be tested - verify layout, display of item name/price/quantity).
    *   `