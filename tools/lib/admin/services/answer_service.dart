import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tools/admin/models/answer_model.dart';

class AnswerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Simpan jawaban user
  Future<void> saveAnswer(AnswerModel answer) async {
    try {
      print(
        'Saving answer to path: users/${answer.userId}/answers/${answer.id}',
      );
      print('Answer data: ${answer.toMap()}');

      // ✅ HANYA FIX INI: Hapus jawaban sebelumnya untuk QUESTION yang sama (bukan level)
      print(
        'Deleting previous answers for user: ${answer.userId}, question: ${answer.questionId}',
      );
      final previousAnswers =
          await _firestore
              .collection('users')
              .doc(answer.userId)
              .collection('answers')
              .where(
                'questionId',
                isEqualTo: answer.questionId,
              ) // ✅ GANTI dari levelId ke questionId
              .get();
      for (var doc in previousAnswers.docs) {
        await doc.reference.delete();
        print('Deleted previous answer: ${doc.id}');
      }

      // Simpan jawaban baru
      await _firestore
          .collection('users')
          .doc(answer.userId)
          .collection('answers')
          .doc(answer.id)
          .set(answer.toMap());
      print(
        'Answer saved for user: ${answer.userId}, question: ${answer.questionId}',
      );

      // Dapatkan status terkini
      print(
        'Fetching category doc: users/${answer.userId}/categories/${answer.categoryId}',
      );
      final categoryDoc =
          await _firestore
              .collection('users')
              .doc(answer.userId)
              .collection('categories')
              .doc(answer.categoryId)
              .get();

      List<String> answeredLevels = [];
      List<String> unlockedLevels = [];
      if (categoryDoc.exists) {
        final data = categoryDoc.data();
        answeredLevels = List<String>.from(data?['answeredLevels'] ?? []);
        unlockedLevels = List<String>.from(data?['unlockedLevels'] ?? []);
        print('Current answeredLevels: $answeredLevels');
        print('Current unlockedLevels: $unlockedLevels');
      } else {
        print('Category doc does not exist, initializing empty lists');
      }

      // Tambahkan levelId ke answeredLevels jika belum ada
      if (!answeredLevels.contains(answer.levelId)) {
        answeredLevels.add(answer.levelId);
        print('Adding levelId to answeredLevels: ${answer.levelId}');
      }

      // Update answeredLevels dan unlockedLevels
      print(
        'Updating category doc with answeredLevels: $answeredLevels, unlockedLevels: $unlockedLevels',
      );
      await _firestore
          .collection('users')
          .doc(answer.userId)
          .collection('categories')
          .doc(answer.categoryId)
          .set({
            'answeredLevels': answeredLevels,
            'unlockedLevels': unlockedLevels,
          }, SetOptions(merge: true));
      print(
        'Category updated for user: ${answer.userId}, category: ${answer.categoryId}',
      );
    } catch (e) {
      print('Error saving answer: $e');
      throw Exception('Gagal menyimpan jawaban: $e');
    }
  }

  // Ambil semua jawaban untuk level tertentu
  Future<List<AnswerModel>> getAllAnswers(String userId, String levelId) async {
    try {
      print('Fetching answers for user: $userId, level: $levelId');
      final answersSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('answers')
              .where('levelId', isEqualTo: levelId)
              .get();

      final answers =
          answersSnapshot.docs
              .map((doc) => AnswerModel.fromMap(doc.data(), doc.id))
              .toList();
      print('Fetched ${answers.length} answers');
      return answers;
    } catch (e) {
      print('Error getting answers: $e');
      throw Exception('Gagal mengambil jawaban: $e');
    }
  }

  // Periksa apakah level sudah pernah dijawab
  Future<bool> isLevelAnswered(
    String userId,
    String categoryId,
    String levelId,
  ) async {
    try {
      print(
        'Checking if level is answered: user: $userId, category: $categoryId, level: $levelId',
      );
      final categoryDoc =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('categories')
              .doc(categoryId)
              .get();

      if (!categoryDoc.exists) {
        print('Category doc does not exist');
        return false;
      }

      final answeredLevels = List<String>.from(
        categoryDoc.data()?['answeredLevels'] ?? [],
      );
      print('Answered levels: $answeredLevels');
      return answeredLevels.contains(levelId);
    } catch (e) {
      print('Error checking level answered: $e');
      throw Exception('Gagal memeriksa status jawaban level: $e');
    }
  }

  // Periksa apakah level selesai dan semua jawaban adalah "F"
  Future<bool> isLevelCompleted(String userId, String levelId) async {
    try {
      print('Checking if level is completed: user: $userId, level: $levelId');
      // Dapatkan semua pertanyaan untuk level ini
      final questionsSnapshot =
          await _firestore
              .collection('questions')
              .where('levelId', isEqualTo: levelId)
              .get();
      final questionIds = questionsSnapshot.docs.map((doc) => doc.id).toList();

      // Jika tidak ada pertanyaan, level tidak dapat diselesaikan
      if (questionIds.isEmpty) {
        print('No questions found for level: $levelId');
        return false;
      }

      // Dapatkan semua jawaban untuk level ini
      final answers = await getAllAnswers(userId, levelId);

      // Debug info
      print(
        'Level $levelId - Total pertanyaan: ${questionIds.length}, Total jawaban: ${answers.length}',
      );
      print('Jawaban: ${answers.map((a) => a.answer).toList()}');

      // Level dianggap selesai jika:
      // 1. Jumlah jawaban sama dengan jumlah pertanyaan
      // 2. Semua jawaban adalah "F"
      return answers.length == questionIds.length &&
          answers.every((answer) => answer.answer == 'F');
    } catch (e) {
      print('Error pada isLevelCompleted: $e');
      throw Exception('Gagal memeriksa status level: $e');
    }
  }

  // Buka level berikutnya untuk user tertentu
  Future<void> unlockNextLevel(
    String userId,
    String categoryId,
    int currentLevelNumber,
  ) async {
    try {
      print(
        'Unlocking next level: user: $userId, category: $categoryId, currentLevel: $currentLevelNumber',
      );
      final nextLevelNumber = currentLevelNumber + 1;
      print(
        'Querying levels for categoryId: $categoryId, levelNumber: $nextLevelNumber',
      );
      final levelSnapshot =
          await _firestore
              .collection('levels')
              .where('categoryId', isEqualTo: categoryId)
              .where('levelNumber', isEqualTo: nextLevelNumber)
              .get();

      if (levelSnapshot.docs.isEmpty) {
        print(
          'No level found for categoryId: $categoryId, levelNumber: $nextLevelNumber',
        );
        return;
      }

      final nextLevelId = levelSnapshot.docs.first.id;
      print('Next level ID: $nextLevelId');

      // Cek status unlockedLevels dan answeredLevels saat ini
      print('Fetching category doc: users/$userId/categories/$categoryId');
      final categoryDoc =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('categories')
              .doc(categoryId)
              .get();

      List<String> currentUnlockedLevels = [];
      List<String> currentAnsweredLevels = [];
      if (categoryDoc.exists) {
        final data = categoryDoc.data();
        currentUnlockedLevels = List<String>.from(
          data?['unlockedLevels'] ?? [],
        );
        currentAnsweredLevels = List<String>.from(
          data?['answeredLevels'] ?? [],
        );
        print('Current unlockedLevels: $currentUnlockedLevels');
        print('Current answeredLevels: $currentAnsweredLevels');
      }

      // Tambahkan level baru ke list jika belum ada
      if (!currentUnlockedLevels.contains(nextLevelId)) {
        currentUnlockedLevels.add(nextLevelId);
        print('Adding nextLevelId to unlockedLevels: $nextLevelId');
      }

      // Pastikan currentLevelNumber ada di answeredLevels
      final currentLevelSnapshot =
          await _firestore
              .collection('levels')
              .where('categoryId', isEqualTo: categoryId)
              .where('levelNumber', isEqualTo: currentLevelNumber)
              .get();
      if (currentLevelSnapshot.docs.isNotEmpty) {
        final currentLevelId = currentLevelSnapshot.docs.first.id;
        if (!currentAnsweredLevels.contains(currentLevelId)) {
          currentAnsweredLevels.add(currentLevelId);
          print('Adding currentLevelId to answeredLevels: $currentLevelId');
        }
      }

      // Update dengan array yang sudah lengkap
      print(
        'Updating category doc with unlockedLevels: $currentUnlockedLevels, answeredLevels: $currentAnsweredLevels',
      );
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(categoryId)
          .set({
            'unlockedLevels': currentUnlockedLevels,
            'answeredLevels': currentAnsweredLevels,
          }, SetOptions(merge: true));
      print('Unlocked level: $nextLevelId for user: $userId');
    } catch (e) {
      print('Error unlocking next level: $e');
      throw Exception('Gagal membuka level berikutnya: $e');
    }
  }

  // Inisialisasi Level 1 sebagai terbuka untuk user baru
  Future<void> initializeUserProgress(String userId, String categoryId) async {
    try {
      print('Initializing user progress: user: $userId, category: $categoryId');
      // Cek apakah dokumen category sudah ada
      final categoryDoc =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('categories')
              .doc(categoryId)
              .get();

      // Jika dokumen sudah ada, tidak perlu inisialisasi lagi
      if (categoryDoc.exists) {
        print('Category doc already exists');
        return;
      }

      // Jika dokumen belum ada, inisialisasi Level 1
      print('Querying level 1 for categoryId: $categoryId');
      final levelSnapshot =
          await _firestore
              .collection('levels')
              .where('categoryId', isEqualTo: categoryId)
              .where('levelNumber', isEqualTo: 1)
              .get();

      if (levelSnapshot.docs.isNotEmpty) {
        final levelId = levelSnapshot.docs.first.id;
        print('Initializing with levelId: $levelId');
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('categories')
            .doc(categoryId)
            .set({
              'unlockedLevels': [levelId],
              'answeredLevels': [],
            }, SetOptions(merge: true));
        print(
          'User progress initialized for user: $userId, category: $categoryId',
        );
      } else {
        print('No level 1 found for category: $categoryId');
      }
    } catch (e) {
      print('Error initializing user progress: $e');
      throw Exception('Gagal menginisialisasi progres user: $e');
    }
  }
}
