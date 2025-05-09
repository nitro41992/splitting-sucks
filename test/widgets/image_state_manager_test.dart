import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:billfie/widgets/image_state_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart'; // We will use MockFile from here
import '../mocks.mocks.dart'; // Import the generated mocks

void main() {
  group('ImageStateManager', () {
    late ImageStateManager imageStateManager;
    late MockFile mockNewFile;
    bool listenerCalled = false;
    late Function() testListener; // Declare variable for the listener

    setUp(() {
      imageStateManager = ImageStateManager();
      mockNewFile = MockFile(); // Initialize mock file
      listenerCalled = false;
      testListener = () { // Define the listener
        debugPrint('[TEST_LISTENER] Listener called!');
        listenerCalled = true;
      };
      imageStateManager.addListener(testListener); // Add the stored listener
    });

    tearDown(() {
      // It's good practice to remove listeners, though in simple test cases
      // without async work after dispose, it might not strictly be necessary.
      imageStateManager.removeListener(testListener); // Remove the stored listener
    });

    test('initial state is correct', () {
      expect(imageStateManager.imageFile, isNull);
      expect(imageStateManager.loadedImageUrl, isNull);
      expect(imageStateManager.loadedThumbnailUrl, isNull);
      expect(imageStateManager.actualImageGsUri, isNull);
      expect(imageStateManager.actualThumbnailGsUri, isNull);
      expect(imageStateManager.pendingDeletionGsUris, isEmpty);
      // Initially, no listener should have been called just by construction
      expect(listenerCalled, isFalse); 
    });

    group('setNewImageFile', () {
      test('sets _imageFile, clears relevant URIs, adds old URIs to pending, and notifies', () {
        // Setup initial state with existing URIs
        imageStateManager.setUploadedGsUris('gs://old_image.jpg', 'gs://old_thumb.jpg');
        imageStateManager.setLoadedImageUrls('http://old_image_url', 'http://old_thumb_url');
        // Note: setActualGsUrisOnLoad would typically be used for drafts, here we use setUploadedGsUris 
        // to simulate having actual URIs that should be added to pendingDeletion on new file set.
        
        listenerCalled = false; // Reset listener after setup

        imageStateManager.setNewImageFile(mockNewFile);

        expect(imageStateManager.imageFile, mockNewFile);
        expect(imageStateManager.loadedImageUrl, isNull, reason: "Loaded image URL should be cleared");
        expect(imageStateManager.loadedThumbnailUrl, isNull, reason: "Loaded thumbnail URL should be cleared");
        expect(imageStateManager.actualImageGsUri, isNull, reason: "Actual image GS URI should be cleared");
        expect(imageStateManager.actualThumbnailGsUri, isNull, reason: "Actual thumbnail GS URI should be cleared");
        
        expect(imageStateManager.pendingDeletionGsUris, contains('gs://old_image.jpg'));
        expect(imageStateManager.pendingDeletionGsUris, contains('gs://old_thumb.jpg'));
        expect(listenerCalled, isTrue);
      });

      test('when no previous URIs, sets _imageFile, clears relevant URIs, and notifies', () {
        // Initial state is clean (no URIs set)
        listenerCalled = false;

        imageStateManager.setNewImageFile(mockNewFile);

        expect(imageStateManager.imageFile, mockNewFile);
        expect(imageStateManager.loadedImageUrl, isNull);
        expect(imageStateManager.loadedThumbnailUrl, isNull);
        expect(imageStateManager.actualImageGsUri, isNull);
        expect(imageStateManager.actualThumbnailGsUri, isNull);
        expect(imageStateManager.pendingDeletionGsUris, isEmpty, reason: "Pending deletions should be empty if no old URIs");
        expect(listenerCalled, isTrue);
      });

      test('calling multiple times only adds previous URIs once and updates file', () {
        final mockFile1 = MockFile();
        final mockFile2 = MockFile();

        // Set initial URIs
        imageStateManager.setUploadedGsUris('gs://initial_image.jpg', 'gs://initial_thumb.jpg');
        listenerCalled = false;

        // Set first new file
        imageStateManager.setNewImageFile(mockFile1);
        expect(imageStateManager.imageFile, mockFile1);
        expect(imageStateManager.pendingDeletionGsUris, contains('gs://initial_image.jpg'));
        expect(imageStateManager.pendingDeletionGsUris, contains('gs://initial_thumb.jpg'));
        expect(imageStateManager.pendingDeletionGsUris.length, 2);
        expect(listenerCalled, isTrue);
        listenerCalled = false; // Reset

        // Set second new file - new file should be set, but no new URIs added to pending from this step as they were cleared
        imageStateManager.setNewImageFile(mockFile2);
        expect(imageStateManager.imageFile, mockFile2);
        // Pending deletions should still be the 'initial' ones, as the act of setting mockFile1 cleared the GS URIs
        expect(imageStateManager.pendingDeletionGsUris, contains('gs://initial_image.jpg'));
        expect(imageStateManager.pendingDeletionGsUris, contains('gs://initial_thumb.jpg'));
        expect(imageStateManager.pendingDeletionGsUris.length, 2, reason: "Pending deletions should not grow further");
        expect(listenerCalled, isTrue);
      });
    });

    group('resetImageFile', () {
      test('clears all image/URI fields, adds existing actual URIs to pending, and notifies', () {
        // Setup initial state with a file and some URIs
        final mockInitialFile = MockFile();
        imageStateManager.setNewImageFile(mockInitialFile); // This sets the file and clears URIs
        imageStateManager.setUploadedGsUris('gs://current_image.jpg', 'gs://current_thumb.jpg');
        imageStateManager.setLoadedImageUrls('http://current_loaded_image', 'http://current_loaded_thumb');
        
        listenerCalled = false; // Reset listener after setup

        imageStateManager.resetImageFile();

        expect(imageStateManager.imageFile, isNull, reason: "Image file should be cleared");
        expect(imageStateManager.loadedImageUrl, isNull, reason: "Loaded image URL should be cleared");
        expect(imageStateManager.loadedThumbnailUrl, isNull, reason: "Loaded thumbnail URL should be cleared");
        expect(imageStateManager.actualImageGsUri, isNull, reason: "Actual image GS URI should be cleared");
        expect(imageStateManager.actualThumbnailGsUri, isNull, reason: "Actual thumbnail GS URI should be cleared");
        
        expect(imageStateManager.pendingDeletionGsUris, contains('gs://current_image.jpg'), reason: "Previous actual image URI should be in pending");
        expect(imageStateManager.pendingDeletionGsUris, contains('gs://current_thumb.jpg'), reason: "Previous actual thumb URI should be in pending");
        expect(listenerCalled, isTrue, reason: "Listener should be called");
      });

      test('when no actual URIs exist, clears fields and notifies without adding to pending', () {
        // Setup initial state with a file but no actual GS URIs set after file set
        final mockInitialFile = MockFile();
        imageStateManager.setNewImageFile(mockInitialFile);
        // At this point, actual GS URIs are null because setNewImageFile clears them and we haven't set new ones.
        
        expect(imageStateManager.actualImageGsUri, isNull);
        expect(imageStateManager.actualThumbnailGsUri, isNull);
        final initialPendingCount = imageStateManager.pendingDeletionGsUris.length;
        listenerCalled = false; // Reset listener after setup

        imageStateManager.resetImageFile();

        expect(imageStateManager.imageFile, isNull);
        expect(imageStateManager.loadedImageUrl, isNull);
        expect(imageStateManager.loadedThumbnailUrl, isNull);
        expect(imageStateManager.actualImageGsUri, isNull);
        expect(imageStateManager.actualThumbnailGsUri, isNull);
        expect(imageStateManager.pendingDeletionGsUris.length, initialPendingCount, reason: "Pending deletions count should not change if no actual URIs were present");
        expect(listenerCalled, isTrue);
      });

      test('when imageFile is null but URIs exist, clears URIs and adds actuals to pending', () {
        // No image file, but URIs are set (e.g. loading a draft)
        imageStateManager.setUploadedGsUris('gs://draft_image.jpg', 'gs://draft_thumb.jpg');
        imageStateManager.setLoadedImageUrls('http://draft_loaded_image', 'http://draft_loaded_thumb');
        expect(imageStateManager.imageFile, isNull);
        listenerCalled = false;

        imageStateManager.resetImageFile();

        expect(imageStateManager.imageFile, isNull);
        expect(imageStateManager.loadedImageUrl, isNull);
        expect(imageStateManager.loadedThumbnailUrl, isNull);
        expect(imageStateManager.actualImageGsUri, isNull);
        expect(imageStateManager.actualThumbnailGsUri, isNull);
        expect(imageStateManager.pendingDeletionGsUris, contains('gs://draft_image.jpg'));
        expect(imageStateManager.pendingDeletionGsUris, contains('gs://draft_thumb.jpg'));
        expect(listenerCalled, isTrue);
      });
    });

    group('URI and URL Setters', () {
      test('setUploadedGsUris sets _actualImageGsUri and _actualThumbnailGsUri and notifies', () {
        const imgGsUri = 'gs://bucket/uploaded_image.jpg';
        const thumbGsUri = 'gs://bucket/uploaded_thumb.jpg';
        listenerCalled = false;

        imageStateManager.setUploadedGsUris(imgGsUri, thumbGsUri);

        expect(imageStateManager.actualImageGsUri, imgGsUri);
        expect(imageStateManager.actualThumbnailGsUri, thumbGsUri);
        expect(listenerCalled, isTrue);
      });

      test('setUploadedGsUris handles null values correctly and notifies', () {
        // Set initial values to ensure they are changed to null
        imageStateManager.setUploadedGsUris('gs://initial_image.jpg', 'gs://initial_thumb.jpg');
        listenerCalled = false; // Reset after initial set

        imageStateManager.setUploadedGsUris(null, null);

        expect(imageStateManager.actualImageGsUri, isNull);
        expect(imageStateManager.actualThumbnailGsUri, isNull);
        expect(listenerCalled, isTrue);
      });

      test('setLoadedImageUrls sets _loadedImageUrl and _loadedThumbnailUrl and notifies', () {
        const imgUrl = 'http://domain.com/loaded_image.jpg';
        const thumbUrl = 'http://domain.com/loaded_thumb.jpg';
        listenerCalled = false;

        imageStateManager.setLoadedImageUrls(imgUrl, thumbUrl);

        expect(imageStateManager.loadedImageUrl, imgUrl);
        expect(imageStateManager.loadedThumbnailUrl, thumbUrl);
        expect(listenerCalled, isTrue);
      });

      test('setLoadedImageUrls handles null values correctly and notifies', () {
        imageStateManager.setLoadedImageUrls('http://initial_url', 'http://initial_thumb_url');
        listenerCalled = false;

        imageStateManager.setLoadedImageUrls(null, null);

        expect(imageStateManager.loadedImageUrl, isNull);
        expect(imageStateManager.loadedThumbnailUrl, isNull);
        expect(listenerCalled, isTrue);
      });

      test('setActualGsUrisOnLoad sets _actualImageGsUri and _actualThumbnailGsUri and notifies', () {
        const imgGsUri = 'gs://bucket/onload_image.jpg';
        const thumbGsUri = 'gs://bucket/onload_thumb.jpg';
        listenerCalled = false;

        // Important: This method should NOT add to pendingDeletionGsUris
        final initialPendingCount = imageStateManager.pendingDeletionGsUris.length;

        imageStateManager.setActualGsUrisOnLoad(imgGsUri, thumbGsUri);

        expect(imageStateManager.actualImageGsUri, imgGsUri);
        expect(imageStateManager.actualThumbnailGsUri, thumbGsUri);
        expect(imageStateManager.pendingDeletionGsUris.length, initialPendingCount, 
               reason: "setActualGsUrisOnLoad should not add to pending deletions");
        expect(listenerCalled, isTrue);
      });

      test('setActualGsUrisOnLoad handles null values correctly and notifies', () {
        imageStateManager.setActualGsUrisOnLoad('gs://initial_onload_image.jpg', 'gs://initial_onload_thumb.jpg');
        listenerCalled = false;
        final initialPendingCount = imageStateManager.pendingDeletionGsUris.length;

        imageStateManager.setActualGsUrisOnLoad(null, null);

        expect(imageStateManager.actualImageGsUri, isNull);
        expect(imageStateManager.actualThumbnailGsUri, isNull);
        expect(imageStateManager.pendingDeletionGsUris.length, initialPendingCount);
        expect(listenerCalled, isTrue);
      });
    });

    group('Pending Deletions List Management', () {
      test('addUriToPendingDeletionsList adds URI and notifies, if not null and not already present', () {
        const uri1 = 'gs://bucket/delete_me_1.jpg';
        const uri2 = 'gs://bucket/delete_me_2.jpg';
        
        listenerCalled = false;
        imageStateManager.addUriToPendingDeletionsList(uri1);
        expect(imageStateManager.pendingDeletionGsUris, contains(uri1));
        expect(imageStateManager.pendingDeletionGsUris.length, 1);
        expect(listenerCalled, isTrue);

        // Add another URI
        listenerCalled = false;
        imageStateManager.addUriToPendingDeletionsList(uri2);
        expect(imageStateManager.pendingDeletionGsUris, containsAll([uri1, uri2]));
        expect(imageStateManager.pendingDeletionGsUris.length, 2);
        expect(listenerCalled, isTrue);

        // Try adding a duplicate
        listenerCalled = false;
        imageStateManager.addUriToPendingDeletionsList(uri1);
        expect(imageStateManager.pendingDeletionGsUris.length, 2, reason: "Duplicate should not be added");
        expect(listenerCalled, isFalse, reason: "Listener should not be called if URI not added");

        // Try adding null
        listenerCalled = false;
        imageStateManager.addUriToPendingDeletionsList(null);
        expect(imageStateManager.pendingDeletionGsUris.length, 2, reason: "Null should not be added");
        expect(listenerCalled, isFalse, reason: "Listener should not be called if URI not added");
      });

      test('removeUriFromPendingDeletionsList removes URI and notifies, if present', () {
        const uri1 = 'gs://bucket/remove_me_1.jpg';
        const uri2 = 'gs://bucket/keep_me_1.jpg';
        imageStateManager.addUriToPendingDeletionsList(uri1);
        imageStateManager.addUriToPendingDeletionsList(uri2);
        listenerCalled = false; // Reset after setup

        imageStateManager.removeUriFromPendingDeletionsList(uri1);
        expect(imageStateManager.pendingDeletionGsUris, isNot(contains(uri1)));
        expect(imageStateManager.pendingDeletionGsUris, contains(uri2));
        expect(imageStateManager.pendingDeletionGsUris.length, 1);
        expect(listenerCalled, isTrue);

        // Try removing a URI that's not in the list
        listenerCalled = false;
        imageStateManager.removeUriFromPendingDeletionsList('gs://bucket/not_present.jpg');
        expect(imageStateManager.pendingDeletionGsUris.length, 1, reason: "Length should not change");
        expect(listenerCalled, isFalse, reason: "Listener should not be called if URI not removed");
        
        // Try removing null
        listenerCalled = false;
        imageStateManager.removeUriFromPendingDeletionsList(null);
        expect(imageStateManager.pendingDeletionGsUris.length, 1, reason: "Length should not change");
        expect(listenerCalled, isFalse, reason: "Listener should not be called for null URI");
      });

      test('clearPendingDeletionsList clears the list and notifies, if not empty', () {
        imageStateManager.addUriToPendingDeletionsList('gs://bucket/clear_me_1.jpg');
        imageStateManager.addUriToPendingDeletionsList('gs://bucket/clear_me_2.jpg');
        expect(imageStateManager.pendingDeletionGsUris, isNotEmpty);
        listenerCalled = false; // Reset after setup

        imageStateManager.clearPendingDeletionsList();
        expect(imageStateManager.pendingDeletionGsUris, isEmpty);
        expect(listenerCalled, isTrue);

        // Try clearing an already empty list
        listenerCalled = false;
        imageStateManager.clearPendingDeletionsList();
        expect(imageStateManager.pendingDeletionGsUris, isEmpty);
        expect(listenerCalled, isFalse, reason: "Listener should not be called if list was already empty");
      });
    });
  });
} 