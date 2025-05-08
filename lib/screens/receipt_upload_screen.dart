import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/receipt_upload/full_image_viewer.dart'; // Import the new viewer
import '../services/file_helper.dart'; // Import FileHelper
import '../theme/app_colors.dart';
import '../utils/toast_helper.dart'; // Import the toast helper
import 'package:cached_network_image/cached_network_image.dart'; // Needed for network image

class ReceiptUploadScreen extends StatefulWidget {
  final File? imageFile;
  final String? imageUrl;
  final String? loadedThumbnailUrl;
  final bool isLoading;
  final bool isSuccessfullyParsed;
  final Function(File?) onImageSelected;
  final Function() onParseReceipt;
  final Function() onRetry; // Callback to clear the image

  const ReceiptUploadScreen({
    super.key,
    required this.imageFile,
    this.imageUrl,
    this.loadedThumbnailUrl,
    required this.isLoading,
    required this.isSuccessfullyParsed,
    required this.onImageSelected,
    required this.onParseReceipt,
    required this.onRetry,
  });

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      
      if (photo != null) {
        final file = File(photo.path);
        // Validate the image file before passing it to the parent
        if (FileHelper.isValidImageFile(file)) {
          widget.onImageSelected(file);
          
          if (mounted) {
            ToastHelper.showToast(
              context,
              'Photo captured successfully!',
              isSuccess: true
            );
          }
        } else {
          if (!mounted) return;
          ToastHelper.showToast(
            context,
            'The captured image is invalid or corrupted. Please try again.',
            isError: true
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showToast(
        context,
        'Error taking picture: ${e.toString()}',
        isError: true
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null) {
        final file = File(image.path);
        // Validate the image file before passing it to the parent
        if (FileHelper.isValidImageFile(file)) {
          widget.onImageSelected(file);
          
          if (mounted) {
            ToastHelper.showToast(
              context,
              'Image selected successfully!',
              isSuccess: true
            );
          }
        } else {
          if (!mounted) return;
          ToastHelper.showToast(
            context,
            'The selected image is invalid or corrupted. Please choose another image.',
            isError: true
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showToast(
        context,
        'Error picking image: ${e.toString()}',
        isError: true
      );
    }
  }

  void _showFullImage() {
     if (widget.imageFile != null) {
       showFullImageDialog(context, widget.imageFile!);
     }
   }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Add debug print to see when build method runs with URLs
    debugPrint('[ReceiptUploadScreen Build] Building - isLoading: ${widget.isLoading}, isParsed: ${widget.isSuccessfullyParsed}, hasImageFile: ${widget.imageFile != null}, hasImageUrl: ${widget.imageUrl != null}, hasThumbUrl: ${widget.loadedThumbnailUrl != null}, thumbUrlValue: ${widget.loadedThumbnailUrl}');

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.imageFile != null) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AspectRatio(
                                aspectRatio: 3 / 4, // Portrait ratio for receipt
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Image Preview with Hero tag for smooth transition
                                      Hero(
                                        tag: 'receipt_image',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _showFullImage, // Use the method here
                                            child: Image.file(
                                              widget.imageFile!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                // Handle image loading errors
                                                return Container(
                                                  color: colorScheme.errorContainer,
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.broken_image,
                                                          color: colorScheme.onErrorContainer,
                                                          size: 48,
                                                        ),
                                                        const SizedBox(height: 16),
                                                        Text(
                                                          'Image could not be loaded',
                                                          style: textTheme.bodyLarge?.copyWith(
                                                            color: colorScheme.onErrorContainer,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                        const SizedBox(height: 8),
                                                        ElevatedButton(
                                                          onPressed: widget.onRetry,
                                                          child: const Text('Try Again'),
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
                                      // Loading indicator overlay
                                      if (widget.isLoading)
                                        Container(
                                          color: Colors.black.withOpacity(0.3),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(
                                                  color: colorScheme.onPrimary,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Processing Receipt...',
                                                  style: textTheme.bodyLarge?.copyWith(
                                                    color: colorScheme.onPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              // Action buttons below the image
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (!widget.isLoading) ...[
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: (widget.isLoading || widget.isSuccessfullyParsed || (widget.imageFile == null && widget.imageUrl == null))
                                              ? null // Disabled if loading, successfully parsed, or no image to clear
                                              : widget.onRetry, // Call the retry callback
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Retry'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: colorScheme.errorContainer,
                                            foregroundColor: colorScheme.onErrorContainer,
                                            minimumSize: const Size(0, 48),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: widget.onParseReceipt,
                                          icon: const Icon(Icons.check_circle_outline),
                                          label: const Text('Use This'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: colorScheme.primary,
                                            foregroundColor: colorScheme.onPrimary,
                                            minimumSize: const Size(0, 48),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ] else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AspectRatio(
                                aspectRatio: 3 / 4,
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Display CachedNetworkImage for loaded drafts
                                      Hero(
                                        tag: 'receipt_image',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell( // Can still allow tap to view full if needed
                                            // onTap: _showFullNetworkImage, // Need a similar function for network images
                                            child: CachedNetworkImage(
                                              imageUrl: widget.imageUrl!, // Use the main image URL
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) {
                                                // Show thumbnail as placeholder if available
                                                if (widget.loadedThumbnailUrl != null && widget.loadedThumbnailUrl!.isNotEmpty) {
                                                  return CachedNetworkImage(
                                                    imageUrl: widget.loadedThumbnailUrl!,
                                                    fit: BoxFit.cover, // Or BoxFit.contain for placeholder?
                                                    // Optional: add a smaller placeholder for the thumbnail itself
                                                    placeholder: (context, url) => const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.0))),
                                                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                                                  );
                                                } else {
                                                  // Default placeholder if no thumbnail URL
                                                  return const Center(child: CircularProgressIndicator());
                                                }
                                              },
                                              errorWidget: (context, url, error) => _buildImageErrorWidget(context, colorScheme, textTheme, 'Saved image could not be loaded'),
                                            ),
                                          ),
                                        ),
                                      ),
                                       // Loading indicator overlay (for parsing, not initial load)
                                      if (widget.isLoading) 
                                        _buildLoadingIndicator(colorScheme, textTheme),
                                    ],
                                  ),
                                ),
                              ),
                              _buildActionButtons(context, colorScheme, textTheme),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      _buildUploadPrompt(context, colorScheme, textTheme),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildImageErrorWidget(BuildContext context, ColorScheme colorScheme, TextTheme textTheme, String errorMessage) {
    return Container(
      color: colorScheme.errorContainer,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image,
              color: colorScheme.onErrorContainer,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: widget.onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: colorScheme.onPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              'Processing Receipt...',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!widget.isLoading) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: (widget.isLoading || widget.isSuccessfullyParsed || (widget.imageFile == null && widget.imageUrl == null))
                    ? null // Disabled if loading, successfully parsed, or no image to clear
                    : widget.onRetry, // Call the retry callback
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.onParseReceipt,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Use This'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadPrompt(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: 80,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Upload Receipt',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Take a picture or select one from your gallery',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildUploadButton(
                context,
                icon: Icons.camera_alt,
                label: 'Camera',
                onPressed: _takePicture,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 16),
              _buildUploadButton(
                context,
                icon: Icons.photo_library,
                label: 'Gallery',
                onPressed: _pickImage,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }
} 