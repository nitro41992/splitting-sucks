import 'dart:io'; // Import dart:io for File
import 'package:mockito/annotations.dart';
import 'package:billfie/widgets/image_state_manager.dart'; // Path to the class to be mocked
import 'package:billfie/providers/workflow_state.dart'; // Import for WorkflowState
import 'package:billfie/models/split_manager.dart'; // ADDED: Import for SplitManager

// If you have other classes to mock from different files, add their imports here.
// For example:
// import 'package:billfie/services/some_service.dart';

@GenerateMocks([
  ImageStateManager, // Class to be mocked
  File, // Add File to the list of mocks
  WorkflowState, // Add WorkflowState to the list of mocks
  SplitManager, // ADDED: SplitManager to the list of mocks
  // Add other class names here if they need to be mocked, e.g.:
  // SomeService,
])
void main() {
  // This file is typically used for generating mock implementations via build_runner.
  // It doesn't need a traditional main() body for execution during tests.
} 