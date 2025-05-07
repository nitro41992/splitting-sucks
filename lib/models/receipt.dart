import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'receipt_item.dart';

/// Receipt model representing the Firestore document structure
/// as defined in app_navigation_redesign.md
class Receipt {
  // Core fields from Cloud Functions
  final String? imageUri;
  final String? thumbnailUri;
  final Map<String, dynamic>? parseReceipt;
  final Map<String, dynamic>? transcribeAudio;
  final Map<String, dynamic>? assignPeopleToItems;
  final Map<String, dynamic>? splitManagerState;
  
  // Metadata fields
  final String id;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String status; // "draft" or "completed"
  final String? restaurantName;
  final List<String> people;
  final double tip; // Default: 20%
  final double tax; // Default: 8.875%

  // Transient field for display URL (not saved to Firestore)
  final String? thumbnailUrlForDisplay;
  
  Receipt({
    required this.id,
    this.imageUri,
    this.thumbnailUri,
    this.parseReceipt,
    this.transcribeAudio,
    this.assignPeopleToItems,
    this.splitManagerState,
    this.createdAt,
    this.updatedAt,
    required this.status,
    this.restaurantName,
    this.people = const [],
    this.tip = 20.0,
    this.tax = 8.875,
    this.thumbnailUrlForDisplay,
  });
  
  /// Create a Receipt from a Firestore DocumentSnapshot
  factory Receipt.fromDocumentSnapshot(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Extract metadata (handle null cases for flexibility)
    final Map<String, dynamic> metadata = 
        data.containsKey('metadata') ? data['metadata'] as Map<String, dynamic> : {};
    
    // Handle timestamps which may be null, Timestamp objects, or DateTime objects
    DateTime? createdAt;
    if (metadata['created_at'] != null) {
      createdAt = metadata['created_at'] is Timestamp 
          ? (metadata['created_at'] as Timestamp).toDate()
          : metadata['created_at'] as DateTime;
    }
    
    DateTime? updatedAt;
    if (metadata['updated_at'] != null) {
      updatedAt = metadata['updated_at'] is Timestamp 
          ? (metadata['updated_at'] as Timestamp).toDate()
          : metadata['updated_at'] as DateTime;
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
      imageUri: data['image_uri'] as String?,
      thumbnailUri: data['thumbnail_uri'] as String?,
      parseReceipt: data['parse_receipt'] as Map<String, dynamic>?,
      transcribeAudio: data['transcribe_audio'] as Map<String, dynamic>?,
      assignPeopleToItems: data['assign_people_to_items'] as Map<String, dynamic>?,
      splitManagerState: data['split_manager_state'] as Map<String, dynamic>?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: metadata['status'] as String? ?? 'draft',
      restaurantName: metadata['restaurant_name'] as String?,
      people: people,
      tip: (metadata['tip'] as num?)?.toDouble() ?? 20.0,
      tax: (metadata['tax'] as num?)?.toDouble() ?? 8.875,
      // thumbnailUrlForDisplay: null, // Explicitly null initially
    );
  }
  
  /// Convert the Receipt to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    // thumbnailUrlForDisplay is NOT included here
    return {
      'image_uri': imageUri,
      'thumbnail_uri': thumbnailUri,
      'parse_receipt': parseReceipt,
      'transcribe_audio': transcribeAudio,
      'assign_people_to_items': assignPeopleToItems,
      'split_manager_state': splitManagerState,
      'metadata': {
        'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'status': status,
        'restaurant_name': restaurantName,
        'people': people,
        'tip': tip,
        'tax': tax,
      },
    };
  }
  
  /// Create a copy of the receipt with updated fields
  Receipt copyWith({
    String? id,
    String? imageUri,
    String? thumbnailUri,
    Map<String, dynamic>? parseReceipt,
    Map<String, dynamic>? transcribeAudio,
    Map<String, dynamic>? assignPeopleToItems,
    Map<String, dynamic>? splitManagerState,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? restaurantName,
    List<String>? people,
    double? tip,
    double? tax,
    // Add parameter for the transient field
    ValueGetter<String?>? thumbnailUrlForDisplay, 
  }) {
    return Receipt(
      id: id ?? this.id,
      imageUri: imageUri ?? this.imageUri,
      thumbnailUri: thumbnailUri ?? this.thumbnailUri,
      parseReceipt: parseReceipt ?? this.parseReceipt,
      transcribeAudio: transcribeAudio ?? this.transcribeAudio,
      assignPeopleToItems: assignPeopleToItems ?? this.assignPeopleToItems,
      splitManagerState: splitManagerState ?? this.splitManagerState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      restaurantName: restaurantName ?? this.restaurantName,
      people: people ?? this.people,
      tip: tip ?? this.tip,
      tax: tax ?? this.tax,
      // Use the provided ValueGetter or keep the existing value
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
    Map<String, dynamic>? splitManagerState,
    List<String>? people,
  }) {
    return Receipt(
      id: id,
      imageUri: imageUri,
      thumbnailUri: thumbnailUri,
      parseReceipt: parseReceipt,
      transcribeAudio: transcribeAudio,
      assignPeopleToItems: assignPeopleToItems,
      splitManagerState: splitManagerState,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
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
      updatedAt: DateTime.now(),
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
    return '${updatedAt!.day}/${updatedAt!.month}/${updatedAt!.year}';
  }
  
  /// Get a formatted string of the total amount for display
  String get formattedAmount {
    // Try to get total from splitManagerState if available
    if (splitManagerState != null && 
        splitManagerState!.containsKey('totalAmount')) {
      final total = splitManagerState!['totalAmount'];
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