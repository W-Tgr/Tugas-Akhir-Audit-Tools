import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tools/auth/auth_service.dart';
import 'package:tools/auth/login_screen.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Models
class LevelDetail {
  final int levelNumber;
  final String levelName;
  final bool isCompleted;
  final double progress;
  final DateTime? completedAt;

  LevelDetail({
    required this.levelNumber,
    required this.levelName,
    required this.isCompleted,
    required this.progress,
    this.completedAt,
  });
}

class UserData {
  final String id;
  final String displayName;
  final String email;
  final String companyName;
  final double overallProgress;
  final DateTime? lastActivity;

  UserData({
    required this.id,
    required this.displayName,
    required this.email,
    required this.companyName,
    required this.overallProgress,
    this.lastActivity,
  });

  factory UserData.fromMap(String id, Map<String, dynamic> data) {
    return UserData(
      id: id,
      displayName: data['displayName'] ?? data['email'] ?? 'Unknown',
      email: data['email'] ?? 'Unknown',
      companyName: data['companyName'] ?? 'No Company',
      overallProgress: 0.0,
    );
  }
}

class LevelProgress {
  final String categoryId;
  final String categoryName;
  final List<LevelDetail> levelDetails;
  final double progressPercentage;

  LevelProgress({
    required this.categoryId,
    required this.categoryName,
    required this.levelDetails,
    required this.progressPercentage,
  });

  List<int> get completedLevels =>
      levelDetails
          .where((level) => level.isCompleted)
          .map((level) => level.levelNumber)
          .toList();
}

class DomainProgress {
  final String domainId;
  final String domainName;
  final List<LevelProgress> categories;
  final double overallProgress;

  DomainProgress({
    required this.domainId,
    required this.domainName,
    required this.categories,
    required this.overallProgress,
  });
}

// Theme Constants
class AppTheme {
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
}

// Services
class ProgressAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<UserData>> getAllUsers() async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'user')
              .get();

      List<UserData> users = [];
      for (var doc in snapshot.docs) {
        final userData = UserData.fromMap(doc.id, doc.data());
        final progress = await calculateUserOverallProgress(doc.id);
        final lastActivity = await getUserLastActivity(doc.id);

        users.add(
          UserData(
            id: userData.id,
            displayName: userData.displayName,
            email: userData.email,
            companyName: userData.companyName,
            overallProgress: progress,
            lastActivity: lastActivity,
          ),
        );
      }

      return users;
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  Future<double> calculateUserOverallProgress(String userId) async {
    try {
      final categoriesSnapshot =
          await _firestore.collection('categories').get();
      if (categoriesSnapshot.docs.isEmpty) return 0.0;

      double totalProgress = 0.0;
      int categoryCount = 0;

      for (var categoryDoc in categoriesSnapshot.docs) {
        final userCategoryDoc =
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('categories')
                .doc(categoryDoc.id)
                .get();

        if (userCategoryDoc.exists) {
          final data = userCategoryDoc.data() as Map<String, dynamic>?;
          final unlockedLevels =
              data?['unlockedLevels'] as List<dynamic>? ?? [];
          final categoryProgress = (unlockedLevels.length / 5.0) * 100.0;
          totalProgress += categoryProgress.clamp(0.0, 100.0);
        }
        categoryCount++;
      }

      return categoryCount > 0 ? totalProgress / categoryCount : 0.0;
    } catch (e) {
      print('Error calculating progress for user $userId: $e');
      return 0.0;
    }
  }

  Future<DateTime?> getUserLastActivity(String userId) async {
    try {
      final answersSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('answers')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

      if (answersSnapshot.docs.isNotEmpty) {
        final data = answersSnapshot.docs.first.data();
        return (data['timestamp'] as Timestamp?)?.toDate();
      }
      return null;
    } catch (e) {
      print('Error getting last activity: $e');
      return null;
    }
  }

  Future<List<DomainProgress>> getUserDetailedProgress(String userId) async {
    try {
      final domainsSnapshot = await _firestore.collection('domains').get();
      final categoriesSnapshot =
          await _firestore.collection('categories').get();
      final levelsSnapshot = await _firestore.collection('levels').get();

      Map<String, String> domainNames = {};
      Map<String, Map<String, dynamic>> categories = {};
      Map<String, Map<String, dynamic>> levels = {};

      for (var doc in domainsSnapshot.docs) {
        domainNames[doc.id] = doc.data()['name'] ?? 'Domain ${doc.id}';
      }

      for (var doc in categoriesSnapshot.docs) {
        categories[doc.id] = {
          'name': doc.data()['name'] ?? 'Category ${doc.id}',
          'domainId': doc.data()['domainId'] ?? '',
        };
      }

      for (var doc in levelsSnapshot.docs) {
        levels[doc.id] = {
          'levelNumber': doc.data()['levelNumber'] ?? 0,
          'name':
              doc.data()['name'] ??
              'Level ${doc.data()['levelNumber'] ?? doc.id}',
          'categoryId': doc.data()['categoryId'] ?? '',
        };
      }

      Map<String, List<String>> categoriesByDomain = {};
      categories.forEach((categoryId, categoryData) {
        final domainId = categoryData['domainId'] as String;
        if (!categoriesByDomain.containsKey(domainId)) {
          categoriesByDomain[domainId] = [];
        }
        categoriesByDomain[domainId]!.add(categoryId);
      });

      List<DomainProgress> domainProgressList = [];

      for (String domainId in domainNames.keys) {
        List<LevelProgress> categoryProgressList = [];
        final domainCategories = categoriesByDomain[domainId] ?? [];

        for (String categoryId in domainCategories) {
          final userCategoryDoc =
              await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('categories')
                  .doc(categoryId)
                  .get();

          List<dynamic> unlockedLevelIds = [];
          Map<String, dynamic> levelProgress = {};

          if (userCategoryDoc.exists) {
            final data = userCategoryDoc.data() as Map<String, dynamic>?;
            unlockedLevelIds = data?['unlockedLevels'] ?? [];
            levelProgress = data?['levelProgress'] ?? {};
          }

          List<LevelDetail> levelDetails = [];
          for (int i = 1; i <= 5; i++) {
            String? levelId;
            String levelName = 'Level $i';

            for (var entry in levels.entries) {
              if (entry.value['categoryId'] == categoryId &&
                  entry.value['levelNumber'] == i) {
                levelId = entry.key;
                levelName = entry.value['name'] ?? 'Level $i';
                break;
              }
            }

            bool isCompleted =
                levelId != null && unlockedLevelIds.contains(levelId);
            double progress = 0.0;

            if (isCompleted) {
              progress = 100.0;
            } else if (levelProgress.containsKey('level$i')) {
              progress = (levelProgress['level$i'] as num?)?.toDouble() ?? 0.0;
            } else if (i == 1 || (i > 1 && levelDetails[i - 2].isCompleted)) {
              progress =
                  levelProgress.containsKey('currentLevel') &&
                          levelProgress['currentLevel'] == i
                      ? 25.0
                      : 0.0;
            }

            levelDetails.add(
              LevelDetail(
                levelNumber: i,
                levelName: levelName,
                isCompleted: isCompleted,
                progress: progress.clamp(0.0, 100.0),
                completedAt: isCompleted ? DateTime.now() : null,
              ),
            );
          }

          final totalProgress = levelDetails
              .map((l) => l.progress)
              .reduce((a, b) => a + b);
          final categoryProgressPercentage = totalProgress / 5.0;

          categoryProgressList.add(
            LevelProgress(
              categoryId: categoryId,
              categoryName: categories[categoryId]!['name'],
              levelDetails: levelDetails,
              progressPercentage: categoryProgressPercentage,
            ),
          );
        }

        final domainOverallProgress =
            categoryProgressList.isEmpty
                ? 0.0
                : categoryProgressList
                        .map((e) => e.progressPercentage)
                        .reduce((a, b) => a + b) /
                    categoryProgressList.length;

        domainProgressList.add(
          DomainProgress(
            domainId: domainId,
            domainName: domainNames[domainId]!,
            categories: categoryProgressList,
            overallProgress: domainOverallProgress,
          ),
        );
      }

      return domainProgressList;
    } catch (e) {
      throw Exception('Failed to load detailed progress: $e');
    }
  }
}

// PDF Service dengan Level Numbers yang Jelas
class PDFExportService {
  static Future<void> exportUserDetailPDF(
    UserData user,
    List<DomainProgress> domains,
  ) async {
    try {
      if (domains.isEmpty) {
        throw Exception('No domain progress data to export');
      }

      final pdf = pw.Document();
      await initializeDateFormatting('id_ID', null);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => _buildPDFContent(user, domains),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name:
            'Progress_Report_${user.displayName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
      );
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  static List<pw.Widget> _buildPDFContent(
    UserData user,
    List<DomainProgress> domains,
  ) {
    return [
      // Header
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'PROGRESS REPORT',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              user.displayName,
              style: pw.TextStyle(color: PdfColors.white, fontSize: 16),
            ),
            pw.Text(
              user.email,
              style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
            ),
            pw.Text(
              user.companyName,
              style: pw.TextStyle(color: PdfColors.white, fontSize: 12),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 20),

      // Overall Progress
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blue),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    '${user.overallProgress.toStringAsFixed(1)}%',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
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
                    '${domains.length}',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
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
                    DateFormat('dd MMM').format(DateTime.now()),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
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
          color: PdfColors.blue,
        ),
      ),
      pw.SizedBox(height: 12),

      // Domain Progress Details
      ...domains.map((domain) => _buildDomainSection(domain)),
    ];
  }

  static pw.Widget _buildDomainSection(DomainProgress domain) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Domain Header
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue,
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
            (category) => _buildCategorySection(category),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCategorySection(LevelProgress category) {
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
              color: PdfColors.blue,
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
                      color: PdfColors.blue,
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

  static pw.Widget _buildLevelProgressWithLinesPDF(LevelProgress category) {
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

  static pw.Widget _buildConnectionLinePDF(
    LevelProgress category,
    int currentLevel,
  ) {
    // Get current and next level details
    final current = category.levelDetails.firstWhere(
      (level) => level.levelNumber == currentLevel,
      orElse:
          () => LevelDetail(
            levelNumber: currentLevel,
            levelName: 'Level $currentLevel',
            isCompleted: false,
            progress: 0.0,
          ),
    );

    final next = category.levelDetails.firstWhere(
      (level) => level.levelNumber == currentLevel + 1,
      orElse:
          () => LevelDetail(
            levelNumber: currentLevel + 1,
            levelName: 'Level ${currentLevel + 1}',
            isCompleted: false,
            progress: 0.0,
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

  static pw.Widget _buildCircularLevelIndicatorPDF(
    LevelProgress category,
    int levelNum,
  ) {
    // Find level data
    LevelDetail? levelDetail;
    try {
      levelDetail = category.levelDetails.firstWhere(
        (level) => level.levelNumber == levelNum,
      );
    } catch (e) {
      levelDetail = LevelDetail(
        levelNumber: levelNum,
        levelName: 'Level $levelNum',
        isCompleted: false,
        progress: 0.0,
      );
    }

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

  // Remove old table-based methods
  static pw.Widget _buildLevelHeaderCell(String levelNum) {
    return pw.Container();
  }

  static pw.Widget _buildLevelProgressCell(
    LevelProgress category,
    int levelNum,
  ) {
    return pw.Container();
  }
}

class ProgressScreenAdmin extends StatefulWidget {
  const ProgressScreenAdmin({Key? key}) : super(key: key);

  @override
  State<ProgressScreenAdmin> createState() => _ProgressScreenAdminState();
}

class _ProgressScreenAdminState extends State<ProgressScreenAdmin>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProgressAnalyticsService _analyticsService = ProgressAnalyticsService();

  String? _selectedUserId;
  String? _selectedCompanyName;
  Map<String?, List<UserData>> _usersByCompany = {};
  bool _isLoading = false;
  bool _isExporting = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : AppTheme.darkBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _exportUserDetailPDF(String userId, String userName) async {
    setState(() => _isExporting = true);
    try {
      final users = await _analyticsService.getAllUsers();
      final user = users.firstWhere((u) => u.id == userId);
      final domains = await _analyticsService.getUserDetailedProgress(userId);

      await PDFExportService.exportUserDetailPDF(user, domains);
      _showSnackBar('PDF berhasil diekspor!');
    } catch (e) {
      _showSnackBar('Gagal mengekspor PDF: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return FutureBuilder<DocumentSnapshot>(
          future:
              _firestore
                  .collection('users')
                  .doc(_authService.getCurrentUser()?.uid)
                  .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              return _buildErrorScreen();
            }

            final userData =
                snapshot.data!.data() as Map<String, dynamic>? ?? {};
            if (userData['role'] != 'admin') {
              return _buildAccessDeniedScreen();
            }

            return Scaffold(
              backgroundColor: AppTheme.backgroundColor,
              appBar: _buildAppBar(isMobile),
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
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      title: Text(
        _selectedUserId != null ? 'Detail Progress User' : 'Progress Analytics',
        style: TextStyle(
          fontSize: isMobile ? 16 : 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          _selectedUserId != null
              ? Icons.arrow_back
              : Icons.arrow_back_ios_rounded,
          size: isMobile ? 20 : 24,
        ),
        onPressed: () {
          if (_selectedUserId != null) {
            setState(() => _selectedUserId = null);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppTheme.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, size: isMobile ? 20 : 24),
          onPressed:
              () => setState(() {
                _usersByCompany.clear();
                _selectedCompanyName = null;
                _selectedUserId = null;
              }),
        ),
        if (_selectedUserId != null)
          IconButton(
            icon: Icon(
              _isExporting ? Icons.hourglass_empty : Icons.picture_as_pdf,
              size: isMobile ? 20 : 24,
            ),
            onPressed:
                _isExporting
                    ? null
                    : () {
                      try {
                        final user = _usersByCompany.values
                            .expand((users) => users)
                            .firstWhere((user) => user.id == _selectedUserId);
                        _exportUserDetailPDF(
                          _selectedUserId!,
                          user.displayName,
                        );
                      } catch (e) {
                        _showSnackBar(
                          'User not found for export',
                          isError: true,
                        );
                      }
                    },
          ),
      ],
    );
  }

  Widget _buildMainView(bool isMobile) {
    if (_selectedUserId != null) {
      // Detail view - no filter shown
      return _buildUserDetailView(_selectedUserId!, isMobile);
    } else {
      // Main view - show filter and user list
      return Column(
        children: [
          _buildUserSelector(isMobile),
          const SizedBox(height: 16),
          Expanded(child: _buildUsersList(isMobile)),
        ],
      );
    }
  }

  Widget _buildUserSelector(bool isMobile) {
    return FutureBuilder<List<UserData>>(
      future: _analyticsService.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data ?? [];
        _groupUsersByCompany(users);

        return Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.shadowColor,
                blurRadius: 15,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Filter Users',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCompanyDropdown(isMobile),
              if (_selectedCompanyName != null) ...[
                const SizedBox(height: 12),
                _buildUserDropdown(isMobile),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompanyDropdown(bool isMobile) {
    final companies =
        _usersByCompany.keys.toList()..sort((a, b) {
          if (a == 'No Company') return 1;
          if (b == 'No Company') return -1;
          return a!.compareTo(b!);
        });

    return DropdownButtonFormField<String?>(
      decoration: InputDecoration(
        labelText: 'Select Company',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: isMobile ? 8 : 12,
        ),
      ),
      value: _selectedCompanyName,
      isExpanded: true,
      items: [
        const DropdownMenuItem(value: null, child: Text('All Companies')),
        ...companies.map((company) {
          final userCount = _usersByCompany[company]?.length ?? 0;
          return DropdownMenuItem(
            value: company,
            child: Text(
              '$company ($userCount users)',
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged:
          (value) => setState(() {
            _selectedCompanyName = value;
            _selectedUserId = null;
          }),
    );
  }

  Widget _buildUserDropdown(bool isMobile) {
    final users = _usersByCompany[_selectedCompanyName] ?? [];

    return DropdownButtonFormField<String?>(
      decoration: InputDecoration(
        labelText: 'Select User',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: isMobile ? 8 : 12,
        ),
      ),
      value: _selectedUserId,
      isExpanded: true,
      menuMaxHeight: 300,
      items:
          users
              .map(
                (user) => DropdownMenuItem(
                  value: user.id,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 10 : 12,
                        backgroundColor: AppTheme.primaryBlue,
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 8 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.displayName,
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: isMobile ? 9 : 10,
                                color: AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
      onChanged: (value) => setState(() => _selectedUserId = value),
    );
  }

  Widget _buildUsersList(bool isMobile) {
    if (_selectedCompanyName != null) {
      return _buildFilteredUsersList(isMobile);
    } else {
      return _buildAllUsersList(isMobile);
    }
  }

  Widget _buildAllUsersList(bool isMobile) {
    return FutureBuilder<List<UserData>>(
      future: _analyticsService.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data ?? [];
        return _buildUsersGrid(users, isMobile);
      },
    );
  }

  Widget _buildFilteredUsersList(bool isMobile) {
    final users = _usersByCompany[_selectedCompanyName] ?? [];
    return _buildUsersGrid(users, isMobile);
  }

  Widget _buildUsersGrid(List<UserData> users, bool isMobile) {
    if (users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) => _buildUserCard(users[index], isMobile),
    );
  }

  Widget _buildUserCard(UserData user, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryBlue,
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.getProgressColor(user.overallProgress / 100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${user.overallProgress.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            user.companyName,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _selectedUserId = user.id),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailView(String userId, bool isMobile) {
    return FutureBuilder<List<DomainProgress>>(
      future: _analyticsService.getUserDetailedProgress(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final domains = snapshot.data ?? [];
        return _buildDomainProgressList(domains, isMobile);
      },
    );
  }

  Widget _buildDomainProgressList(List<DomainProgress> domains, bool isMobile) {
    return ListView.builder(
      itemCount: domains.length,
      itemBuilder:
          (context, index) => _buildDomainCard(domains[index], isMobile),
    );
  }

  Widget _buildDomainCard(DomainProgress domain, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: AppTheme.gradientColors),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.business, color: Colors.white),
        ),
        title: Text(
          domain.domainName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Progress: ${domain.overallProgress.toStringAsFixed(1)}%',
        ),
        children:
            domain.categories
                .map((category) => _buildCategoryTile(category, isMobile))
                .toList(),
      ),
    );
  }

  Widget _buildCategoryTile(LevelProgress category, bool isMobile) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
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
                colors: [AppTheme.primaryBlue, AppTheme.lightBlue],
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
                    color: AppTheme.getProgressColor(
                      category.progressPercentage / 100,
                    ),
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
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level Progress (1-5):',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
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
                    color: AppTheme.textSecondary,
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

  Widget _buildLevelProgressWithLines(LevelProgress category, bool isMobile) {
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
    LevelProgress category,
    int levelNum,
    bool isMobile,
  ) {
    final levelDetail = category.levelDetails.firstWhere(
      (level) => level.levelNumber == levelNum,
      orElse:
          () => LevelDetail(
            levelNumber: levelNum,
            levelName: 'Level $levelNum',
            isCompleted: false,
            progress: 0.0,
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

  void _groupUsersByCompany(List<UserData> users) {
    _usersByCompany.clear();
    for (var user in users) {
      if (!_usersByCompany.containsKey(user.companyName)) {
        _usersByCompany[user.companyName] = [];
      }
      _usersByCompany[user.companyName]!.add(user);
    }

    _usersByCompany.forEach((company, userList) {
      userList.sort((a, b) => a.displayName.compareTo(b.displayName));
    });
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text('Error loading data'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessDeniedScreen() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Access Denied. Admin only.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for drawing connection lines between levels
class LevelConnectionPainter extends CustomPainter {
  final List<LevelDetail> levelDetails;

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
            () => LevelDetail(
              levelNumber: i + 1,
              levelName: 'Level ${i + 1}',
              isCompleted: false,
              progress: 0.0,
            ),
      );

      final nextLevel = levelDetails.firstWhere(
        (level) => level.levelNumber == i + 2,
        orElse:
            () => LevelDetail(
              levelNumber: i + 2,
              levelName: 'Level ${i + 2}',
              isCompleted: false,
              progress: 0.0,
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
