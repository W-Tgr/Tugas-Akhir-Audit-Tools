import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String domainId;
  final String name;
  final Timestamp createdAt;

  CategoryModel({
    required this.id,
    required this.domainId,
    required this.name,
    required this.createdAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> data, String documentId) {
    // Safely handle createdAt
    Timestamp createdAt;
    try {
      createdAt =
          data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : Timestamp.now();
    } catch (e) {
      print('Error parsing createdAt for category $documentId: $e');
      createdAt = Timestamp.now();
    }

    return CategoryModel(
      id: documentId,
      domainId: data['domainId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {'domainId': domainId, 'name': name, 'createdAt': createdAt};
  }
}
