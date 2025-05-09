# Code Cleanup and Refactoring Plan

This document outlines a plan to address technical debt, remove redundant code, and refactor the application for improved maintainability, readability, and adherence to Flutter best practices. It also serves as a task list.

## Task Status

### To Do

#### Phase 1: Refactoring `lib/widgets/workflow_modal.dart`

`workflow_modal.dart` is a critical component of the redesigned receipt processing workflow. Refactoring it will provide significant benefits and insights for the rest of the application.

##### 1.1. State Management (`WorkflowState`)

*   **Review and Simplify:**
    *   **Objective:** Ensure `WorkflowState` is as lean and focused as possible.
    *   **Actions:**
        *   Evaluate each field and method for necessity and clarity.
        *   Consider if any complex logic within setters/notifiers can be simplified or made more declarative.
        *   Examine the image URI management (`_actualImageGsUri`, `_loadedImageUrl`, `_actualThumbnailGsUri`, `_loadedThumbnailUrl`, `_pendingDeletionGsUris`).
            *   **Consideration:** Could this be encapsulated into a dedicated helper class or service (e.g., `ImageWorkflowManager`) to simplify `WorkflowState`? This helper could manage upload states, URI tracking, and deletion lists.
        *   Analyze data clearing logic (e.g., `clearParseAndSubsequentData`, `clearTranscriptionAndSubsequentData`). Ensure these methods are robust, intuitive, and cover all necessary edge cases (e.g., preserving tip/tax correctly).
        *   Assess the boolean flags for data presence (`hasParseData`, `hasTranscriptionData`, `hasAssignmentData`). Ensure their logic is sound and they are used consistently.
*   **Encapsulation:**
    *   **Objective:** Improve encapsulation of state modification logic.
    *   **Actions:**
        *   Ensure that all state modifications happen through well-defined methods in `WorkflowState` rather than direct manipulation from the UI layer where possible.

##### 1.2. Widget Structure (`_WorkflowModalBodyState` and Helper Methods)

*   **Decomposition of `_buildStepContent`:**
    *   **Objective:** Improve readability, maintainability, and testability of step-specific UI.
    *   **Actions:**
        *   Break down the `switch` statement in `_buildStepContent`. Each case (Upload, Review, Assign, Split, Summary) should ideally become its own `StatelessWidget` or `StatefulWidget`.
        *   These new step widgets would take necessary data from `WorkflowState` (via `Provider.of` or `Consumer`) and relevant callbacks as parameters.
        *   **Example:** `ReceiptUploadStepWidget`, `ReceiptReviewStepWidget`, etc.
*   **Callback and Event Handling:**
    *   **Objective:** Clarify event handling and reduce complexity in `_WorkflowModalBodyState`.
    *   **Actions:**
        *   Review long callback functions passed to step screens (e.g., `onImageSelected`, `onParseReceipt` in `ReceiptUploadScreen` setup).
        *   If these callbacks contain significant logic, consider extracting that logic into private methods within `_WorkflowModalBodyState`.
        *   For very complex interactions, a small, dedicated controller or helper class for certain actions might be considered, though this should be weighed against over-engineering.
*   **Review Core Logic Methods:**
    *   **Objective:** Ensure methods like `_loadReceiptData`, `_saveDraft`, `_completeReceipt`, and `_onWillPop` have clear responsibilities and are not overly complex.
    *   **Actions:**
        *   `_loadReceiptData`: Verify its flow, error handling, and how it determines the target step.
        *   `_saveDraft` & `_completeReceipt`: Check for clarity, robust error handling, and clean interaction with `WorkflowState` and `FirestoreService`. Ensure the sequence of operations (e.g., UI updates, async calls, state changes) is logical and safe (e.g., using `mounted` checks appropriately).
        *   `_processPendingDeletions`: Ensure this logic is robust and correctly handles all scenarios for image cleanup.
*   **Use of `Consumer` vs. `Provider.of`:**
    *   **Objective:** Optimize widget rebuilds.
    *   **Actions:**
        *   Ensure `Consumer` widgets are used appropriately to rebuild only the necessary parts of the UI when `WorkflowState` changes.
        *   Verify that `Provider.of(context, listen: false)` is used in callbacks and `initState` where only method calls on the notifier are needed, not reactive updates.
*   **Placeholders and Loading States:**
    *   **Objective:** Consistent and clear user feedback.
    *   **Actions:**
        *   Review `_buildPlaceholder` and general loading indicators. Ensure they are used consistently when data is missing or operations are in progress.

##### 1.3. Dialogs and Navigation

*   **Standardize Dialogs:**
    *   **Objective:** Consistent look, feel, and behavior for dialogs.
    *   **Actions:**
        *   Review `showRestaurantNameDialog` and `_showConfirmationDialog`. Consider extracting them to a common dialogs utility file if they are (or could be) used elsewhere, or if more standardized dialogs are needed.
        *   Ensure they follow Material Design guidelines.
*   **Navigation Logic:**
    *   **Objective:** Clear, predictable, and robust navigation within the modal.
    *   **Actions:**
        *   Review the logic for the step indicator taps, "Next," "Back," and "Exit" buttons.
        *   Ensure that conditions for enabling/disabling navigation (e.g., `isNextEnabled` logic) are comprehensive and clearly tied to the `WorkflowState` (e.g., `hasParseData`).
        *   The `WillPopScope` and `_onWillPop` logic should be robust for saving drafts automatically.

##### 1.4. Service Interactions

*   **Clear Boundaries:**
    *   **Objective:** Maintain a clean separation of concerns between UI logic and service logic.
    *   **Actions:**
        *   Ensure `WorkflowModal` delegates persistence and complex business logic (like image uploading, parsing) to `FirestoreService`, `ReceiptParserService`, etc.
        *   The modal should primarily be responsible for orchestrating the workflow and managing UI-related state.

##### 1.5. Code Comments, Readability, and Error Handling

*   **Code Clarity:**
    *   **Objective:** Make the code easier to understand and maintain.
    *   **Actions:**
        *   Remove obvious comments (e.g., `// Getter for people`).
        *   Add comments to explain non-trivial logic, complex conditions, or important decisions.
        *   Ensure consistent naming conventions for variables, methods, and classes.
        *   Break down overly long methods if it improves readability.
*   **Error Handling & User Feedback:**
    *   **Objective:** Provide clear, actionable feedback to the user for any errors.
    *   **Actions:**
        *   Review all `try-catch` blocks. Ensure errors are caught appropriately and meaningful messages are shown to the user (e.g., via `SnackBar` or updates to `_errorMessage` in `WorkflowState`).
        *   Verify that loading states in `WorkflowState` are correctly set and unset around asynchronous operations.

##### 1.6. Specific Areas of Attention from `implementation_plan.md`

*   **Image URI Handling:** The notes on "Detailed URI logging has been added to the client" suggest this was a complex area. Double-check the logic for `_actualImageGsUri`, `_actualThumbnailGsUri`, `_loadedImageUrl`, `_loadedThumbnailUrl`, and the pending deletion list in `WorkflowState` for robustness and clarity.
*   **Blurry Thumbnail / Full Image Load:** While debugging prints were added, ensure the refactored image handling logic in `ReceiptUploadScreen` (once broken out) and `WorkflowState` clearly manages the transition from thumbnail to full image, especially on draft resume and navigation.
*   **Context Safety (`mounted` checks):** Continue to ensure `mounted` checks are used correctly, especially around `async` operations that interact with `BuildContext` or `setState`.

---

#### Phase 2: General Application Refactoring

Learnings from refactoring `workflow_modal.dart` should inform a broader effort across the application.

##### 2.1. Identify and Eliminate Redundancy

*   **Objective:** Reduce codebase size and complexity by removing duplicated or unused code.
*   **Actions:**
    *   **Automated Analysis:** Utilize Dart's analysis tools (`dart analyze`) and IDE features to identify unused variables, methods, classes, and imports.
    *   **Manual Review:** Systematically review directories (`screens/`, `widgets/`, `services/`, `models/`) for:
        *   **Duplicated Logic:** Look for similar blocks of code that can be extracted into shared utility functions, helper classes, or base classes.
        *   **Unused Files/Assets:** Identify and remove any Dart files, images, or other assets that are no longer referenced.
        *   **Legacy Code:** Identify code related to the pre-redesign UI or workflow that might have been missed during the redesign implementation and is no longer active.

##### 2.2. Enhance Componentization and Reusability

*   **Objective:** Create a more modular and maintainable UI layer by breaking down large widgets and promoting reuse.
*   **Actions:**
    *   **Smaller Widgets:** Identify large `StatelessWidget` or `StatefulWidget` classes (especially in `screens/`) that can be decomposed into smaller, more focused components. Each component should have a single, clear responsibility.
    *   **Promote `StatelessWidget`:** Favor `StatelessWidget`s over `StatefulWidget`s whenever a widget doesn't manage its own internal, mutable state.
    *   **Shared Widgets:** Review the `widgets/shared/` directory. Consolidate and generalize common UI elements (buttons, cards, input fields with specific styling) to maximize reuse.

##### 2.3. State Management Consistency (App-wide)

*   **Objective:** Ensure a consistent and efficient approach to state management across the application.
*   **Actions:**
    *   **Provider Usage:** Confirm that `Provider` (with `ChangeNotifier`, `Consumer`, `Provider.of`) is used consistently for appropriate state management scenarios.
    *   **Local State:** Where state is purely local to a widget and its descendants, ensure `StatefulWidget`'s `setState` is used appropriately. Avoid promoting all state to global `ChangeNotifier`s unnecessarily.
    *   **State Scope:** Review the scope of `ChangeNotifier`s. Ensure they are provided at the lowest possible level in the widget tree where they are needed.

##### 2.4. Service Layer Refinement

*   **Objective:** Ensure services are well-defined, focused, and encapsulate business logic effectively.
*   **Actions:**
    *   **Single Responsibility:** Verify that each service (e.g., `FirestoreService`, `ReceiptParserService`, `AudioTranscriptionService`) adheres to the single responsibility principle.
    *   **No UI Logic:** Confirm that no UI-specific logic (e.g., showing dialogs, navigation) has crept into service classes.
    *   **Interface Clarity:** Ensure public methods of services have clear contracts and are easy to use.

##### 2.5. Data Model Review

*   **Objective:** Maintain robust and clear data models.
*   **Actions:**
    *   **Immutability:** Where appropriate, consider making models immutable (e.g., all `final` fields, methods like `copyWith` for modifications) to improve predictability.
    *   **Serialization/Deserialization:** Review `fromJson` and `toJson` methods in models (`Receipt`, `ReceiptItem`, `Person`). Ensure they are robust, handle potential nulls or type mismatches gracefully, and are perfectly aligned with Firestore data structures and Cloud Function outputs/inputs.
    *   **Clarity:** Ensure field names are descriptive and anemic models (models with only data and no behavior) are used appropriately.

##### 2.6. Navigation Structure

*   **Objective:** Consistent and clear navigation throughout the app.
*   **Actions:**
    *   Review how navigation is handled outside the `WorkflowModal` (e.g., from `ReceiptsScreen` to `WorkflowModal`).
    *   Consider defining named routes for cleaner navigation calls if not already extensively used.

##### 2.7. Theming and Styling

*   **Objective:** Consistent application of Material You design and centralized styling.
*   **Actions:**
    *   **`ThemeData` Usage:** Ensure that colors, typography, and component styles are primarily sourced from `Theme.of(context)`.
    *   **Avoid Hardcoded Values:** Minimize hardcoded colors, font sizes, and padding values directly in widgets. Define them in `ThemeData` or as reusable constants.
    *   **Custom Themes:** If custom theme extensions are used, ensure they are well-organized.

##### 2.8. Asynchronous Operations

*   **Objective:** Robust handling of asynchronous code.
*   **Actions:**
    *   Review `async/await` usage throughout the app.
    *   Ensure comprehensive error handling for `Future`s (e.g., `catchError`, `try-catch` within async methods).
    *   Verify consistent use of `mounted` checks before calling `setState` or accessing `BuildContext` after an `await`.

##### 2.9. Dependency Management

*   **Objective:** Keep dependencies up-to-date and remove unused ones.
*   **Actions:**
    *   Review `pubspec.yaml` for any outdated dependencies. Plan for updates.
    *   Remove any dependencies that are no longer used by the project.

---

### In Progress

*(No tasks currently in progress)*

---

### Completed

*   **Phase 3: Deprecating Old Workflow (`lib/receipt_splitter_ui.dart`)**
    *   **3.1. Verify No Critical Usages of `ReceiptSplitterUI` or `MainPageController`:** Grep search completed. Usages confirmed internal or in docs. `lib/main.dart` import removed; app runs.
    *   **3.2. Address Global UI Elements from `ReceiptSplitterUI`:**
        *   Logout in `SettingsScreen` confirmed functional.
        *   Decision made to remove "Reset App" feature.
        *   "Billfie" branding applied to `SettingsScreen` and `ReceiptsScreen` `AppBar`s. Asset path for `logo.png` confirmed and `pubspec.yaml` verified.
    *   **3.3. Evaluate `SplitManager` Provider in `MainAppContent`:** Confirmed provider in `MainAppContent` (from `lib/receipt_splitter_ui.dart`) is redundant for the modal workflow.
    *   **3.4. File Deletion and Cleanup:** Deleted `lib/receipt_splitter_ui.dart` and `lib/screens/assignment_review_screen.dart`. Verified no lingering imports.
    *   **3.5. Review `SharedPreferences` Usage:** Review completed. Remaining `SharedPreferences` usage in `AuthService` for login attempt throttling is valid. No other active code found reading/writing old workflow state keys.

*   **Bug Fix:** Fixed 'context unmounted' error in `ReceiptsScreen` when launching `WorkflowModal` by capturing and using a stable `BuildContext` from `ReceiptsScreen` for modal/dialog presentation.

---

## Refactoring Process Recommendations

*   **Incremental Changes:** Refactor in small, manageable steps. Avoid large, sweeping changes that are hard to test and debug.
*   **Version Control:** Use Git extensively. Create new branches for each significant refactoring task. Commit frequently with clear messages.
*   **Test After Each Change:** Crucially, after each refactoring step, thoroughly test the affected functionality. If automated tests exist, run them. Manual testing is also vital.
    *   **Recommendation:** Prioritize writing tests for areas *before* refactoring if they are complex or critical and lack coverage. This provides a safety net.
*   **Code Reviews:** If working in a team or if another developer is available, have refactoring changes reviewed. A fresh pair of eyes can catch issues or suggest improvements.
*   **Prioritization:** Start with areas that cause the most pain (e.g., are buggy, hard to understand, or frequently changed) or offer the highest impact (e.g., widely used components or services).
*   **Don't Refactor and Add Features Simultaneously:** Separate refactoring efforts from new feature development to avoid compounding complexity.

--- 

## Security Considerations During Refactoring

Refactoring provides an opportunity to review and enhance application security.

*   **Input Validation:** As you review data models and service layers, ensure all external inputs (user-entered data, API responses) are properly validated.
*   **Sensitive Data Handling:** Check how sensitive data (if any) is managed in memory, persisted, and transmitted. Avoid logging sensitive information.
*   **Firestore Security Rules:** Refactoring service interactions with Firestore is a good time to revisit `firestore.rules`. Ensure rules are least-privilege and align with the application's data access patterns. Changes in data models or query logic might necessitate rule updates.
*   **Storage Security Rules:** Similarly, review `storage.rules` in conjunction with image handling refactoring to ensure users can only access or delete their own images, as noted in `implementation_plan.md`.
*   **Dependencies:** When updating dependencies, be mindful of any security advisories associated with older versions.
*   **Error Handling:** Ensure that error messages exposed to the user do not leak sensitive system information.
*   **API Key Management:** Verify that API keys or sensitive configuration details are not hardcoded and are managed securely (e.g., via `.env` files that are not committed to version control).
*   **Cleartext Traffic:** The note about `android:usesCleartextTraffic="true"` for emulators in `implementation_plan.md` is acceptable for development. Ensure this is *not* the case for production builds unless absolutely necessary and understood.
