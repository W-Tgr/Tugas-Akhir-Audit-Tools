import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tools/admin/models/level.dart';
import 'package:tools/admin/models/retake_request.dart';
import 'package:tools/admin/screens/user/debug_helper.dart';
import 'package:tools/admin/services/category_service.dart';
import 'package:tools/admin/services/level.service.dart';
import 'package:tools/admin/services/answer_service.dart';
import 'package:tools/admin/services/retake_request_services.dart';
import 'package:tools/auth/auth_service.dart';
import 'package:tools/auth/login_screen.dart';
import 'questionnaire_page_user.dart';

class UserLevelPage extends StatefulWidget {
  final String categoryId;

  const UserLevelPage({Key? key, required this.categoryId}) : super(key: key);

  @override
  State<UserLevelPage> createState() => _UserLevelPageState();
}

class _UserLevelPageState extends State<UserLevelPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Stream controllers untuk realtime updates
  final Map<String, StreamController<bool>> _retakeStreamControllers = {};
  final Map<String, bool> _retakeLoadingStates = {};

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

  // Status colors
  static const Map<String, List<Color>> _statusColors = {
    'available': [Color(0xFF10B981), Color(0xFF34D399)],
    'completed': [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    'pending': [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    'approved': [Color(0xFF10B981), Color(0xFF34D399)],
    'rejected': [Color(0xFFEF4444), Color(0xFFF87171)],
  };

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
    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
    _initializeProgress();
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Dispose all stream controllers
    for (var controller in _retakeStreamControllers.values) {
      controller.close();
    }
    _retakeStreamControllers.clear();
    super.dispose();
  }

  void _initializeProgress() {
    final authService = AuthService();
    final categoryService = CategoryService();
    final answerService = AnswerService();
    final user = authService.getCurrentUser();

    if (user != null) {
      categoryService
          .logUserCategoryStatus(user.uid, widget.categoryId)
          .then((_) {
            return answerService.initializeUserProgress(
              user.uid,
              widget.categoryId,
            );
          })
          .catchError((e) {
            _showSnackBar('Gagal menginisialisasi progres: $e', isError: true);
          });
    }
  }

  // Enhanced retake request dengan realtime update
  Future<void> _requestRetake(
    BuildContext context,
    String userId,
    String levelId,
  ) async {
    final retakeRequestService = RetakeRequestService();

    // Set loading state
    setState(() {
      _retakeLoadingStates[levelId] = true;
    });

    try {
      // Show confirmation dialog first
      final shouldProceed = await _showRetakeConfirmation(levelId);
      if (!shouldProceed) {
        setState(() {
          _retakeLoadingStates[levelId] = false;
        });
        return;
      }

      // Haptic feedback
      HapticFeedback.mediumImpact();

      final request = RetakeRequestModel(
        id: '${userId}_$levelId',
        userId: userId,
        levelId: levelId,
        status: 'pending',
        createdAt: Timestamp.now(),
      );

      await retakeRequestService.createRetakeRequest(request);

      // Update stream controller untuk realtime refresh
      if (_retakeStreamControllers.containsKey(levelId)) {
        _retakeStreamControllers[levelId]!.add(true);
      }

      // Show success message
      _showSnackBar(
        'Permintaan retake telah diajukan. Silakan tunggu persetujuan admin.',
        isSuccess: true,
      );

      // Trigger widget rebuild untuk immediate visual feedback
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Gagal mengajukan retake: $e');
      _showSnackBar('Gagal mengajukan retake: $e', isError: true);
    } finally {
      // Clear loading state
      setState(() {
        _retakeLoadingStates[levelId] = false;
      });
    }
  }

  // Confirmation dialog untuk retake
  Future<bool> _showRetakeConfirmation(String levelId) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(Icons.refresh_rounded, color: _primaryBlue, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Konfirmasi Retake',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apakah Anda yakin ingin mengajukan retake untuk level ini?',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade600,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Anda perlu menunggu persetujuan admin untuk dapat mengerjakan level ini lagi.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Ajukan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    if (!mounted) return;

    Color backgroundColor;
    IconData icon;

    if (isError) {
      backgroundColor = Colors.red.shade600;
      icon = Icons.error_outline;
    } else if (isSuccess) {
      backgroundColor = Colors.green.shade600;
      icon = Icons.check_circle_outline;
    } else {
      backgroundColor = _primaryBlue;
      icon = Icons.info_outline;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
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
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levelService = LevelService();
    final answerService = AnswerService();
    final authService = AuthService();
    final categoryService = CategoryService();
    final retakeRequestService = RetakeRequestService();
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
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Column(
                children: [
                  _buildEnhancedHeader(),
                  Expanded(
                    child: _buildContent(
                      categoryService,
                      levelService,
                      retakeRequestService,
                      user,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isTablet = screenWidth > 600;
    final headerHeight = (isTablet ? 160.0 : 140.0) + statusBarHeight;

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
          ...List.generate(3, (index) {
            return Positioned(
              top: statusBarHeight + 20 + (index * 25),
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

          // Header content
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 20,
              statusBarHeight + (isTablet ? 24 : 20),
              isTablet ? 24 : 20,
              isTablet ? 24 : 20,
            ),
            child: Row(
              children: [
                // Back button
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

                // Title section
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daftar Level',
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
                        'Pilih level untuk memulai kuisioner',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.layers_rounded,
                    color: Colors.white,
                    size: isTablet ? 24 : 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    CategoryService categoryService,
    LevelService levelService,
    RetakeRequestService retakeRequestService,
    User user,
  ) {
    return StreamBuilder<DocumentSnapshot>(
      stream: categoryService.getUserCategoryData(user.uid, widget.categoryId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(
            'Terjadi kesalahan saat memuat data kategori',
          );
        }
        if (!snapshot.hasData) {
          return _buildLoadingState();
        }

        final unlockedLevels =
            snapshot.data!.exists
                ? (snapshot.data!['unlockedLevels'] as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    <String>[]
                : <String>[];

        final answeredLevels =
            snapshot.data!.exists
                ? (snapshot.data!['answeredLevels'] as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    <String>[]
                : <String>[];

        return StreamBuilder<List<LevelModel>>(
          stream: levelService.getLevels(widget.categoryId),
          builder: (context, levelSnapshot) {
            if (levelSnapshot.hasError) {
              return _buildErrorState('Terjadi kesalahan saat memuat level');
            }
            if (!levelSnapshot.hasData) {
              return _buildLoadingState();
            }

            final levels = levelSnapshot.data!;
            if (levels.isEmpty) {
              return _buildEmptyState('Belum ada level tersedia');
            }

            final accessibleLevels =
                levels
                    .where((level) => unlockedLevels.contains(level.id))
                    .toList()
                  ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));

            if (accessibleLevels.isEmpty) {
              return _buildEmptyState('Belum ada level yang terbuka');
            }

            return _buildLevelList(
              accessibleLevels,
              answeredLevels,
              retakeRequestService,
              user,
            );
          },
        );
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
            'Memuat daftar level...',
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
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {}); // Trigger rebuild
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

  Widget _buildEmptyState(String message) {
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
                Icons.layers_outlined,
                color: Colors.white,
                size: isTablet ? 48 : 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Level',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
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

  Widget _buildLevelList(
    List<LevelModel> levels,
    List<String> answeredLevels,
    RetakeRequestService retakeRequestService,
    User user,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return RefreshIndicator(
      onRefresh: () async {
        // Force refresh all data
        setState(() {});
        await Future.delayed(Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, 20, 0, bottomPadding + 20),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children:
                    levels.asMap().entries.map((entry) {
                      final index = entry.key;
                      final level = entry.value;
                      final isAnswered = answeredLevels.contains(level.id);
                      final isLastItem = index == levels.length - 1;

                      // Debug level yang sudah dijawab
                      if (isAnswered) {
                        debugLevelAnswers(user.uid, level.id);
                      }

                      return Container(
                        margin: EdgeInsets.only(bottom: isLastItem ? 0 : 16),
                        child: _buildLevelCard(
                          level,
                          isAnswered,
                          retakeRequestService,
                          user,
                          isTablet,
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(
    LevelModel level,
    bool isAnswered,
    RetakeRequestService retakeRequestService,
    User user,
    bool isTablet,
  ) {
    // StreamBuilder untuk retake request dengan realtime updates
    return StreamBuilder<RetakeRequestModel?>(
      stream: retakeRequestService.getUserRetakeRequest(user.uid, level.id),
      builder: (context, retakeSnapshot) {
        return FutureBuilder<bool>(
          future: AnswerService().isLevelCompleted(user.uid, level.id),
          builder: (context, completionSnapshot) {
            // Handle loading state
            if (!completionSnapshot.hasData) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _cardGradient),
                  borderRadius: BorderRadius.circular(_cardRadius),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 24 : 20),
                  child: Center(
                    child: CircularProgressIndicator(color: _primaryBlue),
                  ),
                ),
              );
            }

            final retakeRequest = retakeSnapshot.data;
            final isRetakeLoading = _retakeLoadingStates[level.id] ?? false;

            String status;
            String subtitle;
            List<Color> statusColors;
            IconData statusIcon;
            Widget? actionButton;
            VoidCallback? onTap;

            if (isAnswered) {
              if (retakeRequest?.status == 'pending') {
                status = 'pending';
                subtitle = 'Menunggu Persetujuan Retake';
                statusColors = _statusColors['pending']!;
                statusIcon = Icons.hourglass_empty_rounded;
                onTap = null;
              } else if (retakeRequest?.status == 'approved') {
                status = 'approved';
                subtitle = 'Retake Disetujui';
                statusColors = _statusColors['approved']!;
                statusIcon = Icons.check_circle_rounded;
                onTap = () => _navigateToQuestionnaire(level);
              } else if (retakeRequest?.status == 'rejected') {
                status = 'rejected';
                subtitle = 'Retake Ditolak';
                statusColors = _statusColors['rejected']!;
                statusIcon = Icons.cancel_rounded;
                actionButton = _buildActionButton(
                  'Ajukan Lagi',
                  () => _requestRetake(context, user.uid, level.id),
                  _statusColors['rejected']!,
                  isTablet,
                  isLoading: isRetakeLoading,
                );
                onTap = null;
              } else {
                status = 'completed';
                subtitle = 'Sudah Dijawab';
                statusColors = _statusColors['completed']!;
                statusIcon = Icons.task_alt_rounded;
                final allFullyAchieved = completionSnapshot.data!;
                if (allFullyAchieved) {
                  actionButton = null;
                  subtitle = 'Semua jawaban Fully Achieved';
                } else {
                  actionButton = _buildActionButton(
                    'Ajukan Retake',
                    () => _requestRetake(context, user.uid, level.id),
                    _statusColors['pending']!,
                    isTablet,
                    isLoading: isRetakeLoading,
                  );
                }
                onTap = null;
              }
            } else {
              status = 'available';
              subtitle = 'Siap untuk dikerjakan';
              statusColors = _statusColors['available']!;
              statusIcon = Icons.play_circle_filled_rounded;
              onTap = () => _navigateToQuestionnaire(level);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _cardGradient),
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(
                  color: statusColors[0].withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColors[0].withOpacity(0.08),
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
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(_cardRadius),
                  splashColor: statusColors[0].withOpacity(0.1),
                  highlightColor: statusColors[0].withOpacity(0.05),
                  child: Padding(
                    padding: EdgeInsets.all(isTablet ? 24 : 20),
                    child: Row(
                      children: [
                        // Level icon with status
                        Container(
                          padding: EdgeInsets.all(isTablet ? 18 : 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: statusColors),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: statusColors[0].withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            statusIcon,
                            color: Colors.white,
                            size: isTablet ? 32 : 28,
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Level info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Level ${level.levelNumber}',
                                style: TextStyle(
                                  fontSize: isTablet ? 20 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: isTablet ? 16 : 14,
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Status indicator
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 10 : 8,
                                  vertical: isTablet ? 6 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColors[0].withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(status),
                                  style: TextStyle(
                                    color: statusColors[0],
                                    fontWeight: FontWeight.w600,
                                    fontSize: isTablet ? 14 : 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action button or arrow
                        if (actionButton != null)
                          actionButton
                        else if (onTap != null)
                          Container(
                            padding: EdgeInsets.all(isTablet ? 10 : 8),
                            decoration: BoxDecoration(
                              color: statusColors[0].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: isTablet ? 18 : 16,
                              color: statusColors[0],
                            ),
                          )
                        else
                          Container(
                            padding: EdgeInsets.all(isTablet ? 10 : 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.lock_rounded,
                              size: isTablet ? 18 : 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(
    String text,
    VoidCallback onPressed,
    List<Color> colors,
    bool isTablet, {
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed:
            isLoading
                ? null
                : () {
                  HapticFeedback.lightImpact();
                  onPressed();
                },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white70,
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 10 : 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            isLoading
                ? SizedBox(
                  width: isTablet ? 16 : 14,
                  height: isTablet ? 16 : 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Text(
                  text,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available':
        return 'TERSEDIA';
      case 'completed':
        return 'SELESAI';
      case 'pending':
        return 'MENUNGGU';
      case 'approved':
        return 'DISETUJUI';
      case 'rejected':
        return 'DITOLAK';
      default:
        return 'TIDAK DIKETAHUI';
    }
  }

  void _navigateToQuestionnaire(LevelModel level) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => QuestionnairePage(
              levelId: level.id,
              categoryId: widget.categoryId,
              levelNumber: level.levelNumber,
            ),
      ),
    );
  }
}
