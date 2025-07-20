import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tools/auth/login_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/* 
TAMBAHKAN DEPENDENCIES BERIKUT KE pubspec.yaml:

dependencies:
  pdf: ^3.10.4
  printing: ^5.11.0
  path_provider: ^2.1.1
  fl_chart: ^0.40.0

Untuk Android, tambahkan permission di android/app/src/main/AndroidManifest.xml:
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
*/

// Model untuk Level Detail
class UserLevelDetail {
  final int levelNumber;
  final String levelName;
  final bool isCompleted;
  final double progress;
  final int questionsAnswered;
  final int totalQuestions;

  UserLevelDetail({
    required this.levelNumber,
    required this.levelName,
    required this.isCompleted,
    required this.progress,
    required this.questionsAnswered,
    required this.totalQuestions,
  });
}

// Model untuk Progress Kategori
class UserCategoryProgress {
  final String categoryId;
  final String categoryName;
  final List<UserLevelDetail> levelDetails;
  final double progressPercentage;
  final int currentLevel;
  final Map<String, int> stats;

  UserCategoryProgress({
    required this.categoryId,
    required this.categoryName,
    required this.levelDetails,
    required this.progressPercentage,
    required this.currentLevel,
    required this.stats,
  });

  List<int> get completedLevels =>
      levelDetails
          .where((level) => level.isCompleted)
          .map((level) => level.levelNumber)
          .toList();
}

// Model untuk Progress Domain
class UserDomainProgress {
  final String domainId;
  final String domainName;
  final List<UserCategoryProgress> categories;
  final double overallProgress;
  final int currentLevel;
  final Map<String, int> stats;

  UserDomainProgress({
    required this.domainId,
    required this.domainName,
    required this.categories,
    required this.overallProgress,
    required this.currentLevel,
    required this.stats,
  });
}

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _errorMessage;

  // Data structures
  Map<String, Map<String, dynamic>> _domains = {};
  Map<String, Map<String, dynamic>> _categories = {};
  Map<String, Map<String, dynamic>> _levels = {};
  Map<String, Map<String, dynamic>> _questions = {};
  List<Map<String, dynamic>> _userAnswers = [];

  // Processed data
  List<UserDomainProgress> _domainProgressList = [];
  Map<String, int> _overallStats = {'N': 0, 'P': 0, 'L': 0, 'F': 0};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Theme Constants (menggunakan desain admin)
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color darkBlue = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFF42A5F5);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color shadowColor = Color(0x14336DFB);
  static const Color borderColor = Color(0x4D2196F3);

  static final List<Color> gradientColors = [darkBlue, primaryBlue, lightBlue];

  static Color getProgressColor(double progress) {
    if (progress < 0.3) return Colors.red.shade700;
    if (progress < 0.7) return Colors.orange.shade600;
    return Colors.green.shade700;
  }

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadAllData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Silakan login untuk melihat hasil kuesioner';
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    try {
      // Pastikan dokumen user ada
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Load domains
      final domainsSnapshot =
          await _firestore
              .collection('domains')
              .where('isHidden', isEqualTo: false)
              .get();
      for (var doc in domainsSnapshot.docs) {
        _domains[doc.id] = {
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Domain ${doc.id}',
          'isHidden': doc.data()['isHidden'] ?? false,
        };
      }

      // Load categories
      final categoriesSnapshot =
          await _firestore.collection('categories').get();
      for (var doc in categoriesSnapshot.docs) {
        _categories[doc.id] = {
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Category ${doc.id}',
          'domainId': doc.data()['domainId'] ?? '',
        };
      }

      // Load levels
      final levelsSnapshot = await _firestore.collection('levels').get();
      for (var doc in levelsSnapshot.docs) {
        _levels[doc.id] = {
          'id': doc.id,
          'levelNumber': doc.data()['levelNumber'] ?? 0,
          'name':
              doc.data()['name'] ??
              'Level ${doc.data()['levelNumber'] ?? doc.id}',
          'categoryId': doc.data()['categoryId'] ?? '',
        };
      }

      // Load questions
      final questionsSnapshot = await _firestore.collection('questions').get();
      for (var doc in questionsSnapshot.docs) {
        final data = doc.data();
        _questions[doc.id] = {
          'id': doc.id,
          'levelId': data['levelId'] ?? '',
          'categoryId': data['categoryId'] ?? '',
          'text': data['text'] ?? 'Pertanyaan ${doc.id}',
        };
      }

      // Load user answers
      final answersSnapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('answers')
              .get();
      _userAnswers =
          answersSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'questionId': data['questionId'] ?? '',
              'levelId': data['levelId'] ?? '',
              'categoryId': data['categoryId'] ?? '',
              'answer': data['answer'] ?? '',
            };
          }).toList();

      // Process data
      _processUserProgress();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data: $e';
      });
      _showSnackBar('Gagal memuat hasil: $e', isError: true);
    }
  }

  void _processUserProgress() {
    _domainProgressList.clear();
    _overallStats = {'N': 0, 'P': 0, 'L': 0, 'F': 0};

    // Count overall stats
    for (final answer in _userAnswers) {
      final answerValue = answer['answer'] as String;
      if (['N', 'P', 'L', 'F'].contains(answerValue)) {
        _overallStats[answerValue] = (_overallStats[answerValue] ?? 0) + 1;
      }
    }

    // Group categories by domain
    Map<String, List<String>> categoriesByDomain = {};
    _categories.forEach((categoryId, categoryData) {
      final domainId = categoryData['domainId'] as String;
      if (!categoriesByDomain.containsKey(domainId)) {
        categoriesByDomain[domainId] = [];
      }
      categoriesByDomain[domainId]!.add(categoryId);
    });

    // Process each domain
    for (String domainId in _domains.keys) {
      List<UserCategoryProgress> categoryProgressList = [];
      final domainCategories = categoriesByDomain[domainId] ?? [];

      for (String categoryId in domainCategories) {
        // Get user answers for this category
        final categoryAnswers =
            _userAnswers
                .where((answer) => answer['categoryId'] == categoryId)
                .toList();

        // Determine current level for this category
        int currentLevel = 0;
        for (final answer in categoryAnswers) {
          final levelId = answer['levelId'] as String;
          if (_levels.containsKey(levelId)) {
            final levelNumber = _levels[levelId]!['levelNumber'] as int;
            if (levelNumber > currentLevel) currentLevel = levelNumber;
          }
        }

        // Build level details for levels 1-5
        List<UserLevelDetail> levelDetails = [];
        Map<String, int> categoryStats = {'N': 0, 'P': 0, 'L': 0, 'F': 0};

        for (int i = 1; i <= 5; i++) {
          // Find level ID for this level number in this category
          String? levelId;
          String levelName = 'Level $i';

          for (var entry in _levels.entries) {
            if (entry.value['categoryId'] == categoryId &&
                entry.value['levelNumber'] == i) {
              levelId = entry.key;
              levelName = entry.value['name'] ?? 'Level $i';
              break;
            }
          }

          // Count questions and answers for this level
          int totalQuestions = 0;
          int questionsAnswered = 0;
          bool isCompleted = false;
          double progress = 0.0;

          if (levelId != null) {
            // Count total questions for this level
            totalQuestions =
                _questions.entries
                    .where((q) => q.value['levelId'] == levelId)
                    .length;

            // Count answered questions
            final levelAnswers =
                categoryAnswers
                    .where((answer) => answer['levelId'] == levelId)
                    .toList();
            questionsAnswered = levelAnswers.length;

            // Calculate progress
            if (totalQuestions > 0) {
              progress = (questionsAnswered / totalQuestions) * 100.0;
              isCompleted =
                  questionsAnswered == totalQuestions && i <= currentLevel;
            }

            // Count answer types
            for (final answer in levelAnswers) {
              final answerValue = answer['answer'] as String;
              if (['N', 'P', 'L', 'F'].contains(answerValue)) {
                categoryStats[answerValue] =
                    (categoryStats[answerValue] ?? 0) + 1;
              }
            }
          }

          levelDetails.add(
            UserLevelDetail(
              levelNumber: i,
              levelName: levelName,
              isCompleted: isCompleted,
              progress: progress.clamp(0.0, 100.0),
              questionsAnswered: questionsAnswered,
              totalQuestions: totalQuestions,
            ),
          );
        }

        // Calculate category progress
        final totalProgress = levelDetails
            .map((l) => l.progress)
            .reduce((a, b) => a + b);
        final categoryProgressPercentage = totalProgress / 5.0;

        categoryProgressList.add(
          UserCategoryProgress(
            categoryId: categoryId,
            categoryName: _categories[categoryId]!['name'],
            levelDetails: levelDetails,
            progressPercentage: categoryProgressPercentage,
            currentLevel: currentLevel,
            stats: categoryStats,
          ),
        );
      }

      // Calculate domain progress
      final domainOverallProgress =
          categoryProgressList.isEmpty
              ? 0.0
              : categoryProgressList
                      .map((e) => e.progressPercentage)
                      .reduce((a, b) => a + b) /
                  categoryProgressList.length;

      // Calculate domain stats
      Map<String, int> domainStats = {'N': 0, 'P': 0, 'L': 0, 'F': 0};
      int maxLevel = 0;
      for (final category in categoryProgressList) {
        if (category.currentLevel > maxLevel) maxLevel = category.currentLevel;
        category.stats.forEach((key, value) {
          domainStats[key] = (domainStats[key] ?? 0) + value;
        });
      }

      _domainProgressList.add(
        UserDomainProgress(
          domainId: domainId,
          domainName: _domains[domainId]!['name'],
          categories: categoryProgressList,
          overallProgress: domainOverallProgress,
          currentLevel: maxLevel,
          stats: domainStats,
        ),
      );
    }
  }

  bool _canExportPDF() {
    final totalAnswers = _overallStats.values.fold(
      0,
      (sum, count) => sum + count,
    );
    if (totalAnswers == 0) return false;

    for (final domain in _domainProgressList) {
      for (final category in domain.categories) {
        if (category.currentLevel == 0) return false;

        int requiredQuestions = 0;
        for (int level = 1; level <= category.currentLevel; level++) {
          final levelDetail = category.levelDetails.firstWhere(
            (l) => l.levelNumber == level,
            orElse:
                () => UserLevelDetail(
                  levelNumber: level,
                  levelName: 'Level $level',
                  isCompleted: false,
                  progress: 0.0,
                  questionsAnswered: 0,
                  totalQuestions: 0,
                ),
          );
          requiredQuestions += levelDetail.totalQuestions;
        }

        final answeredQuestions = category.stats.values.fold(
          0,
          (sum, count) => sum + count,
        );
        if (answeredQuestions < requiredQuestions) return false;
      }
    }

    return true;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : darkBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final user = _auth.currentUser;
        if (user == null) return const LoginScreen();

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: _buildSimpleAppBar(isMobile),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildMainView(isMobile),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildSimpleAppBar(bool isMobile) {
    final canExport = _canExportPDF();

    return AppBar(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_rounded,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Hasil Kuesioner',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'Lihat hasil kuesioner Anda',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      titleSpacing: 0,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => _loadAllData(),
        ),
        IconButton(
          icon: Icon(
            canExport ? Icons.download_rounded : Icons.lock_outline,
            color: Colors.white,
            size: 20,
          ),
          onPressed: canExport ? _exportReport : _showExportBlockedDialog,
        ),
      ],
    );
  }

  Widget _buildMainView(bool isMobile) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState(isMobile);
    }

    final totalAnswers = _overallStats.values.fold(
      0,
      (sum, count) => sum + count,
    );
    if (totalAnswers == 0) {
      return _buildEmptyState(isMobile);
    }

    return Padding(
      padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
      child: _buildDomainsList(isMobile),
    );
  }

  Widget _buildDomainsList(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 16),
      child: ListView.builder(
        itemCount: _domainProgressList.length,
        itemBuilder:
            (context, index) =>
                _buildDomainCard(_domainProgressList[index], isMobile),
      ),
    );
  }

  Widget _buildDomainCard(UserDomainProgress domain, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: shadowColor, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.business, color: Colors.white),
        ),
        title: Text(
          domain.domainName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: getProgressColor(domain.overallProgress / 100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Level ${domain.currentLevel} - ${domain.overallProgress.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children:
            domain.categories
                .map((category) => _buildCategoryTile(category, isMobile))
                .toList(),
      ),
    );
  }

  Widget _buildCategoryTile(UserCategoryProgress category, bool isMobile) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, lightBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.category,
                    color: Colors.white,
                    size: isMobile ? 14 : 18,
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.categoryName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 13 : 16,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${category.progressPercentage.toStringAsFixed(1)}% Complete',
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: isMobile ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: getProgressColor(category.progressPercentage / 100),
                    borderRadius: BorderRadius.circular(isMobile ? 15 : 20),
                  ),
                  child: Text(
                    '${category.completedLevels.length}/5',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 11 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 12 : 20),

          // Level progress with connecting lines
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryBlue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level Progress (1-5):',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Level indicators with connecting lines
                _buildLevelProgressWithLines(category, isMobile),

                const SizedBox(height: 12),
                Text(
                  category.completedLevels.isNotEmpty
                      ? 'Completed levels: ${category.completedLevels.join(', ')}'
                      : 'No levels completed yet',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    color: textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelProgressWithLines(
    UserCategoryProgress category,
    bool isMobile,
  ) {
    return Stack(
      children: [
        // Connecting lines background
        Positioned.fill(
          child: CustomPaint(
            painter: LevelConnectionPainter(category.levelDetails),
          ),
        ),
        // Level indicators
        Row(
          children: [
            for (int i = 1; i <= 5; i++) ...[
              Expanded(child: _buildLevelIndicator(category, i, isMobile)),
              if (i < 5) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLevelIndicator(
    UserCategoryProgress category,
    int levelNum,
    bool isMobile,
  ) {
    final levelDetail = category.levelDetails.firstWhere(
      (level) => level.levelNumber == levelNum,
      orElse:
          () => UserLevelDetail(
            levelNumber: levelNum,
            levelName: 'Level $levelNum',
            isCompleted: false,
            progress: 0.0,
            questionsAnswered: 0,
            totalQuestions: 0,
          ),
    );

    Color backgroundColor;
    Color textColor;
    Color borderColor;

    if (levelDetail.isCompleted) {
      backgroundColor = Colors.green.shade600;
      textColor = Colors.white;
      borderColor = Colors.green.shade700;
    } else if (levelDetail.progress > 0) {
      backgroundColor = Colors.orange.shade600;
      textColor = Colors.white;
      borderColor = Colors.orange.shade700;
    } else {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.black;
      borderColor = Colors.grey.shade400;
    }

    return Column(
      children: [
        Container(
          width: isMobile ? 50 : 60,
          height: isMobile ? 50 : 60,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$levelNum',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                '${levelDetail.progress.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: isMobile ? 8 : 9,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          levelDetail.isCompleted
              ? 'COMPLETED'
              : levelDetail.progress > 0
              ? 'IN PROGRESS'
              : 'PENDING',
          style: TextStyle(
            fontSize: isMobile ? 8 : 9,
            fontWeight: FontWeight.bold,
            color: borderColor,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text('Error: $_errorMessage'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllData,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryBlue, lightBlue]),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.quiz_outlined,
              color: Colors.white,
              size: isMobile ? 40 : 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum Ada Hasil',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Anda belum mengisi kuesioner.\nSilakan mulai kuesioner terlebih dahulu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showExportBlockedDialog() {
    final message = _getExportValidationMessage();

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
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height *
                  0.8, // Limit dialog height
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, const Color(0xFFFAFBFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.orange.withOpacity(0.1),
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
                  padding: const EdgeInsets.all(20),
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
                  child: const Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'PDF Tidak Dapat Diekspor',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                Flexible(
                  // Use Flexible instead of Container with constraints
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondary,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: textSecondary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Tutup',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade600,
                              Colors.orange.shade400,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
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
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context);
                            _debugExportValidation();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Lihat Detail',
                            style: TextStyle(
                              fontSize: 14,
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

  // Method untuk refresh data
  void _refreshData() {
    HapticFeedback.lightImpact();
    _loadAllData();
    _showSnackBar('Data diperbarui');
  }

  // Method debug export validation
  void _debugExportValidation() {
    print('\n=== DEBUG EXPORT VALIDATION ===');

    final canExport = _canExportPDF();
    final message = _getExportValidationMessage();

    // Tampilkan detail di dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                canExport ? Icons.check_circle : Icons.error,
                color: canExport ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Debug Export Validation')),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(
              maxHeight: 400,
            ), // Add height constraint
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:
                    MainAxisSize.min, // Important: prevent infinite height
                children: [
                  Text(
                    'Status: ${canExport ? "BISA EXPORT" : "TIDAK BISA EXPORT"}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: canExport ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Detail:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lihat console untuk log detail.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
            if (canExport)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _exportReport();
                },
                child: const Text('Export PDF'),
              ),
          ],
        );
      },
    );
  }

  // Method untuk mendapatkan detail masalah export
  String _getExportValidationMessage() {
    final totalAnswers = _overallStats.values.fold(
      0,
      (sum, count) => sum + count,
    );
    if (totalAnswers == 0) {
      return 'Belum ada jawaban yang tersimpan. Silakan mulai mengisi kuesioner.';
    }

    List<String> problems = [];

    for (final domain in _domainProgressList) {
      for (final category in domain.categories) {
        if (category.currentLevel == 0) {
          problems.add(
            '❌ Kategori "${category.categoryName}" (Domain: ${domain.domainName}) belum dimulai',
          );
          continue;
        }

        // Hitung pertanyaan wajib
        int requiredQuestions = 0;
        for (int level = 1; level <= category.currentLevel; level++) {
          final levelDetail = category.levelDetails.firstWhere(
            (l) => l.levelNumber == level,
            orElse:
                () => UserLevelDetail(
                  levelNumber: level,
                  levelName: 'Level $level',
                  isCompleted: false,
                  progress: 0.0,
                  questionsAnswered: 0,
                  totalQuestions: 0,
                ),
          );
          requiredQuestions += levelDetail.totalQuestions;
        }

        final answeredQuestions = category.stats.values.fold(
          0,
          (sum, count) => sum + count,
        );

        if (answeredQuestions < requiredQuestions) {
          problems.add(
            '❌ Kategori "${category.categoryName}" (Domain: ${domain.domainName}):\n'
            '   Level terbuka: 1-${category.currentLevel}\n'
            '   Pertanyaan wajib: $requiredQuestions\n'
            '   Sudah dijawab: $answeredQuestions\n'
            '   Kurang: ${requiredQuestions - answeredQuestions} jawaban',
          );
        }
      }
    }

    if (problems.isNotEmpty) {
      return 'Ada kategori yang belum lengkap:\n\n${problems.take(2).join('\n\n')}${problems.length > 2 ? '\n\nDan ${problems.length - 2} masalah lainnya...' : ''}\n\nSilakan lengkapi semua pertanyaan di level yang sudah terbuka.';
    }

    return 'Semua kategori sudah lengkap!';
  }

  Future<void> _exportReport() async {
    try {
      if (!_canExportPDF()) {
        _showSnackBar('Ada kategori yang belum lengkap', isError: true);
        return;
      }

      _showSnackBar('Membuat laporan PDF...');

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context ctx) {
            return [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(darkBlue.value),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HASIL KUESIONER',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      _auth.currentUser?.email ?? 'Unknown User',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 16),
                    ),
                    pw.Text(
                      DateTime.now().toString().split(' ')[0],
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Overall Progress Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColor.fromInt(primaryBlue.value),
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            '${(_domainProgressList.fold(0.0, (sum, domain) => sum + domain.overallProgress) / _domainProgressList.length.clamp(1, double.infinity)).toStringAsFixed(1)}%',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(primaryBlue.value),
                            ),
                          ),
                          pw.Text('Overall Progress'),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            '${_domainProgressList.length}',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(primaryBlue.value),
                            ),
                          ),
                          pw.Text('Total Domains'),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            '${DateTime.now().day}/${DateTime.now().month}',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(primaryBlue.value),
                            ),
                          ),
                          pw.Text('Export Date'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Domain Progress Title
              pw.Text(
                'DETAIL PROGRESS PER DOMAIN',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(primaryBlue.value),
                ),
              ),
              pw.SizedBox(height: 12),

              // Domain Progress Details
              ..._domainProgressList.map(
                (domain) => _buildDomainSectionPDF(domain),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'Progress_Report_${_auth.currentUser?.email?.replaceAll('@', '_').replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}',
      );

      _showSnackBar('Laporan PDF berhasil dibuat!');
    } catch (e) {
      _showSnackBar('Gagal membuat PDF: $e', isError: true);
    }
  }

  pw.Widget _buildDomainSectionPDF(UserDomainProgress domain) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Domain Header
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(primaryBlue.value),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    domain.domainName,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  '${domain.overallProgress.toStringAsFixed(1)}%',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Categories
          ...domain.categories.map(
            (category) => _buildCategorySectionPDF(category),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCategorySectionPDF(UserCategoryProgress category) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Category Header
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(primaryBlue.value),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    category.categoryName,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    '${category.completedLevels.length}/5',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(primaryBlue.value),
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Level Progress with connecting lines
          pw.Text(
            'Level Progress (1-5):',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),

          // Level indicators with lines
          _buildLevelProgressWithLinesPDF(category),

          pw.SizedBox(height: 12),
          // Summary
          pw.Text(
            category.completedLevels.isNotEmpty
                ? 'Completed levels: ${category.completedLevels.join(', ')}'
                : 'No levels completed yet',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildLevelProgressWithLinesPDF(UserCategoryProgress category) {
    return pw.Column(
      children: [
        // Level indicators
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            for (int i = 1; i <= 5; i++) ...[
              _buildCircularLevelIndicatorPDF(category, i),
              if (i < 5) _buildConnectionLinePDF(category, i),
            ],
          ],
        ),
      ],
    );
  }

  pw.Widget _buildConnectionLinePDF(
    UserCategoryProgress category,
    int currentLevel,
  ) {
    // Get current and next level details
    final current = category.levelDetails.firstWhere(
      (level) => level.levelNumber == currentLevel,
      orElse:
          () => UserLevelDetail(
            levelNumber: currentLevel,
            levelName: 'Level $currentLevel',
            isCompleted: false,
            progress: 0.0,
            questionsAnswered: 0,
            totalQuestions: 0,
          ),
    );

    final next = category.levelDetails.firstWhere(
      (level) => level.levelNumber == currentLevel + 1,
      orElse:
          () => UserLevelDetail(
            levelNumber: currentLevel + 1,
            levelName: 'Level ${currentLevel + 1}',
            isCompleted: false,
            progress: 0.0,
            questionsAnswered: 0,
            totalQuestions: 0,
          ),
    );

    // Determine line color
    PdfColor lineColor;
    String arrowSymbol = '';

    if (current.isCompleted && next.isCompleted) {
      lineColor = PdfColors.green;
      arrowSymbol = '→';
    } else if (current.isCompleted && next.progress > 0) {
      lineColor = PdfColors.orange;
      arrowSymbol = '→';
    } else if (current.isCompleted) {
      lineColor = PdfColors.grey400;
      arrowSymbol = '→';
    } else {
      lineColor = PdfColors.grey300;
      arrowSymbol = '―';
    }

    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 2),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Container(
                height: 2,
                decoration: pw.BoxDecoration(
                  color: lineColor,
                  borderRadius: pw.BorderRadius.circular(1),
                ),
              ),
            ),
            pw.Text(
              arrowSymbol,
              style: pw.TextStyle(
                fontSize: 8,
                color: lineColor,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                height: 2,
                decoration: pw.BoxDecoration(
                  color: lineColor,
                  borderRadius: pw.BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildCircularLevelIndicatorPDF(
    UserCategoryProgress category,
    int levelNum,
  ) {
    // Find level data
    final levelDetail = category.levelDetails.firstWhere(
      (level) => level.levelNumber == levelNum,
      orElse:
          () => UserLevelDetail(
            levelNumber: levelNum,
            levelName: 'Level $levelNum',
            isCompleted: false,
            progress: 0.0,
            questionsAnswered: 0,
            totalQuestions: 0,
          ),
    );

    PdfColor backgroundColor;
    PdfColor textColor;
    PdfColor borderColor;

    if (levelDetail.isCompleted) {
      backgroundColor = PdfColors.green;
      textColor = PdfColors.white;
      borderColor = PdfColors.green700;
    } else if (levelDetail.progress > 0) {
      backgroundColor = PdfColors.orange;
      textColor = PdfColors.white;
      borderColor = PdfColors.orange700;
    } else {
      backgroundColor = PdfColors.grey200;
      textColor = PdfColors.black;
      borderColor = PdfColors.grey400;
    }

    return pw.Column(
      children: [
        // Circular level indicator
        pw.Container(
          width: 35,
          height: 35,
          decoration: pw.BoxDecoration(
            color: backgroundColor,
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: borderColor, width: 2),
          ),
          child: pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  '$levelNum',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: textColor,
                  ),
                ),
                pw.Text(
                  '${levelDetail.progress.toStringAsFixed(0)}%',
                  style: pw.TextStyle(
                    fontSize: 5,
                    fontWeight: pw.FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 3),
        // Status text
        pw.Text(
          levelDetail.isCompleted
              ? 'COMPLETED'
              : levelDetail.progress > 0
              ? 'PROG'
              : 'PENDING',
          style: pw.TextStyle(
            fontSize: 6,
            fontWeight: pw.FontWeight.bold,
            color: borderColor,
          ),
        ),
      ],
    );
  }
}

// Custom painter untuk menggambar garis penghubung antar level
class LevelConnectionPainter extends CustomPainter {
  final List<UserLevelDetail> levelDetails;

  LevelConnectionPainter(this.levelDetails);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    // Calculate positions for each level circle
    final levelWidth = size.width / 5;
    final centerY = size.height / 2;

    for (int i = 0; i < 4; i++) {
      final startX =
          (levelWidth * i) + (levelWidth / 2) + 25; // Offset for circle radius
      final endX = (levelWidth * (i + 1)) + (levelWidth / 2) - 25;

      final currentLevel = levelDetails.firstWhere(
        (level) => level.levelNumber == i + 1,
        orElse:
            () => UserLevelDetail(
              levelNumber: i + 1,
              levelName: 'Level ${i + 1}',
              isCompleted: false,
              progress: 0.0,
              questionsAnswered: 0,
              totalQuestions: 0,
            ),
      );

      final nextLevel = levelDetails.firstWhere(
        (level) => level.levelNumber == i + 2,
        orElse:
            () => UserLevelDetail(
              levelNumber: i + 2,
              levelName: 'Level ${i + 2}',
              isCompleted: false,
              progress: 0.0,
              questionsAnswered: 0,
              totalQuestions: 0,
            ),
      );

      // Determine line color based on level status
      Color lineColor;
      if (currentLevel.isCompleted && nextLevel.isCompleted) {
        lineColor = Colors.green.shade600;
      } else if (currentLevel.isCompleted && nextLevel.progress > 0) {
        lineColor = Colors.orange.shade600;
      } else if (currentLevel.isCompleted) {
        lineColor = Colors.grey.shade400;
      } else {
        lineColor = Colors.grey.shade300;
      }

      paint.color = lineColor;

      // Draw connecting line
      canvas.drawLine(Offset(startX, centerY), Offset(endX, centerY), paint);

      // Add arrow at the end of the line
      if (currentLevel.isCompleted || nextLevel.progress > 0) {
        _drawArrow(canvas, paint, Offset(endX - 5, centerY), lineColor);
      }
    }
  }

  void _drawArrow(Canvas canvas, Paint paint, Offset position, Color color) {
    paint.color = color;
    paint.style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(position.dx, position.dy);
    path.lineTo(position.dx - 8, position.dy - 4);
    path.lineTo(position.dx - 8, position.dy + 4);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
