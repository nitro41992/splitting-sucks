# Test Coverage Plan for Billfie App

**Note: Completed test items are moved to [docs/test_coverage_completed.md](test_coverage_completed.md) to maintain this document as a focused task list.**

## Test Status Overview

### Completed ✅
- **Python Cloud Functions:** All tests for `generate_thumbnail`, `parse_receipt`, `assign_people_to_items`, and `transcribe_audio` functions
- **Model Unit Tests:** All tests for `Receipt`, `ReceiptItem`, `Person`, and `SplitManager` models
- **Dialog Widget Tests:** Tests for `AddItemDialog`
- **Widget Tests:** `WorkflowStepIndicator`, `UploadStepWidget`/`ReceiptUploadScreen`, `ReceiptReviewScreen`/`ReviewStepWidget`, `WorkflowNavigationControls`
- **Provider Tests:** `WorkflowState` and `ImageStateManager`
- **Shared Utility Widgets:** `QuantitySelector`
- **Flutter Services:** Tests for `FirestoreService` methods including receipt CRUD operations (saveReceipt, saveDraft, completeReceipt, getReceiptsStream, getReceipts, getReceipt, deleteReceipt)

### High Priority Pending ⏳
- **Flutter Services:** Tests for `FirestoreService.uploadReceiptImage` method and any remaining storage methods
- **Core Workflow Logic:** Tests for workflow steps, assignment logic, and split calculations
- **Dialog Widget Tests:** Tests for `EditItemDialog`, `showRestaurantNameDialog`, and `showConfirmationDialog`

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
        *   `Future<String> saveReceipt({String? receiptId, required Map<String, dynamic> data})`
            *   (✅) Test new receipt creation (`receiptId` is null, `add()` called, `created_at`/`updated_at` set).
            *   (✅) Test existing receipt update (`receiptId` provided, doc exists, `set()` with merge called, `updated_at` set, `created_at` preserved).
            *   (✅) Test new receipt creation with client-provided ID (`receiptId` provided, doc doesn't exist, `set()` called, `created_at`/`updated_at` set).
            *   (✅) Test correct Firestore path and data mapping.
        *   `Future<String> saveDraft({String? receiptId, required Map<String, dynamic> data})`
            *   (✅) Verify `data['metadata']['status']` is set to 'draft'.
            *   (✅) Verify it calls `saveReceipt` with correct parameters (mock `saveReceipt` or test integrated behavior carefully).
        *   `Future<String> completeReceipt({required String receiptId, required Map<String, dynamic> data})`
            *   (✅) Verify `data['metadata']['status']` is set to 'completed'.
            *   (✅) Verify `data['metadata']['updated_at']` is set.
            *   (✅) Verify `_receiptsCollection.doc(receiptId).update(data)` is called with correct path and data.
        *   `Stream<QuerySnapshot> getReceiptsStream()`
            *   (✅) Verify correct query construction (`orderBy`).
            *   (✅) Mock `snapshots()` stream and verify service passes it through.
        *   `Future<QuerySnapshot> getReceipts({String? status})`
            *   (✅) Test query with no status filter.
            *   (✅) Test query with status filter.
            *   (✅) Mock `get()` call and verify result.
        *   `Future<DocumentSnapshot> getReceipt(String receiptId)`
            *   (✅) Verify correct document path.
            *   (✅) Mock `get()` call for existing doc and verify result.
            *   (✅) Test for non-existent document (e.g., mock `snapshot.exists` as false).
        *   `Future<void> deleteReceipt(String receiptId)`
            *   (✅) Verify `delete()` is called on the correct document reference.
        *   `Future<String> uploadReceiptImage(File imageFile)` (Interacts with Firebase Storage)
            *   (⏳) Mock `FirebaseStorage`, `Reference`, `UploadTask`, `TaskSnapshot`.
            *   (⏳) Verify correct GCS path generation (includes user ID, timestamp).
            *   (⏳) Verify `putFile()` is called with correct `File` and `SettableMetadata`.
            *   (⏳) Verify correct `gs://` URI is constructed and returned from mocked `TaskSnapshot`.
        *   **(Consider if `_userId` getter needs specific tests, especially around emulator/prod logic if complex, though it's more internal state management).**
    *   **Placeholder for other Flutter Services with external dependencies that will need testing:**
        *   (⏳) Identify and test any other services that will be affected by caching implementation.

### 1.2 Core Workflow Logic & Data Flow Widget Tests

*   **`WorkflowModalBody` / `_WorkflowModalBodyState` (`lib/widgets/workflow_modal.dart`)**
    *   **Objective:** Test critical UI interaction paths and state transitions that need to remain intact during redesign.
    *   **Test Cases:**
        *   ⏳ **Step Indicator Tap Logic:** 
            *   Tapping a previous step calls `workflowState.goToStep()` with the correct `tappedStep`.
            *   Tapping a future step (allowed by data) calls `workflowState.goToStep()`.
            *   Tapping a future step (blocked by data prerequisites) shows a toast and does NOT call `goToStep()`.
        *   ⏳ **`_onWillPop` behavior:** 
            *   With no data: Returns true (allows navigation)
            *   With data: Calls `_saveDraft` (verify mock called)
            *   With `_saveDraft` error: Shows confirmation dialog

*   **`AssignPeopleScreen` / `AssignStepWidget` (`lib/widgets/workflow_steps/assign_step_widget.dart`)**
    *   **Objective:** Verify the critical UI for assigning people to items, focusing on data flow that must be preserved.
    *   **Test Cases:**
        *   ⏳ **Initial Display:** Verify correct rendering of items, people, and assignment UI from `WorkflowState`.
        *   ⏳ **Person Management:** Test adding, removing, renaming people with correct `WorkflowState` updates.
        *   ⏳ **Item Assignment:** Test assigning and unassigning items to people, shared item marking.
        *   ⏳ **Button Logic:** Verify Next/Confirm is conditionally enabled based on assignments.

*   **`SplitStepWidget` (`lib/widgets/workflow_steps/split_step_widget.dart`)**
    *   **Objective:** Verify UI for displaying split amounts and handling adjustments (critical for caching/redesign).
    *   **Test Cases:**
        *   ⏳ **Initial Display:** Verify correct loading of people, items, and amounts from `WorkflowState`.
        *   ⏳ **Tip/Tax Entry:** Test entry of tip and tax amounts with proper `WorkflowState` updates.
        *   ⏳ **Split Calculations:** Verify correct calculation and display of individual and total amounts.
        *   ⏳ **Button Logic:** Verify Next/Confirm is properly enabled/disabled.

*   **`SummaryStepWidget` (`