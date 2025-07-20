import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tools/admin/models/level.dart';
import 'package:tools/admin/screens/admin/category_pages.dart';
import 'package:tools/admin/screens/admin/questionnaire_pages.dart';
import 'package:tools/admin/services/level.service.dart';
import 'package:tools/admin/widgets/customtextfield.dart';
import 'package:tools/auth/auth_service.dart';
import 'package:tools/auth/login_screen.dart';
import 'package:uuid/uuid.dart';

class LevelPage extends StatefulWidget {
  final String categoryId;

  const LevelPage({Key? key, required this.categoryId}) : super(key: key);

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage>
    with SingleTickerProviderStateMixin {
  final LevelService _levelService = LevelService();
  final AuthService _authService = AuthService();
  final TextEditingController _numberController = TextEditingController();
  bool _isUnlocked = false;
  String? editingId;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Enhanced color scheme
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
    _numberController.dispose();
    super.dispose();
  }

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

  Future<String?> _getDomainId() async {
    try {
      final categoryDoc =
          await FirebaseFirestore.instance
              .collection('categories')
              .doc(widget.categoryId)
              .get();
      if (categoryDoc.exists) {
        final domainId = categoryDoc.data()?['domainId'] as String?;
        print(
          'Retrieved domainId: $domainId for categoryId: ${widget.categoryId}',
        );
        return domainId;
      } else {
        print(
          'Category document not found for categoryId: ${widget.categoryId}',
        );
        return null;
      }
    } catch (e) {
      print('Error retrieving domainId: $e');
      return null;
    }
  }

  void _showForm([LevelModel? level]) async {
    if (!(await _isAdmin())) {
      _showSnackBar('Hanya admin yang dapat mengedit level', isError: true);
      return;
    }

    if (level != null) {
      editingId = level.id;
      _numberController.text = level.levelNumber.toString();
      _isUnlocked = level.isUnlocked;
    } else {
      editingId = null;
      _numberController.clear();
      _isUnlocked = false;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (_) => LevelFormDialog(
            initialLevelNumber: _numberController.text,
            isEditing: editingId != null,
          ),
    );

    if (result != null) {
      final numberText = result['levelNumber'] as String;

      if (numberText.isEmpty) {
        _showSnackBar('Nomor level harus diisi', isError: true);
        return;
      }
      final levelNumber = int.tryParse(numberText);
      if (levelNumber == null || levelNumber < 1 || levelNumber > 5) {
        _showSnackBar('Nomor level harus antara 1-5', isError: true);
        return;
      }

      setState(() => _isLoading = true);
      try {
        final levelModel = LevelModel(
          id: editingId ?? const Uuid().v4(),
          categoryId: widget.categoryId,
          levelNumber: levelNumber,
          isUnlocked: _isUnlocked, // ✅ Fixed: use the instance variable
          createdAt: level != null ? level.createdAt : Timestamp.now(),
        );

        if (editingId == null) {
          print('Adding level: ${levelModel.levelNumber}');
          await _levelService.addLevel(levelModel);
          _showSnackBar('Level berhasil ditambahkan');
        } else {
          print('Updating level: ${levelModel.levelNumber}');
          await _levelService.updateLevel(levelModel);
          _showSnackBar('Level berhasil diperbarui');
        }
      } catch (e) {
        print('Error saving level: $e');
        _showSnackBar('Gagal: $e', isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmDelete(String id) async {
    if (!(await _isAdmin())) {
      _showSnackBar('Hanya admin yang dapat menghapus level', isError: true);
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
                          'Hapus Level',
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
                      'Yakin ingin menghapus level ini?\n\nTindakan ini tidak dapat dibatalkan dan akan menghapus semua pertanyaan dan data terkait.',
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
                                    print('Deleting level: $id');
                                    await _levelService.deleteLevel(id);
                                    Navigator.pop(context);
                                    _showSnackBar('Level berhasil dihapus');
                                  } catch (e) {
                                    print('Error deleting level: $e');
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
              'Manajemen Level',
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
              onPressed: () {
                print('Navigating back to CategoryPage');
                Navigator.pop(context);
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
                child: StreamBuilder<List<LevelModel>>(
                  stream: _levelService.getLevels(widget.categoryId),
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
                              'Memuat level...',
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
                        'No levels found for categoryId: ${widget.categoryId}',
                      );
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.layers_outlined,
                              size: isMobile ? 48 : 64,
                              color: _textSecondary.withOpacity(0.5),
                            ),
                            SizedBox(height: isMobile ? 12 : 16),
                            Text(
                              'Belum ada level',
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            Text(
                              'Tambahkan level untuk memulai',
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

                    final levels = snapshot.data!;
                    // Sort levels by levelNumber
                    levels.sort(
                      (a, b) => a.levelNumber.compareTo(b.levelNumber),
                    );
                    print('Displaying ${levels.length} levels');

                    return RefreshIndicator(
                      color: _primaryBlue,
                      onRefresh: () async {
                        setState(() {});
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: levels.length,
                        itemBuilder: (context, index) {
                          final level = levels[index];
                          return FutureBuilder<bool>(
                            future: _isAdmin(),
                            builder: (context, adminSnapshot) {
                              final isAdmin = adminSnapshot.data ?? false;
                              return _buildLevelCard(
                                level,
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

  Widget _buildLevelCard(
    LevelModel level,
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
        child: InkWell(
          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          onTap: () {
            print('Navigating to QuestionPage for level: ${level.id}');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuestionPage(levelId: level.id),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child:
                isMobile
                    ? _buildMobileLevelContent(level, isAdmin)
                    : _buildDesktopLevelContent(level, isAdmin, isTablet),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLevelContent(LevelModel level, bool isAdmin) {
    return Column(
      children: [
        Row(
          children: [
            // Ikon Level
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradientColors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.layers_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            // Nama Level
            Expanded(
              child: Text(
                'Level ${level.levelNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
            ),
            // Arrow indicator
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _primaryBlue,
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
                  onPressed: _isLoading ? null : () => _showForm(level),
                  tooltip: 'Edit Level',
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
                  onPressed: _isLoading ? null : () => _confirmDelete(level.id),
                  tooltip: 'Hapus Level',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopLevelContent(
    LevelModel level,
    bool isAdmin,
    bool isTablet,
  ) {
    return Row(
      children: [
        // Ikon Level
        Container(
          padding: EdgeInsets.all(isTablet ? 10 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _gradientColors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.layers_rounded,
            size: isTablet ? 20 : 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        // Nama Level
        Expanded(
          child: Text(
            'Level ${level.levelNumber}',
            style: TextStyle(
              fontSize: isTablet ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
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
                onPressed: _isLoading ? null : () => _showForm(level),
                tooltip: 'Edit Level',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                  size: isTablet ? 20 : 24,
                ),
                onPressed: _isLoading ? null : () => _confirmDelete(level.id),
                tooltip: 'Hapus Level',
              ),
            ],
          )
        else
          Container(
            padding: EdgeInsets.all(isTablet ? 8 : 10),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: isTablet ? 14 : 16,
              color: _primaryBlue,
            ),
          ),
      ],
    );
  }
}

// Simplified Dialog untuk Form Level (tanpa Switch toggle)
class LevelFormDialog extends StatefulWidget {
  final String initialLevelNumber;
  final bool isEditing;

  const LevelFormDialog({
    Key? key,
    required this.initialLevelNumber,
    required this.isEditing,
  }) : super(key: key);

  @override
  _LevelFormDialogState createState() => _LevelFormDialogState();
}

class _LevelFormDialogState extends State<LevelFormDialog> {
  late TextEditingController _numberController;

  // Enhanced color scheme
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
    _numberController = TextEditingController(text: widget.initialLevelNumber);
  }

  @override
  void dispose() {
    _numberController.dispose();
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
                      widget.isEditing ? 'Edit Level' : 'Tambah Level',
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
                controller: _numberController,
                hint: 'Masukkan nomor level (1-5)',
                label: 'Nomor Level',
                keyboardType: TextInputType.number,
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
                          'levelNumber': _numberController.text.trim(),
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
