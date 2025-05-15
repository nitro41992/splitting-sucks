import 'dart:io';
import 'package:flutter/material.dart';
import '../../screens/receipt_upload_screen.dart';
import '../../theme/app_colors.dart';

class UploadStepWidget extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final String? loadedThumbnailUrl;
  final bool isLoading;
  final bool isSuccessfullyParsed;
  final Function(File?) onImageSelected;
  final Future<void> Function() onParseReceipt;
  final VoidCallback onRetry;
  final String? billName;

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
    this.billName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We pass through to the ReceiptUploadScreen directly, avoiding any wrapping widgets
    // that might cause conflicts with parent layout constraints
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