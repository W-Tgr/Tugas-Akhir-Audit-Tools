import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tools/auth/auth_service.dart';
import 'package:tools/auth/login_screen.dart';
import 'package:uuid/uuid.dart';

class UploadQuestionnaireScreen extends StatefulWidget {
  const UploadQuestionnaireScreen({Key? key}) : super(key: key);

  @override
  State<UploadQuestionnaireScreen> createState() {
    print('Creating state for UploadQuestionnaireScreen');
    return _UploadQuestionnaireScreenState();
  }
}

class _UploadQuestionnaireScreenState extends State<UploadQuestionnaireScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _statusMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Variables untuk dropdown selection
  String? _selectedDomainId;
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _domains = [];
  List<Map<String, dynamic>> _categories = [];

  // Progress tracking
  double _uploadProgress = 0.0;
  bool _showProgress = false;
  int _totalQuestions = 0;
  int _processedQuestions = 0;

  // Warna konsisten dengan halaman lainnya
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _darkBlue = Color(0xFF1976D2);
  static const Color _lightBlue = Color(0xFF42A5F5);
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _surfaceColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _errorColor = Color(0xFFEF4444);

  static final List<Color> _gradientColors = [
    _darkBlue,
    _primaryBlue,
    _lightBlue,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
    _loadDomains();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Improved SnackBar with better styling
  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    if (!mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    Color backgroundColor;
    IconData icon;

    if (isError) {
      backgroundColor = _errorColor;
      icon = Icons.error_outline;
    } else if (isSuccess) {
      backgroundColor = _successColor;
      icon = Icons.check_circle_outline;
    } else {
      backgroundColor = _primaryBlue;
      icon = Icons.info_outline;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: isMobile ? 18 : 20),
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
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        ),
        margin: EdgeInsets.all(isMobile ? 12 : 16),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  // Load domains dari Firestore dengan error handling yang lebih baik
  Future<void> _loadDomains() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final snapshot = await _firestore.collection('domains').get();

      if (mounted) {
        final domains =
            snapshot.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    'name': doc.data()['name'] as String? ?? 'Unknown Domain',
                  },
                )
                .toList();

        // Sort manually after fetching with null safety
        domains.sort((a, b) {
          final nameA = a['name'] as String? ?? '';
          final nameB = b['name'] as String? ?? '';
          return nameA.compareTo(nameB);
        });

        setState(() {
          _domains = domains;
          _isLoading = false;
        });
      }

      if (_domains.isEmpty) {
        _showSnackBar(
          'Tidak ada domain yang tersedia. Silakan buat domain terlebih dahulu.',
          isError: true,
        );
      }
    } catch (e) {
      print('Error loading domains: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar(
          'Gagal memuat daftar domain: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  // Load categories dengan loading state
  Future<void> _loadCategories(String domainId) async {
    try {
      setState(() {
        _isLoading = true;
        _categories.clear();
        _selectedCategoryId = null;
      });

      final snapshot =
          await _firestore
              .collection('categories')
              .where('domainId', isEqualTo: domainId)
              .get();

      if (mounted) {
        final categories =
            snapshot.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    'name': doc.data()['name'] as String? ?? 'Unknown Category',
                  },
                )
                .toList();

        // Sort manually after fetching with null safety
        categories.sort((a, b) {
          final nameA = a['name'] as String? ?? '';
          final nameB = b['name'] as String? ?? '';
          return nameA.compareTo(nameB);
        });

        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }

      if (_categories.isEmpty) {
        _showSnackBar(
          'Tidak ada kategori untuk domain ini. Silakan buat kategori terlebih dahulu.',
          isError: true,
        );
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar(
          'Gagal memuat daftar kategori: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  // Update progress during upload
  void _updateProgress(int processed, int total) {
    if (mounted) {
      setState(() {
        _processedQuestions = processed;
        _totalQuestions = total;
        _uploadProgress = total > 0 ? processed / total : 0.0;
      });
    }
  }

  // Fungsi untuk menormalisasi teks header
  String normalizeHeader(String header) {
    return header.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  // Fungsi untuk memeriksa apakah header yang dinormalisasi cocok dengan salah satu header yang diharapkan
  bool matchesExpectedHeader(
    String normalizedHeader,
    List<String> expectedHeaders,
  ) {
    return expectedHeaders.any(
      (expected) =>
          normalizedHeader == expected || normalizedHeader.contains(expected),
    );
  }

  // Improved file processing with better error handling and progress tracking
  Future<void> _pickAndProcessFile() async {
    // Validasi selection domain dan category
    if (_selectedDomainId == null || _selectedCategoryId == null) {
      _showSnackBar(
        'Domain dan Category harus dipilih terlebih dahulu.',
        isError: true,
      );
      return;
    }

    print('Starting _pickAndProcessFile');
    setState(() {
      _isLoading = true;
      _showProgress = false;
      _statusMessage = null;
      _uploadProgress = 0.0;
    });

    try {
      print('Picking file with FilePicker');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.isEmpty) {
        print('No file selected');
        setState(() {
          _statusMessage = 'Tidak ada file yang dipilih.';
          _isLoading = false;
        });
        return;
      }

      final platformFile = result.files.first;
      final extension = platformFile.extension?.toLowerCase();
      print('File picked: ${platformFile.name}, Extension: $extension');

      if (extension != 'xlsx') {
        setState(() {
          _statusMessage =
              'Format file tidak didukung. Hanya file .xlsx yang diperbolehkan.';
          _isLoading = false;
        });
        _showSnackBar(
          'Format file tidak didukung. Hanya file .xlsx yang diperbolehkan.',
          isError: true,
        );
        return;
      }

      // Show processing status
      setState(() {
        _statusMessage = 'Membaca file Excel...';
      });

      // Membaca file Excel
      List<int>? fileBytes;
      if (kIsWeb) {
        fileBytes = platformFile.bytes;
      } else {
        if (platformFile.path == null) {
          setState(() {
            _statusMessage = 'Path file Excel tidak tersedia.';
            _isLoading = false;
          });
          _showSnackBar('Path file Excel tidak tersedia.', isError: true);
          return;
        }
        final file = File(platformFile.path!);
        if (!await file.exists()) {
          setState(() {
            _statusMessage = 'File Excel tidak ditemukan.';
            _isLoading = false;
          });
          _showSnackBar(
            'File Excel tidak ditemukan di lokasi yang dipilih.',
            isError: true,
          );
          return;
        }
        fileBytes = await file.readAsBytes();
      }

      if (fileBytes == null) {
        setState(() {
          _statusMessage = 'Gagal membaca data Excel.';
          _isLoading = false;
        });
        _showSnackBar(
          'Gagal membaca data Excel. File mungkin rusak.',
          isError: true,
        );
        return;
      }

      setState(() {
        _statusMessage = 'Memproses data Excel...';
      });

      print('Decoding Excel file');
      final excel = Excel.decodeBytes(fileBytes);
      final sheetNames = excel.tables.keys.toList();

      if (sheetNames.isEmpty) {
        setState(() {
          _statusMessage = 'File Excel tidak memiliki sheet yang valid.';
          _isLoading = false;
        });
        _showSnackBar(
          'File Excel tidak memiliki sheet yang valid.',
          isError: true,
        );
        return;
      }

      // Siapkan domain dan category yang sudah dipilih
      final domainId = _selectedDomainId!;
      final categoryId = _selectedCategoryId!;

      final selectedDomain = _domains.firstWhere((d) => d['id'] == domainId);
      final selectedCategory = _categories.firstWhere(
        (c) => c['id'] == categoryId,
      );

      print('Using selected Domain: ${selectedDomain['name']} (ID: $domainId)');
      print(
        'Using selected Category: ${selectedCategory['name']} (ID: $categoryId)',
      );

      // Count total questions first for progress tracking
      int totalQuestions = 0;
      final validSheets = <String, int>{};

      for (
        int sheetIndex = 0;
        sheetIndex < sheetNames.length && sheetIndex < 5;
        sheetIndex++
      ) {
        final sheetName = sheetNames[sheetIndex];
        final excelRows = excel.tables[sheetName]?.rows;
        if (excelRows != null && excelRows.length > 1) {
          final questionCount = excelRows.length - 1; // Exclude header
          validSheets[sheetName] = questionCount;
          totalQuestions += questionCount;
        }
      }

      if (totalQuestions == 0) {
        setState(() {
          _statusMessage =
              'Tidak ada pertanyaan yang valid ditemukan dalam file Excel.';
          _isLoading = false;
        });
        _showSnackBar(
          'Tidak ada pertanyaan yang valid ditemukan dalam file Excel.',
          isError: true,
        );
        return;
      }

      setState(() {
        _showProgress = true;
        _totalQuestions = totalQuestions;
        _statusMessage = 'Mengimpor $totalQuestions pertanyaan...';
      });

      int totalSuccessCount = 0;
      int processedCount = 0;

      // Proses setiap sheet sebagai level
      for (
        int sheetIndex = 0;
        sheetIndex < sheetNames.length && sheetIndex < 5;
        sheetIndex++
      ) {
        final sheetName = sheetNames[sheetIndex];
        final levelNumber = sheetIndex + 1;

        if (!validSheets.containsKey(sheetName)) continue;

        print('Processing Sheet: $sheetName as Level: $levelNumber');

        final excelRows = excel.tables[sheetName]?.rows;
        if (excelRows == null || excelRows.isEmpty) continue;

        // Convert Excel rows to string format
        final rows =
            excelRows
                .map(
                  (row) =>
                      row.map((cell) => cell?.value?.toString() ?? '').toList(),
                )
                .toList();

        // Cari header yang valid
        int headerIndex = 0;
        while (headerIndex < rows.length &&
            rows[headerIndex].every((cell) => cell.isEmpty)) {
          headerIndex++;
        }

        if (headerIndex >= rows.length) continue;

        var headerRow = rows[headerIndex];
        headerRow = headerRow.where((cell) => cell.isNotEmpty).toList();

        // Expected headers untuk format baru: Level, Question Text
        final expectedHeaderVariations = {
          'question text': [
            'question text',
            'question',
            'pertanyaan',
            'teks pertanyaan',
            'text',
          ],
        };

        if (headerRow.isEmpty) continue;

        List<String> normalizedHeaders =
            headerRow.map((h) => normalizeHeader(h)).toList();

        bool questionFound = false;
        Map<String, int> headerIndices = {};

        for (int i = 0; i < normalizedHeaders.length; i++) {
          String current = normalizedHeaders[i];
          if (!questionFound &&
              matchesExpectedHeader(
                current,
                expectedHeaderVariations['question text']!,
              )) {
            headerIndices['question'] = i;
            questionFound = true;
            break;
          }
        }

        // If no question column found, try the first column
        if (!questionFound && headerRow.isNotEmpty) {
          headerIndices['question'] = 0;
          questionFound = true;
        }

        if (!questionFound) continue;

        // Cari atau buat level
        var levelSnapshot =
            await _firestore
                .collection('levels')
                .where('categoryId', isEqualTo: categoryId)
                .where('levelNumber', isEqualTo: levelNumber)
                .get();

        String levelId;
        if (levelSnapshot.docs.isEmpty) {
          levelId = const Uuid().v4();
          await _firestore.collection('levels').doc(levelId).set({
            'categoryId': categoryId,
            'levelNumber': levelNumber,
            'isUnlocked': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          levelId = levelSnapshot.docs.first.id;
        }

        // Proses data rows di sheet ini
        int sheetSuccessCount = 0;
        for (var i = headerIndex + 1; i < rows.length; i++) {
          var row = rows[i];

          if (row.every((cell) => cell.isEmpty)) {
            processedCount++;
            _updateProgress(processedCount, totalQuestions);
            continue;
          }

          if (row.length <= headerIndices['question']!) {
            while (row.length <= headerIndices['question']!) {
              row.add('');
            }
          }

          final questionText = row[headerIndices['question']!].trim();

          if (questionText.isEmpty) {
            processedCount++;
            _updateProgress(processedCount, totalQuestions);
            continue;
          }

          // Check for duplicate questions in this level
          final existingQuestion =
              await _firestore
                  .collection('questions')
                  .where('levelId', isEqualTo: levelId)
                  .where('text', isEqualTo: questionText)
                  .get();

          if (existingQuestion.docs.isNotEmpty) {
            print('Skipping duplicate question: $questionText');
            processedCount++;
            _updateProgress(processedCount, totalQuestions);
            continue;
          }

          // Options otomatis N, P, L, F
          final options = ['N', 'P', 'L', 'F'];

          final questionId = const Uuid().v4();
          await _firestore.collection('questions').doc(questionId).set({
            'levelId': levelId,
            'text': questionText,
            'options': options,
            'createdAt': FieldValue.serverTimestamp(),
          });

          sheetSuccessCount++;
          totalSuccessCount++;
          processedCount++;
          _updateProgress(processedCount, totalQuestions);

          // Small delay to show progress
          await Future.delayed(const Duration(milliseconds: 10));
        }

        print(
          'Completed processing sheet $sheetName (Level $levelNumber). Questions added: $sheetSuccessCount',
        );
      }

      print('Import completed. Total questions imported: $totalSuccessCount');
      setState(() {
        _statusMessage =
            'Berhasil mengimpor $totalSuccessCount dari $totalQuestions pertanyaan!';
        _isLoading = false;
        _showProgress = false;
      });

      _showSnackBar(
        'Berhasil mengimpor $totalSuccessCount pertanyaan dari ${validSheets.length} level.',
        isSuccess: true,
      );
    } catch (e) {
      print('Error during import: $e');
      setState(() {
        _statusMessage = 'Gagal mengimpor kuesioner: ${e.toString()}';
        _isLoading = false;
        _showProgress = false;
      });
      _showSnackBar(
        'Gagal mengimpor kuesioner: ${e.toString()}',
        isError: true,
      );
    }
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _uploadProgress,
          backgroundColor: _primaryBlue.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
          minHeight: 6,
        ),
        const SizedBox(height: 8),
        Text(
          '$_processedQuestions / $_totalQuestions pertanyaan diproses',
          style: TextStyle(
            fontSize: 12,
            color: _textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required void Function(String?) onChanged,
    String? hintText,
    bool enabled = true,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _textSecondary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _textSecondary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryBlue, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade200,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 12 : 16,
        ),
        prefixIcon: Icon(
          label.contains('Domain') ? Icons.domain : Icons.category,
          color: _primaryBlue,
          size: isMobile ? 20 : 24,
        ),
      ),
      items:
          items.map((item) {
            return DropdownMenuItem<String>(
              value: item['id'],
              child: Text(
                item['name'],
                style: TextStyle(fontSize: isMobile ? 14 : 16),
              ),
            );
          }).toList(),
      onChanged: enabled ? onChanged : null,
      style: TextStyle(color: _textPrimary, fontSize: isMobile ? 14 : 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building UploadQuestionnaireScreen');
    final user = _authService.getCurrentUser();
    if (user == null) {
      print('User not logged in, redirecting to LoginScreen');
      return const LoginScreen();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;
        final horizontalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 24.0);

        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(user.uid).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: _backgroundColor,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: _primaryBlue),
                      SizedBox(height: isMobile ? 12 : 16),
                      Text(
                        'Memverifikasi akses...',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.data() == null) {
              return Scaffold(
                backgroundColor: _backgroundColor,
                appBar: AppBar(
                  title: const Text('Unggah Kuesioner'),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  centerTitle: true,
                  elevation: 0,
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
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: isMobile ? 48 : 64,
                        color: _errorColor,
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      Text(
                        'Terjadi kesalahan saat memuat data pengguna.',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            if (userData['role'] != 'admin') {
              return Scaffold(
                backgroundColor: _backgroundColor,
                appBar: AppBar(
                  title: const Text('Unggah Kuesioner'),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  centerTitle: true,
                  elevation: 0,
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
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        size: isMobile ? 48 : 64,
                        color: _warningColor,
                      ),
                      SizedBox(height: isMobile ? 12 : 16),
                      Text(
                        'Akses Terbatas',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isMobile ? 6 : 8),
                      Text(
                        'Hanya administrator yang dapat mengunggah kuesioner.',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: isMobile ? 14 : 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            print('User is admin, rendering upload UI');
            return Scaffold(
              backgroundColor: _backgroundColor,
              appBar: AppBar(
                title: Text(
                  'Unggah Kuesioner',
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
                  onPressed: () => Navigator.pop(context),
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
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? double.infinity : 600,
                          ),
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          decoration: BoxDecoration(
                            color: _surfaceColor,
                            borderRadius: BorderRadius.circular(
                              isMobile ? 16 : 20,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryBlue.withOpacity(0.08),
                                blurRadius: isMobile ? 15 : 25,
                                offset: Offset(0, isMobile ? 6 : 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header dengan icon dan title
                              Container(
                                padding: EdgeInsets.all(isMobile ? 12 : 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _gradientColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.upload_file,
                                      size: isMobile ? 24 : 28,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: isMobile ? 8 : 12),
                                    Expanded(
                                      child: Text(
                                        'Upload Kuesioner Excel',
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

                              SizedBox(height: isMobile ? 16 : 20),

                              // Instruction card
                              Container(
                                padding: EdgeInsets.all(isMobile ? 12 : 16),
                                decoration: BoxDecoration(
                                  color: _primaryBlue.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: _primaryBlue,
                                          size: isMobile ? 16 : 18,
                                        ),
                                        SizedBox(width: isMobile ? 6 : 8),
                                        Text(
                                          'Format File Excel:',
                                          style: TextStyle(
                                            fontSize: isMobile ? 14 : 16,
                                            fontWeight: FontWeight.w600,
                                            color: _primaryBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 6 : 8),
                                    Text(
                                      '• Pilih Domain dan Category yang sudah ada\n'
                                      '• Sheet 1-5 untuk Level 1-5\n'
                                      '• Kolom: Question Text/Pertanyaan\n'
                                      '• Options N, P, L, F akan dibuat otomatis\n'
                                      '• Duplikasi pertanyaan akan dilewati',
                                      style: TextStyle(
                                        fontSize: isMobile ? 12 : 14,
                                        color: _textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: isMobile ? 20 : 24),

                              // Selection Section
                              Row(
                                children: [
                                  Icon(
                                    Icons.settings,
                                    color: _primaryBlue,
                                    size: isMobile ? 20 : 24,
                                  ),
                                  SizedBox(width: isMobile ? 8 : 12),
                                  Text(
                                    'Pilih Target Upload:',
                                    style: TextStyle(
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () {
                                      _loadDomains();
                                      setState(() {
                                        _selectedDomainId = null;
                                        _selectedCategoryId = null;
                                        _categories.clear();
                                      });
                                    },
                                    icon: Icon(
                                      Icons.refresh,
                                      color: _primaryBlue,
                                      size: isMobile ? 20 : 24,
                                    ),
                                    tooltip: 'Refresh daftar',
                                  ),
                                ],
                              ),

                              SizedBox(height: isMobile ? 12 : 16),

                              // Domain Dropdown
                              _buildDropdownField(
                                label: 'Domain',
                                value: _selectedDomainId,
                                items: _domains,
                                enabled: _domains.isNotEmpty && !_isLoading,
                                hintText:
                                    _domains.isEmpty
                                        ? 'Tidak ada domain tersedia'
                                        : 'Pilih domain untuk kuesioner',
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedDomainId = newValue;
                                    _selectedCategoryId = null;
                                    _categories.clear();
                                  });
                                  if (newValue != null) {
                                    _loadCategories(newValue);
                                  }
                                },
                              ),

                              SizedBox(height: isMobile ? 12 : 16),

                              // Category Dropdown
                              _buildDropdownField(
                                label: 'Category',
                                value: _selectedCategoryId,
                                items: _categories,
                                enabled:
                                    _selectedDomainId != null &&
                                    _categories.isNotEmpty &&
                                    !_isLoading,
                                hintText:
                                    _selectedDomainId == null
                                        ? 'Pilih domain terlebih dahulu'
                                        : _categories.isEmpty
                                        ? 'Tidak ada kategori tersedia'
                                        : 'Pilih kategori untuk kuesioner',
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedCategoryId = newValue;
                                  });
                                },
                              ),

                              // Warning for empty lists
                              if (_domains.isEmpty && !_isLoading) ...[
                                SizedBox(height: isMobile ? 8 : 12),
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                                  decoration: BoxDecoration(
                                    color: _warningColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber,
                                        color: _warningColor,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Tidak ada domain tersedia. Silakan buat domain terlebih dahulu.',
                                          style: TextStyle(
                                            color: _warningColor,
                                            fontSize: isMobile ? 12 : 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (_selectedDomainId != null &&
                                  _categories.isEmpty &&
                                  !_isLoading) ...[
                                SizedBox(height: isMobile ? 8 : 12),
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                                  decoration: BoxDecoration(
                                    color: _warningColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber,
                                        color: _warningColor,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Tidak ada kategori untuk domain ini. Silakan buat kategori terlebih dahulu.',
                                          style: TextStyle(
                                            color: _warningColor,
                                            fontSize: isMobile ? 12 : 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              SizedBox(height: isMobile ? 20 : 24),

                              // Upload button
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors:
                                        (_selectedDomainId != null &&
                                                _selectedCategoryId != null &&
                                                !_isLoading)
                                            ? _gradientColors
                                            : [
                                              Colors.grey.shade400,
                                              Colors.grey.shade500,
                                            ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow:
                                      (_selectedDomainId != null &&
                                              _selectedCategoryId != null &&
                                              !_isLoading)
                                          ? [
                                            BoxShadow(
                                              color: _primaryBlue.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5),
                                            ),
                                          ]
                                          : null,
                                ),
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (_isLoading ||
                                              _selectedDomainId == null ||
                                              _selectedCategoryId == null)
                                          ? null
                                          : _pickAndProcessFile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 20 : 30,
                                      vertical: isMobile ? 14 : 16,
                                    ),
                                  ),
                                  icon:
                                      _isLoading
                                          ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : Icon(
                                            Icons.file_upload,
                                            size: isMobile ? 20 : 24,
                                          ),
                                  label: Text(
                                    _isLoading
                                        ? 'Memproses...'
                                        : 'Pilih File Excel',
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              // Progress indicator
                              if (_showProgress) ...[
                                SizedBox(height: isMobile ? 16 : 20),
                                _buildProgressIndicator(),
                              ],

                              // Status message
                              if (_statusMessage != null) ...[
                                SizedBox(height: isMobile ? 16 : 20),
                                Container(
                                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                                  decoration: BoxDecoration(
                                    color:
                                        _statusMessage!.contains('Gagal')
                                            ? _errorColor.withOpacity(0.1)
                                            : _statusMessage!.contains(
                                              'Berhasil',
                                            )
                                            ? _successColor.withOpacity(0.1)
                                            : _primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _statusMessage!.contains('Gagal')
                                            ? Icons.error_outline
                                            : _statusMessage!.contains(
                                              'Berhasil',
                                            )
                                            ? Icons.check_circle_outline
                                            : Icons.info_outline,
                                        color:
                                            _statusMessage!.contains('Gagal')
                                                ? _errorColor
                                                : _statusMessage!.contains(
                                                  'Berhasil',
                                                )
                                                ? _successColor
                                                : _primaryBlue,
                                        size: isMobile ? 20 : 24,
                                      ),
                                      SizedBox(width: isMobile ? 8 : 12),
                                      Expanded(
                                        child: Text(
                                          _statusMessage!,
                                          style: TextStyle(
                                            fontSize: isMobile ? 14 : 16,
                                            color:
                                                _statusMessage!.contains(
                                                      'Gagal',
                                                    )
                                                    ? _errorColor
                                                    : _statusMessage!.contains(
                                                      'Berhasil',
                                                    )
                                                    ? _successColor
                                                    : _primaryBlue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
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
}
