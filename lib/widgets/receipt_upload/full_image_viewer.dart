import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/file_helper.dart'; // Import FileHelper

// Global cache for storing converted URLs
// This prevents multiple conversions of the same URL
final Map<String, String> _imageUrlCache = {};

class FullImageViewer extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final bool isNetworkImage;

  const FullImageViewer({
    super.key,
    this.imageFile,
    this.imageUrl,
    this.isNetworkImage = false,
  }) : assert(imageFile != null || (imageUrl != null && isNetworkImage));

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
                  child: isNetworkImage
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.contain,
                          // Enable better caching with size hints
                          memCacheWidth: 1500,
                          memCacheHeight: 2000,
                          // Pre-cache at higher quality for zooming
                          maxWidthDiskCache: 2000,
                          maxHeightDiskCache: 2500,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (context, url, error) => _buildErrorWidget(context, textTheme),
                        )
                      : Image.file(
                          imageFile!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildErrorWidget(context, textTheme);
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

  Widget _buildErrorWidget(BuildContext context, TextTheme textTheme) {
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
  }
}

void showFullImageDialog(BuildContext context, File imageFile) {
  showDialog(
    context: context,
    builder: (context) => FullImageViewer(imageFile: imageFile),
  );
}

// Updated to handle gs:// URLs with caching
void showFullImageDialogFromUrl(BuildContext context, String imageUrl) {
  // If it's a gs:// URL, we need to convert it first
  if (imageUrl.startsWith('gs://')) {
    // Check if we already have this URL converted in our global cache
    if (_imageUrlCache.containsKey(imageUrl)) {
      // Use the cached URL directly
      showDialog(
        context: context,
        builder: (context) => FullImageViewer(
          imageUrl: _imageUrlCache[imageUrl],
          isNetworkImage: true,
        ),
      );
      return;
    }
    
    // Need to convert - show loading first
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return FutureBuilder<String>(
          future: FileHelper.getDownloadURLFromGsURI(imageUrl),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Dialog(
                backgroundColor: Colors.black87,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Dialog(
                backgroundColor: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              // Cache the result for future use
              _imageUrlCache[imageUrl] = snapshot.data!;
              
              // Close this dialog and open the image viewer with the HTTP URL
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(dialogContext).pop();
                showDialog(
                  context: context,
                  builder: (context) => FullImageViewer(
                    imageUrl: snapshot.data!,
                    isNetworkImage: true,
                  ),
                );
              });
              return Container(); // Placeholder while transitioning
            }
          },
        );
      },
    );
  } else {
    // It's already an HTTP URL, show it directly (and cache it)
    _imageUrlCache[imageUrl] = imageUrl;
    
    showDialog(
      context: context,
      builder: (context) => FullImageViewer(
        imageUrl: imageUrl,
        isNetworkImage: true,
      ),
    );
  }
} 