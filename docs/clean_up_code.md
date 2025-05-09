# Code Cleanup and Refactoring Plan

This document outlines a plan to address technical debt, remove redundant code, and refactor the application for improved maintainability, readability, and adherence to Flutter best practices. It also serves as a task list.

## Task Status

### To Do

#### Phase 1: Refactoring `lib/widgets/workflow_modal.dart`

`workflow_modal.dart` is a critical component of the redesigned receipt processing workflow. Refactoring it will provide significant benefits and insights for the rest of the application.

##### 1.1. State Management (`WorkflowState`) ✅

*   **Review and Simplify:** ✅
    *   **Objective:** Ensure `WorkflowState` is as lean and focused as possible.
    *   **Actions:**
        *   `Evaluate each field and method for necessity and clarity.` - ✅ Fields and methods reviewed; core logic deemed necessary and clear.
        *   `Consider if any complex logic within setters/notifiers can be simplified or made more declarative.` - ✅ Setters are generally declarative. Data inter-dependencies are handled by specific clearing methods invoked by the UI, which maintains a good separation of concerns.
        *   `Examine the image URI management (...)`
            *   **Consideration:** `Could this be encapsulated into a dedicated helper class or service (e.g., ImageWorkflowManager) (...)` - ✅ Confirmed that `ImageStateManager` (`lib/widgets/image_state_manager.dart`) already fulfills this role and is integrated with `WorkflowState`. Linter errors related to its integration were resolved.
            *   **KT for future AI Devs:** Image URI state (local file, GS URIs, loaded URLs, pending deletions) is managed by `ImageStateManager`. `WorkflowState` delegates to it via methods like `setUploadedGsUris`, `setLoadedImageUrls`, `setActualGsUrisOnLoad`, and getters like `actualImageGsUri`.
        *   `Analyze data clearing logic (e.g., clearParseAndSubsequentData, clearTranscriptionAndSubsequentData). Ensure (...) robust (...) preserving tip/tax correctly).` - ✅ `clearTranscriptionAndSubsequentData` was enhanced to also clear assignments, people, tip, and tax, making it more robust. The related UI confirmation messages were updated.
        *   `Assess the boolean flags for data presence (hasParseData, hasTranscriptionData, hasAssignmentData). Ensure their logic is sound and they are used consistently.` - ✅ Flags reviewed and confirmed to be logically sound and consistently used for UI flow control.
*   **Encapsulation:** ✅
    *   **Objective:** Improve encapsulation of state modification logic.
    *   **Actions:**
        *   `Ensure that all state modifications happen through well-defined methods in WorkflowState rather than direct manipulation from the UI layer where possible.` - ✅ Verified this is generally true. The `_people` list management was further refined: it is now consistently derived from `_assignPeopleToItemsResult` within `WorkflowState`, and the direct `setPeople()` method has been removed.
        *   **KT for future AI Devs:** The `_people` list in `WorkflowState` is populated when `setAssignPeopleToItemsResult` is called (which internally uses `_extractPeopleFromAssignments`). Direct setting of `_people` (e.g., from `SplitManager` or draft loading) has been refactored to go through this path.

##### 1.2. Widget Structure (`_WorkflowModalBodyState` and Helper Methods) ✅

*   **Decomposition of `_buildStepContent`:** ✅
    *   **Objective:** Improve readability, maintainability, and testability of step-specific UI.
    *   **Actions:**
        *   `Break down the switch statement in _buildStepContent. Each case (Upload, Review, Assign, Split, Summary) should ideally become its own StatelessWidget or StatefulWidget.`
            *   **Upload Step (case 0):** ✅
                *   Callback logic extracted into `_WorkflowModalBodyState._handleImageSelectedForUploadStep`, `_handleParseReceiptForUploadStep`, `_handleRetryForUploadStep`.
                *   New widget `lib/widgets/workflow_steps/upload_step_widget.dart` created.
                *   `_buildStepContent` case 0 now uses `UploadStepWidget`.
            *   **Review Step (case 1):** ✅
                *   Callback logic extracted into `_WorkflowModalBodyState._handleReviewCompleteForReviewStep`, `_handleItemsUpdatedForReviewStep`, `_handleRegisterCurrentItemsGetterForReviewStep`.
                *   New widget `lib/widgets/workflow_steps/review_step_widget.dart` created.
                *   `_buildStepContent` case 1 now uses `ReviewStepWidget`.
            *   **Assign Step (case 2):** ✅
                *   Callback logic extracted into `_WorkflowModalBodyState._handleAssignmentProcessedForAssignStep`, `_handleTranscriptionChangedForAssignStep`, `_handleReTranscribeRequestedForAssignStep`, `_handleConfirmProcessAssignmentsForAssignStep`.
                *   New widget `lib/widgets/workflow_steps/assign_step_widget.dart` created.
                *   `_buildStepContent` case 2 now uses `AssignStepWidget`.
            *   **Split Step (case 3):** ✅
                *   Callback logic extracted into `_WorkflowModalBodyState._handleTipChangedForSplitStep`, `_handleTaxChangedForSplitStep`, `_handleAssignmentsUpdatedBySplitStep`, `_handleNavigateToPageForSplitStep`.
                *   New widget `lib/widgets/workflow_steps/split_step_widget.dart` created.
                *   `_buildStepContent` case 3 now uses `SplitStepWidget`.
            *   **Summary Step (case 4):** ✅
                *   New widget `lib/widgets/workflow_steps/summary_step_widget.dart` created.
                *   `_buildStepContent` case 4 now uses `SummaryStepWidget`.
        *   `These new step widgets would take necessary data from WorkflowState (via Provider.of or Consumer) and relevant callbacks as parameters.` - ✅ Implemented for Upload, Review, Assign, Split and Summary steps. Data is passed via constructor from `Consumer<WorkflowState>` in `_buildStepContent`.
        *   `Example: ReceiptUploadStepWidget, ReceiptReviewStepWidget, etc.` - ✅ (using names like `UploadStepWidget`).
*   **Callback and Event Handling:** ✅
    *   **Objective:** Clarify event handling and reduce complexity in `_WorkflowModalBodyState`.
    *   **Actions:**
        *   `Review long callback functions passed to step screens (e.g., onImageSelected, onParseReceipt in ReceiptUploadScreen setup).` - ✅ Done for Upload, Review, Assign, and Split steps. (Summary step has no callbacks to `_WorkflowModalBodyState` currently).
        *   `If these callbacks contain significant logic, consider extracting that logic into private methods within _WorkflowModalBodyState.` - ✅ Implemented for Upload, Review, Assign, and Split steps.
        *   `For very complex interactions, a small, dedicated controller or helper class for certain actions might be considered, though this should be weighed against over-engineering.` - 📝 To be evaluated as we proceed.
*   **Review Core Logic Methods:** 📝
    *   **Objective:** Ensure methods like `_loadReceiptData`, `_saveDraft`, `_completeReceipt`, and `_onWillPop` have clear responsibilities and are not overly complex.
    *   **Actions:**
        *   `_loadReceiptData`: 📝 Verify its flow, error handling, and how it determines the target step.
        *   `_saveDraft` & `_completeReceipt`: 📝 Check for clarity, robust error handling, and clean interaction with `WorkflowState` and `FirestoreService`. Ensure the sequence of operations (e.g., UI updates, async calls, state changes) is logical and safe (e.g., using `mounted` checks appropriately).
        *   `_processPendingDeletions`: 📝 Ensure this logic is robust and correctly handles all scenarios for image cleanup.
*   **Use of `Consumer` vs. `Provider.of`:** 🏗️
    *   **Objective:** Optimize widget rebuilds.
    *   **Actions:**
        *   Ensure `Consumer` widgets are used appropriately to rebuild only the necessary parts of the UI when `WorkflowState` changes. 🏗️
        *   Verify that `Provider.of(context, listen: false)` is used in callbacks and `initState` where only method calls on the notifier are needed, not reactive updates. 🏗️
*   **Placeholders and Loading States:** 🏗️
    *   **Objective:** Consistent and clear user feedback.
    *   **Actions:**
        *   Review `_buildPlaceholder` and general loading indicators. Ensure they are used consistently when data is missing or operations are in progress. 🏗️

##### 1.3. Dialogs and Navigation 🏗️

*   **Standardize Dialogs:** 📝
    *   **Objective:** Consistent look, feel, and behavior for dialogs.
    *   **Actions:**
        *   `Extract showRestaurantNameDialog and _WorkflowModalBodyState._showConfirmationDialog into a common dialog utility file (e.g., lib/utils/dialog_helpers.dart).` 📝
        *   `Ensure they follow Material Design guidelines.` 📝
*   **Navigation Logic:** 🏗️
    *   **Objective:** Clear, predictable, and robust navigation within the modal.
    *   **Actions:**
        *   `Review the logic for the step indicator taps, "Next," "Back," and "Exit" buttons.` 🏗️
        *   `Ensure that conditions for enabling/disabling navigation (e.g., isNextEnabled logic) are comprehensive and clearly tied to the WorkflowState (e.g., hasParseData).` 🏗️
        *   `The WillPopScope and _onWillPop logic should be robust for saving drafts automatically.` 🏗️
        *   `Extract _WorkflowModalBodyState._buildStepIndicator into its own reusable widget (e.g., WorkflowStepIndicator) and move to a new file.` 📝
        *   `Extract _WorkflowModalBodyState._buildNavigation into its own reusable widget (e.g., WorkflowNavigationControls) and move to a new file.` 📝

##### 1.4. Service Interactions 🏗️

*   **Clear Boundaries:** 🏗️
    *   **Objective:** Maintain a clean separation of concerns between UI logic and service logic.
    *   **Actions:**
        *   Ensure `WorkflowModal` delegates persistence and complex business logic (like image uploading, parsing) to `FirestoreService`, `ReceiptParserService`, etc. 🏗️
        *   The modal should primarily be responsible for orchestrating the workflow and managing UI-related state. 🏗️
*   **Orchestration Logic within `_WorkflowModalBodyState`:** 📝
    *   **Objective:** Simplify `_WorkflowModalBodyState` by delegating complex process logic.
    *   **Actions:**
        *   `For complex methods in _WorkflowModalBodyState (e.g., _loadReceiptData, _saveDraft, _completeReceipt, _processPendingDeletions), evaluate extracting this orchestration logic into a dedicated non-widget helper class or service (e.g., WorkflowOrchestrator) to simplify _WorkflowModalBodyState.` 📝

##### 1.5. Code Comments, Readability, and Error Handling 🏗️

*   **Code Clarity:** 🏗️
    *   **Objective:** Make the code easier to understand and maintain.
    *   **Actions:**
        *   `Move WorkflowState ChangeNotifier into its own file (e.g., lib/providers/workflow_state.dart) to improve separation of concerns.` 📝
        *   `Extract pure utility functions like _convertToReceiptItems from _WorkflowModalBodyState into appropriate utility files (e.g., lib/utils/receipt_utils.dart).` 📝
        *   `Extract generic UI building helpers like _buildPlaceholder into shared widget files (e.g., lib/widgets/shared/placeholder_widget.dart).` 📝
        *   Remove obvious comments (e.g., `// Getter for people`). 🏗️
        *   Add comments to explain non-trivial logic, complex conditions, or important decisions. 🏗️
        *   Ensure consistent naming conventions for variables, methods, and classes. 🏗️
        *   `Continue to break down overly long methods if it improves readability or identify candidates for extraction into helper classes/services.` 🏗️
*   **Error Handling & User Feedback:** 🏗️
    *   **Objective:** Provide clear, actionable feedback to the user for any errors.
    *   **Actions:**
        *   Review all `try-catch` blocks. Ensure errors are caught appropriately and meaningful messages are shown to the user (e.g., via `SnackBar` or updates to `_errorMessage` in `WorkflowState`). 🏗️
        *   Verify that loading states in `WorkflowState` are correctly set and unset around asynchronous operations. 🏗️
*   **Standardize User Notifications (SnackBars/Toasts):** 📝
    *   **Objective:** Ensure consistent style, positioning, and color-coding for transient notifications.
    *   **Actions:**
        *   `Review all usages of ScaffoldMessenger.showSnackBar (or other toast mechanisms).` 📝
        *   `Create a centralized ToastHelper (or similar utility) to display notifications.` 📝
        *   `Ensure toasts appear at the top of the screen (or chosen consistent position).` 📝
        *   `Implement consistent color scheme: green for success, gold/yellow for warnings, red for errors.` 📝
        *   `Refactor existing code to use the new ToastHelper.` 📝

##### 1.6. Specific Areas of Attention from `implementation_plan.md` 🏗️

*   **Image URI Handling:** The notes on "Detailed URI logging has been added to the client" suggest this was a complex area. Double-check the logic for `_actualImageGsUri`, `_actualThumbnailGsUri`, `_loadedImageUrl`, `_loadedThumbnailUrl`, and the pending deletion list in `WorkflowState` for robustness and clarity. 🏗️
*   **Blurry Thumbnail / Full Image Load:** While debugging prints were added, ensure the refactored image handling logic in `ReceiptUploadScreen` (once broken out) and `WorkflowState` clearly manages the transition from thumbnail to full image, especially on draft resume and navigation. 🏗️
*   **Context Safety (`mounted` checks):** Continue to ensure `mounted` checks are used correctly, especially around `async` operations that interact with `BuildContext` or `setState`. 🏗️

##### 1.7. Application Stability and Resilience 🏗️

*   **Objective:** Enhance the application's robustness against unexpected interruptions, network instability, and lifecycle changes.
*   **Actions:**
    *   **Safe Navigator Usage:** 🏗️
        *   `Ensure Navigator.pop() calls are conditional on the success of preceding asynchronous operations when appropriate (e.g., after saving a draft).` ✅ (Partially addressed for "Save Draft" button in `workflow_modal.dart`)
        *   `Investigate and implement mechanisms (e.g., an _isPopping flag or similar state management) to prevent re-entrant or conflicting calls to Navigator.pop(), especially after lifecycle events (app pause/resume) or network recovery.` 📝
        *   `Review all asynchronous operations that might lead to navigation changes or UI updates (like showing SnackBars) to ensure they handle mounted checks correctly and manage context safely, particularly in error paths.` 📝
    *   **Lifecycle Event Handling:** 🏗️
        *   `Review didChangeAppLifecycleState and other lifecycle-dependent logic (e.g., _onWillPop) to ensure they gracefully handle scenarios like network loss during background operations (e.g., draft saving).` 📝
        *   `Minimize complex operations directly within lifecycle methods; delegate to services or orchestrators that can manage their own state and error handling robustly.` 📝
    *   **Network Error Handling:** 🏗️
        *   `Globally review how network errors (especially from Firestore, Storage, Cloud Functions) are caught and presented to the user. Ensure they don't lead to inconsistent states or crashes.` 📝
        *   `Implement strategies for graceful degradation or retry mechanisms where appropriate when network connectivity is temporarily lost and then regained.` 📝

---

#### Phase 2: General Application Refactoring 📝

Learnings from refactoring `workflow_modal.dart` should inform a broader effort across the application.

##### 2.1. Identify and Eliminate Redundancy 📝

*   **Objective:** Reduce codebase size and complexity by removing duplicated or unused code.
*   **Actions:**
    *   **Automated Analysis:** Utilize Dart's analysis tools (`dart analyze`) and IDE features to identify unused variables, methods, classes, and imports. 🏗️
    *   **Manual Review:** Systematically review directories (`screens/`, `widgets/`, `services/`, `models/`) for:
        *   **Duplicated Logic:** Look for similar blocks of code that can be extracted into shared utility functions, helper classes, or base classes. 🏗️
        *   **Unused Files/Assets:** Identify and remove any Dart files, images, or other assets that are no longer referenced. 🏗️
        *   **Legacy Code:** Identify code related to the pre-redesign UI or workflow that might have been missed during the redesign implementation and is no longer active. 🏗️

##### 2.2. Enhance Componentization and Reusability 📝

*   **Objective:** Create a more modular and maintainable UI layer by breaking down large widgets and promoting reuse.
*   **Actions:**
    *   **Smaller Widgets:** Identify large `StatelessWidget` or `StatefulWidget` classes (especially in `screens/`) that can be decomposed into smaller, more focused components. Each component should have a single, clear responsibility. 🏗️
    *   **Promote `StatelessWidget`:** Favor `StatelessWidget`s over `StatefulWidget`s whenever a widget doesn't manage its own internal, mutable state. 🏗️
    *   **Shared Widgets:** Review the `widgets/shared/` directory. Consolidate and generalize common UI elements (buttons, cards, input fields with specific styling) to maximize reuse. 🏗️

##### 2.3. State Management Consistency (App-wide) 📝

*   **Objective:** Ensure a consistent and efficient approach to state management across the application.
*   **Actions:**
    *   **Provider Usage:** Confirm that `Provider` (with `ChangeNotifier`, `Consumer`, `Provider.of`) is used consistently for appropriate state management scenarios. 🏗️
    *   **Local State:** Where state is purely local to a widget and its descendants, ensure `StatefulWidget`'s `setState` is used appropriately. Avoid promoting all state to global `ChangeNotifier`s unnecessarily. 🏗️
    *   **State Scope:** Review the scope of `ChangeNotifier`s. Ensure they are provided at the lowest possible level in the widget tree where they are needed. 🏗️

##### 2.4. Service Layer Refinement 📝

*   **Objective:** Ensure services are well-defined, focused, and encapsulate business logic effectively.
*   **Actions:**
    *   **Single Responsibility:** Verify that each service (e.g., `FirestoreService`, `ReceiptParserService`, `AudioTranscriptionService`) adheres to the single responsibility principle. 🏗️
    *   **No UI Logic:** Confirm that no UI-specific logic (e.g., showing dialogs, navigation) has crept into service classes. 🏗️
    *   **Interface Clarity:** Ensure public methods of services have clear contracts and are easy to use. 🏗️

##### 2.5. Data Model Review 📝

*   **Objective:** Maintain robust and clear data models.
*   **Actions:**
    *   **Immutability:** Where appropriate, consider making models immutable (e.g., all `final` fields, methods like `copyWith` for modifications) to improve predictability. 🏗️
    *   **Serialization/Deserialization:** Review `fromJson` and `toJson` methods in models (`Receipt`, `ReceiptItem`, `Person`). Ensure they are robust, handle potential nulls or type mismatches gracefully, and are perfectly aligned with Firestore data structures and Cloud Function outputs/inputs. 🏗️
    *   **Clarity:** Ensure field names are descriptive and anemic models (models with only data and no behavior) are used appropriately. 🏗️

##### 2.6. Navigation Structure 📝

*   **Objective:** Consistent and clear navigation throughout the app.
*   **Actions:**
    *   Review how navigation is handled outside the `WorkflowModal` (e.g., from `ReceiptsScreen` to `WorkflowModal`). 🏗️
    *   Consider defining named routes for cleaner navigation calls if not already extensively used. 🏗️

##### 2.7. Theming and Styling 📝

*   **Objective:** Consistent application of Material You design and centralized styling.
*   **Actions:**
    *   **`ThemeData` Usage:** Ensure that colors, typography, and component styles are primarily sourced from `Theme.of(context)`. 🏗️
    *   **Avoid Hardcoded Values:** Minimize hardcoded colors, font sizes, and padding values directly in widgets. Define them in `ThemeData` or as reusable constants. 🏗️
    *   **Custom Themes:** If custom theme extensions are used, ensure they are well-organized. 🏗️

##### 2.8. Asynchronous Operations 📝

*   **Objective:** Robust handling of asynchronous code.
*   **Actions:**
    *   Review `async/await` usage throughout the app. 🏗️
    *   Ensure comprehensive error handling for `Future`s (e.g., `catchError`, `try-catch` within async methods). 🏗️
    *   Verify consistent use of `mounted` checks before calling `setState` or accessing `BuildContext` after an `await`. 🏗️

##### 2.9. Dependency Management 📝

*   **Objective:** Keep dependencies up-to-date and remove unused ones.
*   **Actions:**
    *   Review `pubspec.yaml` for any outdated dependencies. Plan for updates. 🏗️
    *   Remove any dependencies that are no longer used by the project. 🏗️

---

### 🏗️ In Progress

*(No tasks currently in progress with this specific status emoji, but items marked 🏗️ above are active)*

---

### ✅ Completed

*   **Phase 1: Refactoring `lib/widgets/workflow_modal.dart`** (Decomposition of `_buildStepContent` and related callbacks/widgets)
*   **Phase 3: Deprecating Old Workflow (`lib/receipt_splitter_ui.dart`)** ✅
    *   **3.1. Verify No Critical Usages of `ReceiptSplitterUI` or `MainPageController`:** ✅ Grep search completed. Usages confirmed internal or in docs. `lib/main.dart` import removed; app runs.
    *   **3.2. Address Global UI Elements from `ReceiptSplitterUI`:** ✅
        *   Logout in `SettingsScreen` confirmed functional.
        *   Decision made to remove "Reset App" feature.
        *   "Billfie" branding applied to `SettingsScreen` and `ReceiptsScreen` `AppBar`s. Asset path for `logo.png` confirmed and `pubspec.yaml` verified.
    *   **3.3. Evaluate `SplitManager` Provider in `MainAppContent`:** ✅ Confirmed provider in `MainAppContent` (from `lib/receipt_splitter_ui.dart`) is redundant for the modal workflow.
    *   **3.4. File Deletion and Cleanup:** ✅ Deleted `lib/receipt_splitter_ui.dart` and `lib/screens/assignment_review_screen.dart`. Verified no lingering imports.
    *   **3.5. Review `