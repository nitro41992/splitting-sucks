# Test Coverage Plan for Billfie App

**Note: Completed test items have been moved to [docs/test_coverage_completed.md](docs/test_coverage_completed.md) to keep this document focused on pending and in-progress work.**

This document outlines the strategy and specific areas for implementing unit and widget tests, primarily focusing on the `WorkflowModal` and its associated components, and then expanding to other core areas of the application to improve stability and catch regressions.

**Note on Default Widget Test (`test/widget_test.dart.disabled`):** The default Flutter widget test file (originally `test/widget_test.dart`) has been renamed to `test/widget_test.dart.disabled` to temporarily exclude it from test runs. It was causing failures due to UI setup issues (e.g., missing Directionality) unrelated to the current `WorkflowModal` testing effort. Fixing this default test and implementing broader UI smoke tests for the main application is considered out of scope for the initial focused testing phases (Phase 1 & 2 of this plan) but is a recommended activity for later to ensure overall application UI integrity.

**KT for Product Manager (User):** The primary user of this AI assistant for this project is a technical Product Manager. When discussing test implementation, especially around UI behavior or edge cases, explanations should be clear from a product impact perspective, and questions regarding desired behavior are welcome to ensure tests align with product goals.

## Testing Strategy Overview

We will prioritize:

1.  **Widget Tests** for UI components to ensure they render correctly, respond to interactions, and reflect state changes accurately.
2.  **Unit Tests** for business logic within state management classes (like `WorkflowState`), helper classes (`ImageStateManager`), models, and utility functions.

Integration tests and tests requiring Firebase emulators (for services and cloud functions) will be considered as subsequent phases.

## Phase 1: `WorkflowModal` and Core UI Components

**KT for AI Devs:** The initial focus is on `WorkflowModal` due to its complexity and recent refactoring efforts. Tests should cover both the individual extracted step widgets and the core state management. Mocking (e.g., using `mockito`) will be essential for isolating components and their dependencies. When mock definitions in `test/mocks.dart` are updated, the AI assistant should propose running the `dart run build_runner build --delete-conflicting-outputs` command (previously `flutter pub run ...`); the user will then approve its execution in their environment. To run tests, use the command line (`flutter test` for all tests, or `flutter test path/to/specific_test_file.dart` for a single file) or the IDE's built-in test runner.

### 1.1 Unit Tests (for Workflow-related Utilities)

*   **`Dialog Helpers` (`lib/utils/dialog_helpers.dart`)**
    *   **Objective:** While dialogs are UI, any internal logic could be unit tested. However, widget tests are generally more suitable here to verify appearance and interaction. Focus on non-UI logic if any exists.
    *   **(⏳ Primarily Widget Tested - See section 1.5 for Dialog Widget Tests)**

*   **`Toast Utils` (`lib/utils/toast_utils.dart`)**
    *   **Objective:** Similar to dialogs, the core is UI. Test any complex message formatting or logic if present.
    *   **(⏳ Primarily Widget Tested for appearance, unit test any internal logic if complex)**

### 1.2 Workflow Step Widget Tests

*   **`WorkflowStepIndicator` (`lib/widgets/workflow_steps/workflow_step_indicator.dart`)**
    *   **Objective:** Verify correct rendering based on `currentStep` and `stepTitles`, and that taps are handled.
    *   **Test Cases (Pending):**
        *   ⏳ Tapping a step indicator (Handled in `_WorkflowModalBodyState` tests, as indicator has no direct tap callback).

*   **`ParseStepWidget` (`lib/widgets/workflow_steps/parse_step_widget.dart`)**
    *   ⏳ **Objective:** Verify display of parsed data (items, prices), handling of transcription data, and interactions if any (e.g., editing items - though this might be out of scope for the widget itself if it only displays).
    *   **(⏳ To be detailed)**

*   **`AssignPeopleScreen` / `AssignStepWidget` (`lib/widgets/workflow_steps/assign_step_widget.dart` or `lib/screens/assign_people_screen.dart`)**
    *   **Covered By:** `test/screens/assign_people_screen_test.dart` (To be created)
    *   **Objective:** Verify the UI for assigning people to items, managing shared items, adding/removing people, and ensuring correct data propagation for the next step.
    *   **Setup:**
        *   Mock `WorkflowState` to provide items, people, and manage assignments.
        *   Provide callbacks: `onAssignmentsUpdated` (or similar, to reflect changes to `WorkflowState`).
        *   Use `FakeReceiptItem` and `FakePerson` data.
    *   **Test Cases:**
        *   [ ] **Initial Display:**
            *   [ ] Displays a list of `ReceiptItemCard`s (or similar widgets representing items).
            *   [ ] Displays controls for adding/managing people.
            *   [ ] Displays a section for "Shared Items" if applicable.
            *   [ ] "Next" or "Confirm Assignments" button state (enabled/disabled based on whether all items are assigned).
        *   [ ] **Adding a Person:**
            *   [ ] Tapping "Add Person" (or equivalent) opens a dialog or input field.
            *   [ ] Successfully adding a person updates the list of available people.
            *   [ ] `WorkflowState` is updated with the new person.
        *   [ ] **Assigning an Item to a Person:**
            *   [ ] Interacting with an item (e.g., drag-and-drop, tap to select person from a menu) assigns it to a specific person.
            *   [ ] UI reflects the assignment (e.g., item moves under person's section, person's avatar shown on item).
            *   [ ] `WorkflowState` is updated with the assignment.
        *   [ ] **Unassigning an Item:**
            *   [ ] UI allows unassigning an item from a person.
            *   [ ] Item returns to an "unassigned" state or pool.
            *   [ ] `WorkflowState` is updated.
        *   [ ] **Marking an Item as Shared:**
            *   [ ] UI allows an item to be marked as "shared".
            *   [ ] Item moves to a "Shared Items" section.
            *   [ ] UI allows selecting which people share the item.
            *   [ ] `WorkflowState` is updated.
        *   [ ] **Item Interactions (within `ReceiptItemCard` or similar):**
            *   [ ] Tapping an item might show options (assign to person, mark as shared, etc.).
            *   [ ] Quantity adjustments (if applicable at this stage) are reflected.
        *   [ ] **"Next" / "Confirm Assignments" Button Logic:**
            *   [ ] Button is disabled if there are unassigned items (that are not marked as shared implicitly or explicitly).
            *   [ ] Button is enabled when all items are accounted for (assigned to individuals or shared).
            *   [ ] Tapping the button triggers the appropriate callback (e.g., `workflowState.nextStep()` or `onAssignmentsConfirmed`).
    *   **KT for Devs:**
        *   Consider how to represent "unassigned" vs. "assigned" vs. "shared" states clearly in the UI and in tests.
        *   Interactions like drag-and-drop can be complex to test; consider `tester.drag()` and ensure target finders are robust.
        *   This screen likely interacts heavily with `WorkflowState` for both reading item/people data and writing back assignment data.

*   **`SplitStepWidget` (`lib/widgets/workflow_steps/split_step_widget.dart`)**
    *   ⏳ **Objective:** Verify UI for displaying split amounts per person, handling adjustments (e.g. tip/tax per person if applicable), and confirming the split.
    *   **(⏳ To be detailed)**

*   **`SummaryStepWidget` (`lib/widgets/workflow_steps/summary_step_widget.dart`)**
    *   ⏳ **Objective:** Verify final summary display, including individual totals, grand total, and any payment-related information or actions.
    *   **(⏳ To be detailed)**

### 1.3 Other Core WorkflowModal Widget Tests

*   **`SplitViewWidget` (`lib/widgets/split_view.dart`)**
    *   **(⏳ To be tested)** **Objective:** Verify the overall split view renders correctly, including person assignment, item allocation, and summary calculations. This is a potentially complex widget that might be used within `SplitStepWidget` or other places.

*   **`_WorkflowModalBodyState` (selected parts, `lib/widgets/workflow_modal.dart`)**
    *   **Objective:** Test critical UI interaction logic that remains in `_WorkflowModalBodyState`, such as the `GestureDetector` for the step indicator and `WillPopScope` logic.
    *   **Test Cases:**
        *   ⏳ `Step Indicator Tap Logic`:
            *   Tapping a previous step calls `workflowState.goToStep()` with the correct `tappedStep`.
            *   Tapping a future step (that's allowed by data prerequisites) calls `workflowState.goToStep()`.
            *   Tapping a future step (blocked by data prerequisites) shows a `showAppToast` and does NOT call `goToStep()`.
        *   ⏳ `_onWillPop` behavior (this is harder to test purely as a widget test due to navigation, but can test parts):
            *   If no data, returns true.
            *   If data exists, verify `_saveDraft` is called (mocked).
            *   If `_saveDraft` (mocked) throws, verify `showConfirmationDialog` is called.

### 1.4 Reusable UI Components (Used within Workflow and potentially elsewhere)

*   **Objective:** Ensure these reusable components function correctly in isolation.

*   **`FullImageViewer` (`lib/widgets/receipt_upload/full_image_viewer.dart`)**
    *   **(⏳ To be tested)** **Objective:** Verify correct display of local or network images, zoom/pan functionalities if any. (Currently indirectly tested via `ReceiptUploadScreen`)

*   **`PersonSummaryCard` (`lib/widgets/final_summary/person_summary_card.dart`)**
    *   **(⏳ To be tested)** **Objective:** Verify correct display of person's name, total amount, and potentially assigned items. (Likely part of `SummaryStepWidget` but consider dedicated tests if complex).

*   **Cards from `lib/widgets/cards/`**
    *   `SharedItemCard` (⏳ To be tested)
    *   `PersonCard` (⏳ To be tested)
    *   `UnassignedItemCard` (⏳ To be tested)
    *   **Objective:** Verify correct rendering based on input data and handling of any interactions. (May be covered by parent step widgets like `AssignStepWidget` or `SplitStepWidget`, but consider dedicated tests if complex or highly reusable).

*   **Shared Utility Widgets from `lib/widgets/shared/`**
    *   `WaveDividerPainter` (⏳ To be tested - verify no paint errors, visual inspection or specific paint call verification).
    *   `QuantitySelector` (⏳ To be tested - verify increment/decrement logic, callbacks, min/max constraints).
    *   `ItemRow` (⏳ To be tested - verify layout, display of item name/price/quantity).
    *   `EditableText` (⏳ To be tested - verify edit mode, view mode, callbacks on change).
    *   `EditablePrice` (⏳ To be tested - verify currency formatting, edit mode, callbacks).
    *   **Objective:** Ensure these common UI elements are robust and behave as expected.

### 1.5 Dialog Widget Tests (Used within Workflow and potentially elsewhere)

*   **Objective:** Verify dialogs appear, display correct content, and return expected values on button presses.

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
        *   **(⏳ To be tested)** **Objective:** Verify fields for item name, price, quantity; validation; and correct data returned on save.
    *   **`EditItemDialog` (`lib/widgets/dialogs/edit_item_dialog.dart`)**
        *   **(⏳ To be tested)** **Objective:** Verify pre-fill with existing item data; field updates; and correct data returned on save.

### 1.6 Test Structure and Setup

*   Tests will reside in the `test/` directory, mirroring the `lib/` structure.
*   `flutter_test` will be the primary testing framework.
*   `mockito` will be used for creating mock objects for dependencies.
    *   Generate mocks using `build_runner build`.
*   Each test file will use `setUp()` for common test arrangements and `tearDown()` for cleanup if necessary.
*   `group()` will be used to organize related tests.

---

## Phase 2: Expanding Application Core Coverage

**Objective:** Extend test coverage to other critical screens, data models, and application setup logic.

### 2.1 Models (`lib/models/`)

*   **Objective:** Ensure data models are robust, handle serialization/deserialization correctly, and any internal logic is sound.
*   **Classes to Test:**
    *   **`Receipt` (`lib/models/receipt.dart`)**
        *   **Unit Test Cases:**
            *   ⏳ `fromDocumentSnapshot()` / `fromJson()`: Correctly parses Firestore data (including all fields, nested objects, and handling of nulls/defaults).
            *   ⏳ `toMap()` / `toJson()`: Correctly serializes data for Firestore (including all fields).
            *   ⏳ Computed properties (e.g., `formattedDate`, `formattedAmount`, `isDraft`, `isCompleted`, `numberOfPeople`): Verify correct calculations/logic.
            *   ⏳ `copyWith()` method if implemented.
    *   **`ReceiptItem` (`lib/models/receipt_item.dart`)**
        *   **Unit Test Cases:**
            *   ⏳ `fromJson()` / `toMap()` (or equivalent for parsing/serialization).
            *   ⏳ Constructor logic and field initialization.
            *   ⏳ Any helper methods.
    *   **`Person` (`lib/models/person.dart`)**
        *   **Unit Test Cases:**
            *   ⏳ `fromJson()` / `toMap()` (or equivalent).
            *   ⏳ Constructor logic.
    *   **`SplitManager` (`lib/models/split_manager.dart`)**
        *   **Unit Test Cases:** This class is critical for calculations.
            *   ⏳ Initialization with various inputs (items, people, shared items, tip, tax).
            *   ⏳ `addPerson()`, `removePerson()`.
            *   ⏳ `assignItemToPerson()`, `unassignItemFromPerson()`.
            *   ⏳ `addSharedItem()`, `updateSharedItemAssignments()`.
            *   ⏳ Tip and tax calculation and application (percentage, fixed, per person if applicable).
            *   ⏳ `calculateTotals()`: Verification of individual totals, grand total, subtotal.
            *   ⏳ Edge cases: No items, no people, zero tip/tax, etc.

### 2.2 Screens (`lib/screens/`)

*   **`ReceiptsScreen` (`lib/screens/receipts_screen.dart`)**
    *   **Objective:** Verify UI rendering, list display, interactions, and basic navigation triggers.
    *   **Widget Test Cases:**
        *   ⏳ Initial state: Displays loading indicator or empty state correctly.
        *   ⏳ Stream data handling: Renders list of `ReceiptCard` widgets when data arrives from mocked stream.
        *   ⏳ Error state: Displays error message if stream provides error.
        *   ⏳ Empty state: Displays "No receipts yet" message correctly.
        *   ⏳ Search functionality: (May need `_ReceiptSearchDelegate` specific tests or mock interactions)
            *   Filtering receipts based on search query.
            *   Displaying "No results found".
        *   ⏳ `FloatingActionButton`: Tapping it attempts to show `WorkflowModal` (mock the `WorkflowModal.show()` static method or verify `Navigator.push` with correct route).
        *   ⏳ `ReceiptCard` tap: Triggers `_viewReceiptDetails` (verify bottom sheet appears with correct receipt data).
        *   ⏳ `_viewReceiptDetails` bottom sheet:
            *   Displays receipt details correctly.
            *   "Resume Draft" button: visible for drafts, triggers `WorkflowModal.show()` with `receiptId` (mocked).
            *   "Edit Receipt" button: visible for completed, triggers `WorkflowModal.show()` with `receiptId` (mocked).
            *   "Delete Receipt" button: Triggers `_confirmDeleteReceipt` (verify confirmation dialog appears).
        *   ⏳ `_confirmDeleteReceipt` dialog:
            *   Appears correctly.
            *   "CANCEL" dismisses.
            *   "DELETE" calls `FirestoreService.deleteReceipt` and image deletion methods (mocked service calls).
    *   **Mocks:** `FirestoreService`, `WorkflowModal.show` (potentially using `TestWidgetsFlutterBinding.instance.registerService` for static method mocking if complex, or refactoring to make it instance-based for easier mocking).

*   **Other Screens (e.g., `SettingsScreen`, any future screens)**
    *   **Objective:** Basic UI rendering and interaction tests.
    *   **Widget Test Cases:** (⏳ To be detailed as screens are developed/reviewed)
        *   Verify screen title and key UI elements are present.
        *   Test navigation triggers or actions (e.g., logout button in `SettingsScreen`).

### 2.3 Application Setup and Main (`lib/main.dart`)

*   **Objective:** Verify initial app setup, provider configuration, and root-level navigation based on auth state.
*   **Widget Test Cases:**
    *   ⏳ `MyApp` widget:
        *   Initializes `MaterialApp` with correct theme and routes (if using named routes).
        *   Sets up root providers correctly (e.g., `AuthService` provider).
    *   ⏳ Auth state changes:
        *   If user is authenticated (mock `AuthService.authStateChanges` to emit a user), verify `MainNavigation` (or equivalent home screen) is shown.
        *   If user is not authenticated (mock stream to emit null), verify `LoginScreen` (or equivalent) is shown.
    *   **Mocks:** `AuthService`, `Firebase.initializeApp` (may need to mock platform channels if directly calling).

## Phase 3: Services & Integration Tests (Future - Requires Emulators/Advanced Mocking) ⏳

*   **Services (`lib/services/`)**
    *   `FirestoreService`
    *   `ReceiptParserService`
    *   `AudioTranscriptionService`
    *   `AuthService`
*   **Integration Tests for Key User Flows**
    *   Full `WorkflowModal` lifecycle (new, resume, complete).
    *   Login/Logout flows.
*   **Firebase Functions Testing (using Emulator Suite)**

---

This is a starting point. We can refine and add more details as we begin implementing the tests.

*   **Key Takeaways & Best Practices for Testing:**
    *   **Use `ValueKey`s for Widget Tests:** For critical UI elements like buttons or input fields that need to be found in widget tests, assign a `ValueKey` in the widget's implementation (e.g., `TextButton(key: const ValueKey('my_button'), ...)`). In tests, use `find.byKey(const ValueKey('my_button'))`. This makes tests far more resilient to changes in widget tree structure or styling compared to `find.text()`, `find.byIcon()`, or complex `find.ancestor()` chains.
    *   **Isolate Unit Tests with Mocks:** When unit testing state management classes (like `WorkflowState`), inject mock dependencies (like `MockImageStateManager`) to ensure tests are focused and not affected by the internal logic of other classes.
    *   **Test `notifyListeners()` Behavior:** For classes extending `ChangeNotifier`, explicitly test that `notifyListeners()` is called when expected, and *not* called when state changes do not warrant a notification. Use a boolean flag and a listener in your test setup for this.
    *   **Verify All Paths in Conditional Logic:** Ensure tests cover all branches of `if/else` statements or `switch` cases, especially for logic that enables/disables UI elements or alters data flow.
    *   **Use `pumpAndSettle()` is Your Friend:** After triggering actions in widget tests that might involve animations or multiple frames to resolve (like `tester.tap()`, or state changes that rebuild UI), use `await tester.pumpAndSettle()` to ensure the UI has reached a stable state before making assertions. Use `await tester.pump()` for single frame advances if needed, but `pumpAndSettle()` is often more reliable for complex interactions. **Exception:** See KT for Devs under `ReceiptUploadScreen` for scenarios involving `HttpOverrides` and dialogs where `pump()` with a duration might be necessary.

### Key Unresolved Issues & KT for Next Dev

*   **Build Runner for Mocks:**
    *   **Reminder:** If any mock definitions (e.g., in `test/mocks.dart` or other files using `@GenerateMocks`) are updated, remember to run `dart run build_runner build --delete-conflicting-outputs` to regenerate the mock implementation files.
