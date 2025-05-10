import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'receipt_item.dart';
import 'person.dart';

/// Receipt model representing the Firestore document structure
/// as defined in app_navigation_redesign.md
class Receipt {
  // Core fields from Cloud Functions
  final String? imageUri;
  final String? thumbnailUri;
  final Map<String, dynamic>? parseReceipt;
  final Map<String, dynamic>? transcribeAudio;
  final Map<String, dynamic>? assignPeopleToItems;
  final String status; // "draft" or "completed"
  final String? restaurantName;
  final List<String> people;
  final double? tip;
  final double? tax;

  // Metadata fields
  final String id;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  // Transient field for display URL (not saved to Firestore)
  final String? thumbnailUrlForDisplay;
  
  static const Object _noValue = Object();
  
  Receipt({
    required this.id,
    this.imageUri,
    this.thumbnailUri,
    this.parseReceipt,
    this.transcribeAudio,
    this.assignPeopleToItems,
    required this.status,
    this.restaurantName,
    this.people = const [],
    this.tip,
    this.tax,
    this.createdAt,
    this.updatedAt,
    this.thumbnailUrlForDisplay,
  });
  
  /// Create a Receipt from a Firestore DocumentSnapshot
  factory Receipt.fromDocumentSnapshot(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Extract metadata (handle null cases for flexibility)
    final Map<String, dynamic> metadata = 
        data.containsKey('metadata') && data['metadata'] is Map<String, dynamic> 
            ? data['metadata'] as Map<String, dynamic> 
            : {};
    
    // Handle timestamps which may be null, Timestamp objects, or DateTime objects
    Timestamp? createdAt;
    if (metadata['created_at'] != null) {
      createdAt = metadata['created_at'] as Timestamp;
    }
    
    Timestamp? updatedAt;
    if (metadata['updated_at'] != null) {
      updatedAt = metadata['updated_at'] as Timestamp;
    }
    
    // Convert people field to List<String>
    List<String> people = [];
    if (metadata['people'] != null && metadata['people'] is List) {
      people = (metadata['people'] as List).map((e) => e.toString()).toList();
    }
    
    // Note: thumbnailUrlForDisplay is deliberately NOT set here. 
    // It will be fetched and added via copyWith later.
    return Receipt(
      id: doc.id,
      // Read URIs from metadata
      imageUri: metadata['image_uri'] as String?,
      thumbnailUri: metadata['thumbnail_uri'] as String?,
      // Keep other fields as they are, assuming they are correctly placed or don't contain URIs
      parseReceipt: data['parse_receipt'] as Map<String, dynamic>?,
      transcribeAudio: data['transcribe_audio'] as Map<String, dynamic>?,
      assignPeopleToItems: data['assign_people_to_items'] as Map<String, dynamic>?,
      status: metadata['status'] as String? ?? 'draft',
      restaurantName: metadata['restaurant_name'] as String?,
      people: people,
      tip: (metadata['tip'] as num?)?.toDouble(),
      tax: (metadata['tax'] as num?)?.toDouble(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      // thumbnailUrlForDisplay: null, // Explicitly null initially
    );
  }
  
  /// Convert the Receipt to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    // thumbnailUrlForDisplay is NOT included here
    // URIs are now exclusively in metadata
    return {
      // Remove imageUri and thumbnailUri from the root
      // 'image_uri': imageUri, (Removed)
      // 'thumbnail_uri': thumbnailUri, (Removed)
      'parse_receipt': parseReceipt,
      'transcribe_audio': transcribeAudio,
      'assign_people_to_items': assignPeopleToItems,
      'metadata': {
        'created_at': createdAt ?? FieldValue.serverTimestamp(),
        'updated_at': updatedAt ?? FieldValue.serverTimestamp(),
        'status': status,
        'restaurant_name': restaurantName,
        'people': people,
        'tip': tip,
        'tax': tax,
        // Add URIs to metadata map
        'image_uri': imageUri,
        'thumbnail_uri': thumbnailUri,
      },
    };
  }
  
  /// Create a copy of the receipt with updated fields
  Receipt copyWith({
    String? id,
    Object? imageUri = _noValue,
    Object? thumbnailUri = _noValue,
    Map<String, dynamic>? parseReceipt,
    Map<String, dynamic>? transcribeAudio,
    Map<String, dynamic>? assignPeopleToItems,
    String? status,
    Object? restaurantName = _noValue,
    List<String>? people,
    Object? tip = _noValue,
    Object? tax = _noValue,
    Object? createdAt = _noValue,
    Object? updatedAt = _noValue,
    ValueGetter<String?>? thumbnailUrlForDisplay,
  }) {
    return Receipt(
      id: id ?? this.id,
      imageUri: identical(imageUri, _noValue) ? this.imageUri : imageUri as String?,
      thumbnailUri: identical(thumbnailUri, _noValue) ? this.thumbnailUri : thumbnailUri as String?,
      parseReceipt: parseReceipt ?? this.parseReceipt,
      transcribeAudio: transcribeAudio ?? this.transcribeAudio,
      assignPeopleToItems: assignPeopleToItems ?? this.assignPeopleToItems,
      status: status ?? this.status,
      restaurantName: identical(restaurantName, _noValue) ? this.restaurantName : restaurantName as String?,
      people: people ?? this.people,
      tip: identical(tip, _noValue) ? this.tip : tip as double?,
      tax: identical(tax, _noValue) ? this.tax : tax as double?,
      createdAt: identical(createdAt, _noValue) ? this.createdAt : createdAt as Timestamp?,
      updatedAt: identical(updatedAt, _noValue) ? this.updatedAt : updatedAt as Timestamp?,
      thumbnailUrlForDisplay: thumbnailUrlForDisplay != null ? thumbnailUrlForDisplay() : this.thumbnailUrlForDisplay,
    );
  }
  
  /// Create a new draft receipt
  static Receipt createDraft({
    required String id,
    String? imageUri,
    String? thumbnailUri,
    Map<String, dynamic>? parseReceipt,
    Map<String, dynamic>? transcribeAudio,
    Map<String, dynamic>? assignPeopleToItems,
    List<String>? people,
  }) {
    return Receipt(
      id: id,
      imageUri: imageUri,
      thumbnailUri: thumbnailUri,
      parseReceipt: parseReceipt,
      transcribeAudio: transcribeAudio,
      assignPeopleToItems: assignPeopleToItems,
      status: 'draft',
      people: people ?? [],
    );
  }
  
  /// Create a completed receipt from a draft
  Receipt markAsCompleted({
    required String restaurantName,
    double? tip,
    double? tax,
  }) {
    return copyWith(
      status: 'completed',
      updatedAt: Timestamp.fromDate(DateTime.now()),
      restaurantName: restaurantName,
      tip: tip,
      tax: tax,
    );
  }
  
  /// Check if the receipt is a draft
  bool get isDraft => status == 'draft';
  
  /// Check if the receipt is completed
  bool get isCompleted => status == 'completed';
  
  /// Get a formatted string of the updated date for display
  String get formattedDate {
    if (updatedAt == null) return 'Unknown date';
    return '${updatedAt!.toDate().day}/${updatedAt!.toDate().month}/${updatedAt!.toDate().year}';
  }
  
  /// Get a formatted string of the total amount for display
  String get formattedAmount {
    // Try to get total from splitManagerState if available
    if (parseReceipt != null && 
        parseReceipt!.containsKey('totalAmount')) {
      final total = parseReceipt!['totalAmount'];
      if (total is num) {
        return '\$${total.toStringAsFixed(2)}';
      }
    }
    
    // Fallback to "Pending" for drafts without a total
    return isDraft ? 'Pending' : '\$0.00';
  }
  
  /// Get the number of people as a string for display
  String get numberOfPeople {
    int count = people.length;
    return count == 0 ? '—' : '$count ${count == 1 ? 'person' : 'people'}';
  }
} 