# Billfie App Test Coverage: Product Guide

## What's This Document?
This guide explains which parts of the Billfie app have automated tests and which parts still need them. Think of tests as safety nets that catch bugs before they reach users.

## Why Testing Matters for Our Current Projects
We're planning two big changes:
1. **UI Redesign**: Making the app look better and more user-friendly
2. **Local Caching**: Allowing the app to work offline and sync later

Without proper tests, these changes could break existing features. Tests help us change the app confidently.

## Test Coverage Status at a Glance

| Feature Area | Coverage | UI Redesign Risk | Offline Caching Risk |
|--------------|----------|------------------|----------------------|
| Receipt CRUD Operations | 🟢 High | 🟢 Low | 🟡 Medium |
| Image Upload & Display | 🟢 High | 🟢 Low | 🟡 Medium |
| Receipt Review & Item Editing | 🟢 High | 🟢 Low | 🟢 Low |
| Navigation Between Steps | 🟢 High | 🟢 Low | 🟢 Low |
| **People Assignment Screen** | 🟢 High | 🟢 Low | 🟡 Medium |
| **Bill Splitting Calculations** | 🟢 High | 🟢 Low | 🟢 Low |
| Cloud Functions | 🟢 High | 🟢 Low | 🟢 Low |
| Image Storage & Retrieval | 🟡 Medium | 🟢 Low | 🔴 High |
| Confirmation Dialogs | 🟡 Partial | 🟡 Medium | 🟡 Medium |

**Legend:**
- 🟢 Good shape - low risk
- 🟡 Some concerns - medium risk
- 🔴 Needs attention - high risk

## Current Test Status (Product View)

### ✅ Already Well-Tested

**Basic App Functions**
- Creating, updating, and deleting receipts in the database
- Uploading receipt images 
- Reviewing and editing receipt items
- Moving between workflow steps (navigation)
- Bill splitting calculations (including tax and tip distribution)
- People assignment screen (fixed and now well-tested)

**Backend Operations**
- All cloud functions (image processing, receipt parsing, etc.)
- Data models and how they're stored

### ⚠️ Tests in Progress

**Split Screen Tests**
- Tests need to be updated with our improved Firebase mocking approach
- This is the next immediate priority

**Image Storage Tests**  
- Tests for Firebase Storage-related methods have been implemented
- Need additional work to properly mock storage functionality

### ⏳ Top Priority Tests Needed

**1. Fix Split Screen Tests**
- Apply the same pattern used to fix the Assignment Screen tests
- Ensure proper mocking of Firebase dependencies

**2. Bill Splitting Screen** ✅ COMPLETED
- Tests now verify:
  - Tip and tax are calculated and distributed correctly
  - Final split amounts are determined accurately
  - Complex scenarios with shared items work properly
  - Edge cases like removing people after assignments are handled correctly

**3. Summary Screen Tests** (NEW PRIORITY)
- Need to implement tests for the final screen showing the split summary
- Verify total calculations and displays are accurate

**4. Image Handling in Offline Mode** (MEDIUM PRIORITY)
- How receipt images are stored when offline
- How thumbnails are generated
- Only critical if we're changing how images are handled in the redesign

**5. Confirmation Dialogs and Error Handling** (MEDIUM PRIORITY)
- Testing what happens when users confirm or cancel important actions
- How errors are displayed to users

## What This Means for Product Timeline

**UI Redesign Is Now Ready to Proceed:**
- ✅ Tests for the Bill Splitting logic are complete and passing
- ✅ Tests for the People Assignment Screen are fixed and passing
- ⚠️ Split Screen tests need similar updates but core calculation logic is well-tested
- Our calculation logic is well-tested, making the redesign less risky
- We can proceed with the UI redesign with confidence in the core functionality

**Before Offline Caching Can Launch:**
- We need to complete the Split Screen test fixes
- We need to finalize the Image Storage tests
- We should test what happens when network connection is lost during use

## Implementation Plan

### Phase 1: Complete Firebase Testing Improvements ✅ MOSTLY COMPLETED
1. ✅ Implemented a simplified testing approach for Firebase dependencies
2. ✅ Made AssignStepWidget tests fully operational
3. ⏳ Apply the same approach to SplitStepWidget tests

### Phase 2: Assignment Screen Tests ✅ COMPLETED
- ✅ Tests have been written and fixed
- ✅ Firebase initialization issues resolved
- ✅ Return type mismatches corrected

### Phase 3: Split Screen Tests ⏳ IN PROGRESS
1. ✅ Created tests for SplitManager model and advanced scenarios
2. ✅ Tested tip and tax distribution
3. ✅ Verified per-person totals accuracy
4. ✅ Tested advanced scenarios with shared items
5. ✅ Validated edge cases like removing assigned people
6. ⏳ Apply Firebase mocking approach to widget tests

### Phase 4: Proceed with UI Redesign with Confidence
With core calculation tests in place and assignment tests now fixed, we can proceed with UI redesign confidently. The Split Screen tests still need updates but the underlying calculation logic is well-tested.

### Phase 5: Image Handling Tests (For Offline Caching)
1. Implement tests for offline image storage
2. Verify thumbnail generation and retrieval
3. Test synchronization when returning online

## How to Use This Guide

Use this document to understand test coverage when planning feature work. Areas with less test coverage will be riskier to change and should be approached more carefully. 