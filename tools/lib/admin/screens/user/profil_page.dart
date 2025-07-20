import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:tools/auth/login_screen.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  File? _image;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Stream for real-time profile data
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;

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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    print('User UID: ${user?.uid}');
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
    } else {
      _initializeProfileStream();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Initialize real-time profile stream
  void _initializeProfileStream() {
    if (user == null) return;

    _profileStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots();
  }

  // Create user document if it doesn't exist
  Future<void> _createUserDocumentIfNeeded() async {
    if (user == null) return;

    try {
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid);

      final doc = await userDocRef.get();

      if (!doc.exists) {
        final displayName = user!.displayName ?? user!.email!.split('@')[0];

        // Hanya gunakan field yang diizinkan oleh Firestore rules
        await userDocRef.set({
          'email': user!.email,
          'displayName': displayName,
          'photoBase64': null,
          'status': 'active', // Field yang diizinkan
          'phoneNumber': null,
          'companyName': null,
          'workUnit': null,
        });

        print('User document created successfully');
      }
    } catch (e) {
      print('Error creating user document: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null || user == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      print('Uploading image for UID: ${user!.uid}');

      // Kompresi gambar
      final compressedImage = await FlutterImageCompress.compressWithFile(
        _image!.path,
        minWidth: 300,
        minHeight: 300,
        quality: 60,
      );

      if (compressedImage == null) {
        throw Exception('Gagal mengompresi gambar');
      }

      // Konversi gambar yang sudah dikompresi ke Base64
      final base64Image = base64Encode(compressedImage);
      print('Compressed image size (Base64 length): ${base64Image.length}');

      // Periksa ukuran Base64 (dalam byte, kira-kira)
      final base64SizeInBytes = (base64Image.length * 3 / 4).round();
      print('Estimated Base64 size (bytes): $base64SizeInBytes');
      if (base64SizeInBytes > 900000) {
        throw Exception(
          'Ukuran gambar terlalu besar setelah kompresi: ${base64SizeInBytes / 1000} KB',
        );
      }

      // Update foto profil - Hanya field yang diizinkan rules
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid);

      await userDocRef.update({
        'photoBase64': base64Image,
        // Hapus updatedAt karena tidak diizinkan rules
      });

      setState(() {
        _image = null;
        _isUploadingImage = false;
      });

      _showSnackBar('Foto profil berhasil diperbarui!');
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _isUploadingImage = false;
      });
      _showSnackBar('Gagal mengunggah foto: $e', isError: true);
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

  void _showFullProfileImage(BuildContext context, String imageBase64) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Hero(
                      tag: 'profileImage',
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.7,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: _darkBlue.withOpacity(0.3),
                              blurRadius: 25,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.memory(
                            base64Decode(imageBase64),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.black.withOpacity(0.5),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 24,
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
  }

  Future<void> _showEditProfileDialog(Map<String, dynamic> currentData) async {
    final displayNameController = TextEditingController(
      text: currentData['displayName'] ?? user!.email!.split('@')[0],
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

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(28),
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryBlue, _lightBlue],
                        ),
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
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Edit Profil',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Perbarui informasi profil Anda',
                      style: TextStyle(fontSize: 14, color: _textSecondary),
                    ),
                    const SizedBox(height: 24),

                    // Form fields
                    Form(
                      key: formKey,
                      child: Column(
                        children: [
                          _buildEnhancedTextField(
                            controller: displayNameController,
                            label: 'Nama Pengguna',
                            icon: Icons.person_rounded,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama pengguna tidak boleh kosong';
                              }
                              if (value.trim().length < 3) {
                                return 'Nama pengguna minimal 3 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildEnhancedTextField(
                            controller: phoneNumberController,
                            label: 'Nomor HP',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
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
                            label: 'Nama Perusahaan',
                            icon: Icons.business_rounded,
                          ),
                          const SizedBox(height: 16),

                          _buildEnhancedTextField(
                            controller: workUnitController,
                            label: 'Bagian Unit Kerja',
                            icon: Icons.work_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Action buttons
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
                              onPressed: () => Navigator.pop(context),
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
                            child: ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  try {
                                    final userDocRef = FirebaseFirestore
                                        .instance
                                        .collection('users')
                                        .doc(user!.uid);

                                    // Update data - Hanya field yang diizinkan rules
                                    final updateData = {
                                      'displayName':
                                          displayNameController.text.trim(),
                                      'phoneNumber':
                                          phoneNumberController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : phoneNumberController.text
                                                  .trim(),
                                      'companyName':
                                          companyNameController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : companyNameController.text
                                                  .trim(),
                                      'workUnit':
                                          workUnitController.text.trim().isEmpty
                                              ? null
                                              : workUnitController.text.trim(),
                                      // Hapus updatedAt karena tidak diizinkan rules
                                    };

                                    await userDocRef.update(updateData);
                                    await user!.updateDisplayName(
                                      displayNameController.text.trim(),
                                    );

                                    setState(() {
                                      _isLoading = false;
                                    });

                                    Navigator.pop(context);
                                    _showSnackBar(
                                      'Profil berhasil diperbarui!',
                                    );
                                  } catch (e) {
                                    print('Error updating profile: $e');
                                    setState(() {
                                      _isLoading = false;
                                    });
                                    _showSnackBar(
                                      'Gagal memperbarui profil: $e',
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
                                  _isLoading
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
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textSecondary),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_primaryBlue, _lightBlue]),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
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
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
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
            // Handle connection states
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            // Handle document existence
            Map<String, dynamic> profileData = {};
            if (snapshot.hasData && snapshot.data!.exists) {
              profileData = snapshot.data!.data()!;
            } else {
              // Create document if it doesn't exist
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_primaryBlue, _lightBlue]),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Memuat profil...',
            style: TextStyle(
              fontSize: 16,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Terjadi Kesalahan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _textSecondary),
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
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> profileData) {
    final userName = profileData['displayName'] ?? user!.email!.split('@')[0];
    final userEmail = user?.email ?? 'email@example.com';
    final imageBase64 = profileData['photoBase64'];
    final phoneNumber = profileData['phoneNumber'];
    final companyName = profileData['companyName'];
    final workUnit = profileData['workUnit'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final fontScale = isMobile ? 0.9 : 1.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Standard header with modern gradient
              Container(
                width: double.infinity,
                height: 120,
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
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: _basePadding),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profil Saya',
                                style: TextStyle(
                                  fontSize: 24 * fontScale,
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Profile content with enhanced design
              Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: _basePadding),
                  child: Column(
                    children: [
                      // Enhanced profile image dengan edit functionality
                      GestureDetector(
                        onTap:
                            imageBase64 != null
                                ? () =>
                                    _showFullProfileImage(context, imageBase64)
                                : null,
                        child: Hero(
                          tag: 'profileImage',
                          child: Stack(
                            children: [
                              Container(
                                height: 140,
                                width: 140,
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
                                      blurRadius: 25,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [_lightBlue, _accentBlue],
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  child: CircleAvatar(
                                    radius: 62,
                                    backgroundColor: _surfaceColor,
                                    backgroundImage:
                                        _image != null
                                            ? FileImage(_image!)
                                            : imageBase64 != null
                                            ? MemoryImage(
                                                  base64Decode(imageBase64),
                                                )
                                                as ImageProvider
                                            : null,
                                    child:
                                        _image == null && imageBase64 == null
                                            ? Text(
                                              userName.isNotEmpty
                                                  ? userName[0].toUpperCase()
                                                  : 'U',
                                              style: TextStyle(
                                                fontSize: 48,
                                                fontWeight: FontWeight.bold,
                                                color: _primaryBlue,
                                              ),
                                            )
                                            : null,
                                  ),
                                ),
                              ),

                              // Camera button untuk upload foto
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [_primaryBlue, _lightBlue],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _primaryBlue.withOpacity(0.4),
                                          blurRadius: 15,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
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

                              // View photo indicator
                              if (imageBase64 != null)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.7),
                                          Colors.black.withOpacity(0.5),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.visibility_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // User name
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // User email
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 16,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Enhanced edit profile button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_darkBlue, _primaryBlue, _lightBlue],
                          ),
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
                          label: const Text(
                            'Edit Profil',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Info Section with enhanced cards
                      _buildEnhancedInfoSection(
                        fontScale,
                        userName,
                        phoneNumber,
                        companyName,
                        workUnit,
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnhancedInfoSection(
    double fontScale,
    String userName,
    String? phoneNumber,
    String? companyName,
    String? workUnit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Row(
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
              'Informasi Profil',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Info cards
        _buildEnhancedInfoCard(
          icon: Icons.person_rounded,
          title: 'Nama Pengguna',
          value: userName,
          gradient: [_primaryBlue, _lightBlue],
          fontScale: fontScale,
        ),
        const SizedBox(height: 16),

        _buildEnhancedInfoCard(
          icon: Icons.phone_rounded,
          title: 'Nomor HP',
          value: phoneNumber ?? 'Belum diatur',
          gradient: [const Color(0xFF10B981), const Color(0xFF34D399)],
          fontScale: fontScale,
        ),
        const SizedBox(height: 16),

        _buildEnhancedInfoCard(
          icon: Icons.business_rounded,
          title: 'Nama Perusahaan',
          value: companyName ?? 'Belum diatur',
          gradient: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
          fontScale: fontScale,
        ),
        const SizedBox(height: 16),

        _buildEnhancedInfoCard(
          icon: Icons.work_rounded,
          title: 'Bagian Unit Kerja',
          value: workUnit ?? 'Belum diatur',
          gradient: [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
          fontScale: fontScale,
        ),
      ],
    );
  }

  Widget _buildEnhancedInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> gradient,
    required double fontScale,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: gradient[0].withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.08),
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
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                      letterSpacing: 0.3,
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
