import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../models/receipt_item.dart';
import '../services/audio_transcription_service.dart';
import '../services/mock_data_service.dart';
import '../theme/app_colors.dart';

class VoiceAssignmentScreen extends StatefulWidget {
  final List<ReceiptItem> itemsToAssign;
  // Callback to notify the parent UI when assignments are processed
  // It passes the raw assignment data (or mock data structure)
  final Function(Map<String, dynamic> assignmentsData) onAssignmentProcessed;

  const VoiceAssignmentScreen({
    super.key,
    required this.itemsToAssign,
    required this.onAssignmentProcessed,
  });

  @override
  State<VoiceAssignmentScreen> createState() => _VoiceAssignmentScreenState();
}

class _VoiceAssignmentScreenState extends State<VoiceAssignmentScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioTranscriptionService _audioService = AudioTranscriptionService();
  late TextEditingController _transcriptionController;

  bool _isRecording = false;
  bool _isLoading = false; // Loading state specific to this screen
  String? _transcription;

  @override
  void initState() {
    super.initState();
    _transcriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _transcriptionController.dispose();
    super.dispose();
  }

  double _calculateSubtotal() {
    double total = 0.0;
    for (var item in widget.itemsToAssign) {
      total += item.price * item.quantity;
    }
    return total;
  }

  Future<void> _toggleRecording() async {
    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
    print('DEBUG: In _toggleRecording (Screen), useMockData = $useMockData');

    if (useMockData) {
      print('DEBUG: Using mock data in _toggleRecording (Screen)');
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1)); // Simulate recording/processing
      // Use the hardcoded mock transcription string
      final mockTranscription = "John ordered the burger and chicken wings. Sarah got the soda and milkshake. Mike had the salad and caesar salad. Emma took the pizza and nachos. The appetizer is shared between John and Sarah. The garlic bread is shared between everyone. The fries, ice cream, and coffee are still unassigned.";
      setState(() {
        _transcription = mockTranscription;
        _transcriptionController.text = _transcription!;
        _isLoading = false;
      });
      return;
    }

    // Real recording logic
    if (!_isRecording) {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_recording.wav';
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            numChannels: 1,
            sampleRate: 16000,
          ),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _isLoading = false;
        });
      } catch (e) {
        print('Error starting recording: $e');
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    } else {
      setState(() => _isLoading = true); // Show loading while stopping/transcribing
      try {
        final path = await _recorder.stop();
        setState(() => _isRecording = false);

        if (path != null) {
          final File audioFile = File(path);
          final Uint8List audioBytes = await audioFile.readAsBytes();
          final transcriptionResult = await _audioService.getTranscription(audioBytes);
          setState(() {
            _transcription = transcriptionResult;
            _transcriptionController.text = transcriptionResult;
            _isLoading = false;
          });
        } else {
           setState(() => _isLoading = false);
        }
      } catch (e) {
        print('Error stopping/processing recording: $e');
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing recording: $e')),
        );
      }
    }
  }

  Future<void> _processTranscription() async {
    if (_transcription == null) return;

    setState(() => _isLoading = true);
    final editedTranscription = _transcriptionController.text;

    final useMockData = dotenv.env['USE_MOCK_DATA']?.toLowerCase() == 'true';
    print('DEBUG: In _processTranscription (Screen), useMockData = $useMockData');

    try {
      Map<String, dynamic> assignmentsData;
      if (useMockData) {
        print('DEBUG: Using mock assignment data in _processTranscription (Screen)');
        await Future.delayed(const Duration(seconds: 1)); // Simulate processing
        // Return the predefined mock structure (similar to original logic)
        // This structure should match what the API would return
        assignmentsData = {
          'people': MockDataService.mockPeople.map((name) => {'name': name}).toList(),
          'orders': MockDataService.mockAssignments.entries.expand((entry) {
            final personName = entry.key;
            return entry.value.map((item) => {
              'person': personName,
              'item': item.name,
              'price': item.price,
              'quantity': item.quantity,
            });
          }).toList(),
          'shared_items': MockDataService.mockSharedItems.map((item) => {
             'item': item.name,
             'price': item.price,
             'quantity': item.quantity,
             // Mock which people share it - let's assume all for simplicity here, adjust if needed
             'people': MockDataService.mockPeople
          }).toList(),
           'unassigned_items': MockDataService.mockUnassignedItems.map((item) => {
             'item': item.name,
             'price': item.price,
             'quantity': item.quantity,
          }).toList(),
        };
      } else {
        print('DEBUG: Making API call in _processTranscription (Screen)');
        final jsonReceipt = {
          'items': widget.itemsToAssign.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return {
              'id': index + 1, // Add 1-based index as ID
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
            };
          }).toList(),
        };
        final result = await _audioService.assignPeopleToItems(
          editedTranscription,
          jsonReceipt,
        );
        
        // Convert the structured result to the Map format expected by the parent widget
        assignmentsData = result.toJson();
      }

      // Pass the raw assignment data back to the parent widget
      widget.onAssignmentProcessed(assignmentsData);

      // Loading state will be handled by the parent switching pages
      // setState(() => _isLoading = false); // No need to set loading false here

    } catch (e) {
      print('Error processing assignment in screen: $e');
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing assignment: ${e.toString()}')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Use a LayoutBuilder to constrain the button at the bottom
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Scrollable content
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: _isLoading || _transcription != null ? 80 : 16), // Add padding below content when button is visible
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recording Controls Section
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.mic_none_outlined, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Assign Items by Voice',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Voice Input Guide
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colorScheme.secondary.withOpacity(0.3)),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.tips_and_updates_outlined,
                                      color: colorScheme.onSecondaryContainer,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Tips for better voice recognition:',
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.people,
                                      size: 18,
                                      color: colorScheme.onSecondaryContainer.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Start by saying everyone\'s name (including yours).',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu,
                                      size: 18,
                                      color: colorScheme.onSecondaryContainer.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Describe what each person ordered using item names from the list below.',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.share,
                                      size: 18,
                                      color: colorScheme.onSecondaryContainer.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Mention shared items like: "Alex and Jamie shared the fries and we all had the salad."',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Example: "Hey, Sam here. Alex got the burger. Jamie got the pasta. I had the salad. We all shared the garlic bread."',
                                  style: textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: colorScheme.onSecondaryContainer.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isRecording ? colorScheme.errorContainer : colorScheme.primaryContainer,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isRecording ? colorScheme.error : colorScheme.primary).withOpacity(0.3),
                                    spreadRadius: _isRecording ? 4 : 0,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  size: 48,
                                  color: _isRecording ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer,
                                ),
                                onPressed: _isLoading ? null : _toggleRecording, // Disable while loading
                                tooltip: _isRecording ? 'Stop Recording' : 'Start Recording',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_isLoading)
                            const Center(child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: CircularProgressIndicator(),
                            )),
                          if (!_isLoading && _transcription != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Transcription:',
                                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceVariant.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: colorScheme.outlineVariant),
                                    ),
                                    child: Stack(
                                      children: [
                                        TextField(
                                          controller: _transcriptionController,
                                          maxLines: 8,
                                          minLines: 5,
                                          decoration: InputDecoration(
                                            hintText: 'Edit transcription if needed...',
                                            hintStyle: textTheme.bodyLarge?.copyWith(
                                              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.all(16),
                                          ),
                                          style: textTheme.bodyLarge?.copyWith(
                                            height: 1.5,
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Receipt Summary Section
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long_outlined, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Receipt Summary',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: widget.itemsToAssign.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      // Display numeric ID
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${index + 1}', // 1-based index
                                          style: textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${item.quantity}x',
                                          style: textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: textTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '\$${_calculateSubtotal().toStringAsFixed(2)}',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action Button (Positioned at the bottom)
            if (!_isLoading && _transcription != null)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0), // Use screen padding
                  child: FilledButton.icon(
                    onPressed: _processTranscription,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Start Splitting'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary, // Consider using theme colors
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16), // Adjust padding
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
} 