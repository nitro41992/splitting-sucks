import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity;
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  
  bool _lastKnownStatus = true; // Assume connected initially
  
  ConnectivityService({Connectivity? connectivity}) 
    : _connectivity = connectivity ?? Connectivity() {
    // Initialize the connectivity status and set up listeners
    _initConnectivity();
    _setupConnectivityStream();
  }
  
  // Get the current connectivity status
  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    // Consider connected if any result is not NONE
    return results.any((result) => result != ConnectivityResult.none);
  }
  
  // Stream of connectivity changes - true = connected, false = disconnected
  Stream<bool> get onConnectivityChanged => _connectionStatusController.stream;
  
  // Get the last known connectivity status without async
  bool get currentStatus => _lastKnownStatus;
  
  // Initialize connectivity
  Future<void> _initConnectivity() async {
    try {
      _lastKnownStatus = await isConnected();
      _connectionStatusController.add(_lastKnownStatus);
    } catch (e) {
      // If we can't determine connectivity, assume connected to avoid
      // unnecessary offline mode
      _lastKnownStatus = true;
      _connectionStatusController.add(true);
    }
  }
  
  // Set up stream subscription for connectivity changes
  void _setupConnectivityStream() {
    _connectivity.onConnectivityChanged.listen((results) {
      // Consider connected if any result is not NONE
      final isConnected = results.any((result) => result != ConnectivityResult.none);
      
      // Only emit if status changed
      if (isConnected != _lastKnownStatus) {
        _lastKnownStatus = isConnected;
        _connectionStatusController.add(isConnected);
      }
    });
  }
  
  void dispose() {
    _connectionStatusController.close();
  }
} 