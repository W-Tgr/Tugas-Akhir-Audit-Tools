import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tools/admin/models/level.dart';

class LevelService {
  final CollectionReference levelCollection = FirebaseFirestore.instance
      .collection('levels');

  // CREATE
  Future<void> addLevel(LevelModel level) async {
    try {
      await levelCollection.add({
        ...level.toMap(),
        'createdAt': Timestamp.now(),
      });
      print('Level added: ${level.id}');
    } catch (e) {
      print("Error adding level: $e");
      rethrow;
    }
  }

  // READ (Realtime)
  Stream<List<LevelModel>> getLevels(String categoryId) {
    try {
      return levelCollection
          .where('categoryId', isEqualTo: categoryId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) {
            print(
              'Fetched ${snapshot.docs.length} levels for categoryId: $categoryId',
            );
            return snapshot.docs.map((doc) {
              return LevelModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();
          })
          .handleError((error) {
            print('Error in getLevels stream: $error');
            return [];
          });
    } catch (e) {
      print('Error setting up getLevels stream: $e');
      return Stream.value([]);
    }
  }

  // UPDATE
  Future<void> updateLevel(LevelModel level) async {
    try {
      await levelCollection.doc(level.id).update(level.toMap());
      print('Level updated: ${level.id}');
    } catch (e) {
      print("Error updating level: $e");
      rethrow;
    }
  }

  // DELETE
  Future<void> deleteLevel(String id) async {
    try {
      await levelCollection.doc(id).delete();
      print('Level deleted: $id');
    } catch (e) {
      print("Error deleting level: $e");
      rethrow;
    }
  }
}
