import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../lib/services/connectivity_service.dart';
import '../test_helpers/connectivity_mock.dart';

void main() {
  late MockConnectivity mockConnectivity;
  late ConnectivityService connectivityService;

  setUp(() {
    mockConnectivity = MockConnectivity();
    connectivityService = ConnectivityService(connectivity: mockConnectivity);
  });

  tearDown(() {
    mockConnectivity.dispose();
  });

  group('ConnectivityService', () {
    test('isConnected returns true when connected to wifi', () async {
      mockConnectivity.setConnectivityResult(ConnectivityResult.wifi);
      
      final result = await connectivityService.isConnected();
      
      expect(result, true);
    });

    test('isConnected returns true when connected to mobile', () async {
      mockConnectivity.setConnectivityResult(ConnectivityResult.mobile);
      
      final result = await connectivityService.isConnected();
      
      expect(result, true);
    });

    test('isConnected returns false when not connected', () async {
      mockConnectivity.setConnectivityResult(ConnectivityResult.none);
      
      final result = await connectivityService.isConnected();
      
      expect(result, false);
    });

    test('onConnectivityChanged streams connectivity status changes', () async {
      // Create a list to collect emitted values
      final emittedValues = <bool>[];
      final subscription = connectivityService.onConnectivityChanged.listen(emittedValues.add);
      
      // Wait for initial setup
      await Future.delayed(Duration.zero);
      
      // Simulate connectivity changes
      mockConnectivity.setConnectivityResult(ConnectivityResult.none);
      await Future.delayed(Duration.zero);
      
      mockConnectivity.setConnectivityResult(ConnectivityResult.wifi);
      await Future.delayed(Duration.zero);
      
      mockConnectivity.setConnectivityResult(ConnectivityResult.mobile);
      await Future.delayed(Duration.zero);
      
      mockConnectivity.setConnectivityResult(ConnectivityResult.none);
      await Future.delayed(Duration.zero);
      
      // Cancel the subscription
      await subscription.cancel();
      
      // Verify the expected sequence - should have at least [false, true, false]
      // The initial value could be either true or false depending on timing
      expect(emittedValues.contains(false), true);
      expect(emittedValues.contains(true), true);
      
      // We can be more specific about the transitions
      // Check for the false->true->false pattern
      final falseIndex = emittedValues.indexOf(false);
      if (falseIndex >= 0 && falseIndex < emittedValues.length - 2) {
        expect(emittedValues[falseIndex+1], true);
        
        // Find the next false after the true
        final trueIndex = falseIndex + 1;
        final hasFalseAfterTrue = emittedValues.sublist(trueIndex + 1).contains(false);
        expect(hasFalseAfterTrue, true);
      }
    });
    
    test('currentStatus returns last known status synchronously', () async {
      // Initially wifi is set in MockConnectivity
      expect(connectivityService.currentStatus, true);
      
      // Simulate connectivity changes
      mockConnectivity.setConnectivityResult(ConnectivityResult.none);
      await Future.delayed(Duration.zero);
      expect(connectivityService.currentStatus, false);
      
      mockConnectivity.setConnectivityResult(ConnectivityResult.wifi);
      await Future.delayed(Duration.zero);
      expect(connectivityService.currentStatus, true);
    });
  });
} 