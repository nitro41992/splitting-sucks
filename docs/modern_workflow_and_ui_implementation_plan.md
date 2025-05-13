# Modern Workflow and UI Implementation Plan

This plan outlines the implementation tasks for the modern workflow and UI redesign, based on the finalized requirements in `docs/modern_workflow_and_ui_requirements.md`. All changes must work for both Android and iOS (Flutter cross-platform).

---

## 1. Project Preparation
- [ ] Review and update `.gitignore` for any new generated or platform-specific files.
- [ ] Ensure all developers are familiar with the new requirements document.
- [ ] Create a new feature branch for the redesign.
- [ ] **After each major change, run all tests and fix any failures before proceeding.**

## 2. Workflow Logic Refactor
- [x] Refactor modal workflow logic to default to 3 steps: Upload → Assign → Summary.
- [x] Implement logic to show Review and Split screens only when user chooses to edit via pencil icons.
- [x] Ensure data consistency and correct state clearing when editing (e.g., editing items resets assignments).
- [x] Run all tests and fix any failures after completing this section.

## 3. UI/UX Redesign
- [x] Redesign step indicator to show only 3 steps by default; show 5 steps only in edit mode. **(Update: Only 3 steps should ever be shown in the modal stepper; edit views are full-screen overlays with no stepper.)**
- [x] Update Assign step to display both parsed items and assignments, with an inline pencil icon for editing items.
- [x] Update Summary step to display only assignments (individual, shared, unassigned), with an inline pencil icon for editing assignments.
- [x] Style pencil icons in a modern, discoverable way (Material You principles, using `AppColors.puce`).
- [x] Ensure all layouts are minimal, clear, and use Material You components/colors.
- [ ] **IN PROGRESS:** Refactor all edit overlays (Review, Split) to use a bottom app bar for actions (Add Person, Add Item, Done), matching the summary edit view. Remove all legacy FABs from these overlays.
- [ ] **IN PROGRESS:** Fix add person/item logic so that UI and cache update immediately in all edit overlays.
- [ ] **IN PROGRESS:** Update all tests to match new UI structure and logic.
- [x] Add/adjust confirmation dialogs for editing actions that discard downstream data (only where required).
- [x] Ensure all UI/UX is accessible and conforms to platform guidelines.
- [x] Run all tests and fix any failures after completing this section.

## 4. Navigation & Routing
- [ ] Refactor navigation so that editing screens (Review, Split) are independent, full-screen overlays with no stepper.
- [ ] Ensure user can jump directly to editing from Assign or Summary via pencil icons, and return to the workflow after editing using FABs.
- [ ] Remove stepper/step indicator from edit screens.
- [ ] Edit overlays (Review and Split) must fully cover the workflow modal, including navigation controls (Back, Exit, Next), so only the overlay's FAB is visible and interactive. The underlying workflow UI and navigation must not be visible or accessible while in an edit overlay. The overlay should feel like a full-screen dialog/modal, not a partial overlay. FAB actions must always perform the main navigation (e.g., 'Looks Good' returns to Assign, 'Go to Summary' returns to Summary), and must not overlap with any underlying controls.
- [ ] The pencil icon for editing must be a white pencil inside a puce pill-shaped background, following Material You guidelines for discoverability and accessibility.
- [ ] The FAB in edit overlays must always perform the main navigation action and not overlap with any underlying controls.
- [ ] All widget/integration tests must verify that overlays block workflow navigation and that the correct navigation occurs when the FAB is pressed.
- [ ] Update any existing tests that assume partial overlays or visible workflow navigation during editing.
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
- [ ] **Verify that adding people/items in both edit views updates the UI and cache immediately, and that the bottom app bar is consistent across both views.**
- [ ] **Run all tests and fix any failures after completing this section.**

## 9. Post-MVP Enhancements (Future Work)
- [ ] Add Material You animations and transitions for step changes and editing.
- [ ] Explore advanced features (e.g., batch editing, multi-user collaboration) if needed.
- [ ] Further optimize for performance and offline support.

## Knowledge Transfer (KT) for Future AI/Devs
- **Design:** All edit overlays (Review, Split) use a bottom app bar for actions. No floating action buttons (FABs) should remain in these overlays. Use Material You surface colors for backgrounds.
- **Navigation:** Only one pop/navigation event should occur when closing overlays (see double pop bug in SplitStepWidget). Use `Navigator.canPop()` and guard callbacks.
- **State Management:** All add/remove actions (person/item) must update the `SplitManager` and notify listeners. UI must rebuild immediately after changes.
- **Testing:** Widget tests must open dialogs, wait for animations, and use robust finders (by key/label, not just text). Test all action buttons for correct UI updates and navigation.
- **Pitfalls:** Watch for context disposal after pop, and for test failures due to widget tree changes. Always update tests after major UI refactors.
- **Where to look:** Main UI logic for overlays is in `split_step_widget.dart`, `split_view.dart`, and related dialog widgets. Test logic is in `test/widgets/workflow_steps/`.

---

_This plan should be updated as implementation progresses. Track completed tasks and add new ones as needed. **Running and fixing all tests is required after each major change and before merging.**_ 