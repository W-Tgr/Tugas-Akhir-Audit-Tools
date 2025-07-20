import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:tools/auth/login_screen.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({Key? key}) : super(key: key);

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  File? _image;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;

  // Enhanced color scheme
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
    _setupAnimations();
    _checkUserAndInitialize();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  void _checkUserAndInitialize() {
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
    } else {
      _initializeProfileStream();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeProfileStream() {
    if (user == null) return;
    _profileStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots();
  }

  Future<void> _createUserDocumentIfNeeded() async {
    if (user == null) return;

    try {
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid);

      final doc = await userDocRef.get();

      if (!doc.exists) {
        final displayName = user!.displayName ?? user!.email!.split('@')[0];

        await userDocRef.set({
          'email': user!.email,
          'displayName': displayName,
          'photoBase64': null,
          'status': 'approved',
          'role': 'admin',
          'phoneNumber': null,
          'companyName': null,
          'workUnit': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });

        print('Admin user document created successfully');
      }
    } catch (e) {
      print('Error creating admin user document: $e');
      _showSnackBar(
        'Gagal membuat dokumen pengguna: ${e.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null || user == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      print('Uploading image for UID: ${user!.uid}');

      // Enhanced image compression
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _image!.path,
        minWidth: 400,
        minHeight: 400,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (compressedImage == null) {
        throw Exception('Gagal mengompresi gambar');
      }

      final base64Image = base64Encode(compressedImage);
      print('Compressed image size (Base64 length): ${base64Image.length}');

      // Check size limit (1MB for Firestore)
      final base64SizeInBytes = (base64Image.length * 3 / 4).round();
      if (base64SizeInBytes > 900000) {
        throw Exception(
          'Ukuran gambar terlalu besar: ${(base64SizeInBytes / 1000).toStringAsFixed(1)} KB',
        );
      }

      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid);

      await userDocRef.update({
        'photoBase64': base64Image,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _image = null;
        _isUploadingImage = false;
      });

      _showSnackBar('Foto profil berhasil diperbarui!', isSuccess: true);
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _isUploadingImage = false;
      });
      _showSnackBar('Gagal mengunggah foto: ${e.toString()}', isError: true);
    }
  }

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

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();

      // Show image source selection
      final source = await _showImageSourceDialog();
      if (source == null) return;

      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        await _uploadImage();
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('Gagal memilih gambar: ${e.toString()}', isError: true);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.photo_camera, color: _primaryBlue),
                const SizedBox(width: 12),
                const Text('Pilih Sumber Foto'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library, color: _primaryBlue),
                  title: const Text('Galeri'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: _primaryBlue),
                  title: const Text('Kamera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
    );
  }

  void _showFullProfileImage(BuildContext context, String imageBase64) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Center(
                  child: Hero(
                    tag: 'profileImage',
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.8,
                        maxWidth: MediaQuery.of(context).size.width * 0.9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _darkBlue.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: InteractiveViewer(
                          panEnabled: true,
                          scaleEnabled: true,
                          minScale: 0.5,
                          maxScale: 3.0,
                          child: Image.memory(
                            base64Decode(imageBase64),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _showEditProfileDialog(Map<String, dynamic> currentData) async {
    final displayNameController = TextEditingController(
      text: currentData['displayName'] ?? user!.email!.split('@')[0],
    );
    final emailController = TextEditingController(
      text: currentData['email'] ?? user!.email,
    );
    final phoneNumberController = TextEditingController(
      text: currentData['phoneNumber'] ?? '',
    );
    final companyNameController = TextEditingController(
      text: currentData['companyName'] ?? '',
    );
    final workUnitController = TextEditingController(
      text: currentData['workUnit'] ?? '',
    );
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 500,
                      maxHeight: 700,
                    ),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, const Color(0xFFF8FAFC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: _darkBlue.withOpacity(0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Enhanced header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: _gradientColors),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryBlue.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 20),

                          Text(
                            'Edit Profil Admin',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            'Perbarui informasi profil administrator',
                            style: TextStyle(
                              fontSize: 14,
                              color: _textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Enhanced form
                          Form(
                            key: formKey,
                            child: Column(
                              children: [
                                _buildEnhancedTextField(
                                  controller: displayNameController,
                                  label: 'Nama Administrator',
                                  icon: Icons.person_rounded,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Nama administrator tidak boleh kosong';
                                    }
                                    if (value.trim().length < 3) {
                                      return 'Nama administrator minimal 3 karakter';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                _buildEnhancedTextField(
                                  controller: emailController,
                                  label: 'Alamat Email',
                                  icon: Icons.email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: false, // Email shouldn't be editable
                                ),
                                const SizedBox(height: 16),

                                _buildEnhancedTextField(
                                  controller: phoneNumberController,
                                  label: 'Nomor HP (Opsional)',
                                  icon: Icons.phone_rounded,
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (value != null &&
                                        value.trim().isNotEmpty) {
                                      if (!RegExp(
                                        r'^\+?\d{8,15}$',
                                      ).hasMatch(value.trim())) {
                                        return 'Format nomor HP tidak valid';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                _buildEnhancedTextField(
                                  controller: companyNameController,
                                  label: 'Nama Perusahaan (Opsional)',
                                  icon: Icons.business_rounded,
                                ),
                                const SizedBox(height: 16),

                                _buildEnhancedTextField(
                                  controller: workUnitController,
                                  label: 'Bagian Unit Kerja (Opsional)',
                                  icon: Icons.work_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Enhanced action buttons
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
                                    onPressed:
                                        isLoading
                                            ? null
                                            : () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _textSecondary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Batal',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
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
                                      colors: _gradientColors,
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
                                  child: ElevatedButton(
                                    onPressed:
                                        isLoading
                                            ? null
                                            : () async {
                                              if (formKey.currentState!
                                                  .validate()) {
                                                setDialogState(() {
                                                  isLoading = true;
                                                });

                                                try {
                                                  final userDocRef =
                                                      FirebaseFirestore.instance
                                                          .collection('users')
                                                          .doc(user!.uid);

                                                  final updateData = {
                                                    'displayName':
                                                        displayNameController
                                                            .text
                                                            .trim(),
                                                    'phoneNumber':
                                                        phoneNumberController
                                                                .text
                                                                .trim()
                                                                .isEmpty
                                                            ? null
                                                            : phoneNumberController
                                                                .text
                                                                .trim(),
                                                    'companyName':
                                                        companyNameController
                                                                .text
                                                                .trim()
                                                                .isEmpty
                                                            ? null
                                                            : companyNameController
                                                                .text
                                                                .trim(),
                                                    'workUnit':
                                                        workUnitController.text
                                                                .trim()
                                                                .isEmpty
                                                            ? null
                                                            : workUnitController
                                                                .text
                                                                .trim(),
                                                    'updatedAt':
                                                        FieldValue.serverTimestamp(),
                                                  };

                                                  await userDocRef.update(
                                                    updateData,
                                                  );
                                                  await user!.updateDisplayName(
                                                    displayNameController.text
                                                        .trim(),
                                                  );

                                                  setDialogState(() {
                                                    isLoading = false;
                                                  });

                                                  Navigator.pop(context);
                                                  _showSnackBar(
                                                    'Profil admin berhasil diperbarui!',
                                                    isSuccess: true,
                                                  );
                                                } catch (e) {
                                                  print(
                                                    'Error updating admin profile: $e',
                                                  );
                                                  setDialogState(() {
                                                    isLoading = false;
                                                  });
                                                  _showSnackBar(
                                                    'Gagal memperbarui profil: ${e.toString()}',
                                                    isError: true,
                                                  );
                                                }
                                              }
                                            },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child:
                                        isLoading
                                            ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : const Text(
                                              'Simpan',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
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
                  ),
                ),
          ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      style: TextStyle(
        color: enabled ? _textPrimary : _textSecondary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: enabled ? _textSecondary : _textSecondary.withOpacity(0.6),
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient:
                enabled
                    ? LinearGradient(colors: _gradientColors)
                    : LinearGradient(colors: [_textSecondary, _textSecondary]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _textSecondary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _primaryBlue, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _textSecondary.withOpacity(0.2)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _textSecondary.withOpacity(0.1)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _errorColor, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    if (user == null) {
      return const LoginScreen();
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _profileStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            Map<String, dynamic> profileData = {};
            if (snapshot.hasData && snapshot.data!.exists) {
              profileData = snapshot.data!.data()!;
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _createUserDocumentIfNeeded();
              });
            }

            return _buildProfileContent(profileData);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.2, 0.5, 0.9],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Memuat profil admin...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.2, 0.5, 0.9],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _initializeProfileStream();
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
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

  Widget _buildProfileContent(Map<String, dynamic> profileData) {
    final userName = profileData['displayName'] ?? user!.email!.split('@')[0];
    final userEmail =
        profileData['email'] ?? user?.email ?? 'email@example.com';
    final imageBase64 = profileData['photoBase64'];
    final phoneNumber = profileData['phoneNumber'];
    final companyName = profileData['companyName'];
    final workUnit = profileData['workUnit'];
    final lastLogin = profileData['lastLoginAt'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildEnhancedHeader(context, isMobile, isTablet),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 20 : (isTablet ? 24 : 32)),
                child: Column(
                  children: [
                    _buildEnhancedProfileImageSection(
                      imageBase64,
                      userName,
                      isMobile,
                      isTablet,
                    ),
                    SizedBox(height: isMobile ? 24 : 32),

                    // Enhanced edit profile button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: _gradientColors),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryBlue.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed:
                            _isLoading
                                ? null
                                : () => _showEditProfileDialog(profileData),
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        label: Text(
                          'Edit Profil Admin',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 24 : 32,
                            vertical: isMobile ? 14 : 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isMobile ? 24 : 32),
                    _buildEnhancedInfoSection(
                      userName,
                      userEmail,
                      phoneNumber,
                      companyName,
                      workUnit,
                      lastLogin,
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

  Widget _buildEnhancedHeader(
    BuildContext context,
    bool isMobile,
    bool isTablet,
  ) {
    return Container(
      height: isMobile ? 180 : 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.2, 0.5, 0.9],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: EnhancedCirclePainter())),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profil Administrator',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kelola pengaturan profil administrator',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: isMobile ? 13 : 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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

  Widget _buildEnhancedProfileImageSection(
    String? imageBase64,
    String userName,
    bool isMobile,
    bool isTablet,
  ) {
    final avatarSize = isMobile ? 130.0 : (isTablet ? 140.0 : 150.0);

    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap:
                imageBase64 != null
                    ? () => _showFullProfileImage(context, imageBase64)
                    : null,
            child: Hero(
              tag: 'profileImage',
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _darkBlue.withOpacity(0.3),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: CircleAvatar(
                  radius: avatarSize / 2 - 4,
                  backgroundColor: _surfaceColor,
                  backgroundImage:
                      _image != null
                          ? FileImage(_image!)
                          : imageBase64 != null
                          ? MemoryImage(base64Decode(imageBase64))
                          : null,
                  child:
                      _image == null && imageBase64 == null
                          ? Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'A',
                            style: TextStyle(
                              fontSize: isMobile ? 45 : 55,
                              fontWeight: FontWeight.bold,
                              color: _primaryBlue,
                            ),
                          )
                          : null,
                ),
              ),
            ),
          ),

          // Enhanced camera button
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_darkBlue, _primaryBlue]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryBlue.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: _isUploadingImage ? null : _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child:
                        _isUploadingImage
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                  ),
                ),
              ),
            ),
          ),

          // Image indicator
          if (imageBase64 != null)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _successColor.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnhancedInfoSection(
    String userName,
    String userEmail,
    String? phoneNumber,
    String? companyName,
    String? workUnit,
    Timestamp? lastLogin,
    bool isMobile,
    bool isTablet,
  ) {
    return Column(
      children: [
        _buildEnhancedInfoCard(
          icon: Icons.person_rounded,
          title: 'Nama Administrator',
          value: userName,
          color: [_primaryBlue, _lightBlue],
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 12 : 16),

        _buildEnhancedInfoCard(
          icon: Icons.email_rounded,
          title: 'Alamat Email',
          value: userEmail,
          color: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
          isMobile: isMobile,
        ),
        SizedBox(height: isMobile ? 12 : 16),

        _buildEnhancedInfoCard(
          icon: Icons.phone_rounded,
          title: 'Nomor HP',
          value: phoneNumber ?? 'Belum diatur',
          color: [_successColor, const Color(0xFF34D399)],
          isMobile: isMobile,
          isEmpty: phoneNumber == null,
        ),
        SizedBox(height: isMobile ? 12 : 16),

        _buildEnhancedInfoCard(
          icon: Icons.business_rounded,
          title: 'Nama Perusahaan',
          value: companyName ?? 'Belum diatur',
          color: [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
          isMobile: isMobile,
          isEmpty: companyName == null,
        ),
        SizedBox(height: isMobile ? 12 : 16),

        _buildEnhancedInfoCard(
          icon: Icons.work_rounded,
          title: 'Bagian Unit Kerja',
          value: workUnit ?? 'Belum diatur',
          color: [const Color(0xFFE11D48), const Color(0xFFF43F5E)],
          isMobile: isMobile,
          isEmpty: workUnit == null,
        ),
        SizedBox(height: isMobile ? 12 : 16),

        _buildEnhancedInfoCard(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Peran & Izin',
          value: 'System Administrator',
          color: [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)],
          isMobile: isMobile,
        ),

        if (lastLogin != null) ...[
          SizedBox(height: isMobile ? 12 : 16),
          _buildEnhancedInfoCard(
            icon: Icons.access_time_rounded,
            title: 'Login Terakhir',
            value: _formatTimestamp(lastLogin),
            color: [_textSecondary, const Color(0xFF94A3B8)],
            isMobile: isMobile,
          ),
        ],
      ],
    );
  }

  Widget _buildEnhancedInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> color,
    required bool isMobile,
    bool isEmpty = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color[0].withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: color),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color[0].withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: isMobile ? 20 : 24, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: isEmpty ? _textSecondary : _textPrimary,
                      fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (isEmpty)
              Icon(Icons.edit_outlined, size: 16, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }
}

// Enhanced Custom Painter for Header Background Pattern
class EnhancedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..style = PaintingStyle.fill;

    // Multiple circles with different sizes and positions
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 70, paint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.8), 50, paint);
    canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.9), 35, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.2), 25, paint);

    // Additional smaller circles for more texture
    paint.color = Colors.white.withOpacity(0.05);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.1), 20, paint);
    canvas.drawCircle(Offset(size.width * 0.05, size.height * 0.5), 30, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.6), 15, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
