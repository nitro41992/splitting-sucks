import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../models/receipt_item.dart';
import '../services/audio_transcription_service.dart';
import '../theme/app_colors.dart';
import '../utils/platform_config.dart'; // Import platform config
import '../utils/toast_helper.dart'; // Import toast helper

class VoiceAssignmentScreen extends StatefulWidget {
  final List<ReceiptItem> itemsToAssign;
  // Callback to notify the parent UI when assignments are processed
  // It passes the raw assignment data (or mock data structure)
  final Function(Map<String, dynamic> assignmentsData) onAssignmentProcessed;
  // Initial transcription to display (for state preservation)
  final String? initialTranscription;
  // Callback to update parent when transcription changes
  final Function(String? transcription)? onTranscriptionChanged;
  final Future<bool> Function()? onReTranscribeRequested; // MODIFIED to return Future<bool>
  final Future<bool> Function()? onConfirmProcessAssignments; // ADDED new callback
  final VoidCallback? onEditItems;

  const VoiceAssignmentScreen({
    super.key,
    required this.itemsToAssign,
    required this.onAssignmentProcessed,
    this.initialTranscription,
    this.onTranscriptionChanged,
    this.onReTranscribeRequested,
    this.onConfirmProcessAssignments, // ADDED to constructor
    this.onEditItems,
  });

  static VoiceAssignmentScreenState? of(BuildContext context, {bool nullOk = false}) {
    final state = context.findAncestorStateOfType<VoiceAssignmentScreenState>();
    if (state == null && !nullOk) {
      throw FlutterError('VoiceAssignmentScreen.of() called with a context that does not contain a VoiceAssignmentScreen.');
    }
    return state;
  }

  @override
  State<VoiceAssignmentScreen> createState() => VoiceAssignmentScreenState();
}

class VoiceAssignmentScreenState extends State<VoiceAssignmentScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioTranscriptionService _audioService = AudioTranscriptionService();
  late TextEditingController _transcriptionController;
  late FocusNode _transcriptionFocusNode;

  bool _isRecording = false;
  bool _isLoading = false; // Loading state specific to this screen
  bool _tipsExpanded = false; // Track if tips are expanded or collapsed
  String? _transcription;
  
  // Counter to generate unique item IDs
  int _itemIdCounter = 1;

  @override
  void initState() {
    super.initState();
    _transcriptionController = TextEditingController();
    _transcriptionFocusNode = FocusNode();
    
    // Initialize with saved transcription if available
    if (widget.initialTranscription != null) {
      _transcription = widget.initialTranscription;
      _transcriptionController.text = widget.initialTranscription!;
    }
    // Listen for focus loss to trigger cache
    _transcriptionFocusNode.addListener(() {
      if (!_transcriptionFocusNode.hasFocus) {
        if (widget.onTranscriptionChanged != null) {
          widget.onTranscriptionChanged!(_transcriptionController.text);
        }
      }
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _transcriptionController.dispose();
    _transcriptionFocusNode.dispose();
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
    if (!_isRecording) {
      // --- EDIT: Call onReTranscribeRequested and check confirmation ---
      if (widget.onReTranscribeRequested != null) {
        final bool confirmed = await widget.onReTranscribeRequested!();
        if (!confirmed) {
          setState(() => _isLoading = false); // Ensure loading state is reset if aborted
          return; // User cancelled re-transcription
        }
      }
      // --- END EDIT ---

      final hasPermission = await _recorder.hasPermission();
      print('DEBUG: Microphone permission status: $hasPermission');
      
      if (!hasPermission) {
        if (!mounted) return;
        print('DEBUG: Microphone permission denied');
        ToastHelper.showToast(
          context,
          'Microphone permission is required',
          isError: true
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
        ToastHelper.showToast(
          context,
          'Error starting recording: ${e.toString()}',
          isError: true
        );
      }
    } else {
      setState(() => _isLoading = true); // Show loading while stopping/transcribing
      try {
        print('Stopping recording...');
        final path = await _recorder.stop();
        if (!mounted) return;
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
            widget.onTranscriptionChanged!(transcriptionResult);
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
        
        ToastHelper.showToast(
          context,
          'Error processing recording. Please try again.',
          isError: true
        );
      }
    }
  }

  Future<void> _processTranscription() async {
    // Clear focus first to ensure we have the latest value
    _transcriptionFocusNode.unfocus();
    
    // Don't process if already loading or no transcription
    if (_isLoading || _transcriptionController.text.isEmpty) return;
    
    // Check if we should process or not (custom logic via callback)
    if (widget.onConfirmProcessAssignments != null) {
      final bool shouldProcess = await widget.onConfirmProcessAssignments!();
      if (!shouldProcess) return; // Skip processing if callback returns false
    }

    try {
      // User friendly: indicate something is happening while we process
      setState(() => _isLoading = true);
      
      // Capture the current transcription value for processing
      final editedTranscription = _transcriptionController.text;
      
      // Prepare the request with proper typing
      final request = {
        'data': {
          'transcription': editedTranscription,
          'receipt_items': widget.itemsToAssign.map((item) {
            return {
              'item': item.name,
              'quantity': item.quantity,
              'price': item.price,
              'id': _itemIdCounter++, // Unique ID for each item
            };
          }).toList(),
        }
      };
      
      print('DEBUG: Sending request to assign-people endpoint: ${request.toString()}');
      
      try {
        final result = await _audioService.assignPeopleToItems(
          editedTranscription,
          request,
        );
        
        print('DEBUG: Raw result object from _audioService.assignPeopleToItems: ${result?.toString()}');

        final assignmentsData = result.toJson();
        print('DEBUG: assignmentsData map AFTER result.toJson(): ${assignmentsData.toString()}');

        // Pass the raw assignment data back to the parent widget
        widget.onAssignmentProcessed(assignmentsData);
        if (!mounted) return;
        setState(() => _isLoading = false); // Hide spinner after success
      } catch (e) {
        // Handle all errors including timeout exceptions
        print('Error processing assignment in service: $e');
        setState(() => _isLoading = false);
        if (!mounted) return;
        
        String errorMessage;
        
        // Check if it's a timeout error
        if (e.toString().contains('TimeoutException') || 
            e.toString().contains('timed out') ||
            e.toString().contains('DEADLINE_EXCEEDED')) {
          errorMessage = 'Processing timed out. Try simplifying the transcription or using item numbers instead of full names.';
        } 
        // Check if it's a type error
        else if (e.toString().contains('type') && e.toString().contains('is not a subtype')) {
          errorMessage = 'There was an issue processing the data. Try using item numbers (e.g., "item #1") when referring to menu items.';
        }
        else {
          // General error message with the actual error for debugging
          errorMessage = 'Error processing assignment: ${e.toString()}';
        }
        
        ToastHelper.showToast(
          context,
          errorMessage,
          isError: true
        );
      }
    } catch (e) {
      print('Error processing assignment in screen: $e');
      setState(() => _isLoading = false);
      if (!mounted) return;
      ToastHelper.showToast(
        context,
        'Error processing assignment: ${e.toString()}',
        isError: true
      );
    }
  }

  void flushTranscriptionToParent() {
    final value = _transcriptionController.text;
    debugPrint('[VoiceAssignmentScreen] Flushing transcription to parent: $value');
    if (widget.onTranscriptionChanged != null) {
      widget.onTranscriptionChanged!(value);
    }
  }

  void unfocusTranscriptionField() {
    _transcriptionFocusNode.unfocus();
    debugPrint('[VoiceAssignmentScreen] Unfocused transcription field.');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Background color changed to light grey as per design
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Light grey background
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Scrollable content
              SingleChildScrollView(
                padding: EdgeInsets.only(bottom: _isLoading || _transcription != null ? 80 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "Assign Items by Voice" Card - Neumorphic styling
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.9),
                              blurRadius: 8,
                              offset: const Offset(-2, -2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title row
                            Text(
                              'Assign by Voice',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1D1D1F), // Primary Text Color
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Microphone button - Neumorphic styling
                            Center(
                              child: GestureDetector(
                                onTap: !_isLoading ? _toggleRecording : null,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isRecording ? AppColors.secondary.withOpacity(0.9) : AppColors.secondary,
                                    boxShadow: _isRecording 
                                      ? [
                                          // Inset shadow for pressed state
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 5,
                                            offset: const Offset(2, 2),
                                            spreadRadius: -2,
                                          ),
                                        ]
                                      : [
                                          // Raised shadow for normal state
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 8,
                                            offset: const Offset(2, 2),
                                            spreadRadius: 0,
                                          ),
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.9),
                                            blurRadius: 8,
                                            offset: const Offset(-2, -2),
                                            spreadRadius: 0,
                                          ),
                                        ],
                                  ),
                                  child: _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : Icon(
                                        _isRecording ? Icons.stop_circle : Icons.mic,
                                        color: Colors.white, // White icon
                                        size: 40,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Tips section with Neumorphic toggle
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    setState(() {
                                      _tipsExpanded = !_tipsExpanded;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.tips_and_updates_outlined,
                                              color: AppColors.primary, // Updated from slate blue
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Tips for a better split',
                                                style: textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF1D1D1F),
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              _tipsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                              color: AppColors.primary, // Updated from slate blue
                                              size: 24,
                                            ),
                                          ],
                                        ),
                                        if (_tipsExpanded) ...[
                                          const SizedBox(height: 16),
                                          // Tips content with the same structure but updated styling
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.people,
                                                size: 18,
                                                color: const Color(0xFF8A8A8E), // Secondary Text Color
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Start by saying everyone\'s name (including yours).',
                                                  style: textTheme.bodyMedium?.copyWith(
                                                    color: const Color(0xFF8A8A8E), // Secondary Text Color
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
                                                color: const Color(0xFF8A8A8E),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Describe what each person ordered using item names from the list below.',
                                                  style: textTheme.bodyMedium?.copyWith(
                                                    color: const Color(0xFF8A8A8E),
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
                                                color: const Color(0xFF8A8A8E),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Mention shared items like: "Alex and Jamie shared the fries and we all had the salad."',
                                                  style: textTheme.bodyMedium?.copyWith(
                                                    color: const Color(0xFF8A8A8E),
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
                                                color: const Color(0xFF8A8A8E),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Use the item numbers! Say things like "Emma got #2 and we all shared #5" — super handy when dishes have complex names!',
                                                  style: textTheme.bodyMedium?.copyWith(
                                                    color: const Color(0xFF8A8A8E),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Transcription TextField (shown after recording)
                    if (_transcription != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          key: const ValueKey('transcriptionField'),
                          controller: _transcriptionController,
                          focusNode: _transcriptionFocusNode,
                          style: textTheme.bodyMedium,
                          decoration: InputDecoration(
                            labelText: 'Transcription',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          maxLines: 5,
                          onChanged: (value) {
                            if (widget.onTranscriptionChanged != null) {
                              widget.onTranscriptionChanged!(value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Receipt Summary Card with Neumorphic styling
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.9),
                              blurRadius: 8,
                              offset: const Offset(-2, -2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with Edit Items button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Receipt Summary',
                                      style: textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1D1D1F),
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: widget.onEditItems,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 4,
                                          offset: const Offset(1, 1),
                                          spreadRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.9),
                                          blurRadius: 4,
                                          offset: const Offset(-1, -1),
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Item list
                            ...widget.itemsToAssign.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    // Quantity pill with Neumorphic styling
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 3,
                                            offset: const Offset(1, 1),
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${item.quantity}x',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF8A8A8E),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Item name and price
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Row(
                                              children: [
                                                Text(
                                                  '#${index + 1}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    item.name,
                                                    style: TextStyle(
                                                      color: const Color(0xFF1D1D1F),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF1D1D1F),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            
                            // Subtotal
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtotal',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: const Color(0xFF1D1D1F),
                                  ),
                                ),
                                Text(
                                  '\$${_calculateSubtotal().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: const Color(0xFF1D1D1F),
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
              
              // Bottom button (Process Assignments)
              if (_transcription != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: ElevatedButton(
                      onPressed: !_isLoading ? _processTranscription : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, // Use dark blue from AppColors
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        shadowColor: Colors.black.withOpacity(0.1),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Process Assignments',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
} 