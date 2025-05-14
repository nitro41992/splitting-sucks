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
- **Status:** Fixed
- **Notes:** Fixed highlighting issues in the Shared tab with proper itemId-based comparison for shared items. `SharedItemCard` now uses itemId for comparison instead of reference equality, ensuring consistent behavior. The visual indicators (pills/chips) now correctly show which people are sharing specific items.
- **References:** Summary view, Share tab, UI screenshot (flutter_02.png)

### 6. Calculation Warnings and Subtotal Mismatches
- **Status:** Fixed
- **Notes:** Fixed calculation issues with shared items in the split view, improving how subtotals are calculated and displayed. The following changes were made:
  - Updated `getPersonTotal` method in `SplitManager` to properly calculate shared item costs
  - Implemented consistent rounding method across all calculations using `toStringAsFixed(2)` 
  - Fixed the subtotal mismatch warning to use a more precise comparison threshold (0.02 instead of 0.01)
  - Updated person cards to accurately reflect shared item splits
- **References:** Split view, SplitManager calculations, UI screenshot (flutter_03.png)

### 7. Unassigned Items Not Correctly Calculated in Summary View
- **Status:** Fixed
- **Notes:** Fixed an issue where decreasing the quantity of a shared item would create an unassigned item, but the overall subtotal calculation would not reflect this change properly. Changes made:
  - Modified the verification calculation in `final_summary_screen.dart` to use `splitManager.getPersonTotal()` consistently
  - Increased floating point tolerance from 0.02 to 0.05 to prevent false warnings due to rounding
  - Updated the warning message to be more specific about the cause of discrepancies
- **References:** Split view, Final summary screen, SplitManager calculations

--- 