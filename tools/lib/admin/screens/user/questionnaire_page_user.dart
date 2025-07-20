import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tools/admin/models/answer_model.dart';
import 'package:tools/admin/models/questionnaire.dart';
import 'package:tools/admin/models/retake_request.dart';
import 'package:tools/admin/screens/user/user_level_page.dart';
import 'package:tools/admin/services/answer_service.dart';
import 'package:tools/admin/services/category_service.dart';
import 'package:tools/admin/services/questionnaire_service.dart';
import 'package:tools/admin/services/retake_request_services.dart';
import 'package:tools/auth/auth_service.dart';
import 'package:tools/auth/login_screen.dart';
import 'package:uuid/uuid.dart';

class QuestionnairePage extends StatefulWidget {
  final String levelId;
  final String categoryId;
  final int levelNumber;

  const QuestionnairePage({
    Key? key,
    required this.levelId,
    required this.categoryId,
    required this.levelNumber,
  }) : super(key: key);

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage>
    with SingleTickerProviderStateMixin {
  final QuestionService _questionService = QuestionService();
  final AnswerService _answerService = AnswerService();
  final RetakeRequestService _retakeRequestService = RetakeRequestService();
  final AuthService _authService = AuthService();
  final CategoryService _categoryService = CategoryService();

  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  Map<String, String?> _answers = {};
  bool _isLoading = false;
  bool _hasAnswered = false;
  bool _showConfirmation = false;
  RetakeRequestModel? _retakeRequest;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

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
    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();

    _checkIfLevelAnswered();
    _listenToRetakeRequest();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkIfLevelAnswered() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      print('No user logged in, redirecting to LoginScreen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      print(
        'Checking if level is answered for user: ${user.uid}, level: ${widget.levelId}',
      );
      final isAnswered = await _answerService.isLevelAnswered(
        user.uid,
        widget.categoryId,
        widget.levelId,
      );
      setState(() {
        _hasAnswered = isAnswered;
        _isLoading = false;
      });

      await _categoryService.logUserCategoryStatus(user.uid, widget.categoryId);
    } catch (e) {
      print('Gagal memeriksa status level: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Gagal memeriksa status level: $e', isError: true);
    }
  }

  void _listenToRetakeRequest() {
    final user = _authService.getCurrentUser();
    if (user == null) {
      print('No user logged in for retake request listener');
      return;
    }

    print(
      'Listening to retake request for user: ${user.uid}, level: ${widget.levelId}',
    );
    _retakeRequestService
        .getUserRetakeRequest(user.uid, widget.levelId)
        .listen(
          (request) {
            if (mounted) {
              setState(() {
                _retakeRequest = request;
              });
            }
          },
          onError: (e) {
            print('Gagal memuat status retake: $e');
            _showSnackBar('Gagal memuat status retake: $e', isError: true);
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

  Future<void> _saveAnswers(List<QuestionModel> questions) async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    try {
      print('Saving ${questions.length} answers for user: ${user.uid}');
      for (var question in questions) {
        final answer = _answers[question.id];
        if (answer == null) continue;
        final answerModel = AnswerModel(
          id: const Uuid().v4(),
          userId: user.uid,
          questionId: question.id,
          levelId: widget.levelId,
          categoryId: widget.categoryId,
          answer: answer,
          timestamp: DateTime.now(),
        );
        await _answerService.saveAnswer(answerModel);
      }
      print('All answers saved successfully');
    } catch (e) {
      print('Gagal menyimpan jawaban: $e');
      throw Exception('Gagal menyimpan jawaban: $e');
    }
  }

  Future<void> _submitConfirmation(
    String confirmation,
    List<QuestionModel> questions,
  ) async {
    setState(() => _isLoading = true);
    final user = _authService.getCurrentUser();
    if (user == null) {
      print('No user logged in, redirecting to LoginScreen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Simpan status konfirmasi di progress
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('progress')
          .doc(widget.levelId)
          .set({
            'userId': user.uid,
            'levelId': widget.levelId,
            'categoryId': widget.categoryId,
            'confirmation': confirmation,
            'status': confirmation.contains('Setuju') ? 'P' : 'N',
            'createdAt': Timestamp.now(),
          }, SetOptions(merge: true));

      // Reset retake request jika ada
      try {
        print('Resetting retake request for level: ${widget.levelId}');
        await _retakeRequestService.resetRetakeRequest(
          user.uid,
          widget.levelId,
        );
      } catch (e) {
        print('Error resetting retake request: $e');
      }

      // Log status kategori
      await _categoryService.logUserCategoryStatus(user.uid, widget.categoryId);

      if (confirmation.contains('Setuju')) {
        bool allAnswersAreF = true;
        for (var question in questions) {
          final answer = _answers[question.id];
          if (answer != 'F') {
            allAnswersAreF = false;
            break;
          }
        }

        if (allAnswersAreF) {
          print('All answers are F, attempting to unlock next level');
          try {
            await _answerService.unlockNextLevel(
              user.uid,
              widget.categoryId,
              widget.levelNumber,
            );
            await _categoryService.logUserCategoryStatus(
              user.uid,
              widget.categoryId,
            );
            _showSnackBar('Level selesai! Level berikutnya terbuka.');
          } catch (e) {
            print('Error unlocking next level: $e');
            _showSnackBar(
              'Jawaban disimpan, tetapi gagal membuka level berikutnya: $e',
              isError: true,
            );
          }
        } else {
          _showSnackBar(
            'Jawaban disimpan. Level ini belum selesai. Semua jawaban harus F untuk lanjut.',
          );
        }
      } else {
        _showSnackBar(
          'Jawaban disimpan dengan status Tidak Setuju. Anda tidak dapat lanjut ke level berikutnya.',
        );
      }

      // Kembali ke UserLevelPage
      if (mounted) {
        print('Returning to UserLevelPage');
        Navigator.pop(context);
      }
    } catch (e) {
      print('Gagal menyimpan konfirmasi: $e');
      _showSnackBar('Gagal menyimpan konfirmasi: $e', isError: true);
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();
    if (user == null) {
      print('No user logged in, showing LoginScreen');
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
                    child: _isLoading ? _buildLoadingState() : _buildContent(),
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
                        'Kuisioner Level ${widget.levelNumber}',
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
                        'Jawab semua pertanyaan dengan tepat',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Level indicator
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 10 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'L${widget.levelNumber}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 18 : 16,
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
            'Memuat kuisioner...',
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

  Widget _buildContent() {
    if (_hasAnswered &&
        (_retakeRequest == null || _retakeRequest!.status != 'approved')) {
      return _buildRestrictedState();
    }

    return StreamBuilder<List<QuestionModel>>(
      stream: _questionService.getQuestions(widget.levelId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Terjadi kesalahan saat memuat pertanyaan');
        }
        if (!snapshot.hasData) {
          return _buildLoadingState();
        }

        final questions = snapshot.data!;
        if (questions.isEmpty) {
          return _buildEmptyState();
        }

        if (_showConfirmation) {
          return _buildConfirmationScreen(questions);
        }

        return _buildQuestionScreen(questions);
      },
    );
  }

  Widget _buildRestrictedState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    String message;
    IconData icon;
    List<Color> colors;

    if (_retakeRequest?.status == 'pending') {
      message = 'Menunggu persetujuan admin untuk retake.';
      icon = Icons.hourglass_empty_rounded;
      colors = [const Color(0xFFF59E0B), const Color(0xFFFBBF24)];
    } else if (_retakeRequest?.status == 'rejected') {
      message =
          'Permintaan retake ditolak. Ajukan retake baru di halaman level.';
      icon = Icons.cancel_rounded;
      colors = [const Color(0xFFEF4444), const Color(0xFFF87171)];
    } else {
      message = 'Level ini sudah diisi. Ajukan retake di halaman level.';
      icon = Icons.task_alt_rounded;
      colors = [const Color(0xFF10B981), const Color(0xFF34D399)];
    }

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 400.0 : double.infinity,
        ),
        margin: EdgeInsets.all(isTablet ? 32 : 20),
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _cardGradient),
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.1),
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
                gradient: LinearGradient(colors: colors),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: isTablet ? 48 : 40),
            ),
            const SizedBox(height: 20),
            Text(
              'Akses Terbatas',
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

  Widget _buildErrorState(String error) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 400.0 : double.infinity,
        ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 400.0 : double.infinity,
        ),
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
                Icons.quiz_outlined,
                color: Colors.white,
                size: isTablet ? 48 : 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Pertanyaan',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada pertanyaan untuk level ini.\nSilakan hubungi administrator.',
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

  Widget _buildQuestionScreen(List<QuestionModel> questions) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final horizontalPadding = isTablet ? 32.0 : 20.0;
    final currentQuestion = questions[_currentQuestionIndex];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        20,
        horizontalPadding,
        bottomPadding + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _cardGradient),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _primaryBlue.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 10 : 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryBlue, _lightBlue],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.quiz_rounded,
                        color: Colors.white,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pertanyaan ${_currentQuestionIndex + 1} dari ${questions.length}',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Progress: ${((_currentQuestionIndex + 1) / questions.length * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / questions.length,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(_primaryBlue),
                  minHeight: 6,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Question card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _cardGradient),
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(
                color: _primaryBlue.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withOpacity(0.08),
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
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 28 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question text
                  Text(
                    currentQuestion.text,
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Options
                  ...currentQuestion.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected = _answers[currentQuestion.id] == option;

                    return Container(
                      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? _primaryBlue.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isSelected ? _primaryBlue : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: RadioListTile<String>(
                        title: Text(
                          option,
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? _primaryBlue : _textPrimary,
                          ),
                        ),
                        value: option,
                        groupValue: _answers[currentQuestion.id],
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _answers[currentQuestion.id] = value;
                            _selectedAnswer = value;
                          });
                        },
                        activeColor: _primaryBlue,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 20 : 16,
                          vertical: isTablet ? 8 : 4,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Navigation buttons
          Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _textSecondary.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _currentQuestionIndex--;
                          _selectedAnswer =
                              _answers[questions[_currentQuestionIndex].id];
                        });
                      },
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                      label: const Text('Sebelumnya'),
                      style: TextButton.styleFrom(
                        foregroundColor: _textSecondary,
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 24 : 20,
                          vertical: isTablet ? 16 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_currentQuestionIndex > 0) const SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_darkBlue, _primaryBlue, _lightBlue],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryBlue.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (_answers[currentQuestion.id] == null) {
                        _showSnackBar(
                          'Pilih jawaban terlebih dahulu',
                          isError: true,
                        );
                        return;
                      }

                      HapticFeedback.lightImpact();

                      if (_currentQuestionIndex < questions.length - 1) {
                        setState(() {
                          _currentQuestionIndex++;
                          _selectedAnswer =
                              _answers[questions[_currentQuestionIndex].id];
                        });
                      } else {
                        setState(() => _isLoading = true);
                        try {
                          await _saveAnswers(questions);
                          setState(() {
                            _showConfirmation = true;
                            _isLoading = false;
                          });
                        } catch (e) {
                          _showSnackBar(
                            'Gagal menyimpan jawaban: $e',
                            isError: true,
                          );
                          setState(() => _isLoading = false);
                        }
                      }
                    },
                    icon: Icon(
                      _currentQuestionIndex < questions.length - 1
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.check_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _currentQuestionIndex < questions.length - 1
                          ? 'Berikutnya'
                          : 'Selesai',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 20,
                        vertical: isTablet ? 16 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationScreen(List<QuestionModel> questions) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        20,
        horizontalPadding,
        bottomPadding + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Back Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Konfirmasi Jawaban',
                style: TextStyle(
                  fontSize: isTablet ? 28 : 24,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Changed from onPressed to onTap
                    HapticFeedback.lightImpact();
                    setState(() {
                      _showConfirmation = false; // Kembali ke layar pertanyaan
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _primaryBlue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: _primaryBlue,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pastikan jawaban Anda sudah benar sebelum melanjutkan',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Confirmation card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _cardGradient),
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(
                color: _primaryBlue.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withOpacity(0.08),
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
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 32 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question icon
                  Container(
                    padding: EdgeInsets.all(isTablet ? 16 : 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryBlue, _lightBlue],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.help_outline_rounded,
                      color: Colors.white,
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirmation text
                  Text(
                    'Berdasarkan penilaian yang dilakukan, apakah saudara setuju aktivitas tersebut di atas memiliki capability Level ${widget.levelNumber} (semua aktivitas bernilai F)?',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      color: _textPrimary,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action buttons
                  Column(
                    children: [
                      // Agree button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF10B981),
                              const Color(0xFF34D399),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                    HapticFeedback.mediumImpact();
                                    _submitConfirmation(
                                      'Setuju, aktivitas memenuhi level ${widget.levelNumber}',
                                      questions,
                                    );
                                  },
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                          ),
                          label: Text(
                            'Setuju, aktivitas memenuhi level ${widget.levelNumber}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 24 : 20,
                              vertical: isTablet ? 18 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Disagree button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFEF4444),
                              const Color(0xFFF87171),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                    HapticFeedback.mediumImpact();
                                    _submitConfirmation(
                                      'Tidak Setuju',
                                      questions,
                                    );
                                  },
                          icon: const Icon(Icons.cancel_rounded, size: 20),
                          label: Text(
                            'Tidak Setuju',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 24 : 20,
                              vertical: isTablet ? 18 : 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
