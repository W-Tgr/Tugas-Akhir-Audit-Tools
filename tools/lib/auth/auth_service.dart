import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register user with a specified role (admin or user)
  Future<User?> registerWithEmailAndPassword(
    String email,
    String password,
    String role, // "admin" or "user"
    Function onRegisterSuccess, // Callback to handle after registration
  ) async {
    try {
      // Daftar pengguna menggunakan email dan password
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Dapatkan UID pengguna yang terdaftar
      String uid = cred.user!.uid;

      // Simpan data pengguna ke Firestore, termasuk UID
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'role': role,
        'status': 'pending', // Semua pengguna baru memiliki status "pending"
        'uid': uid, // Simpan UID pengguna ke Firestore
        'displayName': email.split('@')[0], // Default displayName dari email
        'photoBase64': null, // Default photo
      });

      // Panggil callback setelah registrasi berhasil
      onRegisterSuccess();

      return cred.user;
    } catch (e) {
      print("Error during user registration: $e");
      return null;
    }
  }

  // Login user with email and password
  Future<User?> loginWithEmailAndPassword(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Fetch user document from Firestore
      final userDoc =
          await _firestore.collection('users').doc(cred.user!.uid).get();

      if (userDoc.exists) {
        // Check if the user's status is 'approved'
        String status =
            userDoc['status'] ?? 'pending'; // Default to 'pending' if null
        String email =
            userDoc['email'] ?? 'no-email@example.com'; // Default email if null
        String role = userDoc['role'] ?? 'user'; // Default to 'user' if null

        print("User data: Email: $email, Role: $role, Status: $status");

        if (status == 'approved') {
          return cred.user; // Allow login if approved
        } else {
          print("User is not approved yet.");
        }
      }

      await _auth.signOut(); // Log the user out if status is not approved
      return null; // Deny login if not approved
    } catch (e) {
      print("Login failed: $e");
      return null;
    }
  }

  // METODE BARU: Reset Password via Email
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true; // Email berhasil dikirim
    } catch (e) {
      print("Error sending password reset email: $e");
      return false; // Email gagal dikirim
    }
  }

  // Get user role from Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc['role']; // Return "admin" or "user"
      }
      return null;
    } catch (e) {
      print("Error fetching user role: $e");
      return null;
    }
  }

  // Approve the user (for admin)
  Future<void> approveUser(String uid) async {
    try {
      // Get the user's document from Firestore
      var userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        // Check the current status before updating
        String currentStatus = userDoc['status'] ?? 'pending';
        print("Current status: $currentStatus");

        // Update status to 'approved'
        await _firestore.collection('users').doc(uid).update({
          'status': 'approved',
        });

        // Log the updated status
        var updatedUserDoc =
            await _firestore.collection('users').doc(uid).get();
        print(
          "Updated status: ${updatedUserDoc['status']}",
        ); // It should now be "approved"
      } else {
        print("User document not found.");
      }
    } catch (e) {
      print("Error approving user: $e");
    }
  }

  // Fetch all users with status 'pending' (for admin)
  Future<List<Map<String, dynamic>>> fetchPendingUsers() async {
    try {
      var snapshot =
          await _firestore
              .collection('users')
              .where(
                'status',
                isEqualTo: 'pending',
              ) // Fetch users dengan status 'pending'
              .get();

      if (snapshot.docs.isEmpty) {
        print("No pending users found.");
      } else {
        print("Pending users found: ${snapshot.docs.length}");
      }

      // Map documents to data and include their document ID (uid)
      return snapshot.docs.map((doc) {
        var userData = doc.data() as Map<String, dynamic>;
        userData['uid'] = doc.id; // Add the document ID (uid) to the data
        return userData;
      }).toList();
    } catch (e) {
      print("Error fetching pending users: $e");
      return [];
    }
  }

  // Sign out user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
