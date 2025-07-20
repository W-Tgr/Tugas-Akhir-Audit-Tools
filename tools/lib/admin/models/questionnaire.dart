import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionModel {
  final String id;
  final String levelId;
  final String text;
  final List<String> options;
  final Timestamp createdAt;

  QuestionModel({
    required this.id,
    required this.levelId,
    required this.text,
    required this.options,
    required this.createdAt,
  });

  factory QuestionModel.fromMap(Map<String, dynamic> data, String documentId) {
    Timestamp createdAt;
    try {
      createdAt =
          data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : Timestamp.now();
    } catch (e) {
      print('Error parsing createdAt for question $documentId: $e');
      createdAt = Timestamp.now();
    }

    return QuestionModel(
      id: documentId,
      levelId: data['levelId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      options: List<String>.from(data['options'] ?? ['N', 'P', 'L', 'F']),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'levelId': levelId,
      'text': text,
      'options': options,
      'createdAt': createdAt,
    };
  }
}
