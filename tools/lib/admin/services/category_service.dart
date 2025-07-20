import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tools/admin/models/category.dart';

class CategoryService {
  final CollectionReference categoryCollection = FirebaseFirestore.instance
      .collection('categories');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // CREATE
  Future<void> addCategory(CategoryModel category) async {
    try {
      await categoryCollection.add({
        ...category.toMap(),
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print("Error adding category: $e");
      rethrow;
    }
  }

  // READ (Realtime)
  Stream<List<CategoryModel>> getCategories(String domainId) {
    try {
      return categoryCollection
          .where('domainId', isEqualTo: domainId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) {
            print(
              'Fetched ${snapshot.docs.length} categories for domainId: $domainId',
            );
            return snapshot.docs.map((doc) {
              return CategoryModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();
          })
          .handleError((error) {
            print('Error in getCategories stream: $error');
            return [];
          });
    } catch (e) {
      print('Error setting up getCategories stream: $e');
      return Stream.value([]);
    }
  }

  // UPDATE
  Future<void> updateCategory(CategoryModel category) async {
    try {
      await categoryCollection.doc(category.id).update(category.toMap());
    } catch (e) {
      print("Error updating category: $e");
      rethrow;
    }
  }

  // DELETE
  Future<void> deleteCategory(String id) async {
    try {
      await categoryCollection.doc(id).delete();
    } catch (e) {
      print("Error deleting category: $e");
      rethrow;
    }
  }

  // FUNGSI: Memeriksa apakah kategori pernah diakses oleh user
  Future<bool> hasUserAccessedCategory(String userId, String categoryId) async {
    try {
      final categoryDoc =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('categories')
              .doc(categoryId)
              .get();
      return categoryDoc.exists;
    } catch (e) {
      print('Error checking category access: $e');
      return false;
    }
  }

  // FUNGSI: Mendapatkan data user untuk kategori tertentu
  Stream<DocumentSnapshot> getUserCategoryData(
    String userId,
    String categoryId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('categories')
        .doc(categoryId)
        .snapshots();
  }

  // FUNGSI: Debugging: Log status kategori user
  Future<void> logUserCategoryStatus(String userId, String categoryId) async {
    try {
      final categoryDoc =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('categories')
              .doc(categoryId)
              .get();

      print('User Category status for $categoryId:');
      print('Exists: ${categoryDoc.exists}');
      if (categoryDoc.exists) {
        final data = categoryDoc.data();
        print('Unlocked Levels: ${data?['unlockedLevels']}');
        print('Answered Levels: ${data?['answeredLevels']}');
      }
    } catch (e) {
      print('Error logging category status: $e');
    }
  }
}
