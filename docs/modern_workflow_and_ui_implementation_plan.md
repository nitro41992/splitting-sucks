# Modern Workflow and UI Implementation Plan

This plan outlines the implementation tasks for the modern workflow and UI redesign, based on the finalized requirements in `docs/modern_workflow_and_ui_requirements.md`. All changes must work for both Android and iOS (Flutter cross-platform).

---

## 1. Project Preparation
- [ ] Review and update `.gitignore` for any new generated or platform-specific files.
- [ ] Ensure all developers are familiar with the new requirements document.
- [ ] Create a new feature branch for the redesign.
- [ ] **After each major change, run all tests and fix any failures before proceeding.**

## 2. Workflow Logic Refactor
- [ ] Refactor modal workflow logic to default to 3 steps: Upload → Assign → Summary.
  - Update `lib/widgets/workflow_modal.dart` and related state/providers.
  - Remove Review and Split steps from the default flow and stepper.
  - Ensure navigation (Back/Next) is limited to these three steps.
- [ ] Implement logic to show Review and Split screens only when user chooses to edit via pencil icons.
  - Add pencil icon (using `AppColors.puce`) inline with the Receipt Summary section header in Assign. Tapping opens Review as a full-screen overlay (no stepper, no modal navigation), with a floating action button (FAB) for navigation (e.g., "Looks Good" returns to Assign).
  - Add pencil icon (using `AppColors.puce`) inline with the Split Summary section header in Summary. Tapping opens Split as a full-screen overlay (no stepper, no modal navigation), with a FAB for navigation (e.g., "Go to Summary" returns to Summary).
  - No confirmation dialogs are needed when entering/exiting edit views via pencil icons. Existing confirmations in the Upload step remain.
  - Saving a draft from an edit view (Review or Split) returns the user to the receipts list, not the modal workflow or edit view. Data in edit views is cached while in the modal workflow and persisted to the database when exiting the receipt or app.
- [ ] Ensure data consistency and correct state clearing when editing (e.g., editing items resets assignments).
- [ ] **Run all tests and fix any failures after completing this section.**

## 3. UI/UX Redesign
- [ ] Redesign step indicator to show only 3 steps by default; show 5 steps only in edit mode. **(Update: Only 3 steps should ever be shown in the modal stepper; edit views are full-screen overlays with no stepper.)**
- [ ] Update Assign step to display both parsed items and assignments, with an inline pencil icon for editing items.
- [ ] Update Summary step to display only assignments (individual, shared, unassigned), with an inline pencil icon for editing assignments.
- [ ] Style pencil icons in a modern, discoverable way (Material You principles, using `AppColors.puce`).
- [ ] Ensure all layouts are minimal, clear, and use Material You components/colors.
- [ ] Add/adjust confirmation dialogs for editing actions that discard downstream data (only where required).
- [ ] Ensure all UI/UX is accessible and conforms to platform guidelines.
- [ ] **Run all tests and fix any failures after completing this section.**

## 4. Navigation & Routing
- [ ] Refactor navigation so that editing screens (Review, Split) are independent, full-screen overlays with no stepper.
- [ ] Ensure user can jump directly to editing from Assign or Summary via pencil icons, and return to the workflow after editing using FABs.
- [ ] Remove stepper/step indicator from edit screens.
- [ ] **Run all tests and fix any failures after completing this section.**

## 5. Modularization & Code Organization
- [ ] Ensure each workflow step and modal is a separate, easily testable widget (`lib/widgets/workflow_steps/`).
- [ ] Reuse shared UI elements (cards, dialogs, buttons) across steps (`lib/widgets/shared/`, `lib/widgets/cards/`).
- [ ] Refactor or extract any large files for maintainability.
- [ ] **Run all tests and fix any failures after completing this section.**

## 6. Test Coverage
- [ ] Update or add widget tests for new/changed UI (use ValueKeys for all interactive elements).
- [ ] Add integration tests for the new workflow (Upload → Assign → Summary, with/without editing).
- [ ] Ensure tests cover navigation, editing, state clearing, and error/loading states.
- [ ] Tests must verify the presence and correct navigation of pencil icons, and that the modal workflow is limited to three steps.
- [ ] Update test helpers/mocks as needed (`test/` directory).
- [ ] **Run all tests and fix any failures after completing this section.**

## 7. Documentation
- [ ] Update `README.md` and relevant docs to reflect the new workflow and UI.
- [ ] Document any new components, navigation patterns, or business logic.
- [ ] **Run all tests and fix any failures after completing this section.**

## 8. QA & Cross-Platform Testing
- [ ] Test all changes on both Android and iOS devices/emulators.
- [ ] Verify platform-specific UI/UX conformity (padding, navigation, dialogs, etc.).
- [ ] Ensure accessibility (contrast, tap targets, screen reader support).
- [ ] **Run all tests and fix any failures after completing this section.**

## 9. Post-MVP Enhancements (Future Work)
- [ ] Add Material You animations and transitions for step changes and editing.
- [ ] Explore advanced features (e.g., batch editing, multi-user collaboration) if needed.
- [ ] Further optimize for performance and offline support.

---

_This plan should be updated as implementation progresses. Track completed tasks and add new ones as needed. **Running and fixing all tests is required after each major change and before merging.**_ 