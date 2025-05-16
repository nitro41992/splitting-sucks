# Splitting Sucks

## Caching and Data Persistence

### Overview

The app implements a comprehensive caching system to ensure user data is never lost during workflow navigation. All changes are automatically cached when:

1. Navigating between workflow screens
2. Editing items in any screen
3. When the app is suspended or closed 

### Data Persistence Triggers

- **Real-time caching**: Changes are cached in memory as they occur
- **Periodic caching**: Some screens implement periodic caching (e.g. receipt review screen)
- **Lifecycle events**: Data is saved when the app is paused or inactive
- **Navigation events**: Data is saved when moving between major workflow steps
- **Manual save**: User can explicitly save drafts

### Supported Screens

All screens in the workflow modal support caching:

- **Upload Screen**: Image selections and parsed receipt data
- **Receipt Review Screen**: Item edits, deletions, and additions
- **Voice Assignment Screen**: Transcriptions and processed assignments 
- **Split View**: People assignments, shared items, and tax/tip values

### Implementation Details

The caching system uses multiple mechanisms:

1. **WorkflowState Provider**: Central state management that notifies on changes
2. **ReceiptPersistenceService**: Handles saving session data to Firestore
3. **OfflineStorageService**: Provides local backup if network is unavailable
4. **Focus and Lifecycle Hooks**: Ensure data is flushed at appropriate times

This ensures a seamless experience where users can navigate through the entire workflow without losing their progress, even if they close the app mid-workflow. 