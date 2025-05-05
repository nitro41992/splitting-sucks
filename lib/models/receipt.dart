import 'package:cloud_firestore/cloud_firestore.dart';
import 'receipt_item.dart';

class Receipt {
  String? id;
  String? imageUri;
  String? thumbnailUri;
  Map<String, dynamic>? parseReceipt;
  Map<String, dynamic>? transcribeAudio;
  Map<String, dynamic>? assignPeopleToItems;
  Map<String, dynamic>? splitManagerState;
  ReceiptMetadata metadata;
  
  Receipt({
    this.id,
    this.imageUri,
    this.thumbnailUri,
    this.parseReceipt,
    this.transcribeAudio,
    this.assignPeopleToItems,
    this.splitManagerState,
    required this.metadata,
  });
  
  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Receipt(
      id: doc.id,
      imageUri: data['image_uri'],
      thumbnailUri: data['thumbnail_uri'],
      parseReceipt: data['parse_receipt'],
      transcribeAudio: data['transcribe_audio'],
      assignPeopleToItems: data['assign_people_to_items'],
      splitManagerState: data['split_manager_state'],
      metadata: ReceiptMetadata.fromMap(data['metadata'] ?? {}),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'image_uri': imageUri,
      'thumbnail_uri': thumbnailUri,
      'parse_receipt': parseReceipt,
      'transcribe_audio': transcribeAudio,
      'assign_people_to_items': assignPeopleToItems,
      'split_manager_state': splitManagerState,
      'metadata': metadata.toMap(),
    };
  }
  
  factory Receipt.createDraft() {
    return Receipt(
      metadata: ReceiptMetadata(
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        status: 'draft',
      ),
    );
  }
  
  Receipt copyWith({
    String? id,
    String? imageUri,
    String? thumbnailUri,
    Map<String, dynamic>? parseReceipt,
    Map<String, dynamic>? transcribeAudio,
    Map<String, dynamic>? assignPeopleToItems,
    Map<String, dynamic>? splitManagerState,
    ReceiptMetadata? metadata,
  }) {
    return Receipt(
      id: id ?? this.id,
      imageUri: imageUri ?? this.imageUri,
      thumbnailUri: thumbnailUri ?? this.thumbnailUri,
      parseReceipt: parseReceipt ?? this.parseReceipt,
      transcribeAudio: transcribeAudio ?? this.transcribeAudio,
      assignPeopleToItems: assignPeopleToItems ?? this.assignPeopleToItems,
      splitManagerState: splitManagerState ?? this.splitManagerState,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ReceiptMetadata {
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String status; // 'draft' or 'completed'
  final String? restaurantName;
  final List<String> people;
  
  ReceiptMetadata({
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.restaurantName,
    this.people = const [],
  });
  
  factory ReceiptMetadata.fromMap(Map<String, dynamic> map) {
    return ReceiptMetadata(
      createdAt: map['created_at'] ?? Timestamp.now(),
      updatedAt: map['updated_at'] ?? Timestamp.now(),
      status: map['status'] ?? 'draft',
      restaurantName: map['restaurant_name'],
      people: map['people'] != null 
        ? List<String>.from(map['people']) 
        : [],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'created_at': createdAt,
      'updated_at': updatedAt,
      'status': status,
      'restaurant_name': restaurantName,
      'people': people,
    };
  }
  
  ReceiptMetadata copyWith({
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? status,
    String? restaurantName,
    List<String>? people,
  }) {
    return ReceiptMetadata(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      restaurantName: restaurantName ?? this.restaurantName,
      people: people ?? this.people,
    );
  }
} 