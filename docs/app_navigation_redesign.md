# Project Progress Summary

**Completed:**
- Firestore emulator successfully seeded with dynamic prompt/model configuration data using a Python script (`init_firestore_config.py`).
- Fixed port conflicts in Firebase emulator configuration in `firebase.json`.
- Fixed validation error in `assign_people_to_items` Cloud Function with updated Pydantic models.
- Created and fully documented data model structure for receipts, drafts, and workflow state.
- Implemented Firebase Emulator integration with environment variable switching.
- Created `FirestoreService` class with emulator support and CRUD operations for receipts.
- Implemented `Receipt` model with Firestore serialization/deserialization.
- Implemented main navigation with bottom tabs (Receipts and Settings).
- Created Receipts screen with filters, search, and FAB.
- Implemented restaurant name input dialog to start the workflow.
- Created the modal workflow controller with 5-step progress indicator.
- Implemented automatic draft saving when exiting the workflow.
- Integrated all workflow screens (upload, review, voice assignment, split, summary).
- Implemented proper data flow between steps with state management.
- App navigation and workflow redesign plan fully documented.

**Pending:**
- Connect final summary screen to the modal workflow.
- Implement handling of draft receipts (resume, edit, delete).
- Connect image upload and thumbnail generation to FirestoreService.
- Implement comprehensive testing (unit, widget, integration).

**Key Notes for Current Session:**
- Use `FirestoreService` for all Firestore operations; it automatically detects whether to use emulator or production.
- The `Receipt` model handles all conversion between Firestore documents and Dart objects.
- Set `USE_FIRESTORE_EMULATOR=true` in `.env` file for local testing with emulator.
- The workflow modal integrates all 5 screens with seamless data flow between them.
- Voice transcription enables automated assignment of items to people in the workflow.
- The split screen allows manual reassignment and sharing of items between people.
- The summary screen provides tax/tip calculations and generates shareable receipt details.
- Progress is automatically saved as a draft when exiting the workflow or leaving the app.

---

# Key Implementation Decisions (as of May 2024)

- **Modal Workflow:** The 5-step receipt workflow is implemented as a full-page modal with automatic draft saving on exit.
- **State Management:** Provider (with ChangeNotifier) is used for in-modal state with memory-only caching during workflow.
- **Drafts and Data Flow:** Workflow state is maintained across steps and automatically persisted to Firestore when exiting the modal or app.
- **Screen Integration:** Existing screens are reused within the modal context with appropriate callbacks to update the workflow state.

---

# App Navigation and Workflow Redesign

## 1. Introduction & Key Goals

This document outlines a significant redesign of the app's navigation and receipt processing workflow, with the following primary objectives:

1. **Enhanced User Experience:** Streamlined navigation with "Receipts" as the central view
2. **Improved Workflow Efficiency:** Converted multi-tab workflow into a transient, full-page modal
3. **Persistent Drafts:** Robust data persistence for saving and resuming workflows
4. **Backend Stability:** Leveraged existing Cloud Functions without immediate modification
5. **Code Quality:** Implemented following best practices for reusability and maintainability

## 2. Core Components

### 2.1. Navigation and UI Transformation

The app's navigation has been simplified to focus on user experience:
- **Bottom Navigation Bar:** Two primary tabs: "Receipts" and "Settings"
- **Receipts Screen:** Central view displaying all receipts with search/filter and FAB
- **Workflow Modal:** 5-step workflow in a full-page modal with step indicator and explicit navigation

### 2.2. Data Model and Persistence Strategy

The core data model follows this structure:

```
users/{userId}/receipts/{receiptId}
  - image_uri: String  // Image reference
  - thumbnail_uri: String  // Thumbnail reference
  - parse_receipt: Map  // Receipt parsing data
  - transcribe_audio: Map  // Voice transcription data
  - assign_people_to_items: Map  // Person-to-item assignments
  - split_manager_state: Map  // Final split calculations
  - metadata: Map {
      - created_at, updated_at: Timestamp
      - status: String  // "draft" or "completed"
      - restaurant_name: String
      - people: Array<String>
      - tip, tax: Float
    }
```

**Key Persistence Notes:**
- In-workflow data is cached in memory with Provider
- Data is only persisted on explicit actions (save/complete/exit)
- Drafts are fully manageable from the Receipts screen

## 3. Implementation Overview

### 3.1 Core Components

1. **FirestoreService** (`lib/services/firestore_service.dart`) - Handles all CRUD operations with emulator support
2. **Receipt Model** (`lib/models/receipt.dart`) - Data structure with Firestore serialization
3. **Receipts Screen** - Central UI with tabs, filters and FAB
4. **Modal Workflow** - Full-page with 5-step indicators

### 3.2 Environment and Emulator Support

- **Environment Variables:** `.env` file with `USE_FIRESTORE_EMULATOR=true` for local testing
- **Automatic Detection:** FirestoreService checks environment and connects accordingly
- **Ports:** Firestore on 8081, Storage on 9199

### 3.3 Cloud Function Updates

The updated `assign_people_to_items` function now returns a more structured format:

```json
{
  "data": {
    "assignments": [
      {
        "person_name": "Person1",
        "items": [
          {
            "name": "Item Name",
            "price": 10.0,
            "quantity": 1
          }
        ]
      }
    ],
    "shared_items": [...],
    "unassigned_items": [...]
  }
}
```

**Key Updates:**
- Changed from `Dict[str, List[ItemDetail]]` to `List[PersonItemAssignment]` for better validation
- Added `person_name` field to each assignment for clarity
- Uses "name" instead of "item" field for items

## 4. UI Mockups

### Main Receipts Screen with FAB

```
┌─────────────────────────────────────────────────┐
│  Receipts                         🔍 Search      │
├─────────────────────────────────────────────────┤
│ Filters: ○ All  ● Completed  ○ Drafts          │
│                                                 │
│ ┌─────────────────────────────────────────────┐ │
│ │ Restaurant Name           $75.50   03/15/23 │ │
│ │ [Receipt thumbnail]       4 people    ⋮     │ │
│ └─────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────┐ │
│ │ Grocery Store            $45.20   03/10/23  │ │
│ │ [Receipt thumbnail]       2 people    ⋮     │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│                      ⊕                         │
│                                                 │
└─────────────────────────────────────────────────┘
┌─────────────────────────┬─────────────────────────┐
│        Receipts         │        Settings         │
└─────────────────────────┴─────────────────────────┘
```

### Workflow Modal

```
┌─────────────────────────────────────────────────┐
│ ●───○───○───○───○                               │
│ Upload  Review  Assign  Split  Summary          │
├─────────────────────────────────────────────────┤
│                                                 │
│                                                 │
│            Current Step Content                 │
│            (Leveraging existing screens)        │
│                                                 │
│                                                 │
├─────────────────────────────────────────────────┤
│    ← Back         [Save & Exit to Draft]         Next →         │
└─────────────────────────────────────────────────┘
```

## 5. Implementation Status and Next Steps

### 5.1 Completed Components

1. **FirestoreService & Receipt Model**
   - Complete CRUD operations with emulator support
   - Serialization/deserialization with Firestore

2. **Main Navigation & Receipts Screen**
   - Bottom navigation bar with tabs
   - Receipts listing with filters and search

3. **Workflow Modal Framework**
   - Restaurant name dialog prompt
   - Modal scaffold with step indicator
   - Navigation between steps
   - Automatic draft saving on exit

4. **Screen Integration**
   - Receipt upload screen with camera/gallery picker
   - Receipt review screen with item editing
   - Voice assignment screen with transcription and item assignment
   - Split screen with item sharing and assignment management
   - Final summary screen with tax/tip calculation and receipt sharing
   - Real-time state updates between steps
   - Data conversion between workflow state and screen models

### 5.2 Next Implementation Phases

1. **Draft Management** (Next Phase)
   - Resume from draft
   - Edit completed receipts
   - Delete receipts
   - End-to-end testing

### 5.3 Expected Review Checkpoints

1. **After Screen Integration:**
   - Complete workflow from upload to summary
   - Data passing correctly between steps
   - Draft saving and completion working

2. **After Draft Management:**
   - Resume functionality working
   - Edit and delete options functional
   - Full testing with emulator

## 6. Emulator Setup Guide

For local development and testing, the Firebase Emulator Suite provides a local environment for Firestore, Functions, and other Firebase services.

### Quick Start

1. Ensure `.env` file has `USE_FIRESTORE_EMULATOR=true`
2. Start emulators with `firebase emulators:start`
3. Seed with test data: `cd functions && python init_firestore_config.py --admin-uid=admin --cred-path=your-key.json --seed-data-dir=../emulator_seed_data`

### Troubleshooting

- **Port Conflicts**: Edit `firebase.json` to use different ports
- **Access Issues**: Make sure environment variables are set correctly
- **Data Not Appearing**: Check emulator UI at `http://localhost:4000`

## 7. Project Structure

```
splitting_sucks/
├── lib/
│   ├── models/
│   │   ├── receipt.dart           # New Receipt model
│   │   ├── receipt_item.dart      # Receipt item model
│   │   ├── person.dart            # Person model
│   │   └── split_manager.dart     # Split operations manager
│   ├── screens/
│   │   ├── main_navigation.dart   # New bottom navigation
│   │   ├── receipts_screen.dart   # New receipts listing
│   │   └── existing screens...    # To be integrated
│   ├── services/
│   │   ├── firestore_service.dart # New Firestore service
│   │   └── existing services...   # Auth, parsing, etc.
│   └── main.dart                  # Entry point
├── functions/                     # Cloud Functions
├── emulator_seed_data/            # Emulator configurations
└── .env                           # Environment variables
``` 