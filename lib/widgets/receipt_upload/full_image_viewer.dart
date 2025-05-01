import 'dart:io';
import 'package:flutter/material.dart';

class FullImageViewer extends StatelessWidget {
  final File imageFile;

  const FullImageViewer({
    super.key,
    required this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

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
            tag: 'receipt_image', // Same tag as in the upload screen
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Material( // Added Material to avoid Hero transition issues
                  color: Colors.transparent,
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.broken_image,
                                color: Colors.white70,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load image',
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'The image file may be corrupted or missing',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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

void showFullImageDialog(BuildContext context, File imageFile) {
  showDialog(
    context: context,
    builder: (context) => FullImageViewer(imageFile: imageFile),
  );
} 