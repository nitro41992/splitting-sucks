import 'package:billfie/models/receipt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// Import the generated mocks
import '../mocks.mocks.dart'; // Adjust path as necessary

void main() {
  group('Receipt Model Tests', () {
    late MockDocumentSnapshot mockDocumentSnapshot;

    setUp(() {
      mockDocumentSnapshot = MockDocumentSnapshot();
    });

    group('fromDocumentSnapshot', () {
      test('should correctly parse a typical Firestore document', () {
        // Arrange
        final timestamp = Timestamp.now();
        final data = {
          'metadata': {
            'image_uri': 'gs://image.jpg',
            'thumbnail_uri': 'gs://thumbnail.jpg',
            'status': 'draft',
            'restaurant_name': 'The Food Place',
            'people': ['Alice', 'Bob'],
            'tip': 10.0,
            'tax': 5.0,
            'created_at': timestamp,
            'updated_at': timestamp,
          },
          'parse_receipt': {'totalAmount': 100.0},
          'transcribe_audio': {'transcript': 'audio text'},
          'assign_people_to_items': {'assignments': 'details'},
        };
        when(mockDocumentSnapshot.data()).thenReturn(data);
        when(mockDocumentSnapshot.id).thenReturn('testId');

        // Act
        final receipt = Receipt.fromDocumentSnapshot(mockDocumentSnapshot);

        // Assert
        expect(receipt.id, 'testId');
        expect(receipt.imageUri, 'gs://image.jpg');
        expect(receipt.thumbnailUri, 'gs://thumbnail.jpg');
        expect(receipt.status, 'draft');
        expect(receipt.restaurantName, 'The Food Place');
        expect(receipt.people, ['Alice', 'Bob']);
        expect(receipt.tip, 10.0);
        expect(receipt.tax, 5.0);
        expect(receipt.createdAt, timestamp);
        expect(receipt.updatedAt, timestamp);
        expect(receipt.parseReceipt, {'totalAmount': 100.0});
        expect(receipt.transcribeAudio, {'transcript': 'audio text'});
        expect(receipt.assignPeopleToItems, {'assignments': 'details'});
        expect(receipt.thumbnailUrlForDisplay, isNull); // Initially null
      });

      test('should handle missing optional fields gracefully with defaults', () {
        // Arrange
        final data = {
          'metadata': {
            // Missing: image_uri, thumbnail_uri, restaurant_name, people, tip, tax, created_at, updated_at
            'status': 'completed', // Only status is provided
          },
          // Missing: parse_receipt, transcribe_audio, assign_people_to_items
        };
         when(mockDocumentSnapshot.data()).thenReturn(data);
        when(mockDocumentSnapshot.id).thenReturn('testIdMinimal');

        // Act
        final receipt = Receipt.fromDocumentSnapshot(mockDocumentSnapshot);

        // Assert
        expect(receipt.id, 'testIdMinimal');
        expect(receipt.imageUri, isNull);
        expect(receipt.thumbnailUri, isNull);
        expect(receipt.status, 'completed');
        expect(receipt.restaurantName, isNull);
        expect(receipt.people, []); // Defaults to empty list
        expect(receipt.tip, isNull);
        expect(receipt.tax, isNull);
        expect(receipt.createdAt, isNull);
        expect(receipt.updatedAt, isNull);
        expect(receipt.parseReceipt, isNull);
        expect(receipt.transcribeAudio, isNull);
        expect(receipt.assignPeopleToItems, isNull);
      });

      test('should use default status "draft" if status is null in metadata', () {
        // Arrange
        final data = {
          'metadata': {
            'status': null, // Status explicitly null
          },
        };
        when(mockDocumentSnapshot.data()).thenReturn(data);
        when(mockDocumentSnapshot.id).thenReturn('testIdNullStatus');

        // Act
        final receipt = Receipt.fromDocumentSnapshot(mockDocumentSnapshot);

        // Assert
        expect(receipt.status, 'draft');
      });
      
      test('should use default status "draft" if status is missing in metadata', () {
        // Arrange
        final data = {
          'metadata': {
            // status field completely missing
          },
        };
        when(mockDocumentSnapshot.data()).thenReturn(data);
        when(mockDocumentSnapshot.id).thenReturn('testIdMissingStatus');

        // Act
        final receipt = Receipt.fromDocumentSnapshot(mockDocumentSnapshot);

        // Assert
        expect(receipt.status, 'draft');
      });

      test('should handle people field being null or not a list', () {
        // Arrange for null people field
        final dataNullPeople = {
          'metadata': {'people': null},
        };
        when(mockDocumentSnapshot.data()).thenReturn(dataNullPeople);
        when(mockDocumentSnapshot.id).thenReturn('nullPeopleId');
        final receiptNullPeople = Receipt.fromDocumentSnapshot(mockDocumentSnapshot);
        expect(receiptNullPeople.people, []);

        // Arrange for people field not being a list (e.g., a string)
        final dataInvalidPeople = {
          'metadata': {'people': 'NotAList'},
        };
        when(mockDocumentSnapshot.data()).thenReturn(dataInvalidPeople);
        when(mockDocumentSnapshot.id).thenReturn('invalidPeopleId');
        final receiptInvalidPeople = Receipt.fromDocumentSnapshot(mockDocumentSnapshot);
        expect(receiptInvalidPeople.people, []);
      });

      test('should correctly parse numeric tip and tax values', () {
        // Arrange
        final data = {
          'metadata': {
            'tip': 15, // Integer tip
            'tax': 7.5, // Double tax
          },
        };
        when(mockDocumentSnapshot.data()).thenReturn(data);
        when(mockDocumentSnapshot.id).thenReturn('numericTypesId');
        
        // Act
        final receipt = Receipt.fromDocumentSnapshot(mockDocumentSnapshot);
        
        // Assert
        expect(receipt.tip, 15.0);
        expect(receipt.tax, 7.5);
      });

      // Add more tests for other edge cases:
      // - Timestamps being different types (e.g., already DateTime - though Firestore SDK usually provides Timestamps)
      // - Empty maps for parseReceipt, transcribeAudio, assignPeopleToItems
      // - Different data types for fields inside nested maps (if strict typing is expected)
    });

    group('toMap', () {
      test('should correctly serialize a typical Receipt object to a map', () {
        // Arrange
        final timestamp = Timestamp.now();
        final receipt = Receipt(
          id: 'testId',
          imageUri: 'gs://image.jpg',
          thumbnailUri: 'gs://thumbnail.jpg',
          status: 'draft',
          restaurantName: 'The Food Place',
          people: ['Alice', 'Bob'],
          tip: 10.0,
          tax: 5.0,
          createdAt: timestamp,
          updatedAt: timestamp,
          parseReceipt: {'totalAmount': 100.0},
          transcribeAudio: {'transcript': 'audio text'},
          assignPeopleToItems: {'assignments': 'details'},
          thumbnailUrlForDisplay: 'http://display.url/thumb.jpg', // This should NOT be in the map
        );

        // Act
        final map = receipt.toMap();

        // Assert
        expect(map.containsKey('id'), isFalse); // id is not part of the map itself
        expect(map['parse_receipt'], {'totalAmount': 100.0});
        expect(map['transcribe_audio'], {'transcript': 'audio text'});
        expect(map['assign_people_to_items'], {'assignments': 'details'});
        
        final metadata = map['metadata'] as Map<String, dynamic>;
        expect(metadata['image_uri'], 'gs://image.jpg');
        expect(metadata['thumbnail_uri'], 'gs://thumbnail.jpg');
        expect(metadata['status'], 'draft');
        expect(metadata['restaurant_name'], 'The Food Place');
        expect(metadata['people'], ['Alice', 'Bob']);
        expect(metadata['tip'], 10.0);
        expect(metadata['tax'], 5.0);
        expect(metadata['created_at'], timestamp); 
        expect(metadata['updated_at'], timestamp);
        expect(metadata.containsKey('thumbnailUrlForDisplay'), isFalse);
      });

      test('should handle null optional fields correctly during serialization', () {
        // Arrange
        final receipt = Receipt(
          id: 'testIdMinimal',
          status: 'completed',
          // All other optional fields are null
        );

        // Act
        final map = receipt.toMap();

        // Assert
        expect(map['parse_receipt'], isNull);
        expect(map['transcribe_audio'], isNull);
        expect(map['assign_people_to_items'], isNull);

        final metadata = map['metadata'] as Map<String, dynamic>;
        expect(metadata['image_uri'], isNull);
        expect(metadata['thumbnail_uri'], isNull);
        expect(metadata['status'], 'completed');
        expect(metadata['restaurant_name'], isNull);
        expect(metadata['people'], []); // Defaults to empty list in constructor if not provided
        expect(metadata['tip'], isNull);
        expect(metadata['tax'], isNull);
        // serverTimestamp() is used if createdAt/updatedAt are null
        expect(metadata['created_at'], isA<FieldValue>()); 
        expect(metadata['updated_at'], isA<FieldValue>());
      });

      test('should use FieldValue.serverTimestamp() for null createdAt and updatedAt', () {
        // Arrange
        final receipt = Receipt(
          id: 'testIdTimestamps',
          status: 'draft',
          createdAt: null, // Explicitly null
          updatedAt: null, // Explicitly null
        );

        // Act
        final map = receipt.toMap();

        // Assert
        final metadata = map['metadata'] as Map<String, dynamic>;
        expect(metadata['created_at'], isA<FieldValue>());
        expect(metadata['updated_at'], isA<FieldValue>());

        // Verify it's specifically serverTimestamp
        // This is a bit tricky to test directly without deeper inspection or custom matchers
        // For now, checking type FieldValue is a good indicator.
      });
    });

    group('Computed Properties', () {
      test('isDraft should return true if status is "draft", false otherwise', () {
        final draftReceipt = Receipt(id: '1', status: 'draft');
        expect(draftReceipt.isDraft, isTrue);

        final completedReceipt = Receipt(id: '2', status: 'completed');
        expect(completedReceipt.isDraft, isFalse);
      });

      test('isCompleted should return true if status is "completed", false otherwise', () {
        final completedReceipt = Receipt(id: '1', status: 'completed');
        expect(completedReceipt.isCompleted, isTrue);

        final draftReceipt = Receipt(id: '2', status: 'draft');
        expect(draftReceipt.isCompleted, isFalse);
      });

      test('formattedDate should return correctly formatted date or "Unknown date"', () {
        final date = DateTime(2023, 10, 26);
        final timestamp = Timestamp.fromDate(date);
        final receiptWithDate = Receipt(id: '1', status: 'draft', updatedAt: timestamp);
        expect(receiptWithDate.formattedDate, '26/10/2023');

        final receiptWithoutDate = Receipt(id: '2', status: 'draft', updatedAt: null);
        expect(receiptWithoutDate.formattedDate, 'Unknown date');
      });

      group('formattedAmount', () {
        test('should return totalAmount from parseReceipt if available and numeric', () {
          final receipt = Receipt(
            id: '1', 
            status: 'draft',
            parseReceipt: {'totalAmount': 123.45}
          );
          expect(receipt.formattedAmount, '\$123.45');
        });

        test('should return totalAmount (integer) from parseReceipt if available and numeric', () {
          final receipt = Receipt(
            id: '1', 
            status: 'draft',
            parseReceipt: {'totalAmount': 123}
          );
          expect(receipt.formattedAmount, '\$123.00');
        });

        test('should return "Pending" if draft and parseReceipt has no totalAmount', () {
          final receipt = Receipt(
            id: '1', 
            status: 'draft',
            parseReceipt: {'someOtherKey': 'value'}
          );
          expect(receipt.formattedAmount, 'Pending');
        });

        test('should return "Pending" if draft and parseReceipt is null', () {
          final receipt = Receipt(id: '1', status: 'draft', parseReceipt: null);
          expect(receipt.formattedAmount, 'Pending');
        });

        test('should return "\$0.00" if completed and parseReceipt has no totalAmount', () {
          final receipt = Receipt(
            id: '1', 
            status: 'completed',
            parseReceipt: {'someOtherKey': 'value'}
          );
          expect(receipt.formattedAmount, '\$0.00');
        });

        test('should return "\$0.00" if completed and parseReceipt is null', () {
          final receipt = Receipt(id: '1', status: 'completed', parseReceipt: null);
          expect(receipt.formattedAmount, '\$0.00');
        });

         test('should return "Pending" if draft and totalAmount is not a number', () {
          final receipt = Receipt(
            id: '1', 
            status: 'draft',
            parseReceipt: {'totalAmount': 'not a number'}
          );
          expect(receipt.formattedAmount, 'Pending');
        });

        test('should return "\$0.00" if completed and totalAmount is not a number', () {
          final receipt = Receipt(
            id: '1', 
            status: 'completed',
            parseReceipt: {'totalAmount': 'not a number'}
          );
          expect(receipt.formattedAmount, '\$0.00');
        });
      });

      test('numberOfPeople should return correct string based on people list length', () {
        final receiptNoPeople = Receipt(id: '1', status: 'draft', people: []);
        expect(receiptNoPeople.numberOfPeople, '—');

        final receiptOnePerson = Receipt(id: '2', status: 'draft', people: ['Alice']);
        expect(receiptOnePerson.numberOfPeople, '1 person');

        final receiptMultiplePeople = Receipt(id: '3', status: 'draft', people: ['Alice', 'Bob', 'Charlie']);
        expect(receiptMultiplePeople.numberOfPeople, '3 people');
      });
    });

    group('copyWith', () {
      final initialTimestamp = Timestamp.fromDate(DateTime(2023, 1, 1));
      final initialReceipt = Receipt(
        id: 'originalId',
        imageUri: 'initialImage.jpg',
        thumbnailUri: 'initialThumbnail.jpg',
        parseReceipt: {'initialKey': 'initialValue'},
        transcribeAudio: {'initialTranscript': 'hello'},
        assignPeopleToItems: {'initialAssignment': 'personA'},
        status: 'draft',
        restaurantName: 'Initial Restaurant',
        people: ['Person1'],
        tip: 5.0,
        tax: 2.0,
        createdAt: initialTimestamp,
        updatedAt: initialTimestamp,
        thumbnailUrlForDisplay: 'initialDisplayUrl.jpg',
      );

      test('should create a copy with all new values if all are provided', () {
        final newTimestamp = Timestamp.fromDate(DateTime(2024, 1, 1));
        final copiedReceipt = initialReceipt.copyWith(
          id: 'newId',
          imageUri: 'newImage.jpg',
          thumbnailUri: 'newThumbnail.jpg',
          parseReceipt: {'newKey': 'newValue'},
          transcribeAudio: {'newTranscript': 'world'},
          assignPeopleToItems: {'newAssignment': 'personB'},
          status: 'completed',
          restaurantName: 'New Restaurant',
          people: ['Person2', 'Person3'],
          tip: 10.0,
          tax: 4.0,
          createdAt: newTimestamp,
          updatedAt: newTimestamp,
          thumbnailUrlForDisplay: () => 'newDisplayUrl.jpg',
        );

        expect(copiedReceipt.id, 'newId');
        expect(copiedReceipt.imageUri, 'newImage.jpg');
        expect(copiedReceipt.thumbnailUri, 'newThumbnail.jpg');
        expect(copiedReceipt.parseReceipt, {'newKey': 'newValue'});
        expect(copiedReceipt.transcribeAudio, {'newTranscript': 'world'});
        expect(copiedReceipt.assignPeopleToItems, {'newAssignment': 'personB'});
        expect(copiedReceipt.status, 'completed');
        expect(copiedReceipt.restaurantName, 'New Restaurant');
        expect(copiedReceipt.people, ['Person2', 'Person3']);
        expect(copiedReceipt.tip, 10.0);
        expect(copiedReceipt.tax, 4.0);
        expect(copiedReceipt.createdAt, newTimestamp);
        expect(copiedReceipt.updatedAt, newTimestamp);
        expect(copiedReceipt.thumbnailUrlForDisplay, 'newDisplayUrl.jpg');
      });

      test('should create a copy with only specified values changed', () {
        final copiedReceipt = initialReceipt.copyWith(
          status: 'pending',
          tip: 7.5,
          thumbnailUrlForDisplay: () => 'updatedDisplayUrl.jpg',
        );

        expect(copiedReceipt.id, initialReceipt.id);
        expect(copiedReceipt.imageUri, initialReceipt.imageUri);
        expect(copiedReceipt.thumbnailUri, initialReceipt.thumbnailUri);
        expect(copiedReceipt.parseReceipt, initialReceipt.parseReceipt);
        expect(copiedReceipt.transcribeAudio, initialReceipt.transcribeAudio);
        expect(copiedReceipt.assignPeopleToItems, initialReceipt.assignPeopleToItems);
        expect(copiedReceipt.status, 'pending'); // Changed
        expect(copiedReceipt.restaurantName, initialReceipt.restaurantName);
        expect(copiedReceipt.people, initialReceipt.people);
        expect(copiedReceipt.tip, 7.5); // Changed
        expect(copiedReceipt.tax, initialReceipt.tax);
        expect(copiedReceipt.createdAt, initialReceipt.createdAt);
        expect(copiedReceipt.updatedAt, initialReceipt.updatedAt); // Note: copyWith doesn't auto-update this
        expect(copiedReceipt.thumbnailUrlForDisplay, 'updatedDisplayUrl.jpg'); // Changed
      });

      test('should create an identical copy if no arguments are provided', () {
        final copiedReceipt = initialReceipt.copyWith();

        expect(copiedReceipt.id, initialReceipt.id);
        expect(copiedReceipt.imageUri, initialReceipt.imageUri);
        expect(copiedReceipt.thumbnailUri, initialReceipt.thumbnailUri);
        expect(copiedReceipt.parseReceipt, initialReceipt.parseReceipt);
        expect(copiedReceipt.transcribeAudio, initialReceipt.transcribeAudio);
        expect(copiedReceipt.assignPeopleToItems, initialReceipt.assignPeopleToItems);
        expect(copiedReceipt.status, initialReceipt.status);
        expect(copiedReceipt.restaurantName, initialReceipt.restaurantName);
        expect(copiedReceipt.people, initialReceipt.people);
        expect(copiedReceipt.tip, initialReceipt.tip);
        expect(copiedReceipt.tax, initialReceipt.tax);
        expect(copiedReceipt.createdAt, initialReceipt.createdAt);
        expect(copiedReceipt.updatedAt, initialReceipt.updatedAt);
        expect(copiedReceipt.thumbnailUrlForDisplay, initialReceipt.thumbnailUrlForDisplay);
        expect(copiedReceipt, isNot(same(initialReceipt))); // Ensure it's a new instance
      });

      test('should handle null values for nullable fields correctly', () {
        final receiptWithNulls = Receipt(
          id: 'id', 
          status: 'draft',
          imageUri: 'some.jpg', // Provide one non-null to ensure nulling works
        );

        final copiedReceipt = receiptWithNulls.copyWith(
          imageUri: null,
          restaurantName: null, // Explicitly setting to null
          tip: null, // Explicitly setting to null
          thumbnailUrlForDisplay: () => null,
        );

        expect(copiedReceipt.imageUri, isNull);
        expect(copiedReceipt.restaurantName, isNull);
        expect(copiedReceipt.tip, isNull);
        expect(copiedReceipt.thumbnailUrlForDisplay, isNull);
        // Ensure other fields remain
        expect(copiedReceipt.id, 'id');
        expect(copiedReceipt.status, 'draft');
      });
       test('copyWith with thumbnailUrlForDisplay: null should set it to null', () {
        final receipt = Receipt(id: '1', status: 'draft', thumbnailUrlForDisplay: 'some/url');
        final copied = receipt.copyWith(thumbnailUrlForDisplay: () => null);
        expect(copied.thumbnailUrlForDisplay, isNull);
      });

      test('copyWith with no change to thumbnailUrlForDisplay should keep original', () {
        final receipt = Receipt(id: '1', status: 'draft', thumbnailUrlForDisplay: 'some/url');
        final copied = receipt.copyWith(status: 'completed'); // Change something else
        expect(copied.thumbnailUrlForDisplay, 'some/url');
      });
    });

    group('createDraft', () {
      test('should create a draft receipt with minimal required fields', () {
        final draft = Receipt.createDraft(id: 'draftId1');

        expect(draft.id, 'draftId1');
        expect(draft.status, 'draft');
        expect(draft.imageUri, isNull);
        expect(draft.thumbnailUri, isNull);
        expect(draft.parseReceipt, isNull);
        expect(draft.transcribeAudio, isNull);
        expect(draft.assignPeopleToItems, isNull);
        expect(draft.restaurantName, isNull);
        expect(draft.people, isEmpty);
        expect(draft.tip, isNull);
        expect(draft.tax, isNull);
        expect(draft.createdAt, isNull); // Not set by createDraft
        expect(draft.updatedAt, isNull); // Not set by createDraft
        expect(draft.thumbnailUrlForDisplay, isNull);
      });

      test('should create a draft receipt with all optional fields provided', () {
        final parseData = {'key': 'value'};
        final audioData = {'transcript': 'text'};
        final assignmentData = {'item': 'person'};
        final peopleList = ['Alice', 'Bob'];

        final draft = Receipt.createDraft(
          id: 'draftId2',
          imageUri: 'image.png',
          thumbnailUri: 'thumb.png',
          parseReceipt: parseData,
          transcribeAudio: audioData,
          assignPeopleToItems: assignmentData,
          people: peopleList,
        );

        expect(draft.id, 'draftId2');
        expect(draft.status, 'draft');
        expect(draft.imageUri, 'image.png');
        expect(draft.thumbnailUri, 'thumb.png');
        expect(draft.parseReceipt, parseData);
        expect(draft.transcribeAudio, audioData);
        expect(draft.assignPeopleToItems, assignmentData);
        expect(draft.restaurantName, isNull); // Not part of createDraft
        expect(draft.people, peopleList);
        expect(draft.tip, isNull); // Not part of createDraft
        expect(draft.tax, isNull); // Not part of createDraft
        expect(draft.createdAt, isNull);
        expect(draft.updatedAt, isNull);
        expect(draft.thumbnailUrlForDisplay, isNull);
      });

      test('people should default to an empty list if not provided', () {
        final draft = Receipt.createDraft(id: 'draftId3', people: null);
        expect(draft.people, isEmpty);
      });
    });

    group('markAsCompleted', () {
      late Receipt draftReceipt;
      final initialTimestamp = Timestamp.fromDate(DateTime(2023, 1, 1, 12, 0, 0));

      setUp(() {
        draftReceipt = Receipt(
          id: 'draftId',
          status: 'draft',
          imageUri: 'image.jpg',
          thumbnailUri: 'thumb.jpg',
          people: ['Person A'],
          createdAt: initialTimestamp,
          updatedAt: initialTimestamp, // Initial updatedAt
          // Other fields can be null or have initial values
        );
      });

      test('should change status to "completed" and update relevant fields', () {
        final completedReceipt = draftReceipt.markAsCompleted(
          restaurantName: 'Test Restaurant',
          tip: 10.0,
          tax: 5.0,
        );

        expect(completedReceipt.id, draftReceipt.id); // ID should remain the same
        expect(completedReceipt.status, 'completed');
        expect(completedReceipt.restaurantName, 'Test Restaurant');
        expect(completedReceipt.tip, 10.0);
        expect(completedReceipt.tax, 5.0);
        
        // Verify updatedAt is updated and is later than the initial one
        expect(completedReceipt.updatedAt, isNotNull);
        expect(completedReceipt.updatedAt!.toDate().isAfter(initialTimestamp.toDate()), isTrue);
        
        // Ensure other fields are preserved from the original draft
        expect(completedReceipt.imageUri, draftReceipt.imageUri);
        expect(completedReceipt.thumbnailUri, draftReceipt.thumbnailUri);
        expect(completedReceipt.people, draftReceipt.people);
        expect(completedReceipt.createdAt, draftReceipt.createdAt); // createdAt should not change
      });

      test('should handle null tip and tax', () {
        final completedReceipt = draftReceipt.markAsCompleted(
          restaurantName: 'Another Restaurant',
          // tip and tax are not provided, should default to null or previous values if copyWith handles it
        );

        expect(completedReceipt.status, 'completed');
        expect(completedReceipt.restaurantName, 'Another Restaurant');
        expect(completedReceipt.tip, isNull); // Or previous value if copyWith logic differs
        expect(completedReceipt.tax, isNull); // Or previous value if copyWith logic differs
        expect(completedReceipt.updatedAt, isNotNull);
        expect(completedReceipt.updatedAt!.toDate().isAfter(initialTimestamp.toDate()), isTrue);
      });

      test('updatedAt timestamp should be very recent', () {
        final beforeCompletion = Timestamp.now();
        final completedReceipt = draftReceipt.markAsCompleted(restaurantName: 'Restaurant');
        final afterCompletion = Timestamp.now();

        expect(completedReceipt.updatedAt, isNotNull);
        // Check if the updatedAt is between just before and just after the call
        // Adding a small buffer for execution time.
        expect(completedReceipt.updatedAt!.microsecondsSinceEpoch, greaterThanOrEqualTo(beforeCompletion.microsecondsSinceEpoch - 1000)); // Allow for slight clock differences
        expect(completedReceipt.updatedAt!.microsecondsSinceEpoch, lessThanOrEqualTo(afterCompletion.microsecondsSinceEpoch + 1000));
      });
    });
  });
} 