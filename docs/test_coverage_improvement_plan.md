# Test Coverage Improvement Plan

## Current Status

Based on our analysis, several key areas of the app lack adequate test coverage, particularly for UI components and user flows. The existing tests don't fully validate that all expected UI elements are present and functional, which has led to issues going undetected.

## Goals

1. Achieve 80%+ test coverage across the entire codebase
2. Ensure all critical user flows are covered by tests
3. Create tests that are resilient to UI redesigns by focusing on functionality
4. Establish consistent testing patterns and best practices

## High Priority Test Additions

### Summary View Tests

The summary view has had multiple issues with missing UI elements. Priority tests to add:

1. **Summary Step Widget Tests**
   ```dart
   testWidgets('Summary step displays all people with their totals', (tester) async {
     // Setup SummaryStepWidget with mock data
     // Verify each person is displayed with the correct total
   });
   
   testWidgets('Summary step shows shared items correctly', (tester) async {
     // Setup SummaryStepWidget with mock shared items
     // Verify shared items are displayed with appropriate indication
   });
   
   testWidgets('Complete button is enabled and functional', (tester) async {
     // Setup SummaryStepWidget in completed state
     // Verify complete button is enabled and calls the right callback
   });
   ```

2. **Person Summary Card Tests**
   ```dart
   testWidgets('PersonSummaryCard displays correct assigned items', (tester) async {
     // Setup PersonSummaryCard with assigned items
     // Verify each item is displayed with correct amount
   });
   
   testWidgets('PersonSummaryCard displays correct shared items', (tester) async {
     // Setup PersonSummaryCard with shared items
     // Verify each shared item is displayed with correct amount
   });
   ```

### Workflow Navigation Tests

1. **Step Transition Tests**
   ```dart
   testWidgets('Navigating between workflow steps preserves data', (tester) async {
     // Setup workflow with multi-step data
     // Navigate through steps
     // Verify data remains consistent
   });
   ```

2. **Completion Navigation Test**
   ```dart
   testWidgets('Completing workflow navigates to receipt list', (tester) async {
     // Setup workflow in final step
     // Tap complete button
     // Verify navigation to receipt list screen
   });
   ```

### Data Integrity Tests

1. **Person Total Calculation Tests**
   ```dart
   test('Person.totalAssignedAmount excludes shared items', () {
     // Create person with both assigned and shared items
     // Verify totalAssignedAmount only includes assigned items
   });
   
   test('Person.calculatedSharedAmount correctly calculates shared portion', () {
     // Create person with shared items
     // Verify calculatedSharedAmount matches expected value
   });
   ```

2. **Split Manager Tests**
   ```dart
   test('SplitManager correctly allocates shared items', () {
     // Setup SplitManager with multiple people and shared items
     // Verify shared amounts are correctly distributed
   });
   ```

## Model-Level Test Improvements

### Receipt Model Tests

1. **Status Calculation Tests**
   ```dart
   test('Receipt status correctly reflects completion state', () {
     // Create receipts in various states
     // Verify status property returns correct values
   });
   ```

2. **Serialization Tests**
   ```dart
   test('Receipt correctly serializes and deserializes', () {
     // Create receipt with complex data
     // Serialize to JSON and back
     // Verify all properties match
   });
   ```

## Widget Test Improvements

All UI components should have dedicated tests. Priority widgets to test:

1. **Receipt Cards**
2. **Item Assignment Widgets**
3. **Workflow Navigation Controls**
4. **Error State Widgets**

Each test should:
- Verify all expected UI elements are present using ValueKeys
- Test interaction behavior (taps, swipes, etc.)
- Verify correct data display
- Test edge cases (empty state, error state)

## Provider Tests

1. **WorkflowState Tests**
   ```dart
   test('WorkflowState correctly tracks current step', () {
     // Create WorkflowState
     // Change steps
     // Verify state updates correctly
   });
   
   test('WorkflowState persists data between steps', () {
     // Create WorkflowState with multi-step data
     // Navigate between steps
     // Verify data integrity
   });
   ```

2. **AuthState Tests**
   ```dart
   test('AuthState correctly handles sign in', () {
     // Mock authentication services
     // Call sign in method
     // Verify state updates
   });
   ```

## Integration Tests

Create integration tests for critical flows:

1. **Complete Receipt Flow**
   - Test the entire receipt creation flow from start to finish
   - Verify all data is correctly saved to database

2. **Receipt Editing Flow**
   - Test editing an existing receipt
   - Verify changes are persisted

## Mocking Strategy

For effective testing:

1. Create standardized mock objects for:
   - FirestoreService
   - AuthService
   - ImageProcessingService

2. Use a consistent approach for mocking providers:
   ```dart
   Widget createWidgetUnderTest({required SomeWidget widget}) {
     return MultiProvider(
       providers: [
         ChangeNotifierProvider<WorkflowState>(
           create: (_) => mockWorkflowState,
         ),
         // Other providers
       ],
       child: MaterialApp(
         home: widget,
       ),
     );
   }
   ```

## Testing Tools and Infrastructure

1. **CI Integration**
   - Run all tests on PR and merge
   - Generate and track coverage reports

2. **Test Helpers**
   - Create helper functions for common test setups
   - Build a library of test fixtures

3. **Visual Regression Tests**
   - Consider adding visual regression tests for critical screens
   - Use golden tests for key components

## Implementation Plan

### Phase 1: Critical Coverage (2 weeks)
- Add tests for the Summary View
- Create WorkflowState tests
- Implement Person and SplitManager calculation tests

### Phase 2: Component Coverage (2 weeks)
- Add tests for all Card components
- Test Workflow steps
- Create Navigation tests

### Phase 3: Integration Coverage (1 week)
- Implement end-to-end flow tests
- Test error handling and recovery

### Phase 4: Edge Cases and Refinement (1 week)
- Test edge cases and error states
- Refine existing tests
- Ensure test documentation is complete

## Best Practices

1. **Use ValueKeys Consistently**
   Every testable UI element should have a unique ValueKey

2. **Test Independence**
   Each test should be independent and not rely on the state of other tests

3. **Focus on Functionality**
   Test what components do, not how they look

4. **Keep Tests Maintainable**
   Break down complex tests into smaller, focused tests

5. **Document Test Intent**
   Include clear comments explaining what each test is verifying

## Conclusion

Implementing this test coverage improvement plan will significantly enhance the reliability and maintainability of the codebase. By focusing on functional validation rather than visual details, the tests will remain valuable through UI redesigns while ensuring the app meets user expectations. 