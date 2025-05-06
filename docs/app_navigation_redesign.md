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

# Key Implementation Decisions (as of May 2024)

- **Modal Workflow:** The 5-step receipt workflow is a full-page modal (not a popup), accessible only from the Receipts screen via the Floating Action Button (FAB). Modal cannot be dismissed by tapping outside; navigation is via explicit actions and back gesture.
- **State Management:** Provider (with ChangeNotifier) is used for in-modal state. State is memory-only during the modal session; no periodic auto-save. On exit (via Save & Exit or app close), user is prompted to save as draft or discard.
- **Drafts:** Drafts are visible and editable from the Receipts screen. Editing a completed receipt reverts it to draft, with a user prompt if data may be overwritten.
- **Image Handling:** Receipt image is uploaded in the first step and cannot be changed after upload. Thumbnails are generated and cached for fast loading in the Receipts list.
- **Restaurant Name:** A blocking dialog prompts for the restaurant name before entering the modal workflow. This name is required and can be edited later from the receipt view.
- **Firestore Integration:** All CRUD operations for receipts/drafts are handled by a dedicated Firestore service class. No offline support for now; app relies on cloud functions for parsing and assignment.
- **UI/UX:** All new UI follows the existing theme and Material You guidelines. User-friendliness and cohesion are prioritized. Further UX improvements will be iterative.
- **Testing:** Widget and unit tests will be scaffolded for modal navigation, Firestore service, and workflow logic.

---

# App Navigation and Workflow Redesign

## 1. Introduction & Key Goals

This document outlines a significant redesign of the app's navigation and receipt processing workflow. The primary objectives are to:

1.  **Enhance User Experience:** Streamline navigation by making "Receipts" the central view and introducing a more intuitive "Add Receipt" flow.
2.  **Improve Workflow Efficiency:** Convert the existing multi-tab workflow into a transient, full-page modal, maintaining current in-memory caching within the flow for responsiveness.
3.  **Enable Persistent Drafts:** Implement robust data persistence, allowing users to save incomplete receipts as drafts and resume them later. This involves storing the workflow's cached state to Firestore upon exiting the modal or the app, with a user prompt to save/discard.
4.  **Maintain Backend Stability:** Leverage existing backend Cloud Functions without immediate modification, ensuring a phased rollout.
5.  **Uphold Code Quality:** Implement all changes following best coding practices, focusing on reusability, clarity, and maintainability.

## 2. Core Redesign Pillars

### 2.1. Navigation and UI Transformation

- The app's navigation is simplified for a focused user experience:
  - **Bottom Navigation Bar:** Two primary items: "Receipts" and "Settings".
  - **Receipts Screen:** Central view displaying all receipts (completed and drafts), with search/filter and a prominent FAB for adding new receipts.
  - **Workflow Modal:** The 5-step workflow (Upload, Review, Assign, Split, Summary) is encapsulated in a full-page modal, accessible only from the Receipts screen FAB. The modal includes a step indicator, explicit navigation, and a Save & Exit button in the app bar. Back gesture navigates steps; exiting prompts to save/discard.

### 2.2. Data Model and Persistence Strategy

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
      - tip: Float  // Tip amount or percentage (default: 20%)
      - tax: Float  // Tax amount or percentage (default: 8.875%)
    }
```

**Key Aspects of the Data Model:**

*   **Raw Function Outputs:** Initially stores direct outputs from existing Cloud Functions to ensure backward compatibility and minimize immediate backend changes. For `assign_people_to_items`, the structure shown is the target detailed format. The current cloud function might output a more generic `Map`; the client application may need to adapt this, or the function will be updated later.
*   **User-Centric:** All receipt data is linked to a specific user.
*   **Metadata for Efficiency:** Includes essential metadata (`status`, `restaurant_name`, `people`, `tip`, `tax`) for list display, filtering, and search functionalities on the "Receipts" screen. **Tip and tax are required for completed receipts and default to 20% and 8.875% respectively if not set.**

**Caching, Persistence, and Scalability:**

1.  **In-Modal Caching (Performance):** While a user is actively in the workflow modal, data (e.g., OCR results, user edits to items, assignments) is cached in memory using Provider. This allows for instant screen transitions and interactions within the modal without constant database reads/writes. No periodic auto-save is performed for performance.
2.  **Prompted Save on Exit (Draft Creation):** If the user explicitly saves and exits the modal, or exits the app mid-workflow, the current in-memory cached state of the entire workflow is persisted to Firestore. The user is prompted to save as draft or discard. The `metadata.status` is set to "draft". This ensures no data loss and allows the user to resume seamlessly.
3.  **Draft Visibility and Editing:** Drafts are visible and editable from the Receipts screen. Editing a completed receipt reverts it to draft, with a user prompt if data may be overwritten. Only steps after upload are editable after completion; image cannot be changed.
4.  **`receiptId` Consistency:** A consistent `receiptId` is used throughout the workflow (from initiation in the modal to all Firestore operations) to ensure updates are applied to the correct document.
5.  **Scalability Benefits:**
    *   Reduces redundant AI function calls by saving intermediate results.
    *   Allows users to resume complex splits without starting over, improving user satisfaction.
    *   Firestore's scalability handles the storage of individual receipt documents efficiently.

**Preserving User Edits:**

- Receipt item edits, transcription corrections, assignment modifications, and final calculation adjustments are all saved to Firestore on Save & Exit or when marking as completed.
- **Summary view:** When the user reaches the summary view, the receipt is automatically marked as completed. Default tax is 8.875% and default tip is 20% if not set.

### 2.3. Efficient Image Handling

- **Upload:** Image is uploaded in the first step and cannot be changed after upload. If the user wants to modify the upload, they must create a new receipt.
- **Thumbnails:** Thumbnails are generated and cached for fast loading in the Receipts list.
- **No Edit After Upload:** Only steps after upload are editable after completion. Editing a completed receipt reverts it to draft, with a user prompt if data may be overwritten.

## 3. Implementation Roadmap & Best Practices

- **Provider** is used for state management throughout the modal workflow.
- **Firestore service class** handles all CRUD operations for receipts and drafts.
- **No offline support** for now; the app relies on cloud functions for parsing and assignment.
- **UI/UX** follows the existing theme and Material You guidelines. Modal workflow is full-page, not a popup, and is accessible only from the Receipts screen FAB.
- **Testing:** Widget and unit tests will be scaffolded for modal navigation, Firestore service, and workflow logic.
- **Code Cleanup:** As the refactor proceeds, opportunities for modularization and reduction of redundancy will be documented and implemented where safe.

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
     set FIRESTORE_EMULATOR_HOST=localhost:8081
     ```
   - On Windows (PowerShell):
     ```sh
     $env:FIRESTORE_EMULATOR_HOST="localhost:8081"
     ```
   - On Mac/Linux:
     ```sh
     export FIRESTORE_EMULATOR_HOST=localhost:8081
     ```

4. **Run the Seeding Script**
   - Provide the path to your service account key (replace with your actual filename):
     ```sh
     export FIRESTORE_EMULATOR_HOST=localhost:8081 
     python init_firestore_config.py --admin-uid=admin --cred-path=billfie-firebase-adminsdk-fbsvc-3478b1c3d9.json --seed-data-dir=../emulator_seed_data # Use venv in functions
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