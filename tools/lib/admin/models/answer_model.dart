import 'package:cloud_firestore/cloud_firestore.dart';

class AnswerModel {
  final String id;
  final String userId;
  final String questionId;
  final String levelId;
  final String categoryId;
  final String answer;
  final DateTime timestamp;

  AnswerModel({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.levelId,
    required this.categoryId,
    required this.answer,
    required this.timestamp,
  });

  factory AnswerModel.fromMap(Map<String, dynamic> data, String documentId) {
    print('Creating AnswerModel from map: $data, docId: $documentId');
    return AnswerModel(
      id: documentId,
      userId: data['userId'] ?? '',
      questionId: data['questionId'] ?? '',
      levelId: data['levelId'] ?? '',
      categoryId: data['categoryId'] ?? '',
      answer: data['answer'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'userId': userId,
      'questionId': questionId,
      'levelId': levelId,
      'categoryId': categoryId,
      'answer': answer,
      'timestamp': Timestamp.fromDate(timestamp),
    };
    print('AnswerModel toMap: $map');
    return map;
  }
}
