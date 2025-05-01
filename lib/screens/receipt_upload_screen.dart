import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/receipt_upload/full_image_viewer.dart'; // Import the new viewer
import '../services/file_helper.dart'; // Import FileHelper

class ReceiptUploadScreen extends StatefulWidget {
  final File? imageFile;
  final bool isLoading;
  final Function(File?) onImageSelected;
  final Function() onParseReceipt;
  final Function() onRetry; // Callback to clear the image

  const ReceiptUploadScreen({
    super.key,
    required this.imageFile,
    required this.isLoading,
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
        imageQuality: 100,
      );
      if (photo != null) {
        final file = File(photo.path);
        // Validate the image file before passing it to the parent
        if (FileHelper.isValidImageFile(file)) {
          widget.onImageSelected(file);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('The captured image is invalid or corrupted. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking picture: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (image != null) {
        final file = File(image.path);
        // Validate the image file before passing it to the parent
        if (FileHelper.isValidImageFile(file)) {
          widget.onImageSelected(file);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('The selected image is invalid or corrupted. Please choose another image.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
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
                    if (widget.imageFile != null)
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
                                          onPressed: widget.onRetry, // Call the retry callback
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
                      )
                    else
                      Padding(
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
                      ),
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
} 