import 'package:cloud_firestore/cloud_firestore.dart';

class LevelModel {
  final String id;
  final String categoryId;
  final int levelNumber;
  final bool isUnlocked;
  final Timestamp createdAt;

  LevelModel({
    required this.id,
    required this.categoryId,
    required this.levelNumber,
    required this.isUnlocked,
    required this.createdAt,
  });

  factory LevelModel.fromMap(Map<String, dynamic> data, String documentId) {
    Timestamp createdAt;
    try {
      createdAt =
          data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : Timestamp.now();
    } catch (e) {
      print('Error parsing createdAt for level $documentId: $e');
      createdAt = Timestamp.now();
    }

    return LevelModel(
      id: documentId,
      categoryId: data['categoryId']?.toString() ?? '',
      levelNumber: (data['levelNumber'] as num?)?.toInt() ?? 1,
      isUnlocked: data['isUnlocked'] as bool? ?? false,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'levelNumber': levelNumber,
      'isUnlocked': isUnlocked,
      'createdAt': createdAt,
    };
  }
}
