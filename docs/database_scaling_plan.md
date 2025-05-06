# Database Scaling Plan

## Current Situation

Our application currently faces several scaling issues related to database operations:

1. **Multiple Uncoordinated Save Paths**: While we have a debouncing mechanism in `receipt_workflow_page.dart` (500ms timer), several save operations bypass this timer:
   - Navigation-triggered saves in `_navigateToNextStep()`, `_navigateToPreviousStep()`
   - Direct calls to `saveAssignmentsToService()` from various dialogs
   - Manual saves on screen transitions

2. **Full State Saves**: Every save operation sends the entire state rather than just what changed.

3. **No Retry Logic**: Failed saves don't have proper retry mechanics with backoff.

4. **Potential Rate Limiting**: With 1000+ concurrent users, we may exceed Firebase quotas.

## Proposed Solution

We'll implement a centralized save mechanism in the `SplitManager` class with:

1. **Global Debouncing**: Move debouncing from widget to model level
2. **Exponential Backoff Retries**: Handle transient errors gracefully
3. **Optional Critical Saves**: Allow bypassing debouncing for essential operations
4. **Staged Implementation**: Tackle issues in order of impact vs. effort

## Implementation Plan

### Phase 1: Centralized Debouncing (High Impact, Low Effort)

1. Add a timer to `SplitManager`:

```dart
class SplitManager extends ChangeNotifier {
  // Existing code...
  
  // Timer for debouncing saves
  Timer? _saveTimer;
  bool _isSaving = false;
  
  // Duration for debounce (consider increasing from 500ms to 2000ms)
  static const Duration _saveDebounceDuration = Duration(milliseconds: 2000);
  
  // Override existing notifyListeners to set _assignmentsModified
  @override
  void notifyListeners() {
    if (_initialized) {
      _assignmentsModified = true;
      
      // Cancel any existing timer
      _saveTimer?.cancel();
      
      // Start a new timer for auto-save
      _saveTimer = Timer(_saveDebounceDuration, () {
        // Auto-save if we have a receiptService and receiptId set
        if (_currentReceiptService != null && _currentReceiptId != null) {
          _debouncedSave();
        }
      });
    }
    super.notifyListeners();
  }
}
```

2. Add receipt reference to SplitManager:

```dart
// Add fields to track current receipt
ReceiptService? _currentReceiptService;
String? _currentReceiptId;

// Method to set the current receipt context
void setReceiptContext(ReceiptService service, String receiptId) {
  _currentReceiptService = service;
  _currentReceiptId = receiptId;
}
```

3. Add the debounced save method with retry logic:

```dart
Future<void> _debouncedSave() async {
  // If already saving or not initialized, skip
  if (_isSaving || !_initialized || !_assignmentsModified) {
    return;
  }
  
  if (_currentReceiptService == null || _currentReceiptId == null) {
    debugPrint('Cannot save: missing receipt service or ID');
    return;
  }
  
  _isSaving = true;
  
  try {
    // Get assignment data
    final assignmentData = getAssignmentData();
    
    // Reset the flag before the save attempt
    _assignmentsModified = false;
    
    // Save to the database with retries
    await _saveWithRetry(_currentReceiptService!, _currentReceiptId!, assignmentData);
    
    debugPrint('Debounced save completed successfully');
  } catch (e) {
    debugPrint('Error in debounced save: $e');
    // Mark as modified again since save failed
    _assignmentsModified = true;
  } finally {
    _isSaving = false;
  }
}
```

4. Implement retry logic with exponential backoff:

```dart
Future<void> _saveWithRetry(
  ReceiptService service, 
  String receiptId, 
  Map<String, dynamic> data
) async {
  int attempts = 0;
  const int maxAttempts = 3;
  Duration backoff = const Duration(milliseconds: 500);
  
  while (attempts < maxAttempts) {
    try {
      await service.saveAssignPeopleToItemsResults(receiptId, data);
      // Success - exit retry loop
      return;
    } catch (e) {
      attempts++;
      
      if (attempts >= maxAttempts) {
        debugPrint('Maximum retry attempts reached ($maxAttempts), giving up: $e');
        rethrow;
      }
      
      // Log the error and retry after backoff
      debugPrint('Save attempt $attempts failed, retrying in ${backoff.inMilliseconds}ms: $e');
      await Future.delayed(backoff);
      
      // Exponential backoff with jitter (randomness)
      backoff *= 2;
      // Add jitter (±20% randomness)
      final jitter = (0.8 + (0.4 * math.Random().nextDouble())) * backoff.inMilliseconds;
      backoff = Duration(milliseconds: jitter.round());
    }
  }
}
```

5. Update `saveAssignmentsToService` to use the retry logic:

```dart
Future<void> saveAssignmentsToService(ReceiptService receiptService, String receiptId, {bool force = false}) async {
  if (!_initialized || (!_assignmentsModified && !force)) {
    debugPrint('No changes to save or not initialized yet');
    return;
  }
  
  // Set the context for future saves
  _currentReceiptService = receiptService;
  _currentReceiptId = receiptId;
  
  // If force is true, save immediately, otherwise use debounced save
  if (force) {
    // Cancel any pending debounced save
    _saveTimer?.cancel();
    
    // Immediate save with retry
    await _debouncedSave();
  } else {
    // Cancel existing timer and start a new one
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, () {
      _debouncedSave();
    });
  }
}
```

### Phase 2: Update Widget References (Medium Impact, Low Effort)

1. Update `receipt_workflow_page.dart` to use the new centralized system:

```dart
// In initState or where the SplitManager is initialized
splitManager.setReceiptContext(_receiptService, widget.receipt.id!);

// Remove the timer-based save from the widget
// Remove this section:
splitManager.addListener(() {
  if (splitManager.assignmentsModified && splitManager.initialized) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _autoSaveAssignments(splitManager);
    });
  }
});

// For critical saves (navigation, completion), use force parameter
splitManager.saveAssignmentsToService(_receiptService, widget.receipt.id!, force: true);
```

2. Search and replace all direct database calls with the new centralized method:
   - Update navigation methods
   - Update dialog confirmations
   - Update screen transitions

### Phase 3: Delta Updates (High Impact, High Effort)

For future implementation, modify the save process to only send changes:

1. Track the previous state in the SplitManager
2. Compare current state with previous state to extract only changed items
3. Update the service to handle partial updates

### Phase 4: Offline Support (Medium Impact, High Effort)

Implement queue-based persistence with IndexedDB or Hive for offline support.

## Expected Benefits

1. **Reduced Database Operations**: Estimated 90% reduction in write operations
2. **Improved Reliability**: Retry logic will handle transient network issues
3. **Better UX**: Less chance of data loss during poor connectivity
4. **Cost Savings**: Reduced Firebase operations = lower costs
5. **Higher Scalability**: Can support 1000+ concurrent users without issues

## Timeline and Effort

| Phase | Description | Effort | Timeline |
|-------|-------------|--------|----------|
| 1 | Centralized Debouncing | Low (1-2 days) | Week 1 |
| 2 | Update Widget References | Low (1 day) | Week 1 |
| 3 | Delta Updates | High (1 week) | Future |
| 4 | Offline Support | High (2 weeks) | Future |

## Testing Plan

1. **Unit Tests**: Verify debounce behavior and retry logic
2. **Load Testing**: Simulate concurrent users with Firebase emulator
3. **Failure Testing**: Verify retry behavior with intentionally failed requests
4. **Monitoring**: Add metrics to track save frequency and success rates

## Conclusion

By implementing a centralized debouncing mechanism with proper retry logic, we can significantly improve our application's scalability with minimal development effort. The most impactful changes (Phases 1-2) can be completed within one week, while more complex optimizations can be scheduled for future releases. 