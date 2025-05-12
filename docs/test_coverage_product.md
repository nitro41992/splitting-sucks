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
| **People Assignment Screen** | 🔴 None | 🔴 High | 🔴 High |
| **Bill Splitting Calculations** | 🔴 None | 🔴 High | 🔴 High |
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

**Backend Operations**
- All cloud functions (image processing, receipt parsing, etc.)
- Data models and how they're stored

### ⏳ Top Priority Tests Needed

**1. People Assignment Screen** (HIGH PRIORITY)
- How users add and remove people from the receipt
- How items get assigned to different people
- This is critical because UI redesign will change how this screen looks, and offline caching will change how assignment data is saved

**Detailed Assignment Screen Features Needing Tests:**
- **Voice recording and transcription** - ensuring audio can be recorded and properly transcribed
- **Manual transcription editing** - verifying users can edit transcribed text
- **Processing assignments from transcription** - confirming the right people are matched to the right items
- **UI for reviewing and adjusting assignments** - testing that assignments can be manually corrected
- **Data persistence** - making sure assignments are saved correctly in WorkflowState and can be restored

**2. Bill Splitting Screen** (HIGH PRIORITY)
- How tip and tax are calculated and distributed
- How the final split amounts are determined
- This is important because calculation logic must remain accurate after UI changes and when working offline

**3. Image Handling in Offline Mode** (MEDIUM PRIORITY)
- How receipt images are stored when offline
- How thumbnails are generated
- Only critical if we're changing how images are handled in the redesign

**4. Confirmation Dialogs and Error Handling** (MEDIUM PRIORITY)
- Testing what happens when users confirm or cancel important actions
- How errors are displayed to users

## What This Means for Product Timeline

**Before UI Redesign Can Start:**
- We need at least basic tests for the People Assignment Screen
- We should have tests for the Bill Splitting Screen
- Without these, redesigning these screens is risky

**Before Offline Caching Can Launch:**
- We need thorough tests for data flows across all screens
- We should test what happens when network connection is lost during use

## Implementation Plan

### Phase 1: Assignment Screen Tests (2-3 days)
1. Create test for AssignStepWidget rendering and VoiceAssignmentScreen
2. Test voice recording and transcription process
3. Test manual assignment of people to items
4. Test data flow to WorkflowState

### Phase 2: Split Screen Tests (2-3 days)
1. Create tests for SplitStepWidget UI and calculations
2. Test tip and tax distribution
3. Test per-person totals accuracy
4. Test data flow between screens

### Phase 3: Proceed with UI Redesign with Confidence
Once these tests are in place, UI redesign can proceed with much lower risk

## How to Use This Guide

Use this document to understand test coverage when planning feature work. Areas with less test coverage will be riskier to change and should be approached more carefully. 