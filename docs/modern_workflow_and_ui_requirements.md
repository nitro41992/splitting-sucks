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
- In the **Assign** step, display both the parsed receipt items and the AI-generated assignments. Include an **Edit Items** button inline with the summary, styled in a modern way. This button navigates to the Review Items screen if the user wants to modify the AI's parsing.
- In the **Summary** step, display only the assignments: individual items, shared items, and unassigned items. Include an **Edit Assignments** button inline with the summary, styled in a modern way. This button navigates to the Split view if the user wants to adjust the AI's assignment (including shared/unassigned items).
- The Review and Split screens are only shown if the user explicitly chooses to edit. When editing, these screens open as independent, full-screen views and are not part of the modal workflow.
- The workflow defaults to the shortest path (Upload → Assign → Summary) unless the user opts to edit.

## 3. UI/UX Requirements

- **Material You Design**: Use Material You components, color schemes, and motion where appropriate. Ensure the design is cohesive and reuses components where possible.
- **Step Navigation**: Show only the 3 active steps (Upload, Assign, Summary) in the step indicator by default. If the user enters an edit mode (Review or Split), show all 5 steps and open the edit view full screen, with the stepper hidden or deemphasized.
- **Minimal, Clear Layouts**: Prioritize whitespace, clear typography, and intuitive grouping of actions. Avoid clutter.
- **Edit Buttons**: Place Edit buttons inline with the summary, styled in a modern and discoverable way.
- **Confirmation Dialogs**: When editing, warn users if changes will discard downstream data (e.g., editing items will reset assignments).
- **Platform Conformity**: Ensure all UI/UX works and looks native on both Android and iOS.
- **Accessibility**: Use sufficient contrast, large tap targets, and support for screen readers. No additional accessibility or localization requirements at this time, but remain open to suggestions.
- **Loading/Error States**: Show clear loading indicators and error messages for async operations.
- **Animations/Transitions**: Defer advanced animations and transitions for the MVP; focus on functionality first.

## 4. Editing and Data Flow

- **AI as Default**: Assume AI-generated results are correct; only show editing screens if the user requests.
- **Data Consistency**: When editing, ensure that changes to items or assignments properly update downstream data and UI.
- **Drafts**: Continue to support draft saving/resuming, with the new workflow logic.
- **Testability**: All new UI elements and flows must be covered by widget/integration tests. Use ValueKeys for all interactive elements.
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