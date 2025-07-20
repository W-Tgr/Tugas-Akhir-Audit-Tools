import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tools/admin/models/questionnaire.dart';
import 'package:tools/admin/screens/admin/level_pages.dart';
import 'package:tools/admin/services/questionnaire_service.dart';
import 'package:tools/admin/widgets/customtextfield.dart';
import 'package:tools/auth/auth_service.dart';
import 'package:tools/auth/login_screen.dart';
import 'package:uuid/uuid.dart';

class QuestionPage extends StatefulWidget {
  final String levelId;

  const QuestionPage({Key? key, required this.levelId}) : super(key: key);

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage>
    with SingleTickerProviderStateMixin {
  final QuestionService _questionService = QuestionService();
  final AuthService _authService = AuthService();
  final TextEditingController _textController = TextEditingController();
  String? editingId;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Warna konsisten dengan AdminDashboardPage, DomainPage, CategoryPage, dan LevelPage
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _darkBlue = Color(0xFF1976D2);
  static const Color _lightBlue = Color(0xFF42A5F5);
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _surfaceColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  static final List<Color> _gradientColors = [
    _darkBlue,
    _primaryBlue,
    _lightBlue,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // Check if the user is an admin
  Future<bool> _isAdmin() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      print('No user logged in');
      return false;
    }
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final isAdmin = userDoc.exists && userDoc.data()?['role'] == 'admin';
    print('User ${user.uid} isAdmin: $isAdmin');
    return isAdmin;
  }

  // Get categoryId from levelId
  Future<String?> _getCategoryId() async {
    try {
      final levelDoc =
          await FirebaseFirestore.instance
              .collection('levels')
              .doc(widget.levelId)
              .get();
      if (levelDoc.exists) {
        final categoryId = levelDoc.data()?['categoryId'] as String?;
        print(
          'Retrieved categoryId: $categoryId for levelId: ${widget.levelId}',
        );
        return categoryId;
      } else {
        print('Level document not found for levelId: ${widget.levelId}');
        return null;
      }
    } catch (e) {
      print('Error retrieving categoryId: $e');
      return null;
    }
  }

  // Show form for adding or editing question
  void _showForm([QuestionModel? question]) async {
    if (!(await _isAdmin())) {
      _showSnackBar('Hanya admin yang dapat mengedit kuisioner', isError: true);
      return;
    }

    if (question != null) {
      editingId = question.id;
      _textController.text = question.text;
    } else {
      editingId = null;
      _textController.clear();
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (_) => QuestionFormDialog(
            initialText: _textController.text,
            isEditing: editingId != null,
          ),
    );

    if (result != null) {
      final text = result['text'] as String;

      if (text.isEmpty) {
        _showSnackBar('Pertanyaan harus diisi', isError: true);
        return;
      }

      setState(() => _isLoading = true);
      try {
        final questionModel = QuestionModel(
          id: editingId ?? const Uuid().v4(),
          levelId: widget.levelId,
          text: text,
          options: ['N', 'P', 'L', 'F'],
          createdAt: question != null ? question.createdAt : Timestamp.now(),
        );

        if (editingId == null) {
          print('Adding question: ${questionModel.text}');
          await _questionService.addQuestion(questionModel);
          _showSnackBar('Kuisioner berhasil ditambahkan');
        } else {
          print('Updating question: ${questionModel.text}');
          await _questionService.updateQuestion(questionModel);
          _showSnackBar('Kuisioner berhasil diperbarui');
        }
      } catch (e) {
        print('Error saving question: $e');
        _showSnackBar('Gagal: $e', isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Confirm question deletion
  void _confirmDelete(String id) async {
    if (!(await _isAdmin())) {
      _showSnackBar(
        'Hanya admin yang dapat menghapus kuisioner',
        isError: true,
      );
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            ),
            contentPadding: EdgeInsets.zero,
            content: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? double.infinity : 400,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                color: _surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: _darkBlue.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.2, 0.5, 0.9],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(isMobile ? 16 : 20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: isMobile ? 20 : 24,
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        Text(
                          'Hapus Kuisioner',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Text(
                      'Yakin ingin menghapus kuisioner ini?\n\nTindakan ini tidak dapat dibatalkan.',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: isMobile ? 14 : 16,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : 20,
                              vertical: isMobile ? 8 : 12,
                            ),
                          ),
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        _isLoading
                            ? SizedBox(
                              width: isMobile ? 20 : 24,
                              height: isMobile ? 20 : 24,
                              child: CircularProgressIndicator(
                                color: Colors.red,
                                strokeWidth: 2,
                              ),
                            )
                            : Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEF4444),
                                    Color(0xFFF87171),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  isMobile ? 8 : 12,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      isMobile ? 8 : 12,
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 20,
                                    vertical: isMobile ? 8 : 12,
                                  ),
                                ),
                                onPressed: () async {
                                  setState(() => _isLoading = true);
                                  try {
                                    print('Deleting question: $id');
                                    await _questionService.deleteQuestion(id);
                                    Navigator.pop(context);
                                    _showSnackBar('Kuisioner berhasil dihapus');
                                  } catch (e) {
                                    print('Error deleting question: $e');
                                    _showSnackBar(
                                      'Gagal menghapus: $e',
                                      isError: true,
                                    );
                                  } finally {
                                    setState(() => _isLoading = false);
                                  }
                                },
                                child: Text(
                                  'Hapus',
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: isMobile ? 18 : 20,
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : _primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        ),
        margin: EdgeInsets.all(isMobile ? 12 : 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();
    if (user == null) return const LoginScreen();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;
        final horizontalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 24.0);

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            title: Text(
              'Manajemen Kuisioner',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                size: isMobile ? 20 : 24,
              ),
              onPressed: () async {
                final categoryId = await _getCategoryId();
                if (categoryId != null) {
                  print(
                    'Navigating back to LevelPage with categoryId: $categoryId',
                  );
                  Navigator.pop(context);
                } else {
                  print('Failed to navigate: categoryId is null');
                  _showSnackBar(
                    'Gagal kembali: Level tidak ditemukan',
                    isError: true,
                  );
                }
              },
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.2, 0.5, 0.9],
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: StreamBuilder<List<QuestionModel>>(
                  stream: _questionService.getQuestions(widget.levelId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      print('StreamBuilder error: ${snapshot.error}');
                      if ('${snapshot.error}'.contains('index')) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: _primaryBlue),
                              SizedBox(height: isMobile ? 12 : 16),
                              Text(
                                'Membuat indeks Firestore...',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: isMobile ? 14 : 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: isMobile ? 6 : 8),
                              Text(
                                'Silakan tunggu beberapa saat',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: isMobile ? 12 : 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(horizontalPadding),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: isMobile ? 48 : 64,
                                color: Colors.red.shade300,
                              ),
                              SizedBox(height: isMobile ? 12 : 16),
                              Text(
                                'Terjadi kesalahan',
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary,
                                ),
                              ),
                              SizedBox(height: isMobile ? 6 : 8),
                              Text(
                                '${snapshot.error}',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: isMobile ? 12 : 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: _primaryBlue),
                            SizedBox(height: isMobile ? 12 : 16),
                            Text(
                              'Memuat kuisioner...',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: isMobile ? 14 : 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      print(
                        'No questions found for levelId: ${widget.levelId}',
                      );
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.question_answer_outlined,
                              size: isMobile ? 48 : 64,
                              color: _textSecondary.withOpacity(0.5),
                            ),
                            SizedBox(height: isMobile ? 12 : 16),
                            Text(
                              'Belum ada kuisioner',
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            Text(
                              'Tambahkan kuisioner untuk memulai',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                color: _textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final questions = snapshot.data!;
                    print('Displaying ${questions.length} questions');

                    return RefreshIndicator(
                      color: _primaryBlue,
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: questions.length,
                        itemBuilder: (context, index) {
                          final question = questions[index];
                          return FutureBuilder<bool>(
                            future: _isAdmin(),
                            builder: (context, adminSnapshot) {
                              final isAdmin = adminSnapshot.data ?? false;
                              return _buildQuestionCard(
                                question,
                                isAdmin,
                                isMobile,
                                isTablet,
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          floatingActionButton: FutureBuilder<bool>(
            future: _isAdmin(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data == true) {
                return FloatingActionButton(
                  onPressed: _isLoading ? null : () => _showForm(),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: isMobile ? 6 : 8,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.2, 0.5, 0.9],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primaryBlue.withOpacity(0.3),
                          blurRadius: isMobile ? 8 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(Icons.add, size: isMobile ? 24 : 28),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Widget _buildQuestionCard(
    QuestionModel question,
    bool isAdmin,
    bool isMobile,
    bool isTablet,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.08),
            blurRadius: isMobile ? 15 : 20,
            offset: Offset(0, isMobile ? 6 : 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child:
              isMobile
                  ? _buildMobileQuestionContent(question, isAdmin)
                  : _buildDesktopQuestionContent(question, isAdmin, isTablet),
        ),
      ),
    );
  }

  Widget _buildMobileQuestionContent(QuestionModel question, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ikon Kuisioner
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradientColors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.question_answer_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            // Teks
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Opsi: ${question.options.join(", ")}',
                    style: const TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Admin actions untuk mobile
        if (isAdmin) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit, color: _primaryBlue),
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onPressed: _isLoading ? null : () => _showForm(question),
                  tooltip: 'Edit Kuisioner',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onPressed:
                      _isLoading ? null : () => _confirmDelete(question.id),
                  tooltip: 'Hapus Kuisioner',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopQuestionContent(
    QuestionModel question,
    bool isAdmin,
    bool isTablet,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ikon Kuisioner
        Container(
          padding: EdgeInsets.all(isTablet ? 10 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _gradientColors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.question_answer_rounded,
            size: isTablet ? 20 : 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        // Teks dan Opsi
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.text,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Opsi: ${question.options.join(", ")}',
                style: TextStyle(
                  fontSize: isTablet ? 12 : 14,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Aksi Admin
        if (isAdmin)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: _primaryBlue,
                  size: isTablet ? 20 : 24,
                ),
                onPressed: _isLoading ? null : () => _showForm(question),
                tooltip: 'Edit Kuisioner',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                  size: isTablet ? 20 : 24,
                ),
                onPressed:
                    _isLoading ? null : () => _confirmDelete(question.id),
                tooltip: 'Hapus Kuisioner',
              ),
            ],
          ),
      ],
    );
  }
}

// Stateful Dialog untuk Form Kuisioner
class QuestionFormDialog extends StatefulWidget {
  final String initialText;
  final bool isEditing;

  const QuestionFormDialog({
    Key? key,
    required this.initialText,
    required this.isEditing,
  }) : super(key: key);

  @override
  _QuestionFormDialogState createState() => _QuestionFormDialogState();
}

class _QuestionFormDialogState extends State<QuestionFormDialog> {
  late TextEditingController _textController;

  // Warna konsisten dengan tema utama
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _darkBlue = Color(0xFF1976D2);
  static const Color _lightBlue = Color(0xFF42A5F5);
  static const Color _surfaceColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  static final List<Color> _gradientColors = [
    _darkBlue,
    _primaryBlue,
    _lightBlue,
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 400),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          color: _surfaceColor,
          boxShadow: [
            BoxShadow(
              color: _darkBlue.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.2, 0.5, 0.9],
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(isMobile ? 16 : 20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isEditing ? Icons.edit : Icons.add_circle,
                    color: Colors.white,
                    size: isMobile ? 20 : 24,
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Text(
                      widget.isEditing ? 'Edit Kuisioner' : 'Tambah Kuisioner',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Form
            Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              child: CustomTextField(
                controller: _textController,
                hint: 'Masukkan pertanyaan',
                label: 'Pertanyaan',
                textAlign: TextAlign.start,
              ),
            ),
            // Actions
            Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 20,
                        vertical: isMobile ? 8 : 12,
                      ),
                    ),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_darkBlue, _primaryBlue],
                      ),
                      borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryBlue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isMobile ? 8 : 12,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 20,
                          vertical: isMobile ? 8 : 12,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context, {
                          'text': _textController.text.trim(),
                        });
                      },
                      child: Text(
                        widget.isEditing ? 'Simpan' : 'Tambah',
                        style: TextStyle(fontSize: isMobile ? 14 : 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
