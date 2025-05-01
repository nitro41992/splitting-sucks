import 'dart:io';

class FileHelper {
  /// Validates that a file exists, is not empty, and is an image file
  static bool isValidImageFile(File? file) {
    if (file == null) return false;
    
    try {
      // Check if file exists
      if (!file.existsSync()) {
        print('File does not exist: ${file.path}');
        return false;
      }
      
      // Check if file is not empty
      if (file.lengthSync() == 0) {
        print('File is empty: ${file.path}');
        return false;
      }
      
      // Check if file has a valid image extension
      final validExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif'];
      final fileExtension = file.path.toLowerCase().split('.').last;
      if (!validExtensions.any((ext) => fileExtension.contains(ext))) {
        print('File does not have a valid image extension: ${file.path}');
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error validating image file: $e');
      return false;
    }
  }
  
  /// Creates a safe copy of an image file with proper validation
  static Future<File?> copyImageSafely(File sourceFile, String targetPath) async {
    try {
      // Validate source file
      if (!isValidImageFile(sourceFile)) {
        print('Source file is not a valid image: ${sourceFile.path}');
        return null;
      }
      
      // Create a copy of the file
      final newFile = await sourceFile.copy(targetPath);
      
      // Validate the new file
      if (isValidImageFile(newFile)) {
        print('Image copied successfully to: ${newFile.path}');
        return newFile;
      } else {
        print('Failed to create a valid copy of the image');
        
        // Try to clean up if the file exists but is invalid
        if (newFile.existsSync()) {
          await newFile.delete();
        }
        
        return null;
      }
    } catch (e) {
      print('Error copying image file: $e');
      return null;
    }
  }
} 