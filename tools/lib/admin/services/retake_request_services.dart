import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tools/admin/models/retake_request.dart';

class RetakeRequestService {
  final CollectionReference requestCollection = FirebaseFirestore.instance
      .collection('retakeRequests');

  // CREATE
  Future<void> createRetakeRequest(RetakeRequestModel request) async {
    try {
      await requestCollection.doc('${request.userId}_${request.levelId}').set({
        ...request.toMap(),
        'createdAt': Timestamp.now(),
      });
      print('Retake request created: ${request.id}');
    } catch (e) {
      print('Error creating retake request: $e');
      rethrow;
    }
  }

  // READ (User-specific)
  Stream<RetakeRequestModel?> getUserRetakeRequest(
    String userId,
    String levelId,
  ) {
    try {
      return requestCollection
          .doc('${userId}_${levelId}')
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) {
              print(
                'No retake request found for user: $userId, level: $levelId',
              );
              return null;
            }
            return RetakeRequestModel.fromMap(
              snapshot.data() as Map<String, dynamic>,
              snapshot.id,
            );
          })
          .handleError((error) {
            print('Error in getUserRetakeRequest stream: $error');
            return null;
          });
    } catch (e) {
      print('Error setting up getUserRetakeRequest stream: $e');
      return Stream.value(null);
    }
  }

  // READ (All for admin)
  Stream<List<RetakeRequestModel>> getAllRetakeRequests() {
    try {
      return requestCollection
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) {
            print('Fetched ${snapshot.docs.length} retake requests');
            return snapshot.docs.map((doc) {
              return RetakeRequestModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();
          })
          .handleError((error) {
            print('Error in getAllRetakeRequests stream: $error');
            if (error.toString().contains('requires an index')) {
              print(
                'Action required: Create a composite index for status and createdAt in Firebase Console.',
              );
            }
            return [];
          });
    } catch (e) {
      print('Error setting up getAllRetakeRequests stream: $e');
      return Stream.value([]);
    }
  }

  // UPDATE
  Future<void> updateRetakeRequestStatus(
    String requestId,
    String status,
  ) async {
    try {
      final doc = await requestCollection.doc(requestId).get();
      if (!doc.exists) {
        print('Dokumen retakeRequests/$requestId tidak ditemukan');
        throw Exception('Permintaan retake tidak ditemukan');
      }
      print('Dokumen ditemukan: ${doc.data()}');
      await requestCollection.doc(requestId).update({'status': status});
      print('Retake request $requestId updated to status: $status');
    } catch (e) {
      print('Error updating retake request: $e');
      rethrow;
    }
  }

  // DELETE
  Future<void> deleteRetakeRequest(String requestId) async {
    try {
      final doc = await requestCollection.doc(requestId).get();
      if (!doc.exists) {
        print('Dokumen retakeRequests/$requestId tidak ditemukan');
        return; // Tidak throw error
      }
      await requestCollection.doc(requestId).delete();
      print('Retake request deleted: $requestId');
    } catch (e) {
      print('Error deleting retake request: $e');
      rethrow;
    }
  }

  // Reset retake request after quiz completion
  Future<void> resetRetakeRequest(String userId, String levelId) async {
    try {
      final requestId = '${userId}_${levelId}';
      print('Attempting to reset retake request: $requestId');
      final doc = await requestCollection.doc(requestId).get();
      if (!doc.exists) {
        print('No retake request to reset for user: $userId, level: $levelId');
        return;
      }
      await requestCollection.doc(requestId).delete();
      print('Retake request reset for user: $userId, level: $levelId');
    } catch (e) {
      print('Error resetting retake request: $e');
      throw Exception('Gagal mereset retake request: $e');
    }
  }
}
