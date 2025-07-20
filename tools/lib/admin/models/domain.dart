import 'package:cloud_firestore/cloud_firestore.dart';

class DomainModel {
  final String id;
  final String name;
  final Timestamp createdAt;
  final bool isHidden;

  DomainModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.isHidden,
  });

  factory DomainModel.fromMap(Map<String, dynamic> data, String documentId) {
    Timestamp createdAt;
    try {
      createdAt =
          data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : Timestamp.now();
    } catch (e) {
      print('Error parsing createdAt for domain $documentId: $e');
      createdAt = Timestamp.now();
    }

    return DomainModel(
      id: documentId,
      name: data['name']?.toString() ?? '',
      createdAt: createdAt,
      isHidden: data['isHidden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'createdAt': createdAt, 'isHidden': isHidden};
  }
}
