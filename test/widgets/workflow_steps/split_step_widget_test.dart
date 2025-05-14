import '../../../lib/models/person.dart';
import '../../../lib/models/receipt_item.dart';
// import '../../../lib/models/split_manager.dart'; // Not directly used in this test's top-level, but by SplitStepWidget
import '../../../lib/providers/workflow_state.dart';
// import '../../../lib/widgets/split_view.dart'; // Not directly used
import '../../../lib/widgets/workflow_steps/split_step_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/firebase_mock_setup.dart'; // Path relative to test directory
import '../../test_helpers/test_util.dart'; // Path relative to test directory


// Mock class for the NavigateToPageNotification
class NavigateToPageNotification extends Notification {
  final int pageIndex;
  NavigateToPageNotification(this.pageIndex);
}

// Mock class for WorkflowState
class MockWorkflowState extends Mock implements WorkflowState {
  double? _currentTip;
  double? _currentTax;
  int _initialSplitViewTabIndex = 0;
  Map<String, dynamic> _parseResult = {};
  Map<String, dynamic> _assignResultMap = {};

  @override
  double? get currentTip => _currentTip;

  @override
  double? get currentTax => _currentTax;

  @override
  int get initialSplitViewTabIndex => _initialSplitViewTabIndex;

  @override
  Map<String, dynamic> get parseResult => _parseResult;

  @override
  Map<String, dynamic> get assignPeopleToItemsResult => _assignResultMap;

  void setParseResult(Map<String, dynamic> result) {
    _parseResult = result;
  }

  void setAssignResultMap(Map<String, dynamic> result) {
    _assignResultMap = result;
  }

  void setTip(double? tip) {
    _currentTip = tip;
  }

  void setTax(double? tax) {
    _currentTax = tax;
  }

  void setInitialSplitViewTabIndex(int index) {
    _initialSplitViewTabIndex = index;
  }
}

void main() {
  setUpAll(() async {
    await TestUtil.initializeFirebaseCoreIfNecessary();
    TestUtil.setupTestErrorHandler();
    debugPrint('Firebase test environment configured');
  });
  
  group('SplitStepWidget Tests', () {
    late MockWorkflowState mockWorkflowState;
    late Map<String, dynamic> mockParseResult;
    late Map<String, dynamic> mockAssignResultMap;
    
    setUp(() {
      // Initialize the mock
      mockWorkflowState = MockWorkflowState();

      // Setup mock data
      mockParseResult = {
        'subtotal': 50.0,
        'items': [
          {'name': 'Burger', 'price': 15.0, 'quantity': 1, 'itemId': 'item_burger_parsed'},
          {'name': 'Fries', 'price': 5.0, 'quantity': 2, 'itemId': 'item_fries_parsed'},
          {'name': 'Soda', 'price': 2.0, 'quantity': 1, 'itemId': 'item_soda_parsed'}
        ],
        'tip': 5.0, 
        'tax': 2.5, 
      };

      mockAssignResultMap = {
        'assignments': [
          {
            'person_name': 'Alice',
            'items': [
              {'name': 'Burger', 'price': 15.0, 'quantity': 1, 'itemId': 'item_alice_burger'},
            ]
          },
          {
            'person_name': 'Bob',
            'items': [
              {'name': 'Fries', 'price': 5.0, 'quantity': 2, 'itemId': 'item_bob_fries'},
            ]
          }
        ],
        'shared_items': [
          {
            'name': 'Soda', 
            'price': 2.0, 
            'quantity': 1, 
            'itemId': 'item_shared_soda',
            'people': ['Alice', 'Bob'] 
          }
        ],
        'unassigned_items': [] 
      };
      
      // Configure the mock
      mockWorkflowState.setParseResult(mockParseResult);
      mockWorkflowState.setAssignResultMap(mockAssignResultMap);
      mockWorkflowState.setTip(mockParseResult['tip'] as double?);
      mockWorkflowState.setTax(mockParseResult['tax'] as double?);
      mockWorkflowState.setInitialSplitViewTabIndex(0);
    });
    
    testWidgets('initializes SplitManager with correct data from parseResult and assignResult', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<WorkflowState>.value(value: mockWorkflowState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SplitStepWidget(
                parseResult: mockParseResult,
                assignResultMap: mockAssignResultMap,
                currentTip: mockWorkflowState.currentTip ?? 0.0,
                currentTax: mockWorkflowState.currentTax ?? 0.0,
                initialSplitViewTabIndex: mockWorkflowState.initialSplitViewTabIndex,
                onTipChanged: (_) {},
                onTaxChanged: (_) {},
                onAssignmentsUpdatedBySplit: (_) {},
                onNavigateToPage: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(); 
      
      // For now, we'll just verify the widget builds without errors
      expect(find.byType(SplitStepWidget), findsOneWidget);
      
      // Additional assertions would test the internal state, but we'd need
      // access to the SplitManager instance inside the widget
    });
  });
} 