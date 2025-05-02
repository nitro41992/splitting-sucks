import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../models/receipt_item.dart';
import '../services/audio_transcription_service.dart';
import '../theme/app_colors.dart';

class VoiceAssignmentScreen extends StatefulWidget {
  final List<ReceiptItem> itemsToAssign;
  // Callback to notify the parent UI when assignments are processed
  // It passes the raw assignment data (or mock data structure)
  final Function(Map<String, dynamic> assignmentsData) onAssignmentProcessed;
  // Initial transcription to display (for state preservation)
  final String? initialTranscription;
  // Callback to update parent when transcription changes
  final Function(String? transcription)? onTranscriptionChanged;

  const VoiceAssignmentScreen({
    super.key,
    required this.itemsToAssign,
    required this.onAssignmentProcessed,
    this.initialTranscription,
    this.onTranscriptionChanged,
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
  bool _tipsExpanded = true; // Track if tips are expanded or collapsed
  String? _transcription;

  @override
  void initState() {
    super.initState();
    _transcriptionController = TextEditingController();
    
    // Initialize with saved transcription if available
    if (widget.initialTranscription != null) {
      _transcription = widget.initialTranscription;
      _transcriptionController.text = widget.initialTranscription!;
    }
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
    // Real recording logic
    if (!_isRecording) {
      final hasPermission = await _recorder.hasPermission();
      print('DEBUG: Microphone permission status: $hasPermission');
      
      if (!hasPermission) {
        if (!mounted) return;
        print('DEBUG: Microphone permission denied');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        print('Starting audio recording...');
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_recording.wav';
        print('Recording to path: $path');
        
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            numChannels: 1,
            sampleRate: 16000,
          ),
          path: path,
        );
        
        print('Recording started successfully');
        setState(() {
          _isRecording = true;
          _isLoading = false;
        });
      } catch (e) {
        print('Error starting recording: $e');
        print('Stack trace: ${StackTrace.current}');
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    } else {
      setState(() => _isLoading = true); // Show loading while stopping/transcribing
      try {
        print('Stopping recording...');
        final path = await _recorder.stop();
        setState(() => _isRecording = false);

        if (path != null) {
          print('Recording saved to: $path');
          final File audioFile = File(path);
          final fileSize = await audioFile.length();
          print('Audio file size: ${fileSize} bytes');
          
          if (fileSize == 0) {
            throw Exception('Recorded audio file is empty');
          }
          
          final Uint8List audioBytes = await audioFile.readAsBytes();
          print('Audio bytes read: ${audioBytes.length} bytes');
          
          print('Sending audio for transcription...');
          final transcriptionResult = await _audioService.getTranscription(audioBytes);
          print('Transcription received: ${transcriptionResult.length} characters');
          
          setState(() {
            _transcription = transcriptionResult;
            _transcriptionController.text = transcriptionResult;
            _isLoading = false;
          });
          
          // Notify parent of transcription change
          if (widget.onTranscriptionChanged != null) {
            widget.onTranscriptionChanged!(_transcription);
          }
        } else {
           print('Error: Recording stop returned null path');
           setState(() => _isLoading = false);
        }
      } catch (e) {
        print('Error stopping/processing recording: $e');
        print('Stack trace: ${StackTrace.current}');
        setState(() => _isLoading = false);
        if (!mounted) return;
        
        // Show a more detailed error message with potential Firebase error details
        final errorMessage = e.toString();
        print('Detailed transcription error: $errorMessage');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing recording. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage),
                    duration: const Duration(seconds: 10),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _processTranscription() async {
    if (_transcription == null) return;

    setState(() => _isLoading = true);
    final editedTranscription = _transcriptionController.text;
    
    // Save the edited transcription in our local state
    _transcription = editedTranscription;
    
    // Notify parent of transcription change to ensure it's persisted
    if (widget.onTranscriptionChanged != null) {
      widget.onTranscriptionChanged!(editedTranscription);
    }

    try {
      print('DEBUG: Making API call for item assignment');
      print('DEBUG: Using transcription: $editedTranscription');
      
      final request = {
        'data': {
          'transcription': editedTranscription,
          'receipt_items': widget.itemsToAssign.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return {
              'id': index + 1, // 1-based ID for the API
              'item': item.name,  // Use the current name (which may have been edited)
              'quantity': item.quantity, // Use the current quantity (which may have been edited)
              'price': item.price, // Use the current price (which may have been edited)
            };
          }).toList(),
        }
      };
      
      print('DEBUG: Sending request to assign-people endpoint: ${request.toString()}');
      
      final result = await _audioService.assignPeopleToItems(
        editedTranscription,
        request,
      );
      
      // Convert the structured result to the Map format expected by the parent widget
      final assignmentsData = result.toJson();
      print('DEBUG: Received assignment data: ${assignmentsData.toString()}');

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
                                  crossAxisAlignment: CrossAxisAlignment.center, // Align icons and text vertically centered
                                  children: [
                                    Icon(
                                      Icons.tips_and_updates_outlined,
                                      color: colorScheme.onSecondaryContainer,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Some tips for a better split',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _tipsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                        color: colorScheme.onSecondaryContainer,
                                        size: 24,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _tipsExpanded = !_tipsExpanded;
                                        });
                                      },
                                      tooltip: _tipsExpanded ? 'Hide tips' : 'Show tips',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                if (_tipsExpanded) ...[
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
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.format_list_numbered,
                                        size: 18,
                                        color: colorScheme.onSecondaryContainer.withOpacity(0.8),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Use the item numbers! Say things like "Emma got #2 and we all shared #5" — super handy when those pasta dishes start sounding the same!',
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
                            // decoration: BoxDecoration(
                            //   color: colorScheme.surfaceVariant.withOpacity(0.3),
                            //   borderRadius: BorderRadius.circular(12),
                            //   border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                            // ),
                            child: Column(
                              children: [
                                // Header row
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      SizedBox(width: 36), // Space for item number
                                      SizedBox(width: 48), // Space for quantity
                                      Expanded(
                                        child: Text(
                                          'Item',
                                          style: textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          'Price',
                                          style: textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Divider with very low opacity to separate header
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: colorScheme.outlineVariant.withOpacity(0.3),
                                ),
                                // Items list
                                ...widget.itemsToAssign.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  
                                  // Add a subtle grid row effect
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: colorScheme.outlineVariant.withOpacity(0.15),
                                          width: 1,
                                        ),
                                      ),
                                      color: index.isEven 
                                          ? Colors.transparent
                                          : colorScheme.surfaceVariant.withOpacity(0.15),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        // Display numeric ID - fixed width
                                        SizedBox(
                                          width: 35,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            // decoration: BoxDecoration(
                                            //   color: colorScheme.secondaryContainer,
                                            //   borderRadius: BorderRadius.circular(4),
                                            // ),
                                            child: Text(
                                              '${index + 1}.', // 1-based index
                                              style: textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.primary,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        // Add spacing between item ID and quantity
                                        const SizedBox(width: 10),
                                        // Quantity - fixed width
                                        SizedBox(
                                          width: 35,
                                          child: Container(
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
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        // Item name - expanded
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                            child: Text(
                                              item.name,
                                              style: textTheme.bodyMedium,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        // Price - fixed width for alignment
                                        SizedBox(
                                          width: 80,
                                          child: Text(
                                            '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                            style: textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.primary,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                // Total row with separation
                                Container(
                                  padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: colorScheme.outlineVariant.withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(width: 84), // Space for ID and quantity
                                      Expanded(
                                        child: Text(
                                          'Total',
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          '\$${_calculateSubtotal().toStringAsFixed(2)}',
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                          textAlign: TextAlign.right,
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