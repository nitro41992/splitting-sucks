import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AudioTranscriptionService {
  final String _apiKey;
  final String _baseUrl = 'https://api.openai.com/v1';
  
  AudioTranscriptionService() : _apiKey = dotenv.env['OPEN_AI_API_KEY'] ?? '';

  Future<String> getTranscription(Uint8List audioBytes) async {
    try {
      final url = Uri.parse('$_baseUrl/audio/transcriptions');
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            audioBytes,
            filename: 'audio.wav',
          ),
        )
        ..fields['model'] = 'whisper-1';

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        throw Exception('Failed to transcribe audio: ${response.statusCode}');
      }

      final json = jsonDecode(responseBody);
      return json['text'] as String;
    } catch (e) {
      print('Error transcribing audio: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> assignPeopleToItems(String transcription, Map<String, dynamic> receipt) async {
    try {
      final url = Uri.parse('$_baseUrl/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': dotenv.env['OPEN_AI_MODEL'] ?? 'gpt-4o-mini',
          'response_format': { 'type': 'json_object' },
          'messages': [
            {
              'role': 'system',
              'content': '''You are a helpful assistant that assigns items from a receipt to people based on voice instructions.
              Analyze the voice transcription and receipt items to determine who ordered what.
              Return a JSON object with the following structure:
              {
                "orders": [
                  {"person": "name", "item": "item_name", "price": price, "quantity": quantity}
                ],
                "shared_items": [
                  {"item": "item_name", "price": price, "quantity": quantity, "people": ["name1", "name2"]}
                ],
                "people": [
                  {"name": "name1"},
                  {"name": "name2"}
                ]
              }''',
            },
            {
              'role': 'user',
              'content': '''Voice transcription: $transcription
              Receipt items: ${jsonEncode(receipt)}''',
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get completion: ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      final content = json['choices'][0]['message']['content'];
      if (content == null) {
        throw Exception('No response from OpenAI');
      }

      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Error assigning items: $e');
      rethrow;
    }
  }
} 