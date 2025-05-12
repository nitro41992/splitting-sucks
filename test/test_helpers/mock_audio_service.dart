import 'dart:typed_data';
import 'package:billfie/services/audio_transcription_service.dart';
import 'package:mockito/mockito.dart';

// Create a mock of the AudioTranscriptionService
class MockAudioService extends Mock implements AudioTranscriptionService {
  @override
  Future<String> getTranscription(Uint8List audioBytes) async {
    return 'This is a mock transcription';
  }

  // Override method to return a hardcoded AssignmentResult
  @override
  Future<AssignmentResult> assignPeopleToItems(
    String transcription, 
    Map<String, dynamic> requestData,
  ) async {
    // Use the factory method from the real AssignmentResult class
    return AssignmentResult.fromJson({
      'assignments': [
        {
          'person_name': 'Alice',
          'items': [
            {
              'id': 1,
              'item': 'Burger',
              'price': 10.99,
              'quantity': 1,
            }
          ]
        }
      ],
      'shared_items': [],
      'unassigned_items': [],
      'summary': 'Alice pays for the burger'
    });
  }
} 