import 'package:cloud_firestore/cloud_firestore.dart';

class RetakeRequestModel {
  final String id;
  final String userId;
  final String levelId;
  final String status; // pending, approved, rejected
  final Timestamp createdAt;

  RetakeRequestModel({
    required this.id,
    required this.userId,
    required this.levelId,
    required this.status,
    required this.createdAt,
  });

  factory RetakeRequestModel.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    if (data['userId'] == null ||
        data['levelId'] == null ||
        data['status'] == null) {
      print('Data retake request $documentId tidak lengkap: $data');
      throw Exception('Data retake request tidak lengkap');
    }

    Timestamp createdAt;
    try {
      createdAt =
          data['createdAt'] is Timestamp
              ? data['createdAt'] as Timestamp
              : Timestamp.now();
    } catch (e) {
      print('Error parsing createdAt for retake request $documentId: $e');
      createdAt = Timestamp.now();
    }

    return RetakeRequestModel(
      id: documentId,
      userId: data['userId'].toString(),
      levelId: data['levelId'].toString(),
      status: data['status'].toString(),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'levelId': levelId,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
