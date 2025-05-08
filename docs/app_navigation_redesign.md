# App Navigation and Workflow Redesign

> **Note:** For current implementation status, see companion document: `docs/implementation_plan.md`

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
  - parse_receipt: Map  // Receipt parsing data
  - transcribe_audio: Map  // Voice transcription data
  - assign_people_to_items: Map  // Person-to-item assignments
  - split_manager_state: Map  // Final split calculations
  - metadata: Map {
      - image_uri: String  // Image reference
      - thumbnail_uri: String  // Thumbnail reference
      - created_at, updated_at: Timestamp
      - status: String  // "draft" or "completed"
      - restaurant_name: String
      - people: Array<String>
      - tip, tax: Float
    }
```

**Key Persistence Notes:**
- In-workflow data is cached in memory with Provider (WorkflowState)
- Data is only persisted on explicit actions (save/complete/exit)
- Drafts are fully manageable from the Receipts screen
- **Workflow Interruption Confirmations:** To prevent accidental data loss, confirmation dialogs will prompt the user if an action (e.g., re-uploading an image after parsing, re-transcribing, navigating backward to a data-entry step after subsequent data exists) would discard data from later steps. If confirmed, relevant subsequent data is cleared.

## 3. Implementation Overview

### 3.1 Core Components

1. **FirestoreService** (`lib/services/firestore_service.dart`) - Handles all CRUD operations with emulator support
2. **Receipt Model** (`lib/models/receipt.dart`) - Data structure with Firestore serialization
3. **Receipts Screen** - Central UI with tabs, filters and FAB
4. **Modal Workflow** - Full-page with 5-step indicator and navigation

### 3.2 Environment and Emulator Support

- **Environment Variables:** `.env` file with `USE_FIRESTORE_EMULATOR=true` for local testing
- **Automatic Detection:** FirestoreService checks environment and connects accordingly
- **Ports:** Firestore on 8081, Storage on 9199

### 3.3 Cloud Function Interface

The updated `assign_people_to_items` function returns this structured format:

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

**Key Requirements:**
- Changed from `Dict[str, List[ItemDetail]]` to `List[PersonItemAssignment]` for better validation
- Added `person_name` field to each assignment for clarity
- Uses "name" instead of "item" field for items

## 4. UI Mockups and Implementation

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
**Modal Behavior Notes:**
- Automatic draft saving on exit.
- Step indicator shows current progress.
- Navigation is primarily linear (Next/Back), but users can tap step indicators (logic TBD, may also need confirmations).
- Confirmation dialogs appear if navigating backward or re-initiating a prior step (e.g., re-uploading image, re-transcribing) would cause loss of data from subsequent steps. If the user confirms, subsequent data is cleared before proceeding.

## 5. Key Implementation Decisions

- **Modal Workflow:** The 5-step receipt workflow as a full-page modal with automatic draft saving on exit
- **State Management:** Provider (with ChangeNotifier) for in-modal state with WorkflowState class
- **Split Manager:** SplitManager class handles tax/tip calculations and item assignments
- **Drafts and Data Flow:** Workflow state maintained across steps and persisted to Firestore on exit
- **Screen Integration:** Existing screens reused within the modal context with callbacks to update workflow state
- **Component Interfaces:** Consistent parameter interfaces between workflow components ensure proper data flow
  - ReceiptUploadScreen handles null-safety for image files
  - ReceiptReviewScreen receives and returns properly formatted receipt items
  - VoiceAssignmentScreen manages transcription state with proper callbacks
  - SplitView and FinalSummaryScreen use consistent data models for calculations

## 6. Project Structure

```
splitting_sucks/
├── lib/
│   ├── models/
│   │   ├── receipt.dart           # Receipt model with Firestore serialization
│   │   ├── receipt_item.dart      # Receipt item model
│   │   ├── person.dart            # Person model
│   │   └── split_manager.dart     # Split operations manager
│   ├── screens/
│   │   ├── main_navigation.dart   # Bottom tab navigation
│   │   ├── receipts_screen.dart   # Receipts listing with filters/search
│   │   ├── receipt_upload_screen.dart # Image upload
│   │   ├── receipt_review_screen.dart # Item review and editing
│   │   ├── voice_assignment_screen.dart # Voice transcription
│   │   ├── final_summary_screen.dart # Final summary with tip/tax
│   │   └── workflow_modal.dart    # Modal workflow controller
│   ├── services/
│   │   ├── firestore_service.dart # CRUD operations with emulator support
│   │   └── receipt_parser_service.dart # Receipt parsing service
│   ├── widgets/
│   │   ├── split_view.dart        # Split management interface
│   │   ├── cards/                 # Reusable card components
│   │   ├── dialogs/               # Dialog components
│   │   ├── final_summary/         # Summary-specific widgets
│   │   ├── receipt_review/        # Review-specific widgets
│   │   ├── receipt_upload/        # Upload-specific widgets
│   │   └── shared/                # Shared UI components
│   └── main.dart                  # Entry point
├── functions/                     # Cloud Functions
├── emulator_seed_data/            # Emulator configurations
└── .env                           # Environment variables
```

## 7. Future Enhancements

- **Receipt Editing:** Enable advanced editing of completed receipts
- **Comprehensive Testing:** Add unit, widget, and integration tests
- **Performance Optimization:** Implement image caching and pagination 
- **UI Improvements:** Add animations and transitions for smoother user experience
- **Multi-user Collaboration:** Allow multiple users to work on the same receipt 