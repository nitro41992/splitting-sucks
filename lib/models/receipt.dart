import 'package:cloud_firestore/cloud_firestore.dart';
import 'receipt_item.dart';

class Receipt {
  String? id;
  String? imageUri;
  String? thumbnailUri;
  Map<String, dynamic>? parseReceipt;
  Map<String, dynamic>? transcribeAudio;
  Map<String, dynamic>? assignPeopleToItems;
  ReceiptMetadata metadata;
  
  Receipt({
    this.id,
    this.imageUri,
    this.thumbnailUri,
    this.parseReceipt,
    this.transcribeAudio,
    this.assignPeopleToItems,
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
      metadata: ReceiptMetadata.fromMap(data['metadata'] ?? {}),
    );
  }
  
  Map<String, dynamic> toFirestore() {
    // Need to create deep copies of the nested structures
    final Map<String, dynamic> result = {
      'image_uri': imageUri,
      'thumbnail_uri': thumbnailUri,
      'parse_receipt': parseReceipt != null ? Map<String, dynamic>.from(parseReceipt!) : null,
      'transcribe_audio': transcribeAudio != null ? Map<String, dynamic>.from(transcribeAudio!) : null,
      'metadata': metadata.toMap(),
    };
    
    // Special handling for assign_people_to_items to ensure correct structure
    if (assignPeopleToItems != null) {
      final Map<String, dynamic> deepCopiedAssignments = {};
      
      // Handle assignments map
      if (assignPeopleToItems!.containsKey('assignments')) {
        final Map<String, dynamic> assignmentsMap = Map<String, dynamic>.from(assignPeopleToItems!['assignments'] as Map<String, dynamic>);
        final Map<String, dynamic> deepAssignments = {};
        
        // Handle each person's assignments
        assignmentsMap.forEach((person, items) {
          if (items is List) {
            // Deep copy each item in the list
            final List<dynamic> deepItems = [];
            for (final item in items) {
              if (item is Map<String, dynamic>) {
                deepItems.add(Map<String, dynamic>.from(item));
              } else {
                deepItems.add(item);
              }
            }
            deepAssignments[person] = deepItems;
          } else {
            // If somehow not a list, maintain structure
            deepAssignments[person] = items;
          }
        });
        
        deepCopiedAssignments['assignments'] = deepAssignments;
      }
      
      // Handle shared_items list
      if (assignPeopleToItems!.containsKey('shared_items')) {
        final List<dynamic> sharedItems = assignPeopleToItems!['shared_items'] as List<dynamic>;
        final List<dynamic> deepSharedItems = [];
        
        // Deep copy each shared item
        for (final item in sharedItems) {
          if (item is Map<String, dynamic>) {
            final Map<String, dynamic> deepItem = Map<String, dynamic>.from(item);
            
            // Handle the 'people' list inside each shared item
            if (deepItem.containsKey('people') && deepItem['people'] is List) {
              deepItem['people'] = List<dynamic>.from(deepItem['people'] as List<dynamic>);
            }
            
            deepSharedItems.add(deepItem);
          } else {
            deepSharedItems.add(item);
          }
        }
        
        deepCopiedAssignments['shared_items'] = deepSharedItems;
      }
      
      // Handle unassigned_items list
      if (assignPeopleToItems!.containsKey('unassigned_items')) {
        final List<dynamic> unassignedItems = assignPeopleToItems!['unassigned_items'] as List<dynamic>;
        final List<dynamic> deepUnassignedItems = [];
        
        // Deep copy each unassigned item
        for (final item in unassignedItems) {
          if (item is Map<String, dynamic>) {
            deepUnassignedItems.add(Map<String, dynamic>.from(item));
          } else {
            deepUnassignedItems.add(item);
          }
        }
        
        deepCopiedAssignments['unassigned_items'] = deepUnassignedItems;
      }
      
      result['assign_people_to_items'] = deepCopiedAssignments;
    }
    
    return result;
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
    ReceiptMetadata? metadata,
  }) {
    return Receipt(
      id: id ?? this.id,
      imageUri: imageUri ?? this.imageUri,
      thumbnailUri: thumbnailUri ?? this.thumbnailUri,
      parseReceipt: parseReceipt ?? this.parseReceipt,
      transcribeAudio: transcribeAudio ?? this.transcribeAudio,
      assignPeopleToItems: assignPeopleToItems ?? this.assignPeopleToItems,
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