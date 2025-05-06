# Project Progress Summary

**Completed:**
- Firestore emulator successfully seeded with dynamic prompt/model configuration data using a Python script (`init_firestore_config.py`).
- App navigation and workflow redesign plan documented, including:
  - Bottom navigation bar structure (Receipts, Settings)
  - Centralized Receipts screen with FAB for adding receipts
  - Workflow modal design for the 5-step receipt process
  - Detailed data model and persistence strategy for receipts, drafts, and workflow state
  - Cloud Function and backend integration strategy
  - Security and best practices outlined

**Pending:**
- Implementation of redesigned UI components in Flutter (navigation bar, Receipts screen, workflow modal, etc.)
- Firestore service methods for CRUD operations and auto-save logic
- Draft management (save, resume, edit, delete) in the app
- Integration of image upload, thumbnail generation, and caching
- Connecting UI to backend (Cloud Functions, Firestore persistence)
- Widget and logic reusability refactor as per new design
- Comprehensive testing (unit, widget, integration)

---

# App Navigation and Workflow Redesign

## 1. Introduction & Key Goals

This document outlines a significant redesign of the app's navigation and receipt processing workflow. The primary objectives are to:

1.  **Enhance User Experience:** Streamline navigation by making "Receipts" the central view and introducing a more intuitive "Add Receipt" flow.
2.  **Improve Workflow Efficiency:** Convert the existing multi-tab workflow into a transient modal, maintaining current in-memory caching within the flow for responsiveness.
3.  **Enable Persistent Drafts:** Implement robust data persistence, allowing users to save incomplete receipts as drafts and resume them later. This involves storing the workflow's cached state to Firestore upon exiting the modal or the app.
4.  **Maintain Backend Stability:** Leverage existing backend Cloud Functions without immediate modification, ensuring a phased rollout.
5.  **Uphold Code Quality:** Implement all changes following best coding practices, focusing on reusability, clarity, and maintainability.

## 2. Core Redesign Pillars

### 2.1. Navigation and UI Transformation

The app's navigation will be simplified for a more focused user experience:

*   **Main Navigation:**
    *   A **Bottom Navigation Bar** with two primary items: "Receipts" and "Settings".
    *   A **Floating Action Button (FAB)** for "Add Receipt" to initiate the new receipt workflow.
*   **Receipts Screen (Primary View):**
    *   Displays a list of all saved receipts (both completed and drafts).
    *   Features search and filter capabilities.
    *   Allows users to select receipts for viewing details or editing drafts.
    *   The FAB for adding new receipts will be prominently displayed here.
*   **Workflow Modal (Transient Flow):**
    *   The current 5-step workflow (Upload, Review, Assign, Split, Summary) will be encapsulated within a **transient modal dialog**.
    *   A **step indicator** at the top of the modal will replicate the functionality of the current tab navigation, guiding users through the process.
    *   Progression logic (Back/Next navigation) within the modal remains consistent with the current app.
    *   **Existing in-memory caching between steps within the modal flow will be maintained** to ensure a smooth and fast user experience while actively working on a receipt.
    *   The modal will provide options to "Save and Exit" (creating/updating a draft) or "Cancel".

*(Refer to Section 6: UI Mockups for visual representations.)*

### 2.2. Data Model and Persistence Strategy

A robust data model and a clear persistence strategy are crucial for enabling drafts, ensuring data integrity, and supporting scalability.

**Data Model Definition:**

```
users/{userId}/receipts/{receiptId}
  - image_uri: String  // Image reference for the receipt
  - thumbnail_uri: String  // Cached thumbnail reference for fast loading
  - parse_receipt: Map  // Direct output from parse_receipt function (each item includes name, quantity, price)
  - transcribe_audio: Map  // Output from voice transcription function
  - assign_people_to_items: Map {
      - assignments: Map<String, List<Map>> {  // Person name to items
          "<person_name>": [
            {"name": "<item_name>", "quantity": <integer>, "price": <float>}
          ]
        }
      - shared_items: List<Map> [
          {"name": "<item_name>", "quantity": <integer>, "price": <float>, "people": ["person1", "person2"]}
        ]
      - unassigned_items: List<Map> [
          {"name": "<item_name>", "quantity": <integer>, "price": <float>}
        ]
    }
  - split_manager_state: Map  // Final app state with all calculations
  - metadata: Map {
      - created_at: Timestamp
      - updated_at: Timestamp
      - status: String  // "draft" or "completed"
      - restaurant_name: String  // Required when completed
      - people: Array<String>  // List of people involved (for search)
    }
```

**Key Aspects of the Data Model:**

*   **Raw Function Outputs:** Initially stores direct outputs from existing Cloud Functions to ensure backward compatibility and minimize immediate backend changes. For `assign_people_to_items`, the structure shown is the target detailed format. The current cloud function might output a more generic `Map`; the client application may need to adapt this, or the function will be updated later.
*   **User-Centric:** All receipt data is linked to a specific user.
*   **Metadata for Efficiency:** Includes essential metadata (`status`, `restaurant_name`, `people`) for list display, filtering, and search functionalities on the "Receipts" screen.

**Caching, Persistence, and Scalability:**

This strategy is designed for both a responsive UI and scalable data management, avoiding hacky solutions by clearly defining when data is cached versus persisted:

1.  **In-Modal Caching (Performance):** While a user is actively in the workflow modal, data (e.g., OCR results, user edits to items, assignments) is cached in memory. This allows for instant screen transitions and interactions within the modal without constant database reads/writes. This maintains the current workflow's performant caching.
2.  **Auto-Save to Firestore (Data Integrity & Drafts):**
    *   **After Cloud Function Calls:** Results from each Cloud Function (`parse_receipt`, `transcribe_audio`, `assign_people_to_items`) are immediately saved to the corresponding fields in the Firestore `receipt` document.
    *   **After User Edits:** Any modifications made by the user within a step (e.g., editing item names/prices in Review, correcting transcriptions, changing assignments) are also saved to Firestore, updating the relevant fields (`parse_receipt`, `transcribe_audio`, `assign_people_to_items`, `split_manager_state`).
    *   **On Workflow Exit (Draft Creation):** If the user explicitly saves and exits the modal, or exits the app mid-workflow, the **current in-memory cached state of the entire workflow is persisted to Firestore**. The `metadata.status` is set to "draft". This ensures no data loss and allows the user to resume seamlessly. This is a critical step for scalability, as it prevents re-processing from scratch if a user returns to a draft.
3.  **`receiptId` Consistency:** A consistent `receiptId` is used throughout the workflow (from initiation in the modal to all Firestore operations) to ensure updates are applied to the correct document.
4.  **Scalability Benefits:**
    *   Reduces redundant AI function calls by saving intermediate results.
    *   Allows users to resume complex splits without starting over, improving user satisfaction.
    *   Firestore's scalability handles the storage of individual receipt documents efficiently.

**Preserving User Edits:**

The data model and persistence logic ensure all user modifications are saved:

*   **Receipt Item Edits:** Changes to item names, prices, quantities in the Review screen update `parse_receipt`.
*   **Transcription Edits:** Corrections to transcribed text update `transcribe_audio`.
*   **Assignment Modifications:** Changes to people, item assignments, shared/unassigned items, and sharing proportions update `assign_people_to_items` and potentially `split_manager_state`.
*   **Final Calculation Adjustments:** Modifications to tax, tip, etc., update `split_manager_state`.

**Guidance for `functions/main.py` (Pydantic Models):**

(This subsection remains largely the same as your previous version, detailing how Pydantic models should evolve, ensuring current functions are not broken while new structures are adopted for storage.)

1.  **Existing Function Outputs:** Current Cloud Functions (e.g., `assign_people_to_items`) continue outputting their existing data structure. Pydantic models for *responses* of these specific functions should *not* change yet.
2.  **Client-Side Handling (Flutter App):** The Flutter app will save data to Firestore (drafts or completed receipts) using the *new, detailed structure* for fields like `assign_people_to_items`. When reading, it expects this new structure.
3.  **New/Updated Functions Reading from Firestore:** Any *new* Cloud Functions, or existing ones updated to process stored receipt documents, will need Pydantic models reflecting the *new, detailed structure* as stored by the app.
4.  **Pydantic Models for New Structure (Conceptual):**
    ```python
    from typing import List, Dict, Any
    from pydantic import BaseModel, Field

    class ItemDetail(BaseModel):
        name: str
        quantity: int
        price: float

    class SharedItemDetail(BaseModel):
        name: str
        quantity: int
        price: float
        people: List[str]

    class AssignPeopleToItems(BaseModel):
        assignments: Dict[str, List[ItemDetail]] = Field(default_factory=dict)
        shared_items: List[SharedItemDetail] = Field(default_factory=list)
        unassigned_items: List[ItemDetail] = Field(default_factory=list)
    ```
This allows the Flutter app to use the richer data model in Firestore immediately, while Cloud Functions evolve.

### 2.3. Efficient Image Handling

To ensure fast loading and a smooth experience, especially on the "Receipts" list:

1.  **Thumbnail Generation:** Generate a smaller thumbnail when the receipt image is first uploaded. Store it in Firebase Storage alongside the original. References to both are saved in the receipt document.
2.  **Image Caching (Local):** Use Flutter's `cached_network_image` (or similar) for local caching of thumbnails. Pre-cache visible thumbnails in lists. Use a memory cache for recently viewed full receipts.
3.  **Lazy Loading:** Load thumbnails on-demand when scrolling. Load full-resolution images only when viewing receipt details.

## 3. Implementation Roadmap & Best Practices

### 3.1. Guiding Coding Principles

Development should adhere to best practices to ensure a high-quality, maintainable, and scalable application:

*   **Non-Duplication (DRY - Don't Repeat Yourself):** Abstract common logic into reusable functions, services, and widgets.
*   **Reusability:** Design components (UI and logic) to be adaptable for different contexts. For instance, the existing workflow screens should be reused within the new modal container with minimal changes.
*   **Clean Code & Readability:** Write clear, concise, and well-documented code. Break down large code files and complex widgets into smaller, manageable units.
*   **Modularity:** Structure the codebase into logical layers (UI, services, state management, models) to improve separation of concerns.
*   **Testability:** Write code that is easy to test, including unit tests for logic and widget tests for UI components.
*   **Scalability:** Design with future growth in mind, particularly for data handling and asynchronous operations. The described caching and persistence strategy is a core part of this.
*   **No Hacky Solutions:** Avoid temporary fixes or workarounds that compromise code quality or long-term stability.

### 3.2. Key Implementation Tasks

1.  **Navigation & Core UI Shell:**
    *   Implement the 2-item Bottom Navigation Bar (Receipts, Settings).
    *   Create the main "Receipts" screen (list view, search/filter placeholders).
    *   Add the global Floating Action Button for initiating the receipt workflow.
2.  **Workflow Modal Implementation:**
    *   Develop the modal container to host the existing 5 workflow screens.
    *   Implement the step indicator navigation within the modal.
    *   Ensure smooth transitions between steps, leveraging existing screen logic.
    *   Implement "Save & Exit" (to draft) and "Cancel" functionalities.
3.  **Firestore Persistence & Services:**
    *   Develop service methods for creating, reading, updating, and deleting receipt documents in Firestore.
    *   Implement the auto-save logic:
        *   After each Cloud Function result is received by the client.
        *   After user edits within each step of the workflow.
        *   Crucially, on modal exit (saving the complete cached state as a draft if not completed).
4.  **Receipt Management Features:**
    *   Populate the "Receipts" screen list with data from Firestore (drafts and completed).
    *   Implement receipt detail view.
    *   Enable editing of "draft" receipts (re-opening the modal pre-filled with stored data).
    *   Implement delete functionality for receipts.
5.  **Image Handling:**
    *   Integrate thumbnail generation (client-side or via a new lightweight function if necessary).
    *   Implement image uploading to Firebase Storage (original and thumbnail).
    *   Set up local image caching and lazy loading in the UI.

## 4. Cloud Function Development and Deployment Strategy

(This section remains largely the same as your previous version, detailing local testing with Emulator Suite, dedicated Firebase projects, dev workflow, promotion to production, version control with Git, environment configuration, and managing function changes, including the handling of dynamic prompts.)

To manage changes to Cloud Functions effectively and avoid impacting the production environment, the following strategy is recommended:

1.  **Local Development and Testing (Firebase Emulator Suite):**
    *   Utilize the Firebase Emulator Suite for local development and testing of Cloud Functions ([Firebase Documentation](https://firebase.google.com/docs/functions/get-started#emulate_execution_of_your_functions)).
    *   This allows you to run and debug your functions, including those triggered by Firestore, Authentication, and HTTP requests, on your local machine. The **Emulator UI (usually at `http://localhost:4000`)** provides a way to inspect and manage emulated services like Firestore.
    *   **Testing Prompts and Configuration:** If your functions fetch dynamic configurations (like prompts for AI services that dictate JSON structure, as managed by `config_helper.py`), you will also run the emulators for the services hosting this configuration (e.g., Firestore Emulator, Remote Config Emulator).
        *   You will need to **seed these emulated services with the development/test versions of your prompts/configurations**. These test configurations should align with any local changes to your Pydantic models or other code that expects specific structures.
        *   The Firebase SDKs used in your functions (and `config_helper.py`) will automatically connect to these emulated services when the emulators are active, ensuring your local tests use your local configurations.
    *   Testing locally significantly reduces the risk of errors that could affect live data or incur costs.

2.  **Dedicated Firebase Projects (Dev/Staging and Production):**
    *   **Production Project:** Your current live Firebase project.
    *   **Development/Staging Project:** Create a separate, new Firebase project for development and staging.
    *   Configure your Flutter app to target the appropriate Firebase project based on the build environment.

3.  **Development Workflow:**
    *   Develop and test functions locally with the Emulator Suite.
    *   Deploy to the dev/staging Firebase project for integration testing.

4.  **Promotion to Production:**
    *   After successful staging, deploy to the production Firebase project using Firebase CLI project aliases or direct project ID specification.

5.  **Version Control (Git):**
    *   Maintain Cloud Function code in Git, using branches for features/fixes.
    *   Merge to `develop`/`staging` branches for dev/staging deployment, and to `main`/`production` for production deployment.
    *   **Consider versioning your prompt seed files or Remote Config templates alongside your function code if they are tightly coupled.**

6.  **Environment Configuration for Functions:**
    *   Use Firebase's environment configuration (`functions.config()`) for API keys, service URLs, etc., that differ between environments.
    *   Set via Firebase CLI: `firebase functions:config:set someservice.key="API_KEY_FOR_DEV"`.
    *   **Distinction from Dynamic Prompts:** While `functions.config()` is for secrets/stable settings, dynamic prompts (tied to Pydantic models) are better managed in Firestore/Remote Config. Emulated services hold dev prompt versions; deployed projects hold their respective versions.

7.  **Managing Function Changes:**
    *   For non-breaking changes, update existing functions.
    *   For breaking changes, consider deploying as new functions (e.g., `myFunction_v2`) and update clients gradually. This is relevant for `assign_people_to_items` if its core output structure changes in the future beyond the client-side adoption of the new detailed model for storage.

## 5. Security Considerations

1.  **Firestore Rules:** Implement robust Firestore security rules to ensure users can only access and modify their own receipt data.
2.  **Secure Deletion:** Properly handle user account deletion, ensuring associated data is also securely removed or anonymized according to policy.
3.  **Authentication:** Maintain a secure authentication flow, especially within any settings or account management sections.
4.  **Input Validation:** Continue to validate all inputs on the client-side and, critically, within Cloud Functions before processing or storing data.

## 6. UI Mockups

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

## 7. Firestore Emulator Seeding: Configuration and SOP

### What Was Done

To enable local development and testing with dynamic prompts and model configurations, the Firestore emulator was seeded with initial configuration data using a Python script. This ensures that the emulator environment closely mirrors production/staging for workflows that depend on Firestore-stored prompts and model settings. The process leverages the `init_firestore_config.py` script in the `functions/` directory, which writes default prompt and model provider configurations for all relevant AI-powered workflows (e.g., `parse_receipt`, `assign_people_to_items`, `transcribe_audio`).

**Key Points:**
- The Firestore emulator is started using the Firebase CLI.
- The Python Admin SDK requires a service account key, even for the emulator. This key is used only locally and should be kept out of version control.
- The script seeds the emulator with all necessary configuration documents for prompts and models, supporting multiple AI providers.

### Standard Operating Procedure (SOP): Reseeding the Firestore Emulator

**Prerequisites:**
- You have the Firebase CLI installed and configured.
- You have a service account key JSON file (e.g., `functions/emulator-service-account.json` or similar) available locally (never commit this to git).
- The `init_firestore_config.py` script exists in the `functions/` directory.

**Step-by-Step:**

1. **Start the Firebase Emulator Suite**
   - From the project root, run:
     ```sh
     firebase emulators:start
     ```
   - This will start the Firestore emulator (and any other configured emulators).

2. **Open a New Terminal for Seeding**
   - Keep the emulator running in its own terminal window/tab.
   - Open a new terminal for the seeding process.

3. **Set the Firestore Emulator Environment Variable**
   - On Windows (Command Prompt):
     ```sh
     set FIRESTORE_EMULATOR_HOST=localhost:8080
     ```
   - On Windows (PowerShell):
     ```sh
     $env:FIRESTORE_EMULATOR_HOST="localhost:8080"
     ```
   - On Mac/Linux:
     ```sh
     export FIRESTORE_EMULATOR_HOST=localhost:8080
     ```

4. **Run the Seeding Script**
   - Provide the path to your service account key (replace with your actual filename):
     ```sh
     python functions/init_firestore_config.py --admin-uid=admin --cred-path=functions/emulator-service-account.json
     ```
   - You should see output confirming that prompt and model configurations have been set for each workflow.

5. **Verify**
   - Visit [http://localhost:4000/firestore](http://localhost:4000/firestore) in your browser to confirm the seeded data is present in the emulator.

**Security Note:**
- Always add your service account key file to `.gitignore` to prevent accidental commits.
- The key is only used locally for emulator access and is not sent to Google when the emulator is running.

**Troubleshooting:**
- If you see credential errors, double-check the path to your service account key and ensure the environment variable is set in the same terminal session as your Python command.
- If the emulator is not running, the script will attempt to connect to production—always confirm the emulator is active before running the script. 