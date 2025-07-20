import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tools/admin/screens/user/domain_list_page.dart';
import 'package:tools/admin/screens/user/profil_page.dart';
import 'package:tools/admin/screens/user/result_page.dart';
import 'package:tools/auth/auth_service.dart';
import 'package:tools/auth/login_screen.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  List<Widget> _screens = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Data untuk validasi kuesioner
  Map<String, Map<String, dynamic>> _domains = {};
  Map<String, Map<String, dynamic>> _categories = {};
  Map<String, Map<String, dynamic>> _levels = {};
  Map<String, Map<String, dynamic>> _questions = {};
  List<Map<String, dynamic>> _userAnswers = [];
  Map<String, Map<String, dynamic>> _domainResults = {};
  bool _isLoadingQuestionnaireData = true;

  // Stream subscriptions untuk realtime data
  List<StreamSubscription> _streamSubscriptions = [];

  // Enhanced Modern Blue Theme (consistent with UserDashboard)
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _darkBlue = Color(0xFF1565C0);
  static const Color _lightBlue = Color(0xFF42A5F5);
  static const Color _accentBlue = Color(0xFF64B5F6);
  static const Color _ultraLightBlue = Color(0xFF90CAF9);
  static const Color _backgroundColor = Color(0xFFF8FAFF);
  static const Color _surfaceColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _shadowColor = Color(0xFF2196F3);

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
  static const double _basePadding = 20.0;

  @override
  void initState() {
    super.initState();
    _screens = [const SizedBox(), const ProfilePage()];

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    _setupRealtimeQuestionnaireData();
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

  // Setup realtime listeners untuk semua data kuesioner
  void _setupRealtimeQuestionnaireData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingQuestionnaireData = true;
    });

    final firestore = FirebaseFirestore.instance;

    print('🚀 Setting up realtime questionnaire listeners...');

    // 1. Listen to domains (realtime)
    final domainsSubscription = firestore
        .collection('domains')
        .where('isHidden', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            print('🔄 Domains updated: ${snapshot.docs.length} documents');
            _domains.clear();
            for (var doc in snapshot.docs) {
              _domains[doc.id] = {
                'id': doc.id,
                'name': doc.data()['name'] ?? 'Domain ${doc.id}',
                'isHidden': doc.data()['isHidden'] ?? false,
              };
            }
            _processQuestionnaireData();
          },
          onError: (error) {
            print('❌ Error listening to domains: $error');
            if (mounted) {
              _showSnackBar('Error loading domains: $error', isError: true);
            }
          },
        );
    _streamSubscriptions.add(domainsSubscription);

    // 2. Listen to categories (realtime)
    final categoriesSubscription = firestore
        .collection('categories')
        .snapshots()
        .listen(
          (snapshot) {
            print('🔄 Categories updated: ${snapshot.docs.length} documents');
            _categories.clear();
            for (var doc in snapshot.docs) {
              _categories[doc.id] = {
                'id': doc.id,
                'name': doc.data()['name'] ?? 'Category ${doc.id}',
                'domainId': doc.data()['domainId'] ?? '',
              };
            }
            _processQuestionnaireData();
          },
          onError: (error) {
            print('❌ Error listening to categories: $error');
            if (mounted) {
              _showSnackBar('Error loading categories: $error', isError: true);
            }
          },
        );
    _streamSubscriptions.add(categoriesSubscription);

    // 3. Listen to levels (realtime)
    final levelsSubscription = firestore
        .collection('levels')
        .snapshots()
        .listen(
          (snapshot) {
            print('🔄 Levels updated: ${snapshot.docs.length} documents');
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
            _processQuestionnaireData();
          },
          onError: (error) {
            print('❌ Error listening to levels: $error');
            if (mounted) {
              _showSnackBar('Error loading levels: $error', isError: true);
            }
          },
        );
    _streamSubscriptions.add(levelsSubscription);

    // 4. Listen to questions (realtime)
    final questionsSubscription = firestore
        .collection('questions')
        .snapshots()
        .listen(
          (snapshot) {
            print('🔄 Questions updated: ${snapshot.docs.length} documents');
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
            _processQuestionnaireData();
          },
          onError: (error) {
            print('❌ Error listening to questions: $error');
            if (mounted) {
              _showSnackBar('Error loading questions: $error', isError: true);
            }
          },
        );
    _streamSubscriptions.add(questionsSubscription);

    // 5. Listen to user answers (realtime)
    final answersSubscription = firestore
        .collection('users')
        .doc(user.uid)
        .collection('answers')
        .snapshots()
        .listen(
          (snapshot) {
            print(
              '🔄 🎯 User answers updated: ${snapshot.docs.length} documents',
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

            print('📊 Total answers now: ${_userAnswers.length}');
            _processQuestionnaireData();
          },
          onError: (error) {
            print('❌ Error listening to user answers: $error');
            if (mounted) {
              _showSnackBar('Error loading answers: $error', isError: true);
            }
          },
        );
    _streamSubscriptions.add(answersSubscription);

    // 6. Listen to user categories progress (realtime)
    final userCategoriesSubscription = firestore
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .snapshots()
        .listen(
          (snapshot) {
            print(
              '🔄 📈 User categories updated: ${snapshot.docs.length} documents',
            );
            _processUserCategories(snapshot.docs);
          },
          onError: (error) {
            print('❌ Error listening to user categories: $error');
            if (mounted) {
              _showSnackBar(
                'Error loading user progress: $error',
                isError: true,
              );
            }
          },
        );
    _streamSubscriptions.add(userCategoriesSubscription);
  }

  // Process user categories data
  void _processUserCategories(List<QueryDocumentSnapshot> docs) {
    print('🔄 Processing user categories...');

    // Clear existing user category data in domain results
    for (final domainResult in _domainResults.values) {
      final categories =
          domainResult['categories'] as Map<String, Map<String, dynamic>>;
      for (final categoryResult in categories.values) {
        categoryResult['unlockedLevels'] = <String>[];
        categoryResult['answeredLevels'] = <String>[];
      }
    }

    // Process new user category data
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

      print(
        '  Category $categoryId: ${unlockedLevels.length} unlocked, ${answeredLevels.length} answered',
      );

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

    _processQuestionnaireData();
  }

  // Process semua data kuesioner setelah ada update
  void _processQuestionnaireData() {
    // Hanya process jika semua data dasar sudah ada
    if (_domains.isEmpty ||
        _categories.isEmpty ||
        _levels.isEmpty ||
        _questions.isEmpty) {
      print('⏳ Waiting for all basic data to load...');
      print('  Domains: ${_domains.length}, Categories: ${_categories.length}');
      print('  Levels: ${_levels.length}, Questions: ${_questions.length}');
      return;
    }

    print('🔄 Processing questionnaire data...');
    print('  Domains: ${_domains.length}, Categories: ${_categories.length}');
    print('  Levels: ${_levels.length}, Questions: ${_questions.length}');
    print('  User Answers: ${_userAnswers.length}');

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

      // Update UI
      if (mounted) {
        setState(() {
          _isLoadingQuestionnaireData = false;
        });
        print('✅ UI Updated - Loading: false');
      }

      print('✅ Questionnaire data processed successfully');
    } catch (e) {
      print('❌ Error processing questionnaire data: $e');
      if (mounted) {
        setState(() {
          _isLoadingQuestionnaireData = false;
        });
        _showSnackBar('Error processing data: $e', isError: true);
      }
    }
  }

  // Initialize domain results structure
  void _initializeDomainResults() {
    print('🏗️ Initializing domain results...');
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

    print('🏗️ Domain results initialized: ${_domainResults.length} domains');
  }

  // Update domain results dengan data terbaru
  void _updateDomainResults() {
    // Update category info with latest data
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
    print('📊 Processing answer statistics...');

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
    int processedAnswers = 0;
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

      processedAnswers++;
    }

    print('📊 Processed $processedAnswers answers for statistics');
  }

  // Calculate current levels untuk setiap kategori
  void _calculateCurrentLevels() {
    print('🎯 Calculating current levels...');

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

    print('🎯 Current levels calculated');
  }

  // Validasi yang diperbaiki - SEMUA kategori di SEMUA domain harus selesai
  Map<String, dynamic> _validateQuestionnaireAccess() {
    print('\n=== 🔍 VALIDASI AKSES HASIL KUESIONER (REALTIME) ===');

    if (_isLoadingQuestionnaireData) {
      print('⏳ Still loading questionnaire data...');
      return {
        'canAccess': false,
        'message': 'Sedang memuat data kuesioner...',
        'isLoading': true,
      };
    }

    // Cek apakah ada jawaban sama sekali
    final totalAnswers = _userAnswers.length;
    if (totalAnswers == 0) {
      print('❌ AKSES DITOLAK: Tidak ada jawaban sama sekali');
      return {
        'canAccess': false,
        'message':
            'Anda belum mengisi kuesioner sama sekali.\n\nSilakan mulai mengisi kuesioner terlebih dahulu.',
        'isLoading': false,
      };
    }

    print('✓ Total jawaban ditemukan: $totalAnswers (REALTIME)');

    List<String> unfinishedCategories = [];
    List<String> notStartedCategories = [];

    // Cek SEMUA domain dan SEMUA kategori
    for (final domainEntry in _domainResults.entries) {
      final domainId = domainEntry.key;
      final domainResult = domainEntry.value;
      final domainName = domainResult['domain']['name'] as String;
      final categories =
          domainResult['categories'] as Map<String, Map<String, dynamic>>;

      print('\n--- Validasi Domain: $domainName (REALTIME) ---');

      for (final categoryEntry in categories.entries) {
        final categoryId = categoryEntry.key;
        final categoryResult = categoryEntry.value;
        final categoryName = categoryResult['category']['name'] as String;
        final unlockedLevels = categoryResult['unlockedLevels'] as List<String>;
        final answeredLevels = categoryResult['answeredLevels'] as List<String>;

        print('Kategori: $categoryName');
        print('  Unlocked levels: ${unlockedLevels.length}');
        print('  Answered levels: ${answeredLevels.length}');

        // SEMUA kategori harus diselesaikan, tidak boleh ada yang kosong/belum mulai
        if (unlockedLevels.isEmpty && answeredLevels.isEmpty) {
          print('  ❌ Kategori belum dimulai sama sekali');
          notStartedCategories.add('$categoryName (Domain: $domainName)');
          continue;
        }

        // Jika kategori sudah dimulai, harus SELESAI sampai tidak bisa dilanjutkan
        bool categoryIsStarted =
            unlockedLevels.isNotEmpty || answeredLevels.isNotEmpty;

        if (categoryIsStarted) {
          print('  🟡 Kategori sudah dimulai - validasi kelengkapan');

          // Dapatkan semua level untuk kategori ini
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

          print('  Total levels dalam kategori: ${categoryLevels.length}');

          // Cek apakah kategori sudah SELESAI SAMPAI TIDAK BISA DILANJUTKAN
          bool categoryIsCompletelyFinished = _isCategoryCompletelyFinished(
            categoryId,
            categoryLevels,
            unlockedLevels,
            answeredLevels,
          );

          if (!categoryIsCompletelyFinished) {
            print('  ❌ Kategori belum selesai semua');
            unfinishedCategories.add('$categoryName (Domain: $domainName)');
          } else {
            print('  ✅ Kategori sudah selesai semua');
          }
        }
      }
    }

    // Jika ada kategori yang belum dimulai
    if (notStartedCategories.isNotEmpty) {
      final categoryText = notStartedCategories.take(5).join('\n• ');
      final moreText =
          notStartedCategories.length > 5
              ? '\n• Dan ${notStartedCategories.length - 5} kategori lainnya...'
              : '';

      print(
        '\n❌ AKSES DITOLAK: Ada ${notStartedCategories.length} kategori belum dimulai',
      );
      return {
        'canAccess': false,
        'message':
            'Masih ada kategori yang belum dimulai:\n\n• $categoryText$moreText\n\n'
            'Silakan mulai dan selesaikan SEMUA kategori kuesioner untuk melihat hasil.',
        'isLoading': false,
      };
    }

    // Jika ada kategori yang sudah dimulai tapi belum selesai semua
    if (unfinishedCategories.isNotEmpty) {
      final categoryText = unfinishedCategories.take(5).join('\n• ');
      final moreText =
          unfinishedCategories.length > 5
              ? '\n• Dan ${unfinishedCategories.length - 5} kategori lainnya...'
              : '';

      print(
        '\n❌ AKSES DITOLAK: Ada ${unfinishedCategories.length} kategori belum selesai',
      );
      return {
        'canAccess': false,
        'message':
            'Beberapa kategori kuesioner belum diselesaikan semua:\n\n• $categoryText$moreText\n\n'
            'Silakan selesaikan SEMUA kategori hingga tidak dapat dilanjutkan lagi untuk melihat hasil.',
        'isLoading': false,
      };
    }

    print(
      '\n✅ AKSES DIIZINKAN: SEMUA kategori di SEMUA domain sudah selesai (REALTIME)',
    );
    return {
      'canAccess': true,
      'message':
          'Semua kategori kuesioner sudah diselesaikan! Anda dapat melihat hasil lengkap.',
      'isLoading': false,
    };
  }

  // Helper function untuk mengecek apakah kategori sudah SELESAI SEMUA
  bool _isCategoryCompletelyFinished(
    String categoryId,
    List<Map<String, dynamic>> categoryLevels,
    List<String> unlockedLevels,
    List<String> answeredLevels,
  ) {
    print('    Cek status SELESAI untuk kategori:');

    // 1. WAJIB: Semua level yang unlocked harus sudah answered
    for (final unlockedLevelId in unlockedLevels) {
      if (!answeredLevels.contains(unlockedLevelId)) {
        print('    ❌ Level unlocked belum dijawab: $unlockedLevelId');
        return false;
      }
    }
    print('    ✓ Semua unlocked levels sudah dijawab');

    // 2. WAJIB: Semua level yang answered harus lengkap (semua pertanyaan dijawab)
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
          '    ❌ Level answered tidak lengkap: $answeredLevelId ($answersInLevel/$questionsInLevel)',
        );
        return false;
      }
    }
    print('    ✓ Semua answered levels lengkap');

    // 3. WAJIB: Kategori harus benar-benar selesai semua (tidak bisa dilanjutkan)
    final maxLevelInCategory =
        categoryLevels.isNotEmpty
            ? categoryLevels
                .map((level) => level['levelNumber'] as int)
                .reduce((a, b) => a > b ? a : b)
            : 5;

    final maxAnsweredLevel =
        answeredLevels.isEmpty
            ? 0
            : answeredLevels
                .map((levelId) => _levels[levelId]?['levelNumber'] ?? 0)
                .where((levelNum) => levelNum != null)
                .cast<int>()
                .reduce((a, b) => a > b ? a : b);

    print('    Max level tersedia dalam kategori: $maxLevelInCategory');
    print('    Max level yang sudah dijawab: $maxAnsweredLevel');

    // Skenario A: Sudah mencapai level maksimal yang tersedia
    if (maxAnsweredLevel >= maxLevelInCategory) {
      print(
        '    ✅ Kategori selesai: Sudah mencapai level maksimal ($maxLevelInCategory)',
      );
      return true;
    }

    // Skenario B: Progress berhenti di tengah (level berikutnya tidak ter-unlock)
    final nextLevelNumber = maxAnsweredLevel + 1;
    final nextLevelExists = categoryLevels.any(
      (level) => level['levelNumber'] == nextLevelNumber,
    );

    if (nextLevelExists) {
      final nextLevelId =
          categoryLevels
              .where((level) => level['levelNumber'] == nextLevelNumber)
              .map((level) => level['id'] as String)
              .firstOrNull;

      if (nextLevelId != null && !unlockedLevels.contains(nextLevelId)) {
        print(
          '    ✅ Kategori selesai: Level $nextLevelNumber ada tapi tidak ter-unlock (progress terhenti)',
        );
        return true;
      } else if (nextLevelId != null && unlockedLevels.contains(nextLevelId)) {
        print(
          '    ❌ Kategori belum selesai: Level $nextLevelNumber masih ter-unlock, harus diselesaikan',
        );
        return false;
      }
    }

    // Skenario C: Jika tidak ada level berikutnya sama sekali, berarti sudah mencapai akhir
    if (!nextLevelExists && maxAnsweredLevel > 0) {
      print(
        '    ✅ Kategori selesai: Tidak ada level berikutnya, sudah mencapai akhir',
      );
      return true;
    }

    print(
      '    ❌ Kategori belum selesai: Masih bisa dilanjutkan atau ada level yang belum diselesaikan',
    );
    return false;
  }

  void _showQuestionnaireAccessDialog() {
    final validation = _validateQuestionnaireAccess();

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
                color: _primaryBlue.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _darkBlue.withOpacity(0.15),
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
                      colors:
                          validation['canAccess']
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : validation['isLoading']
                              ? [_primaryBlue, _lightBlue]
                              : [
                                Colors.orange.shade400,
                                Colors.orange.shade600,
                              ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (validation['canAccess']
                                ? Colors.green
                                : validation['isLoading']
                                ? _primaryBlue
                                : Colors.orange)
                            .withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    validation['isLoading']
                        ? Icons.hourglass_empty_rounded
                        : validation['canAccess']
                        ? Icons.check_circle
                        : Icons.warning_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  validation['isLoading']
                      ? 'Memuat Data...'
                      : validation['canAccess']
                      ? 'Kuesioner Lengkap!'
                      : 'Kuesioner Belum Lengkap',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: SingleChildScrollView(
                    child: Text(
                      validation['message'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: _textSecondary,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _textSecondary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: _textSecondary,
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!validation['canAccess'] &&
                        !validation['isLoading']) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_darkBlue, _primaryBlue, _lightBlue],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
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
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DomainListPage(),
                                ),
                              );
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
                              'Isi Kuesioner',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (validation['canAccess']) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade600,
                                Colors.green.shade400,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
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
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ResultPage(),
                                ),
                              );
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
                              'Lihat Hasil',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    final authService = AuthService();
    final user = authService.getCurrentUser();

    if (user == null) return const LoginScreen();

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
      builder: (context, snapshot) {
        String userName = user.displayName ?? user.email!.split('@')[0];
        String? profileImageBase64;
        bool isLoadingProfile = true;

        // Check profile completeness
        bool isProfileComplete = true;
        String? phoneNumber;
        String? companyName;
        String? workUnit;

        if (snapshot.connectionState == ConnectionState.waiting) {
          isLoadingProfile = true;
        } else if (snapshot.hasError) {
          print('Error loading profile: ${snapshot.error}');
          _showSnackBar('Gagal memuat profil', isError: true);
        } else if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          userName = data['displayName'] ?? user.email!.split('@')[0];
          profileImageBase64 = data['photoBase64'];
          phoneNumber = data['phoneNumber'];
          companyName = data['companyName'];
          workUnit = data['workUnit'];
          isLoadingProfile = false;

          // Check if profile is complete
          isProfileComplete =
              phoneNumber != null &&
              companyName != null &&
              workUnit != null &&
              phoneNumber!.trim().isNotEmpty &&
              companyName!.trim().isNotEmpty &&
              workUnit!.trim().isNotEmpty;
        } else {
          isLoadingProfile = false;
          isProfileComplete = false;
        }

        _screens[0] = _buildHomeScreen(
          context,
          userName,
          profileImageBase64,
          isLoadingProfile,
          isProfileComplete,
        );

        return Scaffold(
          backgroundColor: _backgroundColor,
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: _screens[_currentIndex],
          ),
          bottomNavigationBar: _buildEnhancedBottomNavBar(),
        );
      },
    );
  }

  Widget _buildEnhancedBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _shadowColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEnhancedNavItem(0, Icons.home_rounded, 'Beranda'),
              _buildEnhancedNavItem(1, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color:
              isSelected ? _primaryBlue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              isSelected
                  ? Border.all(color: _primaryBlue.withOpacity(0.2))
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryBlue : _textSecondary,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: _primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHomeScreen(
    BuildContext context,
    String userName,
    String? profileImageBase64,
    bool isLoadingProfile,
    bool isProfileComplete,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        final padding = isMobile ? 20.0 : (isTablet ? 24.0 : 32.0);
        final fontScale = isMobile ? 0.9 : (isTablet ? 1.0 : 1.1);
        final headerHeight = isMobile ? 280.0 : (isTablet ? 300.0 : 320.0);

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildEnhancedHeader(
                context,
                userName,
                profileImageBase64,
                isLoadingProfile,
                headerHeight,
                padding,
                fontScale,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile completion notification
                    if (!isProfileComplete) ...[
                      _buildProfileNotification(context, fontScale, isMobile),
                      const SizedBox(height: 24),
                    ],
                    _buildEnhancedSectionTitle('Menu Utama'),
                    const SizedBox(height: 24),
                    _buildEnhancedMenuCards(
                      context,
                      fontScale,
                      isMobile,
                      isTablet,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileNotification(
    BuildContext context,
    double fontScale,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(0.1),
            const Color(0xFFFBBF24).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = 1); // Switch to Profile tab
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: isMobile ? 24 : 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lengkapi Profil Anda',
                        style: TextStyle(
                          fontSize: 16 * fontScale,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Beberapa informasi profil Anda belum lengkap. Tap untuk melengkapi data.',
                        style: TextStyle(
                          fontSize: 13 * fontScale,
                          color: const Color(0xFFA16207),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedHeader(
    BuildContext context,
    String userName,
    String? profileImageBase64,
    bool isLoadingProfile,
    double headerHeight,
    double padding,
    double fontScale,
  ) {
    return Container(
      width: double.infinity,
      height: headerHeight,
      child: Stack(
        children: [
          // Enhanced gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _gradientColors,
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // Simple background patterns (no animation)
          ...List.generate(3, (index) {
            return Positioned(
              top: 50 + (index * 40),
              right: 20 + (index * 60),
              child: Container(
                width: 60 + (index * 20),
                height: 60 + (index * 20),
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

          // Enhanced wave background
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              painter: EnhancedWavePainter(),
              size: Size(MediaQuery.of(context).size.width, 120),
            ),
          ),

          // Main content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Enhanced profile avatar
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.9),
                                  Colors.white.withOpacity(0.6),
                                  Colors.white.withOpacity(0.9),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: _darkBlue.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [_lightBlue, _accentBlue],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 28 * fontScale,
                                backgroundColor: Colors.white,
                                backgroundImage:
                                    profileImageBase64 != null
                                        ? MemoryImage(
                                          base64Decode(profileImageBase64),
                                        )
                                        : null,
                                child:
                                    isLoadingProfile
                                        ? CircularProgressIndicator(
                                          color: _primaryBlue,
                                          strokeWidth: 2,
                                        )
                                        : (profileImageBase64 == null
                                            ? Text(
                                              userName.isNotEmpty
                                                  ? userName[0].toUpperCase()
                                                  : 'U',
                                              style: TextStyle(
                                                color: _primaryBlue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 22 * fontScale,
                                              ),
                                            )
                                            : null),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreeting(),
                                style: TextStyle(
                                  fontSize: 15 * fontScale,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 22 * fontScale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: _darkBlue.withOpacity(0.5),
                                      offset: const Offset(0, 2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Enhanced logout button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap:
                              () =>
                                  _showEnhancedLogoutDialog(context, fontScale),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.25),
                                  Colors.white.withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 22 * fontScale,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Enhanced date and time card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: _darkBlue.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.white,
                            size: 18 * fontScale,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getCurrentDate(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14 * fontScale,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Container(
                          height: 25 * fontScale,
                          width: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.6),
                                Colors.white.withOpacity(0.2),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.access_time_rounded,
                            color: Colors.white,
                            size: 18 * fontScale,
                          ),
                        ),
                        const SizedBox(width: 12),
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (context, snapshot) {
                            return Text(
                              _getCurrentTime(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14 * fontScale,
                                letterSpacing: 0.3,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSectionTitle(String title) {
    return Row(
      children: [
        Container(
          height: 28,
          width: 5,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_darkBlue, _primaryBlue, _lightBlue],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedMenuCards(
    BuildContext context,
    double fontScale,
    bool isMobile,
    bool isTablet,
  ) {
    final validation = _validateQuestionnaireAccess();
    final canAccessResults = validation['canAccess'] as bool;
    final isLoadingResults = validation['isLoading'] as bool;

    return Column(
      children: [
        _buildEnhancedMenuCard(
          context,
          icon: Icons.business_rounded,
          title: 'Audit',
          subtitle: 'Audit Sekarang',
          iconGradient: [_primaryBlue, _lightBlue],
          backgroundGradient: [
            _primaryBlue.withOpacity(0.05),
            Colors.transparent,
          ],
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DomainListPage()),
            );
          },
          fontScale: fontScale,
          isMobile: isMobile,
          isEnabled: true,
        ),
        SizedBox(height: isMobile ? 16 : 20),
        _buildEnhancedMenuCard(
          context,
          icon:
              isLoadingResults
                  ? Icons.hourglass_empty_rounded
                  : (canAccessResults
                      ? Icons.analytics_rounded
                      : Icons.analytics_outlined),
          title: 'Hasil Kuesioner',
          subtitle:
              isLoadingResults
                  ? 'Memuat data kuesioner...'
                  : (canAccessResults
                      ? 'Analisis hasil dan laporan terkini'
                      : 'Selesaikan semua kuesioner untuk melihat hasil'),
          iconGradient:
              canAccessResults
                  ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                  : [Colors.grey.shade500, Colors.grey.shade400],
          backgroundGradient:
              canAccessResults
                  ? [
                    const Color(0xFF10B981).withOpacity(0.05),
                    Colors.transparent,
                  ]
                  : [Colors.grey.withOpacity(0.05), Colors.transparent],
          onTap: () {
            HapticFeedback.lightImpact();
            if (canAccessResults) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ResultPage()),
              );
            } else {
              _showQuestionnaireAccessDialog();
            }
          },
          fontScale: fontScale,
          isMobile: isMobile,
          isEnabled: !isLoadingResults,
          showLockIcon: !canAccessResults && !isLoadingResults,
        ),
      ],
    );
  }

  Widget _buildEnhancedMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> iconGradient,
    required List<Color> backgroundGradient,
    required VoidCallback onTap,
    required double fontScale,
    required bool isMobile,
    bool isEnabled = true,
    bool showLockIcon = false,
  }) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.7,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _cardGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(
            color: iconGradient[0].withOpacity(isEnabled ? 0.1 : 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: iconGradient[0].withOpacity(isEnabled ? 0.08 : 0.04),
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
        child: Stack(
          children: [
            // Background gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: backgroundGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(_cardRadius),
              ),
            ),

            // Main content
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isEnabled ? onTap : null,
                borderRadius: BorderRadius.circular(_cardRadius),
                splashColor: iconGradient[0].withOpacity(0.1),
                highlightColor: iconGradient[0].withOpacity(0.05),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 20 : 24),
                  child: Row(
                    children: [
                      // Enhanced icon container
                      Container(
                        padding: EdgeInsets.all(isMobile ? 16 : 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: iconGradient),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow:
                              isEnabled
                                  ? [
                                    BoxShadow(
                                      color: iconGradient[0].withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                      spreadRadius: 2,
                                    ),
                                    BoxShadow(
                                      color: iconGradient[1].withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                  : [],
                        ),
                        child: Icon(
                          icon,
                          size: isMobile ? 30 : 34,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 19 * fontScale,
                                      fontWeight: FontWeight.bold,
                                      color: _textPrimary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                if (showLockIcon)
                                  Icon(
                                    Icons.lock_outline,
                                    size: 20,
                                    color: Colors.grey.shade500,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14 * fontScale,
                                color: _textSecondary,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Enhanced arrow button
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              iconGradient[0].withOpacity(0.1),
                              iconGradient[1].withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: iconGradient[0].withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          showLockIcon
                              ? Icons.info_outline
                              : Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: iconGradient[0],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEnhancedLogoutDialog(BuildContext context, double fontScale) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
                color: _primaryBlue.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _darkBlue.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 20,
                  offset: const Offset(-10, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Enhanced logout icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade400,
                        Colors.red.shade600,
                        Colors.red.shade700,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.red.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Keluar dari Aplikasi?',
                  style: TextStyle(
                    fontSize: 24 * fontScale,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Anda akan keluar dari akun ini dan perlu login kembali untuk mengakses aplikasi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15 * fontScale,
                    color: _textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),

                // Enhanced buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _textSecondary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: _textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 16 * fontScale,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_darkBlue, _primaryBlue, _lightBlue],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
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
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
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
                          child: Text(
                            'Keluar',
                            style: TextStyle(
                              fontSize: 16 * fontScale,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Selamat Pagi';
    } else if (hour < 15) {
      return 'Selamat Siang';
    } else if (hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

// Simplified Wave Painter for better performance
class EnhancedWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // First wave layer
    Paint paint1 =
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.4);
    path1.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.2,
      size.width * 0.6,
      size.height * 0.35,
    );
    path1.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.5,
      size.width,
      size.height * 0.4,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Second wave layer
    Paint paint2 =
        Paint()
          ..color = Colors.white.withOpacity(0.15)
          ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.6);
    path2.quadraticBezierTo(
      size.width * 0.25,
      size.width * 0.4,
      size.width * 0.5,
      size.height * 0.55,
    );
    path2.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.7,
      size.width,
      size.height * 0.6,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);

    // Third wave layer
    Paint paint3 =
        Paint()
          ..color = const Color(0xFF64B5F6).withOpacity(0.2)
          ..style = PaintingStyle.fill;

    final path3 = Path();
    path3.moveTo(0, size.height * 0.8);
    path3.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.6,
      size.width * 0.7,
      size.height * 0.75,
    );
    path3.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.9,
      size.width,
      size.height * 0.8,
    );
    path3.lineTo(size.width, size.height);
    path3.lineTo(0, size.height);
    path3.close();
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
