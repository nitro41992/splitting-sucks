import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint;

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
      
      // Check if file has a valid image extension - FIXED
      final validExtensions = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'];
      final fileExtension = file.path.toLowerCase().split('.').last;
      if (!validExtensions.contains(fileExtension)) {
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

  /// Convert a Firebase Storage gs:// URI to an HTTPS download URL
  /// 
  /// Example: 
  /// - Input: gs://your-bucket/receipts/image.jpg
  /// - Output: https://firebasestorage.googleapis.com/v0/b/your-bucket/o/receipts%2Fimage.jpg?alt=media
  static Future<String> getDownloadURLFromGsURI(String? gsUri) async {
    if (gsUri == null || gsUri.isEmpty || !gsUri.startsWith('gs://')) {
      debugPrint('Invalid gs:// URI: $gsUri');
      return ''; // Return empty string for invalid URIs
    }

    try {
      // Extract bucket and path from gs:// URI
      // Format: gs://bucket-name/path/to/file.jpg
      final uri = gsUri.replaceFirst('gs://', '');
      final components = uri.split('/');
      
      if (components.length < 2) {
        debugPrint('Invalid gs:// URI format: $gsUri');
        return '';
      }
      
      final bucketName = components.first;
      final objectPath = components.sublist(1).join('/');
      
      // Get a reference to the file
      final ref = FirebaseStorage.instance.ref().child(objectPath);
      
      // Get the download URL
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('Converted gs:// URI to download URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error converting gs:// URI to download URL: $e');
      return '';
    }
  }
} 