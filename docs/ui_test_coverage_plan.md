# UI Test Coverage Plan

## Overview

This document outlines the critical UI components that must be validated through tests, focusing on functional elements and user expectations that should remain stable across visual redesigns. The emphasis is on *what* should be present and functional rather than *how* it looks, ensuring tests remain valid when the app's appearance changes.

## Critical Components to Test

### Receipt Management

#### Home/Receipts Screen
- **Receipt List**
  - Each receipt should display restaurant name
  - Each receipt should display date
  - Each receipt should display status (draft/completed)
  - Each receipt should display total amount
  - Receipt cards should be tappable to open the receipt

- **Add Receipt Button**
  - Should be visible on screen
  - Should trigger workflow when tapped

- **Navigation**
  - Should allow navigation to People view

#### Workflow Modal/Flow

- **Step Navigation**
  - Step indicators should be present
  - Step indicators should reflect current step
  - Back button should be present when not on first step
  - Next button should be present when not on last step

- **Image Capture Step**
  - Camera/gallery selection options should be present
  - Image preview should be displayed after selection
  - Retake option should be available after image is selected

- **Receipt Parsing Step**
  - Receipt item list should be present after parsing
  - Each item should display name and price
  - Edit options should be available for items
  - Add item button should be present
  - Tax and tip fields should be present

- **People Assignment Step**
  - People list should be present
  - Add person option should be available
  - Each receipt item should be assignable to people
  - Each person should show their assigned items
  - Each person should show their total

- **Final Summary Step**
  - Each person should be displayed with their total
  - Each person's list of items should be displayed
  - Shared items should be clearly identified
  - Complete button should be present
  - Completing should navigate back to receipt list

### People Management

#### People Screen
- **People List**
  - Each person should display name
  - Each person should display their total amount from all receipts
  - Each person card should be tappable

- **Person Detail View**
  - Should display assigned items across receipts
  - Should display shared items across receipts
  - Should display total assigned amount
  - Should properly exclude shared items from total pill (already fixed)
  - Should display payment status

### Navigation and State Handling

- **App Navigation**
  - Bottom navigation should allow switching between main views
  - Back buttons should return to previous screen
  - Completing a workflow should navigate back to receipts list

- **Loading States**
  - Loading indicators should be displayed during async operations
  - User should be prevented from triggering multiple operations while loading

- **Error States**
  - Error messages should be displayed when operations fail
  - Retry options should be available when applicable

## Test Structure Recommendations

### Widget Tests
Focus on testing individual components with their key functionalities:

1. **Presence Tests**: Verify that critical UI elements are present
   ```dart
   testWidgets('Receipt card displays all required information', (tester) async {
     // Setup and render widget
     // Verify presence of restaurant name, date, status, and amount with ValueKeys
   });
   ```

2. **Interaction Tests**: Verify that user interactions work correctly
   ```dart
   testWidgets('Tapping add person button shows dialog', (tester) async {
     // Setup and render widget
     // Tap the add person button
     // Verify dialog appears
   });
   ```

3. **Value Tests**: Verify that displayed values are correct
   ```dart
   testWidgets('Person card shows correct total amount', (tester) async {
     // Setup and render widget with mock data
     // Verify the total amount matches expected calculation
   });
   ```

### Integration Tests
Test full user journeys across multiple screens:

1. **Complete Receipt Workflow**
2. **Adding Items and People**
3. **Assigning Items to People**
4. **Completing a Receipt and Returning to List**

## Current Issues to Address

1. **Navigation After Completion**
   - Ensure workflow modal properly navigates back to receipt list after completing a receipt

2. **Data Integrity Across Steps**
   - Ensure data entered in one step is properly preserved when navigating between steps
   - Test back/forward navigation to verify data persistence

3. **Shared vs. Individual Item Handling**
   - Ensure shared items are clearly marked in all relevant views
   - Verify shared item costs are correctly distributed
   - Verify individual totals exclude shared amounts when appropriate

4. **Summary View Completeness**
   - Ensure all required elements are present in summary view
   - Test that all person cards display correct data
   - Verify that navigation controls work as expected

5. **Error Recovery**
   - Test recovery from network errors during saving
   - Test recovery from parsing errors

## Implementation Guidelines

### ValueKey Usage
All testable UI elements should have ValueKeys to ensure reliable test selection:

```dart
ElevatedButton(
  key: const ValueKey('add_receipt_button'),
  onPressed: () { /* ... */ },
  child: const Text('Add Receipt'),
)
```

### Test Independence
Tests should be independent and not rely on the state of previous tests:

1. Mock dependencies (providers, services)
2. Create fresh test data for each test
3. Reset state between tests

### Visual vs. Functional Testing
Focus tests on functionality rather than appearance:

✅ DO test: "Complete button is present and enabled when data is valid"  
❌ DON'T test: "Complete button has blue background and rounded corners"

## Prioritization

1. **Critical Path**: Full receipt workflow from creation to completion
2. **Data Integrity**: Correct calculations and assignments
3. **Navigation**: Proper flow between screens and steps
4. **Edge Cases**: Handling of empty states, errors, and recovery

## Test File Organization

Organize test files to mirror the app structure:

```
test/
  widgets/
    cards/
      receipt_card_test.dart
      person_card_test.dart
    workflow_steps/
      image_capture_step_test.dart
      parsing_step_test.dart
      assignment_step_test.dart
      summary_step_test.dart
  screens/
    home_screen_test.dart
    people_screen_test.dart
  integration/
    complete_receipt_flow_test.dart
```

## Conclusion

By focusing tests on the functional requirements rather than specific UI implementations, we can ensure that the test suite remains valuable through redesigns while validating that the app meets user expectations. All critical UI components should have appropriate ValueKeys, and tests should verify that the expected information and controls are available to users. 