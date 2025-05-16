import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/receipt_upload/full_image_viewer.dart'; // Import the full image viewer
import '../services/file_helper.dart'; // Import FileHelper
import '../utils/toast_helper.dart'; // Import the toast helper
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/neumorphic_theme.dart'; // Use NeumorphicTheme instead of AppColors

// These are now imported from NeumorphicTheme
// const Color lightGrey = Color(0xFFF5F5F7);
// const Color primaryTextColor = Color(0xFF1D1D1F);
// const Color secondaryTextColor = Color(0xFF8A8A8E);

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

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> with SingleTickerProviderStateMixin {
  // Use the injected picker if available, otherwise create a new one.
  late final ImagePicker _picker;
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ReceiptUploadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Detect if an image was newly selected
    final bool imageNowSelected = (widget.imageFile != null || widget.imageUrl != null) && 
                                 (oldWidget.imageFile == null && oldWidget.imageUrl == null);
    
    // Only auto-proceed if an image was newly selected AND we're not already loading
    if (imageNowSelected && !widget.isLoading) {
      debugPrint('[ReceiptUploadScreen] Image newly selected and not loading. Setting up auto-proceed timer.');
      _autoProceedAfterImageSelection();
    } else if (imageNowSelected && widget.isLoading) {
      debugPrint('[ReceiptUploadScreen] Image newly selected but already loading. Skipping auto-proceed.');
    }
  }

  // Auto proceed to process receipt after selecting an image
  void _autoProceedAfterImageSelection() {
    // Add a small delay before auto-proceeding to allow the user to see the image
    Future.delayed(const Duration(milliseconds: 800), () {
      // Only proceed if we're still mounted, have an image, and not already loading
      if (mounted && 
          (widget.imageFile != null || widget.imageUrl != null) && 
          !widget.isLoading) {
        // Auto-proceed when we have a valid image
        debugPrint('[ReceiptUploadScreen] Auto-proceeding to parse receipt after delay.');
        widget.onParseReceipt();
      } else if (mounted && widget.isLoading) {
        debugPrint('[ReceiptUploadScreen] Not auto-proceeding because isLoading is true.');
      }
    });
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
      color: NeumorphicTheme.pageBackground,
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
                color: NeumorphicTheme.slateBlue,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Instructional text heading
            Text(
              'Scan or Upload Your Receipt',
              key: const ValueKey('upload_placeholder_text'),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: NeumorphicTheme.darkGrey,
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
                color: NeumorphicTheme.mediumGrey,
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
            
            // Add extra bottom padding (no longer needed with bottom bar removed)
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Build the image preview screen with floating action buttons
  Widget _buildImagePreviewScreen(Widget imagePreviewWidget, String heroTag) {
    return Stack(
      children: [
        // Main scrollable content
        SingleChildScrollView(
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
                
                // Informational text - what to do next
                // Text(
                //   'Tap the buttons below the image to change or process it.',
                //   textAlign: TextAlign.center,
                //   style: TextStyle(
                //     color: secondaryTextColor,
                //     fontSize: 14,
                //   ),
                // ),
                
                // Add bottom padding
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        
        // Overlay floating action buttons near the bottom of the image
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left floating button - Change image
                _buildFloatingActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'Change',
                  onPressed: widget.isLoading ? null : widget.onRetry,
                  isPrimary: false,
                ),
                
                // Right floating button - Process image
                _buildFloatingActionButton(
                  icon: Icons.auto_fix_high,
                  label: 'Process',
                  onPressed: widget.isLoading ? null : () => widget.onParseReceipt(),
                  isPrimary: true,
                ),
              ],
            ),
          ),
        ),
      ],
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
    final Color backgroundColor = isPrimary ? NeumorphicTheme.slateBlue : Colors.white;
    final Color textColor = isPrimary ? Colors.white : NeumorphicTheme.slateBlue;
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
              : NeumorphicTheme.slateBlue.withOpacity(0.05),
          highlightColor: isPrimary 
              ? Colors.white.withOpacity(0.05) 
              : NeumorphicTheme.slateBlue.withOpacity(0.01),
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
  
  // Build a floating action button for image actions
  Widget _buildFloatingActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
  }) {
    // Colors based on primary/secondary and enabled/disabled state
    final Color backgroundColor = isPrimary ? NeumorphicTheme.slateBlue : NeumorphicTheme.mutedCoral;
    final Color textColor = Colors.white;
    final bool isEnabled = onPressed != null;
    
    // Apply opacity for disabled state
    final Color effectiveBackgroundColor = isEnabled 
        ? backgroundColor 
        : backgroundColor.withOpacity(isPrimary ? 0.6 : 0.9);
    final Color effectiveTextColor = isEnabled 
        ? textColor 
        : textColor.withOpacity(0.6);
    
    return Container(
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isEnabled ? [
          BoxShadow(
            color: Colors.black.withOpacity(isPrimary ? 0.15 : 0.08),
            blurRadius: 10,
            offset: const Offset(3, 3),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(isPrimary ? 0.1 : 0.9),
            blurRadius: 10,
            offset: const Offset(-3, -3),
            spreadRadius: 0,
          ),
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: effectiveTextColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: effectiveTextColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
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
              color: NeumorphicTheme.mediumGrey,
              size: 48,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                message,
                style: const TextStyle(
                  color: NeumorphicTheme.mediumGrey,
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