import 'dart:io';
import 'package:flutter/material.dart';
import '../../screens/receipt_upload_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/workflow_state.dart';

class UploadStepWidget extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final String? loadedThumbnailUrl;
  final bool isLoading;
  final bool isSuccessfullyParsed;
  final Function(File?) onImageSelected;
  final VoidCallback onParseReceipt;
  final VoidCallback onRetry;
  final bool isUploading;

  const UploadStepWidget({
    Key? key,
    required this.imageFile,
    required this.imageUrl,
    this.loadedThumbnailUrl,
    required this.isLoading,
    required this.isSuccessfullyParsed,
    required this.onImageSelected,
    required this.onParseReceipt,
    required this.onRetry,
    this.isUploading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Direct pass-through to ReceiptUploadScreen with additional state checking
    // to prevent duplicate uploads and processing
    return ReceiptUploadScreen(
      imageFile: imageFile,
      imageUrl: imageUrl,
      loadedThumbnailUrl: loadedThumbnailUrl,
      isLoading: isLoading || isUploading,  // Account for both loading states
      isSuccessfullyParsed: isSuccessfullyParsed,
      onImageSelected: onImageSelected,
      onParseReceipt: onParseReceipt,
      onRetry: onRetry,
    );
  }
} 