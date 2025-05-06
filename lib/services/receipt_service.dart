import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/receipt.dart';

class ReceiptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection reference
  CollectionReference<Map<String, dynamic>> get _receiptsCollection {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore.collection('users').doc(userId).collection('receipts');
  }
  
  // Get all receipts for the current user
  Stream<List<Receipt>> getReceipts() {
    return _receiptsCollection
        .orderBy('metadata.created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Receipt.fromFirestore(doc)).toList();
    });
  }
  
  // Get a single receipt by ID
  Future<Receipt?> getReceiptById(String receiptId) async {
    try {
      final doc = await _receiptsCollection.doc(receiptId).get();
      if (doc.exists) {
        return Receipt.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting receipt: $e');
      return null;
    }
  }
  
  // Create a new receipt draft
  Future<Receipt> createReceiptDraft() async {
    try {
      final receipt = Receipt.createDraft();
      final docRef = await _receiptsCollection.add(receipt.toFirestore());
      return receipt.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('Error creating receipt draft: $e');
      rethrow;
    }
  }
  
  // Update a receipt
  Future<void> updateReceipt(Receipt receipt) async {
    try {
      if (receipt.id == null) {
        throw Exception('Receipt ID is null');
      }
      
      // Update the updatedAt timestamp
      final updatedMetadata = receipt.metadata.copyWith(
        updatedAt: Timestamp.now(),
      );
      
      final updatedReceipt = receipt.copyWith(metadata: updatedMetadata);
      await _receiptsCollection.doc(receipt.id).update(updatedReceipt.toFirestore());
    } catch (e) {
      debugPrint('Error updating receipt: $e');
      rethrow;
    }
  }
  
  // Delete a receipt
  Future<void> deleteReceipt(String receiptId) async {
    try {
      // Get the receipt to check for image URIs
      final receipt = await getReceiptById(receiptId);
      
      // Delete the image and thumbnail from storage if they exist
      if (receipt?.imageUri != null) {
        await _storage.refFromURL(receipt!.imageUri!).delete();
      }
      
      if (receipt?.thumbnailUri != null) {
        await _storage.refFromURL(receipt!.thumbnailUri!).delete();
      }
      
      // Delete the receipt document
      await _receiptsCollection.doc(receiptId).delete();
    } catch (e) {
      debugPrint('Error deleting receipt: $e');
      rethrow;
    }
  }
  
  // Update receipt status (draft/completed)
  Future<void> updateReceiptStatus(String receiptId, String status) async {
    try {
      final receipt = await getReceiptById(receiptId);
      if (receipt == null) {
        throw Exception('Receipt not found');
      }
      
      // Validate that if setting to completed, restaurant name is set
      if (status == 'completed' && 
          (receipt.metadata.restaurantName == null || 
           receipt.metadata.restaurantName!.isEmpty)) {
        throw Exception('Restaurant name is required for completed receipts');
      }
      
      final updatedMetadata = receipt.metadata.copyWith(
        status: status,
        updatedAt: Timestamp.now(),
      );
      
      final updatedReceipt = receipt.copyWith(metadata: updatedMetadata);
      await updateReceipt(updatedReceipt);
    } catch (e) {
      debugPrint('Error updating receipt status: $e');
      rethrow;
    }
  }
  
  // Upload receipt image and generate thumbnail
  Future<Map<String, String>> uploadReceiptImage(File imageFile, String receiptId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Generate thumbnail
      final originalBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(originalBytes);
      
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }
      
      // Resize to create thumbnail (max width 300px)
      const thumbnailWidth = 300;
      final thumbnailHeight = (originalImage.height * thumbnailWidth) ~/ originalImage.width;
      final thumbnailImage = img.copyResize(
        originalImage,
        width: thumbnailWidth,
        height: thumbnailHeight,
      );
      final thumbnailBytes = img.encodeJpg(thumbnailImage, quality: 85);
      
      // Define paths in Firebase Storage
      final imagePath = 'users/$userId/receipts/$receiptId/image.jpg';
      final thumbnailPath = 'users/$userId/receipts/$receiptId/thumbnail.jpg';
      
      // Upload original image
      final imageRef = _storage.ref().child(imagePath);
      await imageRef.putFile(imageFile);
      final imageUrl = await imageRef.getDownloadURL();
      
      // Upload thumbnail
      final thumbnailRef = _storage.ref().child(thumbnailPath);
      await thumbnailRef.putData(thumbnailBytes);
      final thumbnailUrl = await thumbnailRef.getDownloadURL();
      
      return {
        'imageUri': imageUrl,
        'thumbnailUri': thumbnailUrl,
      };
    } catch (e) {
      debugPrint('Error uploading receipt image: $e');
      rethrow;
    }
  }
  
  // Save parse receipt results
  Future<void> saveParseReceiptResults(String receiptId, Map<String, dynamic> parseResults) async {
    try {
      final receipt = await getReceiptById(receiptId);
      if (receipt == null) {
        throw Exception('Receipt not found');
      }
      
      final updatedReceipt = receipt.copyWith(
        parseReceipt: parseResults,
        metadata: receipt.metadata.copyWith(
          updatedAt: Timestamp.now(),
        ),
      );
      
      await updateReceipt(updatedReceipt);
    } catch (e) {
      debugPrint('Error saving parse receipt results: $e');
      rethrow;
    }
  }
  
  // Save transcribe audio results
  Future<void> saveTranscribeAudioResults(String receiptId, Map<String, dynamic> transcriptionResults) async {
    try {
      final receipt = await getReceiptById(receiptId);
      if (receipt == null) {
        throw Exception('Receipt not found');
      }
      
      final updatedReceipt = receipt.copyWith(
        transcribeAudio: transcriptionResults,
        metadata: receipt.metadata.copyWith(
          updatedAt: Timestamp.now(),
        ),
      );
      
      await updateReceipt(updatedReceipt);
    } catch (e) {
      debugPrint('Error saving transcribe audio results: $e');
      rethrow;
    }
  }
  
  // Save assign people to items results
  Future<void> saveAssignPeopleToItemsResults(String receiptId, Map<String, dynamic> assignmentResults) async {
    try {
      debugPrint('STARTING SAVE ASSIGNMENTS: ${assignmentResults.keys.join(', ')}');
      
      // Debug log the structure of the data
      if (assignmentResults.containsKey('assignments')) {
        final assignmentsMap = assignmentResults['assignments'] as Map<String, dynamic>;
        debugPrint('Assignments map has ${assignmentsMap.length} people');
        assignmentsMap.forEach((person, items) {
          final itemsList = items as List<dynamic>;
          debugPrint('  Person $person has ${itemsList.length} assigned items');
        });
      }
      
      if (assignmentResults.containsKey('shared_items')) {
        final sharedItems = assignmentResults['shared_items'] as List<dynamic>;
        debugPrint('Shared items list has ${sharedItems.length} items');
        for (final item in sharedItems) {
          final itemMap = item as Map<String, dynamic>;
          final people = itemMap['people'] as List<dynamic>;
          debugPrint('  Shared item ${itemMap['name']} is shared among ${people.length} people: ${people.join(', ')}');
        }
      }
      
      final receipt = await getReceiptById(receiptId);
      if (receipt == null) {
        throw Exception('Receipt not found');
      }
      
      // Extract people from assignments for searching
      final List<String> people = [];
      if (assignmentResults.containsKey('assignments')) {
        final assignments = assignmentResults['assignments'] as Map<String, dynamic>;
        people.addAll(assignments.keys);
      }
      
      final updatedReceipt = receipt.copyWith(
        assignPeopleToItems: assignmentResults,
        metadata: receipt.metadata.copyWith(
          updatedAt: Timestamp.now(),
          people: people,
        ),
      );
      
      // Log the final data being sent to Firestore
      final Map<String, dynamic> firestoreData = updatedReceipt.toFirestore();
      debugPrint('SAVING TO FIRESTORE: ${firestoreData.keys.join(', ')}');
      
      if (firestoreData.containsKey('assign_people_to_items')) {
        final savedAssignments = firestoreData['assign_people_to_items'] as Map<String, dynamic>;
        debugPrint('Firestore assign_people_to_items has ${savedAssignments.keys.join(', ')}');
        
        if (savedAssignments.containsKey('assignments')) {
          final assignmentsMap = savedAssignments['assignments'] as Map<String, dynamic>;
          debugPrint('Firestore assignments map has ${assignmentsMap.length} people');
          assignmentsMap.forEach((person, items) {
            debugPrint('  Person $person items type: ${items.runtimeType}');
            if (items is List) {
              debugPrint('  Person $person has ${items.length} assigned items');
            } else {
              debugPrint('  Person $person items is NOT a list: $items');
            }
          });
        }
      }
      
      await updateReceipt(updatedReceipt);
      
      debugPrint('ASSIGNMENTS SAVED SUCCESSFULLY TO FIRESTORE');
    } catch (e) {
      debugPrint('Error saving assignment results: $e');
      rethrow;
    }
  }
  
  // Update restaurant name
  Future<void> updateRestaurantName(String receiptId, String? restaurantName) async {
    try {
      final receipt = await getReceiptById(receiptId);
      if (receipt == null) {
        throw Exception('Receipt not found');
      }
      
      final updatedReceipt = receipt.copyWith(
        metadata: receipt.metadata.copyWith(
          restaurantName: restaurantName,
          updatedAt: Timestamp.now(),
        ),
      );
      
      await updateReceipt(updatedReceipt);
    } catch (e) {
      debugPrint('Error updating restaurant name: $e');
      rethrow;
    }
  }
} 