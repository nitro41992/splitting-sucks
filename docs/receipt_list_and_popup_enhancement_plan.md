# Receipt List & Popup Enhancement Implementation Plan

## Modern Design Trends (2025) Principles for Billfie

Billfie will follow the latest 2025 UX/UI trends, focusing on:
- **Minimalism:** Clean layouts, ample white space, and clear hierarchy. Avoid visual clutter and unnecessary decoration. [Source: Medium - UX/UI Trends 2025](https://medium.com/codeart-mk/ux-ui-trends-2025-818ea752c9f7)
- **Playful-Professional Tone:** Friendly, approachable elements (rounded corners, soft colors, subtle icons) balanced with a professional, trustworthy feel. [Source: UX Trends 2025](https://trends.uxdesign.cc/)
- **Clarity & Accessibility:** Prioritize legibility, intuitive navigation, and clear feedback. Use high-contrast text and simple iconography.
- **Material You/Material 3:** Leverage modern Material Design principles for consistency and familiarity.

No advanced AI-driven UI, dark mode, or AI-generated avatars are planned at this stage. The design will use user-uploaded or default avatars and a minimal, modern icon style.

---

## 1. Editable Restaurant Name in Popup
- [ ] Add an editable text field for the restaurant name in the receipt popup/modal, styled minimally
- [ ] Add an edit icon or make the name tappable to trigger editing (use playful, clear iconography)
- [ ] Save and update the restaurant name in the data model and UI
- [ ] Ensure updates reflect in the main receipts list and all relevant views
- [ ] Validate and sanitize input

---

## 2. Receipts List: Remove Useless Attributes & Actions
- [ ] Remove the three-dot menu from each receipt card if no actions are available
- [ ] Remove the "Pending" status and $0.00 if not meaningful
- [ ] Only display useful attributes: restaurant name, date, people, and status
- [ ] Ensure the card layout is minimal, clear, and visually balanced

---

## 3. Date Format Consistency
- [ ] Change all date displays to mm/dd/yyyy format
- [ ] Update date formatting logic in both list and popup

---

## 4. Show Restaurant Name & Attendees
- [ ] Display restaurant name prominently on each receipt card (bold, clear, minimal)
- [ ] Show a row of attendee avatars or names (distinct people, minimal style)
- [ ] If attendees > 3, show "+N" for overflow

---

## 5. Draft Completion Logic
- [ ] If the summary view has data (items assigned, people exist), auto-mark draft as complete
- [ ] Remove the "Complete" button; only show "Exit" or "Back"
- [ ] Optionally, show a confirmation when draft is auto-completed

---

## 6. Status Pill Consistency
- [ ] Use the same pill style (color, shape, font) for status in both list and popup (minimal, playful-professional)
- [ ] Use title case ("Draft", "Completed") for status text

---

## 7. Additional Redesigns
- [ ] Redesign receipt card layout for clarity and modern look (minimal, playful-professional)
- [ ] Redesign popup/modal for Material 3 style, rounded corners, and spacing
- [ ] Ensure accessibility (labels, focus, contrast)
- [ ] Add confirmation dialog for "Delete Receipt"
- [ ] Use shared widgets for pills and avatars

---

## 8. Security & Validation
- [ ] Sanitize all user input (restaurant names, etc.)
- [ ] Ensure only authorized users can edit/delete receipts

---

## 9. QA & Testing
- [ ] Add/Update tests for new UI and logic
- [ ] Verify all enhancements work as intended

---

## Progress Tracking
- [ ] Each section above should be checked off as completed
- [ ] PRs should reference checklist items
- [ ] Product can review this doc to track implementation status 