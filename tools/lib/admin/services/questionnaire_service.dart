import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tools/admin/models/questionnaire.dart';

class QuestionService {
  final CollectionReference questionCollection = FirebaseFirestore.instance
      .collection('questions');

  // CREATE
  Future<void> addQuestion(QuestionModel question) async {
    try {
      await questionCollection.add({
        ...question.toMap(),
        'createdAt': Timestamp.now(),
      });
      print('Question added: ${question.id}');
    } catch (e) {
      print("Error adding question: $e");
      rethrow;
    }
  }

  // READ (Realtime)
  Stream<List<QuestionModel>> getQuestions(String levelId) {
    try {
      return questionCollection
          .where('levelId', isEqualTo: levelId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) {
            print(
              'Fetched ${snapshot.docs.length} questions for levelId: $levelId',
            );
            return snapshot.docs.map((doc) {
              return QuestionModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();
          })
          .handleError((error) {
            print('Error in getQuestions stream: $error');
            return [];
          });
    } catch (e) {
      print('Error setting up getQuestions stream: $e');
      return Stream.value([]);
    }
  }

  // UPDATE
  Future<void> updateQuestion(QuestionModel question) async {
    try {
      await questionCollection.doc(question.id).update(question.toMap());
      print('Question updated: ${question.id}');
    } catch (e) {
      print("Error updating question: $e");
      rethrow;
    }
  }

  // DELETE
  Future<void> deleteQuestion(String id) async {
    try {
      await questionCollection.doc(id).delete();
      print('Question deleted: $id');
    } catch (e) {
      print("Error deleting question: $e");
      rethrow;
    }
  }
}
