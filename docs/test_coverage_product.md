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
| **People Assignment Screen** | 🟢 High | 🟢 Low | 🟢 Low |
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
- Assigning people to items and managing people
- Calculating bill splits including tax and tip distribution

**Backend Operations**
- All cloud functions (image processing, receipt parsing, etc.)
- Data models and how they're stored

### ⏳ Top Priority Tests Needed

**1. People Assignment Screen** ✅ COMPLETED
- Tests now verify:
  - Users can add and remove people from the receipt
  - Items can be assigned to different people
  - Navigation between workflow steps works correctly
  - Data flows correctly between components

**2. Bill Splitting Screen** ✅ COMPLETED
- Tests now verify:
  - Tip and tax are calculated and distributed correctly
  - Final split amounts are determined accurately
  - Complex scenarios with shared items work properly
  - Edge cases like removing people after assignments are handled correctly

**3. Image Handling in Offline Mode** (MEDIUM PRIORITY)
- How receipt images are stored when offline
- How thumbnails are generated
- Only critical if we're changing how images are handled in the redesign

**4. Confirmation Dialogs and Error Handling** (MEDIUM PRIORITY)
- Testing what happens when users confirm or cancel important actions
- How errors are displayed to users

## What This Means for Product Timeline

**UI Redesign Can Now Proceed with Confidence:**
- ✅ Tests for the People Assignment Screen are complete
- ✅ Tests for the Bill Splitting Screen are complete
- The core functionality is now well-tested, making UI redesign much less risky

**Before Offline Caching Can Launch:**
- We still need to implement tests for image handling in offline mode
- We should test what happens when network connection is lost during use

## Implementation Plan

### Phase 1: Assignment Screen Tests ✅ COMPLETED
1. ✅ Created tests for AssignStepWidget rendering
2. ✅ Tested person management (add/remove/rename)
3. ✅ Tested manual assignment of people to items
4. ✅ Tested data flow to WorkflowState

### Phase 2: Split Screen Tests ✅ COMPLETED
1. ✅ Created tests for SplitStepWidget UI and calculations
2. ✅ Tested tip and tax distribution
3. ✅ Verified per-person totals accuracy
4. ✅ Tested advanced scenarios with shared items
5. ✅ Validated edge cases like removing assigned people

### Phase 3: Proceed with UI Redesign with Confidence
With core functionality tests now in place, UI redesign can proceed with much lower risk.

### Phase 4: Image Handling Tests (For Offline Caching)
1. Implement tests for offline image storage
2. Verify thumbnail generation and retrieval
3. Test synchronization when returning online

## How to Use This Guide

Use this document to understand test coverage when planning feature work. Areas with less test coverage will be riskier to change and should be approached more carefully. 