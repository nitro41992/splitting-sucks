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
  final ImagePicker? picker; // Added for testability

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
    this.picker, // Added
  });

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  // Use the injected picker if available, otherwise create a new one.
  late final ImagePicker _picker;

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
  }

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
       showFullImageDialog(context, imageFile: widget.imageFile!);
     } else if (widget.imageUrl != null) {
       showFullImageDialog(context, imageFile: null, imageUrl: widget.imageUrl!);
     }
   }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Add debug print to see when build method runs with URLs
    debugPrint('[ReceiptUploadScreen Build] Building - isLoading: ${widget.isLoading}, isParsed: ${widget.isSuccessfullyParsed}, hasImageFile: ${widget.imageFile != null}, hasImageUrl: ${widget.imageUrl != null}, hasThumbUrl: ${widget.loadedThumbnailUrl != null}, thumbUrlValue: ${widget.loadedThumbnailUrl}');

    // Determine if we have any image to display (local file, network URL, or thumbnail URL)
    final bool hasLocalImage = widget.imageFile != null;
    final bool hasNetworkImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
    final bool hasNetworkThumbnail = widget.loadedThumbnailUrl != null && widget.loadedThumbnailUrl!.isNotEmpty;
    final bool shouldShowImagePreview = hasLocalImage || hasNetworkImage || hasNetworkThumbnail;

    // Select the image provider based on availability
    Widget imagePreviewWidget;
    String heroTag = 'receipt_image_placeholder'; // Default tag, non-nullable String

    if (hasLocalImage) {
      heroTag = 'receipt_image_${widget.imageFile!.path}';
      imagePreviewWidget = Image.file(
        widget.imageFile!,
        fit: BoxFit.cover,
      );
    } else if (hasNetworkImage) {
      heroTag = 'receipt_image_${widget.imageUrl}';
      imagePreviewWidget = CachedNetworkImage(
        key: ValueKey('main_image_${widget.imageUrl}'),
        imageUrl: widget.imageUrl!,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) {
          if (hasNetworkThumbnail) {
            return CachedNetworkImage(
              key: ValueKey('thumbnail_as_placeholder_${widget.loadedThumbnailUrl}'),
              imageUrl: widget.loadedThumbnailUrl!,
              fit: BoxFit.cover,
              placeholder: (ctx, thumbnailUrl) => Container(
                color: colorScheme.surfaceVariant.withOpacity(0.5),
              ),
              errorWidget: (context, thumbnailUrl, error) => const Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.grey,
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
        errorWidget: (context, url, error) {
          debugPrint('[ReceiptUploadScreen MainImage CachedNetworkImage] ERROR WIDGET BUILT for ${widget.imageUrl}. Error: $error');
          return Container(
            color: Colors.red.withOpacity(0.3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 8),
                Text(
                  'Main image failed to load.\nURL: ${widget.imageUrl}\nError: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 10),
                ),
              ],
            ),
          );
        },
      );
    } else if (hasNetworkThumbnail) {
      heroTag = 'receipt_image_${widget.loadedThumbnailUrl}';
      imagePreviewWidget = CachedNetworkImage(
        imageUrl: widget.loadedThumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => _buildImageErrorPlaceholder(context, 'Thumbnail could not be loaded'),
      );
    } else {
      // This case should ideally not be reached if shouldShowImagePreview is false,
      // but as a fallback for the Stack if needed.
      imagePreviewWidget = Container(color: colorScheme.surfaceVariant); 
    }

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
                    if (shouldShowImagePreview) ...[ // Show image preview section
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
                                      Hero(
                                        tag: heroTag, // Use dynamic heroTag
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            key: const ValueKey('image_preview_inkwell'),
                                            onTap: () {
                                              if (hasLocalImage) {
                                                _showFullImage();
                                              } else if (hasNetworkImage) {
                                                showFullImageDialog(context, imageFile: null, imageUrl: widget.imageUrl);
                                              } else if (hasNetworkThumbnail) {
                                                showFullImageDialog(context, imageFile: null, imageUrl: widget.loadedThumbnailUrl);
                                              }
                                            },
                                            child: imagePreviewWidget,
                                          ),
                                        ),
                                      ),
                                      if (widget.isLoading)
                                        Container(
                                          color: Colors.black.withOpacity(0.3),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(
                                                  key: const ValueKey('loading_indicator'),
                                                  color: colorScheme.onPrimary,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Processing Receipt...',
                                                  key: const ValueKey('loading_text'),
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
                                          key: const ValueKey('retry_button'),
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
                                          key: const ValueKey('use_this_button'),
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
                    ] else ...[ // Show "No image selected" UI and upload buttons
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 80,
                        color: colorScheme.primary.withOpacity(0.6),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Upload or Take a Photo of Your Receipt',
                        key: const ValueKey('upload_placeholder_text'),
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text(
                          'Capture a photo or select an image from your gallery to get started.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('gallery_button'),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Gallery'),
                            onPressed: widget.isLoading ? null : _pickImage,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(140, 50),
                              textStyle: textTheme.labelLarge,
                            ),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            key: const ValueKey('camera_button'),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Camera'),
                            onPressed: widget.isLoading ? null : _takePicture,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(140, 50),
                              textStyle: textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (widget.isLoading) ... [
                        const SizedBox(height: 20), // Add some space if loading indicator is shown for processing
                    ],
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper widget to build a consistent error placeholder for images
  Widget _buildImageErrorPlaceholder(BuildContext context, String message) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      color: colorScheme.surfaceVariant, // Use a less jarring background
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 48,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                message,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.imageFile == null) // Only show retry if it's for a network image error
              ElevatedButton(
                onPressed: widget.onRetry, // This should re-trigger load or allow re-selection
                child: const Text('Try Again / Change'),
              ),
          ],
        ),
      ),
    );
  }
}

// Ensure showFullImageDialog can handle network URLs (add nullable networkImageUrl)
// void showFullImageDialog(BuildContext context, File? imageFile, {String? networkImageUrl}) { // REMOVED this conflicting local definition
//   // ... existing code ...
// } 