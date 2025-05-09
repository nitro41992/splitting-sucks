import 'dart:io';
import 'package:flutter/foundation.dart';

class ImageStateManager extends ChangeNotifier {
  File? _imageFile;
  String? _actualImageGsUri;
  String? _actualThumbnailGsUri;
  String? _loadedImageUrl; // For displaying an image from a URL (e.g., loaded draft)
  String? _loadedThumbnailUrl; // For displaying a thumbnail from a loaded draft

  final List<String> _pendingDeletionGsUris = [];

  // Getters
  File? get imageFile => _imageFile;
  String? get actualImageGsUri => _actualImageGsUri;
  String? get actualThumbnailGsUri => _actualThumbnailGsUri;
  String? get loadedImageUrl => _loadedImageUrl;
  String? get loadedThumbnailUrl => _loadedThumbnailUrl;
  List<String> get pendingDeletionGsUris => List.unmodifiable(_pendingDeletionGsUris);

  // --- Methods to be migrated/created ---

  // Example: Setting a new image file
  void setNewImageFile(File newFile) {
    // If there was a previous actual image, add its GS URI to pending deletions
    if (_actualImageGsUri != null && _actualImageGsUri!.isNotEmpty) {
      if (!_pendingDeletionGsUris.contains(_actualImageGsUri!)) {
        _pendingDeletionGsUris.add(_actualImageGsUri!);
        debugPrint('[ImageStateManager] Added old actualImageGsUri to pending deletions: $_actualImageGsUri');
      }
    }
    // If there was a previous actual thumbnail, add its GS URI to pending deletions
    if (_actualThumbnailGsUri != null && _actualThumbnailGsUri!.isNotEmpty) {
      if (!_pendingDeletionGsUris.contains(_actualThumbnailGsUri!)) {
        _pendingDeletionGsUris.add(_actualThumbnailGsUri!);
        debugPrint('[ImageStateManager] Added old actualThumbnailGsUri to pending deletions: $_actualThumbnailGsUri');
      }
    }

    _imageFile = newFile;
    _loadedImageUrl = null; 
    _loadedThumbnailUrl = null; 
    _actualImageGsUri = null; 
    _actualThumbnailGsUri = null; 
    
    debugPrint('[ImageStateManager] New image file set. Pending deletions: $_pendingDeletionGsUris');
    notifyListeners();
  }

  void resetImageFile() {
    // Similar logic to setNewImageFile for adding current URIs to pending deletion
    if (_actualImageGsUri != null && _actualImageGsUri!.isNotEmpty) {
      if (!_pendingDeletionGsUris.contains(_actualImageGsUri!)) {
        _pendingDeletionGsUris.add(_actualImageGsUri!);
        debugPrint('[ImageStateManager] Added actualImageGsUri to pending deletions on reset: $_actualImageGsUri');
      }
    }
    if (_actualThumbnailGsUri != null && _actualThumbnailGsUri!.isNotEmpty) {
      if (!_pendingDeletionGsUris.contains(_actualThumbnailGsUri!)) {
        _pendingDeletionGsUris.add(_actualThumbnailGsUri!);
        debugPrint('[ImageStateManager] Added actualThumbnailGsUri to pending deletions on reset: $_actualThumbnailGsUri');
      }
    }

    _imageFile = null;
    _loadedImageUrl = null;
    _loadedThumbnailUrl = null;
    _actualImageGsUri = null;
    _actualThumbnailGsUri = null;

    debugPrint('[ImageStateManager] Image file reset. Pending deletions: $_pendingDeletionGsUris');
    notifyListeners();
  }

  // Placeholder for setting URIs after upload
  void setUploadedGsUris(String? imageGsUri, String? thumbnailGsUri) {
    _actualImageGsUri = imageGsUri;
    _actualThumbnailGsUri = thumbnailGsUri;
    // If a local file was being tracked, it's now represented by these GS URIs.
    // We might not null out _imageFile here, as it could still be useful for display
    // until a download URL is available, or for re-upload attempts if needed.
    // However, the primary source of truth for storage is now the GS URIs.
    debugPrint('[ImageStateManager] Set uploaded GS URIs - Image: $imageGsUri, Thumbnail: $thumbnailGsUri');
    notifyListeners();
  }

  // Placeholder for setting URLs when loading from draft
  void setLoadedImageUrls(String? imageUrl, String? thumbnailUrl) {
    _loadedImageUrl = imageUrl;
    _loadedThumbnailUrl = thumbnailUrl;
    _imageFile = null; // When loading from URL, there's no local file selection
    debugPrint('[ImageStateManager] Set loaded image URLs - Image: $imageUrl, Thumbnail: $thumbnailUrl');
    notifyListeners();
  }
  
  // Placeholder for setting actual GS URIs when loading from draft
  void setActualGsUrisOnLoad(String? imageGsUri, String? thumbnailGsUri) {
    _actualImageGsUri = imageGsUri;
    _actualThumbnailGsUri = thumbnailGsUri;
    debugPrint('[ImageStateManager] Set actual GS URIs on load - Image: $imageGsUri, Thumbnail: $thumbnailGsUri');
    notifyListeners();
  }

  // Methods to manage the pending deletion list directly (could be made private or more controlled)
  void clearPendingDeletionsList() {
    if (_pendingDeletionGsUris.isNotEmpty) {
      _pendingDeletionGsUris.clear();
      debugPrint('[ImageStateManager] Cleared all pending deletions.');
      notifyListeners(); 
    } else {
      debugPrint('[ImageStateManager] clearPendingDeletionsList called on already empty list.');
    }
  }

  void removeUriFromPendingDeletionsList(String? uri) {
    if (uri != null && uri.isNotEmpty) {
      final removed = _pendingDeletionGsUris.remove(uri);
      if (removed) {
        debugPrint('[ImageStateManager] Removed URI from pending deletions: $uri. Remaining: $_pendingDeletionGsUris');
        notifyListeners();
      }
    }
  }

  void addUriToPendingDeletionsList(String? uri) {
    if (uri != null && uri.isNotEmpty && !_pendingDeletionGsUris.contains(uri)) {
        _pendingDeletionGsUris.add(uri);
        debugPrint('[ImageStateManager] Added URI to pending deletions: $uri. Current list: $_pendingDeletionGsUris');
        notifyListeners();
    }
  }
} 