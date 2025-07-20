import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tools/admin/models/domain.dart';
import 'package:tools/auth/auth_service.dart';

class DomainService {
  final CollectionReference domainCollection = FirebaseFirestore.instance
      .collection('domains');
  final AuthService _authService = AuthService();

  // Check if the user is an admin
  Future<bool> _isAdmin() async {
    final user = _authService.getCurrentUser();
    if (user == null) return false;
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    return userDoc.exists && userDoc.data()?['role'] == 'admin';
  }

  // CREATE
  Future<void> addDomain(DomainModel domain) async {
    try {
      await domainCollection.add({
        ...domain.toMap(),
        'createdAt': Timestamp.now(),
        'isHidden': domain.isHidden,
      });
      print('Domain added: ${domain.id}');
    } catch (e) {
      print("Error adding domain: $e");
      rethrow;
    }
  }

  // READ (Realtime)
  Stream<List<DomainModel>> getDomains() {
    try {
      return domainCollection
          .orderBy('createdAt', descending: false)
          .snapshots()
          .asyncMap((snapshot) async {
            final isAdmin = await _isAdmin();
            print('Fetched ${snapshot.docs.length} domains, isAdmin: $isAdmin');
            final domains =
                snapshot.docs.map((doc) {
                  return DomainModel.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                }).toList();
            // Filter hidden domains for non-admins
            return isAdmin
                ? domains
                : domains.where((d) => !d.isHidden).toList();
          })
          .handleError((error) {
            print('Error in getDomains stream: $error');
            return [];
          });
    } catch (e) {
      print('Error setting up getDomains stream: $e');
      return Stream.value([]);
    }
  }

  // UPDATE
  Future<void> updateDomain(DomainModel domain) async {
    try {
      await domainCollection.doc(domain.id).update(domain.toMap());
      print('Domain updated: ${domain.id}');
    } catch (e) {
      print("Error updating domain: $e");
      rethrow;
    }
  }

  // DELETE
  Future<void> deleteDomain(String id) async {
    try {
      await domainCollection.doc(id).delete();
      print('Domain deleted: $id');
    } catch (e) {
      print("Error deleting domain: $e");
      rethrow;
    }
  }
}
