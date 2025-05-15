import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/receipt_upload/full_image_viewer.dart'; // Import the full image viewer
import '../services/file_helper.dart'; // Import FileHelper
import '../theme/app_colors.dart';
import '../utils/toast_helper.dart'; // Import the toast helper
import 'package:cached_network_image/cached_network_image.dart';

// Define Slate Blue color constant
const Color slateBlue = Color(0xFF5D737E);
const Color lightGrey = Color(0xFFF5F5F7);
const Color primaryTextColor = Color(0xFF1D1D1F);
const Color secondaryTextColor = Color(0xFF8A8A8E);

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
      showFullImageDialog(context, imageUrl: widget.imageUrl!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Size screenSize = MediaQuery.of(context).size;

    // Debug print for tracking
    debugPrint('[ReceiptUploadScreen Build] Building - isLoading: ${widget.isLoading}, isParsed: ${widget.isSuccessfullyParsed}, hasImageFile: ${widget.imageFile != null}, hasImageUrl: ${widget.imageUrl != null}, hasThumbUrl: ${widget.loadedThumbnailUrl != null}, thumbUrlValue: ${widget.loadedThumbnailUrl}');

    // Determine if we have any image to display
    final bool hasLocalImage = widget.imageFile != null;
    final bool hasNetworkImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
    final bool hasNetworkThumbnail = widget.loadedThumbnailUrl != null && widget.loadedThumbnailUrl!.isNotEmpty;
    final bool shouldShowImagePreview = hasLocalImage || hasNetworkImage || hasNetworkThumbnail;

    // Configure image widget
    Widget imagePreviewWidget;
    String heroTag = 'receipt_image_placeholder';

    if (hasLocalImage) {
      heroTag = 'receipt_image_${widget.imageFile!.path}';
      imagePreviewWidget = Image.file(
        widget.imageFile!,
        fit: BoxFit.contain,
      );
    } else if (hasNetworkImage) {
      heroTag = 'receipt_image_${widget.imageUrl}';
      imagePreviewWidget = CachedNetworkImage(
        key: ValueKey('main_image_${widget.imageUrl}'),
        imageUrl: widget.imageUrl!,
        fit: BoxFit.contain,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) {
          if (hasNetworkThumbnail) {
            return CachedNetworkImage(
              key: ValueKey('thumbnail_as_placeholder_${widget.loadedThumbnailUrl}'),
              imageUrl: widget.loadedThumbnailUrl!,
              fit: BoxFit.contain,
              placeholder: (ctx, thumbnailUrl) => Container(
                color: Colors.grey.withOpacity(0.2),
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
          debugPrint('[ReceiptUploadScreen MainImage CachedNetworkImage] ERROR: $error');
          return _buildImageErrorPlaceholder(context, 'Image failed to load');
        },
      );
    } else if (hasNetworkThumbnail) {
      heroTag = 'receipt_image_${widget.loadedThumbnailUrl}';
      imagePreviewWidget = CachedNetworkImage(
        imageUrl: widget.loadedThumbnailUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => _buildImageErrorPlaceholder(context, 'Thumbnail could not be loaded'),
      );
    } else {
      imagePreviewWidget = Container(color: Colors.grey.withOpacity(0.2));
    }

    // This container directly holds the content
    return Container(
      color: lightGrey,
      child: shouldShowImagePreview 
          ? _buildImagePreviewScreen(imagePreviewWidget, heroTag)
          : _buildInitialUploadScreen(textTheme),
    );
  }

  // Build the initial upload screen with vertically stacked buttons
  Widget _buildInitialUploadScreen(TextTheme textTheme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            
            // Primary illustrative icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(4, 4),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.9),
                    blurRadius: 12,
                    offset: const Offset(-4, -4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: slateBlue,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Instructional text heading
            Text(
              'Scan or Upload Your Receipt',
              key: const ValueKey('upload_placeholder_text'),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Instructional text sub-heading
            Text(
              'Choose from your gallery or use the camera to capture your bill.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: secondaryTextColor,
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Gallery button - Neumorphic style
            _buildNeumorphicButton(
              icon: Icons.photo_library_outlined,
              label: 'Upload from Gallery',
              onPressed: widget.isLoading ? null : _pickImage,
              isPrimary: false,
            ),
            
            const SizedBox(height: 16),
            
            // Camera button - Neumorphic style with primary color
            _buildNeumorphicButton(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo with Camera',
              onPressed: widget.isLoading ? null : _takePicture,
              isPrimary: true,
            ),
            
            // Add extra space at the bottom to ensure buttons don't get covered by navigation
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // Build the image preview screen
  Widget _buildImagePreviewScreen(Widget imagePreviewWidget, String heroTag) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            
            // Main image preview with enhanced Neumorphic styling
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    offset: const Offset(4, 4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.9),
                    offset: const Offset(-4, -4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 3/4, // Portrait ratio for receipt
                  child: GestureDetector(
                    onTap: _showFullImage,
                    child: Hero(
                      tag: heroTag,
                      child: Material(
                        color: Colors.white,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            imagePreviewWidget,
                            if (widget.isLoading)
                              Container(
                                color: Colors.black.withOpacity(0.5),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Processing Receipt...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
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
                  ),
                ),
              ),
            ),
            
            // Parse button with Neumorphic styling
            _buildNeumorphicButton(
              icon: Icons.auto_fix_high,
              label: 'Process Receipt',
              onPressed: widget.isLoading ? null : () => widget.onParseReceipt(),
              isPrimary: true,
            ),
            
            const SizedBox(height: 16),
            
            // Retry button
            _buildNeumorphicButton(
              icon: Icons.refresh_rounded,
              label: 'Select Different Image',
              onPressed: widget.isLoading ? null : widget.onRetry,
              isPrimary: false,
            ),
            
            // Add extra space at the bottom
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // Build a Neumorphic-styled button with proper shadows and raised effect
  Widget _buildNeumorphicButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
  }) {
    // Colors based on primary/secondary and enabled/disabled state
    final Color backgroundColor = isPrimary ? slateBlue : Colors.white;
    final Color textColor = isPrimary ? Colors.white : slateBlue;
    final bool isEnabled = onPressed != null;
    
    // Apply opacity for disabled state
    final Color effectiveBackgroundColor = isEnabled 
        ? backgroundColor 
        : backgroundColor.withOpacity(isPrimary ? 0.6 : 0.9);
    final Color effectiveTextColor = isEnabled 
        ? textColor 
        : textColor.withOpacity(0.6);
    
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isEnabled ? [
          // Stronger shadow for raised effect - bottom right
          BoxShadow(
            color: Colors.black.withOpacity(isPrimary ? 0.15 : 0.08),
            blurRadius: 10,
            offset: const Offset(4, 4),
            spreadRadius: 0,
          ),
          // Lighter highlight for neumorphic effect - top left
          BoxShadow(
            color: Colors.white.withOpacity(isPrimary ? 0.1 : 0.9),
            blurRadius: 10,
            offset: const Offset(-4, -4),
            spreadRadius: 0,
          ),
          // Extra subtle inner highlight for depth
          BoxShadow(
            color: isPrimary 
                ? Colors.white.withOpacity(0.05) 
                : Colors.black.withOpacity(0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: isPrimary 
              ? Colors.white.withOpacity(0.1) 
              : slateBlue.withOpacity(0.05),
          highlightColor: isPrimary 
              ? Colors.white.withOpacity(0.05) 
              : slateBlue.withOpacity(0.01),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: effectiveTextColor,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: effectiveTextColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to build a consistent error placeholder for images
  Widget _buildImageErrorPlaceholder(BuildContext context, String message) {
    return Container(
      color: Colors.grey.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: secondaryTextColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                message,
                style: const TextStyle(
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
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