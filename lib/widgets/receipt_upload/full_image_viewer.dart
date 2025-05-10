import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullImageViewer extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;

  FullImageViewer({
    super.key,
    this.imageFile,
    this.imageUrl,
  }) : assert(imageFile != null || (imageUrl != null && imageUrl.isNotEmpty), 'Either imageFile or a non-empty imageUrl must be provided.');

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    Widget imageWidget;
    String heroTag;

    if (imageFile != null) {
      imageWidget = Image.file(
        imageFile!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget(context, textTheme, 'Failed to load local image', 'The image file may be corrupted or missing.');
        },
      );
      heroTag = 'receipt_image_viewer_${imageFile!.path}';
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) {
          return _buildErrorWidget(context, textTheme, 'Failed to load network image', 'The image could not be fetched. Please check the URL and your connection.');
        },
      );
      heroTag = 'receipt_image_viewer_${imageUrl!}';
    } else {
      imageWidget = _buildErrorWidget(context, textTheme, 'Image Not Available', 'No valid image source was provided.');
      heroTag = 'receipt_image_viewer_error';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dismissible background
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black87),
          ),
          // Image viewer
          Hero(
            tag: heroTag,
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: imageWidget,
                ),
              ),
            ),
          ),
          // Close button
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Zoom hint
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.zoom_out_map, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      'Pinch to zoom • Drag to move',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildErrorWidget(BuildContext context, TextTheme textTheme, String title, String message) {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.white70, size: 48),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ],
    ),
  );
}

void showFullImageDialog(BuildContext context, {File? imageFile, String? imageUrl}) {
  if (imageFile == null && (imageUrl == null || imageUrl.isEmpty)) {
    debugPrint("showFullImageDialog: Both imageFile and imageUrl are null/empty. Dialog not shown.");
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => FullImageViewer(imageFile: imageFile, imageUrl: imageUrl),
  );
} 