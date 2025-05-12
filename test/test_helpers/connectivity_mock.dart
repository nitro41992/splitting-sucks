import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mockito/mockito.dart';

class MockConnectivity extends Mock implements Connectivity {
  final StreamController<List<ConnectivityResult>> _controller = 
      StreamController<List<ConnectivityResult>>.broadcast();
  
  ConnectivityResult _lastResult = ConnectivityResult.wifi;
  
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;
  
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return [_lastResult];
  }
  
  void setConnectivityResult(ConnectivityResult result) {
    _lastResult = result;
    _controller.add([result]);
  }
  
  void dispose() {
    _controller.close();
  }
} 