# Modern Workflow and UI Requirements

## 1. Goals

- **Streamline the receipt workflow**: Minimize the number of steps/screens a user must go through by default. Assume AI-generated results are correct unless the user chooses to edit.
- **Modernize the UI**: Adopt Material You design principles for a visually appealing, platform-conformant, and accessible experience on both Android and iOS.
- **Prioritize clarity and minimalism**: Use clear, minimal UIs with straightforward widgets and logic. Avoid unnecessary animations in the MVP.
- **Maintain robust test coverage**: Ensure all changes are covered by widget and integration tests, using ValueKeys for critical UI elements.
- **Keep code modular and maintainable**: Structure files and components for easy navigation and future extension.

## 2. Workflow Changes

### Current (5-step):
- Upload → Review → Assign → Split → Summary

### New Default Workflow (3-step):
- **Upload** (image selection/upload)
- **Assign** (shows AI-generated assignments and parsed items; user can edit items if needed)
- **Summary** (shows split/summary; user can edit assignments if needed)

#### Editing Logic:
- The modal stepper must only show three steps: **Upload → Assign → Summary**. Navigation (Back/Next) is limited to these steps.
- **Review** and **Split** screens are NOT part of the modal stepper. They are only accessible via pencil icons in the Assign and Summary steps, respectively.
- The pencil icon in Assign appears inline with the Receipt Summary section header, styled with `AppColors.puce`. Tapping it opens the Review screen as a full-screen overlay (no stepper, no modal navigation). The Review screen uses a floating action button (FAB) for navigation (e.g., "Looks Good" returns to Assign).
- The pencil icon in Summary appears inline with the Split Summary section header, styled with `AppColors.puce`. Tapping it opens the Split screen as a full-screen overlay (no stepper, no modal navigation). The Split screen uses a FAB for navigation (e.g., "Go to Summary" returns to Summary).
- No confirmation dialogs are needed when entering/exiting edit views via pencil icons. Existing confirmations in the Upload step remain.
- Saving a draft from an edit view (Review or Split) returns the user to the receipts list, not the modal workflow or edit view. Data in edit views is cached while in the modal workflow and persisted to the database when exiting the receipt or app.

## 3. UI/UX Requirements

- **Material You Design**: Use Material You components, color schemes, and motion where appropriate. Ensure the design is cohesive and reuses components where possible.
- **Step Navigation**: Show only the 3 active steps (Upload, Assign, Summary) in the step indicator by default. If the user enters an edit mode (Review or Split), show the edit view full screen, with the stepper completely hidden. Optionally, a subtle label may indicate the parent view.
- **Minimal, Clear Layouts**: Prioritize whitespace, clear typography, and intuitive grouping of actions. Avoid clutter.
- **Edit Buttons**: Place pencil icons (using `AppColors.puce`) inline with the relevant section headers (Receipt Summary in Assign, Split Summary in Summary) for editing. These icons are the only way to access Review and Split screens.
- **Confirmation Dialogs**: When editing, warn users if changes will discard downstream data (e.g., editing items will reset assignments). (No additional confirmations needed for pencil icon navigation.)
- **Platform Conformity**: Ensure all UI/UX works and looks native on both Android and iOS.
- **Accessibility**: Use sufficient contrast, large tap targets, and support for screen readers. Pencil icons should be clearly visible and accessible.
- **Loading/Error States**: Show clear loading indicators and error messages for async operations.
- **Animations/Transitions**: Defer advanced animations and transitions for the MVP; focus on functionality first.

## 4. Editing and Data Flow

- **AI as Default**: Assume AI-generated results are correct; only show editing screens if the user requests (via pencil icons).
- **Data Consistency**: When editing, ensure that changes to items or assignments properly update downstream data and UI.
- **Drafts**: Continue to support draft saving/resuming, with the new workflow logic. Saving a draft from an edit view returns to the receipts list.
- **Testability**: All new UI elements and flows must be covered by widget/integration tests. Use ValueKeys for all interactive elements. Tests must verify the presence and correct navigation of pencil icons, and that the modal workflow is limited to three steps.
- **Batch Editing**: The modal workflow only supports one receipt at a time; batch editing is not supported.

## 5. Technical/Code Requirements

- **Modular Components**: Each workflow step and modal should be a separate, easily testable widget.
- **Reusability**: Shared UI elements (cards, dialogs, buttons) should be reused across steps.
- **No Overengineering**: Use straightforward logic and widgets for the MVP. Add advanced features/animations only after core functionality is stable.
- **Platform Support**: All changes must work on both Android and iOS.
- **.gitignore**: Add any new generated or platform-specific files to .gitignore as needed.
- **Documentation**: Update README and docs/ as needed to reflect new workflow and UI.

---

_These requirements are now finalized based on stakeholder input and are ready for design and implementation. If new business rules or constraints arise, they can be added in future revisions._ 