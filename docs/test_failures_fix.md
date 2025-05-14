# Test Failures Fix Plan

This document tracks the plan for fixing failing tests after the major UI redesign and subsequent bug fixes.

## Failing Tests

1.  **Test File:** `test/widgets/workflow_steps/split_step_widget_test.dart`
    *   **Test Description:** `SplitStepWidget Tests pressing Done button only pops dialog once and does not crash`
    *   **Error:** `Expected: exactly one matching candidate Actual: _AncestorWidgetFinder:<Found 0 widgets with type "ElevatedButton" that are ancestors of widgets with text "Done": []> Which: means none were found but one was expected`
    *   **Hypothesis:** The "Done" button was no longer an `ElevatedButton` due to redesign (became a FAB).
    *   **Fix Applied:**
        1.  Modified `_SplitStepWidgetState`'s `dispose` method to call `widget.onClose?.call()`.
        2.  Updated the test to push `SplitStepWidget` as a `MaterialPageRoute`.
        3.  Changed button finder to `find.byTooltip('Done')`.
        4.  Verified route pop and `onCloseCalled` flag.
    *   **Status:** FIXED

2.  **Test File:** `test/services/firestore_service_test.dart`
    *   **Test Description:** `Firebase Storage Tests generateThumbnail calls Firebase Function and returns thumbnail URI`
    *   **Current Error:** Compilation Failure during `flutter test`.
        *   `Error: Couldn't resolve the package 'firebase_functions' in 'package:firebase_functions/firebase_functions.dart'.`
        *   `test/services/firestore_service_test.dart:16:8: Error: Not found: 'package:firebase_functions/firebase_functions.dart'`
        *   Dependent errors: `FirebaseFunctions` isn't a type, `HttpsCallable` isn't a type, `HttpsCallableResult` not found.
    *   **Original Error:** `Generic error calling generate_thumbnail function: [core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()`
    *   **Fix Attempted (Blocked by Compilation Error):** 
        1.  Refactored `FirestoreService` to allow injection of a `FirebaseFunctions` instance.
        2.  Implemented behavioral mocking for `FirebaseFunctions` and `HttpsCallable` in `test/services/firestore_service_test.dart` using `mockito` and `noSuchMethod`.
    *   **Status:** FAILING (Compilation Error - Package not found)

## Next Steps

1.  **Resolve `package:firebase_functions` import issue:** This is the highest priority.
2.  Re-run tests to see if `firestore_service_test.dart` compiles and if the `generateThumbnail` test passes with the behavioral mock.
3.  Identify and address the remaining (currently 18, but this number might change after the compilation fix) failing tests based on the `flutter test` output.
    *   Potential areas from `grep` output: `_Completer.completeError` messages, tests in `test/providers/workflow_state_test.dart`. 