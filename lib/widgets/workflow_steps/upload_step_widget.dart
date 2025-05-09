import 'dart:io';
import 'package:flutter/material.dart';
import '../../screens/receipt_upload_screen.dart';

class UploadStepWidget extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final String? loadedThumbnailUrl;
  final bool isLoading;
  final bool isSuccessfullyParsed;
  final Function(File?) onImageSelected;
  final Future<void> Function() onParseReceipt;
  final VoidCallback onRetry;

  const UploadStepWidget({
    Key? key,
    required this.imageFile,
    required this.imageUrl,
    required this.loadedThumbnailUrl,
    required this.isLoading,
    required this.isSuccessfullyParsed,
    required this.onImageSelected,
    required this.onParseReceipt,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The debugPrint from the original _buildStepContent for case 0 can be here if needed,
    // or in the _WorkflowModalBodyState before calling this widget.
    // For now, we'll assume relevant state is passed correctly.
    // debugPrint('[_buildStepContent Consumer for Upload] consumedState.loadedImageUrl: $imageUrl, consumedState.loadedThumbnailUrl: $loadedThumbnailUrl');
    
    return ReceiptUploadScreen(
      imageFile: imageFile,
      imageUrl: imageUrl,
      loadedThumbnailUrl: loadedThumbnailUrl,
      isLoading: isLoading,
      isSuccessfullyParsed: isSuccessfullyParsed,
      onImageSelected: onImageSelected,
      onParseReceipt: onParseReceipt,
      onRetry: onRetry,
    );
  }
} 