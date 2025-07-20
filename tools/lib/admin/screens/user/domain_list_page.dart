import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tools/admin/models/domain.dart';
import 'package:tools/admin/screens/user/category_list_page.dart';
import 'package:tools/admin/services/domain_service.dart';
import 'package:tools/auth/auth_service.dart';
import 'package:tools/auth/login_screen.dart';

// Enum untuk status domain
enum DomainStatus {
  hasRetake, // Ada kategori yang bisa di-retake
  hasUnlocked, // Ada kategori yang unlocked tapi belum dimulai
  inProgress, // Masih dalam progress normal
  completed, // Sudah selesai 100%
}

class DomainListPage extends StatefulWidget {
  const DomainListPage({Key? key}) : super(key: key);

  @override
  State<DomainListPage> createState() => _DomainListPageState();
}

class _DomainListPageState extends State<DomainListPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Stream subscriptions untuk realtime data
  List<StreamSubscription> _streamSubscriptions = [];

  // Data untuk validasi domain locks
  Map<String, Map<String, dynamic>> _domains = {};
  Map<String, Map<String, dynamic>> _categories = {};
  Map<String, Map<String, dynamic>> _levels = {};
  Map<String, Map<String, dynamic>> _questions = {};
  List<Map<String, dynamic>> _userAnswers = [];
  Map<String, Map<String, dynamic>> _domainResults = {};
  Map<String, bool> _domainLockStatus = {};
  Map<String, Map<String, dynamic>> _domainProgress = {};
  bool _isLoadingLockData = true;

  // Enhanced Modern Blue Theme (consistent with other pages)
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _darkBlue = Color(0xFF1565C0);
  static const Color _lightBlue = Color(0xFF42A5F5);
  static const Color _accentBlue = Color(0xFF64B5F6);
  static const Color _backgroundColor = Color(0xFFF8FAFF);
  static const Color _surfaceColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF64748B);

  static final List<Color> _gradientColors = [
    _darkBlue,
    _primaryBlue,
    _lightBlue,
    _accentBlue,
  ];

  static final List<Color> _cardGradient = [
    Colors.white,
    const Color(0xFFF8FAFF),
  ];

  static const double _cardRadius = 24.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    _setupRealtimeLockData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Cancel semua stream subscriptions
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
    _streamSubscriptions.clear();
    super.dispose();
  }

  // Setup realtime listeners untuk lock validation
  void _setupRealtimeLockData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingLockData = true;
    });

    final firestore = FirebaseFirestore.instance;

    // 1. Listen to domains
    final domainsSubscription = firestore
        .collection('domains')
        .where('isHidden', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          print(
            '🔄 Domains updated for lock validation: ${snapshot.docs.length} documents',
          );
          _domains.clear();
          for (var doc in snapshot.docs) {
            _domains[doc.id] = {
              'id': doc.id,
              'name': doc.data()['name'] ?? 'Domain ${doc.id}',
              'isHidden': doc.data()['isHidden'] ?? false,
            };
          }
          _processLockData();
        });
    _streamSubscriptions.add(domainsSubscription);

    // 2. Listen to categories
    final categoriesSubscription = firestore
        .collection('categories')
        .snapshots()
        .listen((snapshot) {
          print(
            '🔄 Categories updated for lock validation: ${snapshot.docs.length} documents',
          );
          _categories.clear();
          for (var doc in snapshot.docs) {
            _categories[doc.id] = {
              'id': doc.id,
              'name': doc.data()['name'] ?? 'Category ${doc.id}',
              'domainId': doc.data()['domainId'] ?? '',
            };
          }
          _processLockData();
        });
    _streamSubscriptions.add(categoriesSubscription);

    // 3. Listen to levels
    final levelsSubscription = firestore.collection('levels').snapshots().listen((
      snapshot,
    ) {
      print(
        '🔄 Levels updated for lock validation: ${snapshot.docs.length} documents',
      );
      _levels.clear();
      for (var doc in snapshot.docs) {
        _levels[doc.id] = {
          'id': doc.id,
          'levelNumber': doc.data()['levelNumber'] ?? 0,
          'categoryId': doc.data()['categoryId'] ?? '',
          'name':
              doc.data()['name'] ??
              'Level ${doc.data()['levelNumber'] ?? doc.id}',
        };
      }
      _processLockData();
    });
    _streamSubscriptions.add(levelsSubscription);

    // 4. Listen to questions
    final questionsSubscription = firestore
        .collection('questions')
        .snapshots()
        .listen((snapshot) {
          print(
            '🔄 Questions updated for lock validation: ${snapshot.docs.length} documents',
          );
          _questions.clear();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            _questions[doc.id] = {
              'id': doc.id,
              'levelId': data['levelId'] ?? '',
              'categoryId': data['categoryId'] ?? '',
              'text': data['text'] ?? 'Pertanyaan ${doc.id}',
            };
          }
          _processLockData();
        });
    _streamSubscriptions.add(questionsSubscription);

    // 5. Listen to user answers
    final answersSubscription = firestore
        .collection('users')
        .doc(user.uid)
        .collection('answers')
        .snapshots()
        .listen((snapshot) {
          print(
            '🔄 User answers updated for lock validation: ${snapshot.docs.length} documents',
          );
          _userAnswers.clear();
          _userAnswers =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'questionId': data['questionId'] ?? '',
                  'levelId': data['levelId'] ?? '',
                  'categoryId': data['categoryId'] ?? '',
                  'answer': data['answer'] ?? '',
                  'timestamp': data['timestamp'],
                };
              }).toList();
          _processLockData();
        });
    _streamSubscriptions.add(answersSubscription);

    // 6. Listen to user categories progress
    final userCategoriesSubscription = firestore
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .snapshots()
        .listen((snapshot) {
          print(
            '🔄 User categories updated for lock validation: ${snapshot.docs.length} documents',
          );
          _processUserCategories(snapshot.docs);
        });
    _streamSubscriptions.add(userCategoriesSubscription);
  }

  // Process user categories data
  void _processUserCategories(List<QueryDocumentSnapshot> docs) {
    // Clear existing user category data
    for (final domainResult in _domainResults.values) {
      final categories =
          domainResult['categories'] as Map<String, Map<String, dynamic>>;
      for (final categoryResult in categories.values) {
        categoryResult['unlockedLevels'] = <String>[];
        categoryResult['answeredLevels'] = <String>[];
      }
    }

    // Process new data
    for (var doc in docs) {
      final categoryId = doc.id;
      final data = doc.data() as Map<String, dynamic>;

      List<String> unlockedLevels =
          (data['unlockedLevels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      List<String> answeredLevels =
          (data['answeredLevels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      // Update the specific category in domain results
      if (_categories.containsKey(categoryId)) {
        final domainId = _categories[categoryId]!['domainId'] as String;
        if (_domainResults.containsKey(domainId) &&
            _domainResults[domainId]!['categories'].containsKey(categoryId)) {
          _domainResults[domainId]!['categories'][categoryId]['unlockedLevels'] =
              unlockedLevels;
          _domainResults[domainId]!['categories'][categoryId]['answeredLevels'] =
              answeredLevels;
        }
      }
    }

    _processLockData();
  }

  // Process semua data untuk menentukan lock status
  void _processLockData() {
    // Hanya process jika semua data dasar sudah ada
    if (_domains.isEmpty ||
        _categories.isEmpty ||
        _levels.isEmpty ||
        _questions.isEmpty) {
      print('⏳ Waiting for all basic data to load for lock validation...');
      return;
    }

    print('🔄 Processing domain lock data...');

    try {
      // Initialize domain results jika belum ada
      if (_domainResults.isEmpty) {
        _initializeDomainResults();
      }

      // Update domain results with current data
      _updateDomainResults();

      // Process answers untuk statistik
      _processAnswerStatistics();

      // Calculate current levels
      _calculateCurrentLevels();

      // Calculate domain lock status dan progress
      _calculateDomainLockStatus();

      // Update UI
      if (mounted) {
        setState(() {
          _isLoadingLockData = false;
        });
      }

      print('✅ Domain lock data processed successfully');
    } catch (e) {
      print('❌ Error processing domain lock data: $e');
      if (mounted) {
        setState(() {
          _isLoadingLockData = false;
        });
      }
    }
  }

  // Initialize domain results structure
  void _initializeDomainResults() {
    _domainResults.clear();

    for (final domainId in _domains.keys) {
      _domainResults[domainId] = {
        'domain': _domains[domainId]!,
        'categories': <String, Map<String, dynamic>>{},
        'stats': {'N': 0, 'P': 0, 'L': 0, 'F': 0, 'total': 0},
      };
    }

    for (final categoryId in _categories.keys) {
      final domainId = _categories[categoryId]!['domainId'] as String;
      if (_domainResults.containsKey(domainId)) {
        _domainResults[domainId]!['categories'][categoryId] = {
          'category': _categories[categoryId]!,
          'unlockedLevels': <String>[],
          'answeredLevels': <String>[],
          'stats': {'N': 0, 'P': 0, 'L': 0, 'F': 0, 'total': 0},
          'currentLevel': 0,
        };
      }
    }
  }

  // Update domain results dengan data terbaru
  void _updateDomainResults() {
    // Update category info
    for (final categoryId in _categories.keys) {
      final domainId = _categories[categoryId]!['domainId'] as String;
      if (_domainResults.containsKey(domainId)) {
        if (!_domainResults[domainId]!['categories'].containsKey(categoryId)) {
          _domainResults[domainId]!['categories'][categoryId] = {
            'category': _categories[categoryId]!,
            'unlockedLevels': <String>[],
            'answeredLevels': <String>[],
            'stats': {'N': 0, 'P': 0, 'L': 0, 'F': 0, 'total': 0},
            'currentLevel': 0,
          };
        } else {
          // Update category data
          _domainResults[domainId]!['categories'][categoryId]['category'] =
              _categories[categoryId]!;
        }
      }
    }
  }

  // Process answer statistics
  void _processAnswerStatistics() {
    // Reset all stats
    for (final domainResult in _domainResults.values) {
      final domainStats = domainResult['stats'] as Map<String, dynamic>;
      domainStats['N'] = 0;
      domainStats['P'] = 0;
      domainStats['L'] = 0;
      domainStats['F'] = 0;
      domainStats['total'] = 0;

      final categories =
          domainResult['categories'] as Map<String, Map<String, dynamic>>;
      for (final categoryResult in categories.values) {
        final categoryStats = categoryResult['stats'] as Map<String, dynamic>;
        categoryStats['N'] = 0;
        categoryStats['P'] = 0;
        categoryStats['L'] = 0;
        categoryStats['F'] = 0;
        categoryStats['total'] = 0;
      }
    }

    // Process all answers
    for (final answer in _userAnswers) {
      final categoryId = answer['categoryId'] as String;
      final answerValue = answer['answer'] as String;

      if (!['N', 'P', 'L', 'F'].contains(answerValue)) continue;
      if (!_categories.containsKey(categoryId)) continue;

      final domainId = _categories[categoryId]!['domainId'] as String;
      if (!_domainResults.containsKey(domainId)) continue;
      if (!_domainResults[domainId]!['categories'].containsKey(categoryId))
        continue;

      final categoryResult =
          _domainResults[domainId]!['categories'][categoryId];
      final categoryStats = categoryResult['stats'] as Map<String, dynamic>;
      categoryStats[answerValue] = (categoryStats[answerValue] ?? 0) + 1;
      categoryStats['total'] = (categoryStats['total'] ?? 0) + 1;

      // Update domain stats
      final domainStats =
          _domainResults[domainId]!['stats'] as Map<String, dynamic>;
      domainStats[answerValue] = (domainStats[answerValue] ?? 0) + 1;
      domainStats['total'] = (domainStats['total'] ?? 0) + 1;
    }
  }

  // Calculate current levels untuk setiap kategori
  void _calculateCurrentLevels() {
    for (final domainResult in _domainResults.values) {
      final categories =
          domainResult['categories'] as Map<String, Map<String, dynamic>>;
      for (final categoryResult in categories.values) {
        final answeredLevels = categoryResult['answeredLevels'] as List<String>;
        int maxLevelNumber = 0;

        for (final levelId in answeredLevels) {
          if (_levels.containsKey(levelId)) {
            final levelNumber = _levels[levelId]!['levelNumber'] as int;
            if (levelNumber > maxLevelNumber) {
              maxLevelNumber = levelNumber;
            }
          }
        }

        categoryResult['currentLevel'] = maxLevelNumber;
      }
    }
  }

  // ENHANCED: Fungsi baru untuk mengecek apakah kategori masih bisa di-retake
  bool _canCategoryBeRetaken(String categoryId, List<String> answeredLevels) {
    // Dapatkan semua jawaban untuk kategori ini
    final categoryAnswers =
        _userAnswers
            .where((answer) => answer['categoryId'] == categoryId)
            .toList();

    if (categoryAnswers.isEmpty) {
      print('  ❌ NO RETAKE: No answers found for category $categoryId');
      return false; // Tidak ada jawaban, tidak bisa retake
    }

    // Hitung distribusi jawaban
    final answerDistribution = <String, int>{};
    for (final answer in categoryAnswers) {
      final answerValue = answer['answer'] as String;
      answerDistribution[answerValue] =
          (answerDistribution[answerValue] ?? 0) + 1;
    }

    final totalAnswers = categoryAnswers.length;
    final frequentlyCount = answerDistribution['F'] ?? 0;
    final neverCount = answerDistribution['N'] ?? 0;
    final sometimesCount = answerDistribution['P'] ?? 0;
    final littleCount = answerDistribution['L'] ?? 0;

    print('🔍 RETAKE ANALYSIS for category $categoryId:');
    print('  📊 Total answers: $totalAnswers');
    print(
      '  📈 Distribution: N=$neverCount, P=$sometimesCount, L=$littleCount, F=$frequentlyCount',
    );
    print(
      '  📍 Answered levels: ${answeredLevels.length} levels (${answeredLevels.join(', ')})',
    );

    // Debug: Print individual answers untuk troubleshooting
    if (totalAnswers <= 10) {
      // Only for small datasets
      print('  📝 Individual answers:');
      for (int i = 0; i < categoryAnswers.length; i++) {
        final answer = categoryAnswers[i];
        print(
          '    ${i + 1}. Level: ${answer['levelId']}, Answer: ${answer['answer']}, Question: ${answer['questionId']}',
        );
      }
    }

    // ===== LOGIKA RETAKE BERDASARKAN REQUIREMENT =====

    // SPECIAL CASE: Cek apakah SEMUA jawaban adalah F (100% F)
    if (totalAnswers > 0 && frequentlyCount == totalAnswers) {
      print('  🔍 100% F Analysis - checking if more levels available...');

      // Cek apakah masih ada level yang bisa dibuka
      final categoryLevels =
          _levels.entries
              .where((level) => level.value['categoryId'] == categoryId)
              .map(
                (level) => {
                  'id': level.key,
                  'levelNumber': level.value['levelNumber'] ?? 0,
                  'name': level.value['name'] ?? 'Unknown Level',
                },
              )
              .where(
                (level) =>
                    level['levelNumber'] != null && level['levelNumber'] != 0,
              )
              .toList();

      categoryLevels.sort((a, b) {
        final aLevel = a['levelNumber'] as int? ?? 0;
        final bLevel = b['levelNumber'] as int? ?? 0;
        return aLevel.compareTo(bLevel);
      });

      final maxLevelInCategory =
          categoryLevels.isNotEmpty
              ? categoryLevels
                  .map((level) => level['levelNumber'] as int)
                  .reduce((a, b) => a > b ? a : b)
              : 0;

      final maxAnsweredLevel =
          answeredLevels.isEmpty
              ? 0
              : answeredLevels
                  .map((levelId) => _levels[levelId]?['levelNumber'] ?? 0)
                  .reduce((a, b) => a > b ? a : b);

      print('    Max level in category: $maxLevelInCategory');
      print('    Max answered level: $maxAnsweredLevel');

      if (maxAnsweredLevel >= maxLevelInCategory) {
        print(
          '  ❌ NO RETAKE: All levels completed with 100% F - category finished',
        );
        return false; // Semua level selesai dan semua 'F', kategori selesai
      } else {
        print('  ✅ RETAKE: 100% F but more levels available');
        return true; // Masih ada level yang bisa dibuka, bisa retake
      }
    }

    // MAIN LOGIC: Jika BUKAN 100% F, maka selalu bisa retake jika ada jawaban concerning

    // 1. SINGLE ANSWER CRITERIA: Bahkan 1 jawaban non-F bisa trigger retake
    if (totalAnswers == 1) {
      print('  📊 Single answer analysis:');
      print('    Answer: ${categoryAnswers[0]['answer']}');

      // Jika bukan F, bisa retake (karena belum 100% F)
      if (frequentlyCount == 0) {
        print('  ✅ RETAKE: Single non-F answer - not 100% F yet');
        return true;
      }

      // Jika F tapi hanya 1 jawaban, cek apakah masih ada level lain
      if (frequentlyCount == 1) {
        // Cek level tersedia
        final categoryLevels =
            _levels.entries
                .where((level) => level.value['categoryId'] == categoryId)
                .length;

        if (answeredLevels.length < categoryLevels) {
          print('  ✅ RETAKE: Single F but more levels available');
          return true;
        } else {
          print('  ❌ NO RETAKE: Single F and no more levels');
          return false;
        }
      }
    }

    // 2. MULTIPLE ANSWERS: Jika ada campuran jawaban (bukan 100% F)
    if (totalAnswers >= 2) {
      // Jika bukan 100% F, selalu bisa retake
      if (frequentlyCount < totalAnswers) {
        print('  ✅ RETAKE: Not 100% F - mixed answers detected');
        return true;
      }
    }

    // 3. ADDITIONAL CRITERIA: Untuk kasus edge lainnya

    // Jika ada jawaban L (concerning pattern)
    if (littleCount > 0) {
      print('  ✅ RETAKE: Contains L answers (concerning pattern)');
      return true;
    }

    // Mental health categories - lebih sensitif
    final categoryName =
        _categories[categoryId]?['name']?.toString().toLowerCase() ?? '';
    final isMentalHealthCategory =
        categoryName.contains('anxiety') ||
        categoryName.contains('depression') ||
        categoryName.contains('stress') ||
        categoryName.contains('kecemasan') ||
        categoryName.contains('depresi') ||
        categoryName.contains('mental') ||
        categoryName.contains('psikologi');

    if (isMentalHealthCategory && neverCount > 0) {
      print(
        '  ✅ RETAKE: Mental health category with N answers (potential denial)',
      );
      return true;
    }

    // Inconsistent patterns
    if (totalAnswers >= 2 && neverCount > 0 && frequentlyCount > 0) {
      print('  ✅ RETAKE: Inconsistent pattern (N+F mix)');
      return true;
    }

    print('  ❌ NO RETAKE: No retake criteria met for category $categoryId');
    return false;
  }

  // Ultra-sensitive retake check untuk jawaban minimal
  bool _checkUltraSensitiveRetake(
    List<Map<String, dynamic>> categoryAnswers,
    String categoryId,
  ) {
    final totalAnswers = categoryAnswers.length;
    final frequentlyCount =
        categoryAnswers.where((a) => a['answer'] == 'F').length;
    final littleCount = categoryAnswers.where((a) => a['answer'] == 'L').length;
    final neverCount = categoryAnswers.where((a) => a['answer'] == 'N').length;
    final sometimesCount =
        categoryAnswers.where((a) => a['answer'] == 'P').length;

    final categoryName =
        _categories[categoryId]?['name']?.toString().toLowerCase() ?? '';
    final isMentalHealthCategory =
        categoryName.contains('anxiety') ||
        categoryName.contains('depression') ||
        categoryName.contains('stress') ||
        categoryName.contains('kecemasan') ||
        categoryName.contains('depresi') ||
        categoryName.contains('mental') ||
        categoryName.contains('psikologi');

    print('  🔬 Ultra-sensitive analysis:');
    print('    Total answers: $totalAnswers');
    print('    Category: $categoryName');
    print('    Is mental health: $isMentalHealthCategory');
    print(
      '    Distribution: N=$neverCount, P=$sometimesCount, L=$littleCount, F=$frequentlyCount',
    );

    // ===== ULTRA-SENSITIVE CRITERIA =====

    // 1. ANY F answer in minimal responses
    if (frequentlyCount >= 1) {
      print(
        '    🚨 ANY F detected in minimal answers -> ULTRA SENSITIVE RETAKE',
      );
      return true;
    }

    // 2. Mental health categories - lebih sensitif
    if (isMentalHealthCategory) {
      // Bahkan 1 L answer bisa concerning
      if (littleCount >= 1) {
        print(
          '    🚨 L answer in mental health category -> ULTRA SENSITIVE RETAKE',
        );
        return true;
      }

      // N answer dengan konteks - bisa denial
      if (neverCount >= 1 && totalAnswers <= 3) {
        print(
          '    🚨 N answer in mental health (possible denial) -> ULTRA SENSITIVE RETAKE',
        );
        return true;
      }
    }

    // 3. Combinasi answers yang concerning dalam jumlah minimal
    if (totalAnswers >= 2) {
      final concerningCount = frequentlyCount + littleCount;
      final concerningPercentage = (concerningCount / totalAnswers) * 100;

      // Untuk jawaban minimal, threshold lebih rendah
      if (concerningPercentage >= 25) {
        // 25% threshold untuk ultra-sensitive
        print(
          '    🚨 ${concerningPercentage.toStringAsFixed(1)}% concerning in minimal answers -> ULTRA SENSITIVE RETAKE',
        );
        return true;
      }
    }

    // 4. Pattern inconsistency dalam jawaban minimal
    if (totalAnswers >= 2 &&
        neverCount >= 1 &&
        (frequentlyCount >= 1 || littleCount >= 1)) {
      print(
        '    🚨 Inconsistent pattern in minimal answers -> ULTRA SENSITIVE RETAKE',
      );
      return true;
    }

    // 5. Sequential concerning answers
    if (totalAnswers >= 2) {
      // Cek apakah ada sequential F atau L answers
      final sortedAnswers =
          categoryAnswers.toList()..sort(
            (a, b) => (a['timestamp'] as Timestamp? ?? Timestamp.now())
                .compareTo(b['timestamp'] as Timestamp? ?? Timestamp.now()),
          );

      bool hasSequentialConcerning = false;
      for (int i = 0; i < sortedAnswers.length - 1; i++) {
        final current = sortedAnswers[i]['answer'] as String;
        final next = sortedAnswers[i + 1]['answer'] as String;

        if ((current == 'F' || current == 'L') &&
            (next == 'F' || next == 'L')) {
          hasSequentialConcerning = true;
          break;
        }
      }

      if (hasSequentialConcerning) {
        print(
          '    🚨 Sequential concerning answers detected -> ULTRA SENSITIVE RETAKE',
        );
        return true;
      }
    }

    // 6. All answers same (except 'P') dalam jumlah minimal
    if (totalAnswers >= 2) {
      if (frequentlyCount == totalAnswers ||
          littleCount == totalAnswers ||
          neverCount == totalAnswers) {
        print(
          '    🚨 All answers identical (non-P) in minimal response -> ULTRA SENSITIVE RETAKE',
        );
        return true;
      }
    }

    // 7. Rapid deterioration pattern
    if (totalAnswers >= 3) {
      final sortedAnswers =
          categoryAnswers.toList()..sort(
            (a, b) => (a['timestamp'] as Timestamp? ?? Timestamp.now())
                .compareTo(b['timestamp'] as Timestamp? ?? Timestamp.now()),
          );

      // Cek apakah ada pola memburuk: N/P -> L -> F
      final answerValues =
          sortedAnswers.map((a) => a['answer'] as String).toList();

      bool hasDeterioration = false;
      for (int i = 0; i < answerValues.length - 2; i++) {
        if ((answerValues[i] == 'N' || answerValues[i] == 'P') &&
            answerValues[i + 1] == 'L' &&
            answerValues[i + 2] == 'F') {
          hasDeterioration = true;
          break;
        }
      }

      if (hasDeterioration) {
        print(
          '    🚨 Deterioration pattern detected (N/P->L->F) -> ULTRA SENSITIVE RETAKE',
        );
        return true;
      }
    }

    print('    ✅ Passed ultra-sensitive criteria');
    return false;
  }

  // Enhanced progression-based retake check
  bool _checkProgressionBasedRetakeEnhanced(
    String categoryId,
    List<String> answeredLevels,
    List<Map<String, dynamic>> categoryAnswers,
  ) {
    if (answeredLevels.isEmpty) return false;

    // Check if user got stuck on early levels with concerning answers
    final levelStats = <int, Map<String, int>>{};

    for (final answer in categoryAnswers) {
      final levelId = answer['levelId'] as String;
      final answerValue = answer['answer'] as String;
      final levelNumber = _levels[levelId]?['levelNumber'] ?? 0;

      if (levelNumber > 0) {
        levelStats[levelNumber] ??= {'N': 0, 'P': 0, 'L': 0, 'F': 0};
        levelStats[levelNumber]![answerValue] =
            (levelStats[levelNumber]![answerValue] ?? 0) + 1;
      }
    }

    // Check if user is stuck on level 1-2 with high F/L answers
    for (int level = 1; level <= 2; level++) {
      if (levelStats.containsKey(level)) {
        final stats = levelStats[level]!;
        final total = stats.values.reduce((a, b) => a + b);
        final concerningCount = (stats['F'] ?? 0) + (stats['L'] ?? 0);

        if (total > 0 && (concerningCount / total) > 0.5) {
          // Turunkan dari 0.6 ke 0.5
          print(
            '  High concerning answers on early level $level: ${(concerningCount / total * 100).toStringAsFixed(1)}%',
          );
          return true;
        }
      }
    }

    return false;
  }

  // Enhanced single level retake check
  bool _checkSingleLevelRetakePattern(
    List<Map<String, dynamic>> categoryAnswers,
    String levelId,
  ) {
    final levelAnswers =
        categoryAnswers
            .where((answer) => answer['levelId'] == levelId)
            .toList();

    if (levelAnswers.isEmpty) return false;

    final totalAnswers = levelAnswers.length;
    final frequentlyCount =
        levelAnswers.where((a) => a['answer'] == 'F').length;
    final littleCount = levelAnswers.where((a) => a['answer'] == 'L').length;
    final neverCount = levelAnswers.where((a) => a['answer'] == 'N').length;
    final sometimesCount = levelAnswers.where((a) => a['answer'] == 'P').length;

    print('  🔍 Single level analysis for level $levelId:');
    print('    Total answers in this level: $totalAnswers');
    print(
      '    Distribution: N=$neverCount, P=$sometimesCount, L=$littleCount, F=$frequentlyCount',
    );

    // ===== KRITERIA UNTUK SINGLE LEVEL =====

    // 1. Bahkan 1 jawaban F dalam level tunggal bisa trigger retake
    if (frequentlyCount >= 1) {
      print('    ⚠️ Found F answers in single level -> RETAKE NEEDED');
      return true;
    }

    // 2. Mayoritas jawaban L (concerning pattern)
    if (totalAnswers > 0) {
      final littlePercentage = (littleCount / totalAnswers) * 100;
      if (littlePercentage > 50) {
        print(
          '    ⚠️ High L percentage in single level (${littlePercentage.toStringAsFixed(1)}%) -> RETAKE NEEDED',
        );
        return true;
      }
    }

    // 3. Kombinasi L+F yang concerning
    if (totalAnswers > 0) {
      final concerningCount = frequentlyCount + littleCount;
      final concerningPercentage = (concerningCount / totalAnswers) * 100;

      if (concerningPercentage > 40) {
        // Lebih sensitif untuk single level
        print(
          '    ⚠️ High concerning percentage in single level (${concerningPercentage.toStringAsFixed(1)}%) -> RETAKE NEEDED',
        );
        return true;
      }
    }

    // 4. Pola inkonsistensi dalam level tunggal
    if (totalAnswers >= 3 && neverCount > 0 && frequentlyCount > 0) {
      print(
        '    ⚠️ Inconsistent pattern in single level (N+F mix) -> RETAKE NEEDED',
      );
      return true;
    }

    // 5. Single answer criteria untuk level tunggal
    if (totalAnswers == 1) {
      final singleAnswer = levelAnswers[0]['answer'] as String;

      // Single F atau L answer
      if (singleAnswer == 'F' || singleAnswer == 'L') {
        print(
          '    ⚠️ Single concerning answer ($singleAnswer) in level -> RETAKE NEEDED',
        );
        return true;
      }

      // Single N answer bisa concerning untuk kategori mental health
      if (singleAnswer == 'N') {
        // Dapatkan kategori untuk cek konteks
        final categoryAnswer = categoryAnswers.firstWhere(
          (answer) => answer['levelId'] == levelId,
          orElse: () => {'categoryId': ''},
        );
        final categoryId = categoryAnswer['categoryId'] as String;
        final categoryName =
            _categories[categoryId]?['name']?.toString().toLowerCase() ?? '';

        if (categoryName.contains('anxiety') ||
            categoryName.contains('depression') ||
            categoryName.contains('stress') ||
            categoryName.contains('kecemasan') ||
            categoryName.contains('depresi')) {
          print(
            '    ⚠️ Single N answer in mental health level (potential denial) -> RETAKE NEEDED',
          );
          return true;
        }
      }
    }

    // 6. Two answers criteria
    if (totalAnswers == 2) {
      // Jika ada F
      if (frequentlyCount >= 1) {
        print('    ⚠️ Contains F in 2-answer level -> RETAKE NEEDED');
        return true;
      }

      // Jika kedua jawaban L
      if (littleCount == 2) {
        print('    ⚠️ Both answers are L in 2-answer level -> RETAKE NEEDED');
        return true;
      }

      // Jika mix N+L yang concerning
      if (neverCount == 1 && littleCount == 1) {
        print(
          '    ⚠️ N+L mix in 2-answer level (potential inconsistency) -> RETAKE NEEDED',
        );
        return true;
      }
    }

    print('    ✅ Single level passed all retake criteria');
    return false;
  }

  // Enhanced anxiety pattern check
  bool _checkAnxietyRetakePatternEnhanced(List<Map<String, dynamic>> answers) {
    final frequentlyCount = answers.where((a) => a['answer'] == 'F').length;
    final littleCount = answers.where((a) => a['answer'] == 'L').length;
    final totalAnswers = answers.length;

    if (totalAnswers == 0) return false;

    // Anxiety-specific: Jika >30% F atau kombinasi F+L >50% (lebih sensitif)
    final frequentlyPercentage = (frequentlyCount / totalAnswers) * 100;
    final concerningPercentage =
        ((frequentlyCount + littleCount) / totalAnswers) * 100;

    return frequentlyPercentage > 30 ||
        concerningPercentage > 50; // Turunkan threshold
  }

  // Enhanced depression pattern check
  bool _checkDepressionRetakePatternEnhanced(
    List<Map<String, dynamic>> answers,
  ) {
    final frequentlyCount = answers.where((a) => a['answer'] == 'F').length;
    final littleCount = answers.where((a) => a['answer'] == 'L').length;
    final neverCount = answers.where((a) => a['answer'] == 'N').length;
    final totalAnswers = answers.length;

    if (totalAnswers == 0) return false;

    // Depression-specific: Pattern yang menunjukkan inkonsistensi atau deteriorasi
    final concerningCount = frequentlyCount + littleCount;
    final concerningPercentage = (concerningCount / totalAnswers) * 100;

    // Jika kombinasi F+L >40% atau ada pola N+F yang mencurigakan (lebih sensitif)
    if (concerningPercentage > 40) return true; // Turunkan dari 50% ke 40%

    // Pattern inconsistency: Mix of Never dan Frequently
    if (totalAnswers >= 3 && neverCount > 0 && frequentlyCount > 0) {
      // Turunkan dari 5 ke 3
      final inconsistencyRatio = (neverCount + frequentlyCount) / totalAnswers;
      return inconsistencyRatio > 0.5; // Turunkan dari 0.6 ke 0.5
    }

    return false;
  }

  // Enhanced stress pattern check
  bool _checkStressRetakePatternEnhanced(List<Map<String, dynamic>> answers) {
    final frequentlyCount = answers.where((a) => a['answer'] == 'F').length;
    final littleCount = answers.where((a) => a['answer'] == 'L').length;
    final totalAnswers = answers.length;

    if (totalAnswers == 0) return false;

    // Stress-specific: Jika >25% F atau F+L >45% (lebih sensitif)
    final frequentlyPercentage = (frequentlyCount / totalAnswers) * 100;
    final concerningPercentage =
        ((frequentlyCount + littleCount) / totalAnswers) * 100;

    return frequentlyPercentage > 25 ||
        concerningPercentage > 45; // Turunkan threshold
  }

  // FIXED: Helper function untuk mengecek apakah kategori sudah SELESAI SAMPAI MENTOK
  // PENTING: Jika ada kemungkinan retake, kategori TIDAK dianggap selesai
  bool _isCategoryCompletelyFinished(
    String categoryId,
    List<Map<String, dynamic>> categoryLevels,
    List<String> unlockedLevels,
    List<String> answeredLevels,
  ) {
    print('🔍 Checking if category $categoryId is completely finished...');

    // ===== PRIORITAS TERTINGGI: CEK RETAKE DULU =====
    // Jika kategori masih bisa di-retake, maka TIDAK SELESAI
    final canRetake = _canCategoryBeRetaken(categoryId, answeredLevels);
    if (canRetake) {
      print('  🔄 Category $categoryId CAN BE RETAKEN -> NOT FINISHED');
      return false; // Kategori masih bisa di-retake, jadi BELUM selesai
    }

    print('  ✓ No retake available, checking other completion criteria...');

    // ===== VALIDASI DASAR =====

    // 1. Cek apakah ada jawaban sama sekali
    if (answeredLevels.isEmpty) {
      print('  ❌ No answered levels -> NOT FINISHED');
      return false;
    }

    // 2. Semua level yang unlocked harus sudah answered
    for (final unlockedLevelId in unlockedLevels) {
      if (!answeredLevels.contains(unlockedLevelId)) {
        print(
          '  ❌ Unlocked level $unlockedLevelId not answered -> NOT FINISHED',
        );
        return false;
      }
    }

    // 3. Semua level yang answered harus lengkap (semua pertanyaan dijawab)
    for (final answeredLevelId in answeredLevels) {
      final questionsInLevel =
          _questions.entries
              .where(
                (q) =>
                    q.value['levelId'] == answeredLevelId &&
                    q.value['categoryId'] == categoryId,
              )
              .length;

      final answersInLevel =
          _userAnswers
              .where(
                (a) =>
                    a['levelId'] == answeredLevelId &&
                    a['categoryId'] == categoryId,
              )
              .length;

      if (questionsInLevel > answersInLevel) {
        print(
          '  ❌ Level $answeredLevelId has incomplete answers ($answersInLevel/$questionsInLevel) -> NOT FINISHED',
        );
        return false;
      }
    }

    // ===== CEK APAKAH KATEGORI BENAR-BENAR MENTOK =====

    // 4. Hitung level tertinggi yang sudah dijawab
    final maxAnsweredLevel =
        answeredLevels.isEmpty
            ? 0
            : answeredLevels
                .map((levelId) => _levels[levelId]?['levelNumber'] ?? 0)
                .where((levelNum) => levelNum > 0)
                .cast<int>()
                .reduce((a, b) => a > b ? a : b);

    // 5. Hitung level tertinggi yang ada di kategori ini
    final maxLevelInCategory =
        categoryLevels.isNotEmpty
            ? categoryLevels
                .map((level) => level['levelNumber'] as int)
                .reduce((a, b) => a > b ? a : b)
            : 5;

    print('  📊 Level analysis:');
    print('    Max answered level: $maxAnsweredLevel');
    print('    Max level in category: $maxLevelInCategory');
    print('    Total levels in category: ${categoryLevels.length}');

    // 6. Jika sudah mencapai level tertinggi di kategori
    if (maxAnsweredLevel >= maxLevelInCategory) {
      print(
        '  ✅ Category $categoryId FINISHED: Reached max level ($maxAnsweredLevel >= $maxLevelInCategory)',
      );
      return true;
    }

    // 7. Cek apakah level berikutnya tersedia
    final nextLevelNumber = maxAnsweredLevel + 1;
    final nextLevelExists = categoryLevels.any(
      (level) => level['levelNumber'] == nextLevelNumber,
    );

    print('  📍 Next level check:');
    print('    Next level number: $nextLevelNumber');
    print('    Next level exists: $nextLevelExists');

    if (!nextLevelExists) {
      print('  ✅ Category $categoryId FINISHED: No next level exists');
      return true;
    }

    // 8. Jika level berikutnya ada, cek apakah sudah di-unlock
    final nextLevelId =
        categoryLevels
            .where((level) => level['levelNumber'] == nextLevelNumber)
            .map((level) => level['id'] as String)
            .firstOrNull;

    if (nextLevelId != null) {
      final isNextLevelUnlocked = unlockedLevels.contains(nextLevelId);
      print('    Next level ID: $nextLevelId');
      print('    Next level unlocked: $isNextLevelUnlocked');

      if (isNextLevelUnlocked) {
        print(
          '  ❌ Category $categoryId NOT FINISHED: Next level ($nextLevelNumber) is unlocked but not answered',
        );
        return false;
      } else {
        print(
          '  ✅ Category $categoryId FINISHED: Next level ($nextLevelNumber) is locked',
        );
        return true;
      }
    }

    // 9. Default: jika tidak ada kondisi lain yang terpenuhi
    print('  ❌ Category $categoryId NOT FINISHED: Default case');
    return false;
  }

  // ENHANCED: Calculate domain lock status dengan prioritas retake yang jelas
  void _calculateDomainLockStatus() {
    _domainLockStatus.clear();
    _domainProgress.clear();

    for (final domainEntry in _domainResults.entries) {
      final domainId = domainEntry.key;
      final domainResult = domainEntry.value;
      final domainName = domainResult['domain']['name'] as String;
      final categories =
          domainResult['categories'] as Map<String, Map<String, dynamic>>;

      print('\n🔐 === DOMAIN LOCK ANALYSIS: $domainName ===');
      print('Domain ID: $domainId');
      print('Total categories: ${categories.length}');

      int totalCategories = categories.length;
      int completedCategories = 0;
      int startedCategories = 0;
      int retakeableCategories = 0;
      int unlockedButNotStartedCategories = 0;

      List<String> unfinishedCategoryNames = [];
      List<String> retakeableCategoryNames = [];
      List<String> notStartedCategoryNames = [];

      // Detailed analysis per category
      for (final categoryEntry in categories.entries) {
        final categoryId = categoryEntry.key;
        final categoryResult = categoryEntry.value;
        final categoryName = categoryResult['category']['name'] as String;
        final unlockedLevels = categoryResult['unlockedLevels'] as List<String>;
        final answeredLevels = categoryResult['answeredLevels'] as List<String>;

        print('\n  📂 Category: $categoryName (ID: $categoryId)');
        print(
          '    Unlocked levels: ${unlockedLevels.length} -> [${unlockedLevels.join(', ')}]',
        );
        print(
          '    Answered levels: ${answeredLevels.length} -> [${answeredLevels.join(', ')}]',
        );

        // Status analysis
        bool categoryIsStarted =
            unlockedLevels.isNotEmpty || answeredLevels.isNotEmpty;
        bool categoryHasAnswers = answeredLevels.isNotEmpty;

        if (categoryIsStarted) {
          startedCategories++;
          print('    ✅ Status: STARTED');

          if (categoryHasAnswers) {
            // ===== PRIORITAS UTAMA: CHECK RETAKE =====
            final canRetake = _canCategoryBeRetaken(categoryId, answeredLevels);
            if (canRetake) {
              retakeableCategories++;
              retakeableCategoryNames.add(categoryName);
              unfinishedCategoryNames.add(
                categoryName,
              ); // PENTING: Masukkan ke unfinished
              print('    🔄 Retake: AVAILABLE -> Category is UNFINISHED');
            } else {
              print('    ❌ Retake: NOT AVAILABLE');

              // Baru cek completion jika tidak ada retake
              final categoryLevels =
                  _levels.entries
                      .where((level) => level.value['categoryId'] == categoryId)
                      .map(
                        (level) => {
                          'id': level.key,
                          'levelNumber': level.value['levelNumber'] ?? 0,
                          'name': level.value['name'] ?? 'Unknown Level',
                        },
                      )
                      .where(
                        (level) =>
                            level['levelNumber'] != null &&
                            level['levelNumber'] != 0,
                      )
                      .toList();

              categoryLevels.sort((a, b) {
                final aLevel = a['levelNumber'] as int? ?? 0;
                final bLevel = b['levelNumber'] as int? ?? 0;
                return aLevel.compareTo(bLevel);
              });

              bool categoryIsCompleted = _isCategoryCompletelyFinished(
                categoryId,
                categoryLevels,
                unlockedLevels,
                answeredLevels,
              );

              if (categoryIsCompleted) {
                completedCategories++;
                print('    ✅ Completion: FULLY COMPLETED');
              } else {
                unfinishedCategoryNames.add(categoryName);
                print('    ⏳ Completion: IN PROGRESS');
              }
            }
          } else {
            // Category started (unlocked) but no answers yet
            unlockedButNotStartedCategories++;
            notStartedCategoryNames.add(categoryName);
            unfinishedCategoryNames.add(categoryName);
            print('    ⏸️ Status: UNLOCKED BUT NOT ANSWERED');
          }
        } else {
          notStartedCategoryNames.add(categoryName);
          unfinishedCategoryNames.add(categoryName);
          print('    🔒 Status: NOT STARTED (LOCKED)');
        }
      }

      // ===== DECISION LOGIC BERDASARKAN REQUIREMENT =====
      print('\n  📊 DOMAIN SUMMARY:');
      print('    Total categories: $totalCategories');
      print('    Started categories: $startedCategories');
      print('    Completed categories: $completedCategories');
      print('    🔄 Retakeable categories: $retakeableCategories');
      print(
        '    ⏸️ Unlocked but not started: $unlockedButNotStartedCategories',
      );
      print('    ❌ Unfinished categories: ${unfinishedCategoryNames.length}');

      // MAIN LOGIC: Domain terkunci HANYA jika TIDAK ADA retake yang bisa dilakukan
      bool isDomainLocked = true; // Default: locked

      // Domain TIDAK TERKUNCI jika ada retake (walaupun 1 jawaban saja)
      if (retakeableCategories > 0) {
        isDomainLocked = false;
        print(
          '    🔓 DOMAIN UNLOCKED: Ada $retakeableCategories kategori yang bisa di-retake',
        );
      }
      // Domain TIDAK TERKUNCI jika masih ada kategori unlocked tapi belum dikerjakan
      else if (unlockedButNotStartedCategories > 0) {
        isDomainLocked = false;
        print(
          '    🔓 DOMAIN UNLOCKED: Ada $unlockedButNotStartedCategories kategori yang belum dikerjakan',
        );
      }
      // Domain TIDAK TERKUNCI jika masih ada kategori yang belum selesai
      else if (completedCategories < totalCategories) {
        isDomainLocked = false;
        print(
          '    🔓 DOMAIN UNLOCKED: Masih ada kategori yang belum selesai ($completedCategories/$totalCategories)',
        );
      }
      // Domain TERKUNCI jika semua selesai dan tidak ada retake
      else {
        isDomainLocked = true;
        print(
          '    🔒 DOMAIN LOCKED: Semua kategori selesai dan tidak ada retake yang bisa dilakukan',
        );
      }

      // Calculate pending activity
      bool hasPendingActivity = !isDomainLocked;

      _domainLockStatus[domainId] = isDomainLocked;
      _domainProgress[domainId] = {
        'totalCategories': totalCategories,
        'completedCategories': completedCategories,
        'startedCategories': startedCategories,
        'retakeableCategories': retakeableCategories,
        'unlockedButNotStartedCategories': unlockedButNotStartedCategories,
        'unfinishedCategories': unfinishedCategoryNames,
        'retakeableCategoryNames': retakeableCategoryNames,
        'notStartedCategoryNames': notStartedCategoryNames,
        'progressPercentage':
            totalCategories > 0
                ? (completedCategories / totalCategories * 100).round()
                : 0,
        'hasPendingActivity': hasPendingActivity,
      };

      print('\n  🎯 FINAL DECISION:');
      print('    Domain locked: ${isDomainLocked ? '🔒 YES' : '🔓 NO'}');
      print(
        '    Has pending activity: ${hasPendingActivity ? '✅ YES' : '❌ NO'}',
      );
      print(
        '    Progress: $completedCategories/$totalCategories (${_domainProgress[domainId]!['progressPercentage']}%)',
      );

      if (retakeableCategories > 0) {
        print(
          '    🔄 RETAKEABLE CATEGORIES: ${retakeableCategoryNames.join(', ')}',
        );
        print('    🔓 DOMAIN ACCESSIBLE: Masih ada yang bisa di-retake');
      }

      if (unlockedButNotStartedCategories > 0) {
        print(
          '    ⏸️ UNLOCKED BUT NOT STARTED: ${notStartedCategoryNames.join(', ')}',
        );
      }

      if (unfinishedCategoryNames.isNotEmpty) {
        print(
          '    ❌ UNFINISHED CATEGORIES: ${unfinishedCategoryNames.join(', ')}',
        );
      }

      print('  ========================================');
    }
  }

  // Enhanced method untuk memastikan domain accessible
  bool isDomainAccessible(String domainId) {
    final progress = _domainProgress[domainId];
    if (progress == null) {
      print('🔍 Domain $domainId: No progress data -> DEFAULT ACCESSIBLE');
      return true; // Default allow access if no data
    }

    final retakeableCount = progress['retakeableCategories'] as int;
    final hasPendingActivity = progress['hasPendingActivity'] as bool;

    // PRIORITAS: Jika ada retake, domain PASTI accessible
    if (retakeableCount > 0) {
      print(
        '🔍 Domain $domainId: ACCESSIBLE because $retakeableCount retakeable categories',
      );
      return true;
    }

    // Fallback ke pending activity
    final accessible =
        hasPendingActivity ||
        progress['unlockedButNotStartedCategories'] > 0 ||
        progress['completedCategories'] < progress['totalCategories'];

    print(
      '🔍 Domain $domainId: ${accessible ? 'ACCESSIBLE' : 'LOCKED'} based on pending activity',
    );
    return accessible;
  }

  // Get domain status configuration untuk UI
  Map<String, dynamic> _getDomainStatusConfig(
    DomainStatus status,
    Map<String, dynamic> progress,
  ) {
    switch (status) {
      case DomainStatus.hasRetake:
        return {
          'gradientColors': [Colors.orange.shade50, Colors.orange.shade100],
          'borderColor': Colors.orange.withOpacity(0.3),
          'borderWidth': 2.0,
          'shadowColor': Colors.orange.withOpacity(0.15),
          'iconColor': Colors.orange.shade600,
          'textColor': Colors.orange.shade700,
          'icon': Icons.refresh_rounded,
          'statusText': 'ADA RETAKE',
          'subtitleText':
              '${progress['retakeableCategories']} kategori bisa di-retake',
        };
      case DomainStatus.hasUnlocked:
        return {
          'gradientColors': [Colors.blue.shade50, Colors.blue.shade100],
          'borderColor': Colors.blue.withOpacity(0.3),
          'borderWidth': 2.0,
          'shadowColor': Colors.blue.withOpacity(0.15),
          'iconColor': _primaryBlue,
          'textColor': _primaryBlue,
          'icon': Icons.play_circle_filled_rounded,
          'statusText': 'TERSEDIA',
          'subtitleText':
              '${progress['unlockedButNotStartedCategories']} kategori siap dikerjakan',
        };
      case DomainStatus.inProgress:
        return {
          'gradientColors': _cardGradient,
          'borderColor': _primaryBlue.withOpacity(0.3),
          'borderWidth': 1.0,
          'shadowColor': _primaryBlue.withOpacity(0.08),
          'iconColor': _primaryBlue,
          'textColor': _textPrimary,
          'icon': Icons.trending_up_rounded,
          'statusText': 'DALAM PROGRESS',
          'subtitleText': 'Tap untuk melanjutkan',
        };
      case DomainStatus.completed:
        return {
          'gradientColors': [Colors.green.shade50, Colors.green.shade100],
          'borderColor': Colors.green.withOpacity(0.3),
          'borderWidth': 2.0,
          'shadowColor': Colors.green.withOpacity(0.15),
          'iconColor': Colors.green.shade600,
          'textColor': Colors.green.shade700,
          'icon': Icons.check_circle_rounded,
          'statusText': 'SELESAI',
          'subtitleText': 'Domain sudah diselesaikan 100%',
        };
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : _primaryBlue,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final domainService = DomainService();
    final authService = AuthService();
    final user = authService.getCurrentUser();

    if (user == null) {
      return const LoginScreen();
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildEnhancedHeader(),
            Expanded(child: _buildContent(domainService)),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isTablet = screenWidth > 600;
    final headerHeight = (isTablet ? 180.0 : 160.0) + statusBarHeight;

    return Container(
      width: double.infinity,
      height: headerHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _darkBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background patterns
          ...List.generate(4, (index) {
            return Positioned(
              top: statusBarHeight + 20 + (index * 30),
              right: 20 + (index * 35),
              child: Container(
                width: 35 + (index * 12),
                height: 35 + (index * 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05 + (index * 0.02)),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
            );
          }),

          // Header content with status bar padding
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 20,
              statusBarHeight + (isTablet ? 24 : 20),
              isTablet ? 24 : 20,
              isTablet ? 24 : 20,
            ),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Daftar Domain',
                        style: TextStyle(
                          fontSize: isTablet ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: _darkBlue.withOpacity(0.5),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih domain untuk memulai kuisioner',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Loading indicator untuk lock data
                if (_isLoadingLockData)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(DomainService domainService) {
    return StreamBuilder<List<DomainModel>>(
      stream: domainService.getDomains(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return _buildLoadingState();
        }

        final domains = snapshot.data!;

        if (domains.isEmpty) {
          return _buildEmptyState();
        }

        return _buildDomainList(domains);
      },
    );
  }

  Widget _buildLoadingState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_primaryBlue, _lightBlue]),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: isTablet ? 4 : 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Memuat daftar domain...',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final maxWidth = isTablet ? 400.0 : double.infinity;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: EdgeInsets.all(isTablet ? 32 : 20),
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _cardGradient),
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red.shade600,
                size: isTablet ? 36 : 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gagal memuat daftar domain',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {}); // Trigger rebuild to retry
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32 : 24,
                  vertical: isTablet ? 16 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final maxWidth = isTablet ? 400.0 : double.infinity;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: EdgeInsets.all(isTablet ? 32 : 20),
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _cardGradient),
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_primaryBlue, _lightBlue]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_outlined,
                color: Colors.white,
                size: isTablet ? 48 : 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Domain',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada domain yang tersedia.\nSilakan hubungi administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: _textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDomainList(List<DomainModel> domains) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Calculate grid properties based on screen size
    int crossAxisCount = 1;
    if (isDesktop) {
      crossAxisCount = 3;
    } else if (isTablet) {
      crossAxisCount = 2;
    }

    final horizontalPadding = isTablet ? 32.0 : 20.0;

    if (crossAxisCount == 1) {
      // Mobile: Use ListView for single column
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          bottomPadding + 16,
        ),
        physics: const BouncingScrollPhysics(),
        itemCount: domains.length,
        itemBuilder: (context, index) {
          final domain = domains[index];
          return _buildDomainCard(domain, index);
        },
      );
    } else {
      // Tablet/Desktop: Use GridView for multiple columns
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          bottomPadding + 16,
        ),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: isDesktop ? 1.8 : 2.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: domains.length,
        itemBuilder: (context, index) {
          final domain = domains[index];
          return _buildDomainCard(domain, index);
        },
      );
    }
  }

  Widget _buildDomainCard(DomainModel domain, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Get detailed progress dan status untuk domain ini
    final progress =
        _domainProgress[domain.id] ??
        {
          'totalCategories': 0,
          'completedCategories': 0,
          'startedCategories': 0,
          'retakeableCategories': 0,
          'unlockedButNotStartedCategories': 0,
          'progressPercentage': 0,
          'unfinishedCategories': <String>[],
          'retakeableCategoryNames': <String>[],
          'notStartedCategoryNames': <String>[],
          'hasPendingActivity': false,
        };

    // ENHANCED: Determine domain status dengan PRIORITAS RETAKE
    final retakeableCount = progress['retakeableCategories'] as int;
    final unlockedButNotStarted =
        progress['unlockedButNotStartedCategories'] as int;
    final completedCount = progress['completedCategories'] as int;
    final totalCount = progress['totalCategories'] as int;
    final retakeableCategoryNames =
        progress['retakeableCategoryNames'] as List<String>;

    // PRIORITAS STATUS:
    // 1. Ada retake (TERTINGGI) -> Domain PASTI bisa diakses
    // 2. Ada unlocked tapi belum dikerjakan -> Domain bisa diakses
    // 3. Masih progress -> Domain bisa diakses
    // 4. Completed -> Domain locked (tapi masih bisa masuk untuk lihat hasil)

    DomainStatus domainStatus;
    bool isDomainAccessible = true; // Default: selalu bisa diakses

    if (retakeableCount > 0) {
      domainStatus = DomainStatus.hasRetake;
      isDomainAccessible = true; // PASTI bisa diakses
      print(
        '🔓 Domain ${domain.name}: ACCESSIBLE - Has $retakeableCount retakeable categories',
      );
    } else if (unlockedButNotStarted > 0) {
      domainStatus = DomainStatus.hasUnlocked;
      isDomainAccessible = true;
      print(
        '🔓 Domain ${domain.name}: ACCESSIBLE - Has $unlockedButNotStarted unlocked categories',
      );
    } else if (completedCount < totalCount) {
      domainStatus = DomainStatus.inProgress;
      isDomainAccessible = true;
      print(
        '🔓 Domain ${domain.name}: ACCESSIBLE - In progress ($completedCount/$totalCount)',
      );
    } else {
      domainStatus = DomainStatus.completed;
      isDomainAccessible = true; // Tetap bisa diakses untuk melihat hasil
      print(
        '✅ Domain ${domain.name}: COMPLETED - But still accessible to view results',
      );
    }

    // Get status-specific UI properties
    final statusConfig = _getDomainStatusConfig(domainStatus, progress);

    return Container(
      margin: EdgeInsets.only(bottom: isTablet && screenWidth <= 900 ? 0 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: statusConfig['gradientColors'],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(
          color: statusConfig['borderColor'],
          width: statusConfig['borderWidth'],
        ),
        boxShadow: [
          BoxShadow(
            color: statusConfig['shadowColor'],
            blurRadius: 25,
            offset: const Offset(0, 12),
            spreadRadius: 3,
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 20,
            offset: const Offset(-8, -8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();

            // DEBUG: Print current status
            print('\n🎯 Domain card tapped: ${domain.name}');
            print('   Status: $domainStatus');
            print('   Retakeable count: $retakeableCount');
            print('   Unlocked but not started: $unlockedButNotStarted');
            print('   Is accessible: $isDomainAccessible');

            // ENHANCED LOGIC: Selalu bisa masuk, tapi beda handling
            if (domainStatus == DomainStatus.hasRetake) {
              // Ada kategori yang bisa di-retake
              print('   Action: Show retake dialog then navigate');
              _showDomainRetakeDialog(domain.name, progress, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryListPage(domainId: domain.id),
                  ),
                );
              });
            } else if (domainStatus == DomainStatus.hasUnlocked) {
              // Ada kategori yang unlocked tapi belum dikerjakan
              print('   Action: Show unlocked categories dialog then navigate');
              _showDomainUnlockedDialog(domain.name, progress, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryListPage(domainId: domain.id),
                  ),
                );
              });
            } else if (domainStatus == DomainStatus.completed) {
              // Domain completed, tapi masih bisa masuk untuk melihat hasil
              print('   Action: Show completion dialog with option to view');
              _showDomainCompletedDialog(domain.name, progress, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryListPage(domainId: domain.id),
                  ),
                );
              });
            } else {
              // Domain dalam progress normal
              print('   Action: Navigate directly');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryListPage(domainId: domain.id),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(_cardRadius),
          splashColor: statusConfig['iconColor'].withOpacity(0.1),
          highlightColor: statusConfig['iconColor'].withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: _buildMobileCardContent(
              domain,
              isTablet,
              statusConfig,
              progress,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCardContent(
    DomainModel domain,
    bool isTablet,
    Map<String, dynamic> statusConfig,
    Map<String, dynamic> progress,
  ) {
    return Column(
      children: [
        Row(
          children: [
            // Domain icon
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusConfig['iconColor'],
                    statusConfig['iconColor'].withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: statusConfig['iconColor'].withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                statusConfig['icon'],
                color: Colors.white,
                size: isTablet ? 32 : 28,
              ),
            ),
            const SizedBox(width: 20),

            // Domain info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          domain.name,
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: statusConfig['textColor'],
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusConfig['iconColor'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusConfig['iconColor'].withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          statusConfig['statusText'],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusConfig['iconColor'],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusConfig['subtitleText'],
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: statusConfig['textColor'].withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow atau indicator
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusConfig['iconColor'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: isTablet ? 18 : 16,
                color: statusConfig['iconColor'],
              ),
            ),
          ],
        ),

        // Progress bar dan info
        if (!_isLoadingLockData && progress['totalCategories'] > 0) ...[
          const SizedBox(height: 16),
          Column(
            children: [
              // Progress bar
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: statusConfig['iconColor'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: progress['progressPercentage'] as int,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusConfig['iconColor'],
                              statusConfig['iconColor'].withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 100 - (progress['progressPercentage'] as int),
                      child: Container(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Progress text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress['completedCategories']}/${progress['totalCategories']} kategori',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusConfig['textColor'].withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${progress['progressPercentage']}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusConfig['iconColor'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Dialog khusus untuk domain dengan retake
  void _showDomainRetakeDialog(
    String domainName,
    Map<String, dynamic> progress,
    VoidCallback onNavigate,
  ) {
    final retakeableCategoryNames =
        progress['retakeableCategoryNames'] as List<String>;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, const Color(0xFFFAFBFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade600],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Ada Kategori yang Bisa Di-retake!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Domain "$domainName" memiliki ${retakeableCategoryNames.length} kategori yang bisa di-retake atau belom di kerjakan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: _textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Daftar kategori retake
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kategori yang bisa di-retake:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...retakeableCategoryNames.map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 16,
                                color: Colors.orange.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Action buttons
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade600, Colors.orange.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      onNavigate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Masuk untuk Retake',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Nanti Saja',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Dialog untuk kategori unlocked
  void _showDomainUnlockedDialog(
    String domainName,
    Map<String, dynamic> progress,
    VoidCallback onNavigate,
  ) {
    final unlockedCount = progress['unlockedButNotStartedCategories'] as int;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, const Color(0xFFFAFBFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryBlue, _lightBlue],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryBlue.withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.play_circle_filled_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Ada Kategori Siap Dikerjakan!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Domain "$domainName" memiliki $unlockedCount kategori yang sudah terbuka dan siap untuk dikerjakan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: _textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryBlue, _lightBlue],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryBlue.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      onNavigate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Mulai Mengerjakan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Nanti Saja',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Dialog untuk domain completed
  void _showDomainCompletedDialog(
    String domainName,
    Map<String, dynamic> progress,
    VoidCallback onNavigate,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, const Color(0xFFFAFBFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Domain Selesai!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Selamat! Anda telah menyelesaikan semua kuesioner di domain "$domainName".',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: _textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
