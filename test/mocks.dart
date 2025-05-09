import 'package:mockito/annotations.dart';
import 'package:billfie/widgets/image_state_manager.dart'; // Path to the class to be mocked

// If you have other classes to mock from different files, add their imports here.
// For example:
// import 'package:billfie/services/some_service.dart';

@GenerateMocks([
  ImageStateManager, // Class to be mocked
  // Add other class names here if they need to be mocked, e.g.:
  // SomeService,
])
void main() {
  // This file is primarily for build_runner to generate mocks.
  // The main function here is often empty or contains minimal setup if needed for generation.
} 