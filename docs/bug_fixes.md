# Bug Fixes Tracker

This document tracks known bugs and their status for the splitting_sucks project. Please update status and notes as bugs are fixed or new information is discovered.

---

## Ready for Verification

### 1. Transcription Text Box in Assign View Does Not Cache or Persist Changes
- **Status:** Fixed
- **Notes:** Transcription is now robustly cached to `WorkflowState` and persisted to local storage on every navigation event (Next, Back, modal close) and on blur. The value is always restored when returning to the Assign step, and persists across app restarts. This matches the behavior of the tax field. Verified to work regardless of keyboard/focus state.
- **References:** Assign view, modal workflow logic, [modern_workflow_and_ui_implementation_plan.md](modern_workflow_and_ui_implementation_plan.md), [modern_workflow_and_ui_requirements.md](modern_workflow_and_ui_requirements.md)
- **My Notes:** Issue resolved. Edits are now always retained when navigating between steps, exiting, or reloading the app.

### 2. Can Click Next Past the Summary Screen
- **Status:** Fixed
- **Notes:** The "Next" button is now hidden/disabled on the Summary step (step 2) in `workflow_modal.dart` navigation controls. Users cannot proceed past the last step. Please verify that the Next button is not visible or enabled on the Summary step.
- **References:** [modern_workflow_and_ui_implementation_plan.md](modern_workflow_and_ui_implementation_plan.md), [modern_workflow_and_ui_requirements.md](modern_workflow_and_ui_requirements.md), UI screenshots (e.g., flutter_02.png)

### 3. Tax Field in Summary Page Refreshes on Every Character
- **Status:** Fixed
- **Notes:** Tax field now updates calculations and caches to `WorkflowState` immediately on every change, not just on blur or navigation. The UI and calculations update as you type. Please verify that calculations update live and the value is retained when navigating between steps.
- **References:** Summary page, [modern_workflow_and_ui_implementation_plan.md](modern_workflow_and_ui_implementation_plan.md), [modern_workflow_and_ui_requirements.md](modern_workflow_and_ui_requirements.md)

### 4. No Indication of Cloud Function Call When Starting Splitting
- **Status:** Fixed
- **Notes:** All async setState calls in `VoiceAssignmentScreen` now check `if (!mounted) return;` before calling setState, preventing the "setState after dispose" error. Please verify that you no longer see the error when clicking Start Splitting and navigating away quickly.
- **References:** Assign view, cloud function integration

### 5. Shared People Not Highlighted in Edit Screen (Summary View)
- **Status:** Partially Fixed / Pending
- **Notes:** Shared people chips in the Shared tab are not visually distinct (filled and colored) when selected. However, highlighting is still inconsistent in the Shared tab of the edit view. Changes to shared items now call `notifyListeners()` on `SplitManager`, ensuring the summary and person cards update immediately. Please verify that highlighting works and shared items are reflected in the summary and person cards. Use `flutter test` to check for bugs relating to this.
- **References:** Summary view, Share tab, UI screenshot (flutter_01.png)
- **My Notes:** Partially fixed. I see the shared items in the people summary card. But in the Shared tab of the edit view, the people are not highlighted on the card. This is still pending.
--- 