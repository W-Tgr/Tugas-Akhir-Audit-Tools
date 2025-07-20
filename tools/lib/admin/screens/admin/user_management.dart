import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tools/auth/auth_service.dart';
import 'package:tools/auth/login_screen.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Protected Admin Email - tidak bisa diubah rolenya
  static const String PROTECTED_ADMIN_EMAIL = 'admin@gmail.com';

  // Loading states
  bool _isLoading = false;
  String _loadingMessage = '';

  // Search only
  String _searchQuery = '';

  // Warna konsisten
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
    dotenv.load(fileName: ".env");
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Helper method untuk mengecek apakah user adalah protected admin
  bool _isProtectedAdmin(String email) {
    return email.toLowerCase() == PROTECTED_ADMIN_EMAIL.toLowerCase();
  }

  // Helper method untuk mengecek apakah current user adalah protected admin
  bool _isCurrentUserProtectedAdmin() {
    final user = _authService.getCurrentUser();
    return user != null && _isProtectedAdmin(user.email ?? '');
  }

  // Enhanced SnackBar with better styling
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

  // Show loading dialog
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _primaryBlue),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
    );
  }

  // Hide loading dialog
  void _hideLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _approveUser(String userId, String email) async {
    print('Mencoba menyetujui pengguna dengan ID: $userId, email: $email');

    _showLoadingDialog('Menyetujui pengguna...');

    try {
      if (dotenv.env['EMAIL_USER'] == null ||
          dotenv.env['EMAIL_PASSWORD'] == null) {
        throw Exception(
          'Kredensial email tidak ditemukan di .env. Pastikan file .env ada dan terisi.',
        );
      }

      // Auto-assign admin role if email matches protected admin
      String userRole = 'user';
      if (_isProtectedAdmin(email)) {
        userRole = 'admin'; // Protected admin memiliki role admin
      }

      await _firestore.collection('users').doc(userId).update({
        'status': 'approved',
        'role': userRole,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      final smtpServer = SmtpServer(
        'smtp.gmail.com',
        port: 587,
        ssl: false,
        username: dotenv.env['EMAIL_USER'],
        password: dotenv.env['EMAIL_PASSWORD'],
      );

      final message =
          Message()
            ..from = Address(dotenv.env['EMAIL_USER']!, 'Admin Tools')
            ..recipients.add(email)
            ..subject = 'Selamat! Akun Anda Telah Disetujui'
            ..text = '''
Halo,

Selamat! Akun Anda telah disetujui oleh administrator.

Detail Akun:
- Email: $email
- Status: Approved
- Role: ${_isProtectedAdmin(email) ? 'Admin' : 'User'}
- Tanggal Persetujuan: ${DateTime.now().toString().split('.')[0]}

Anda sekarang dapat mengakses semua fitur aplikasi dengan penuh.

Selamat bergabung dengan kami!

Salam,
Tim Administrator
        '''
            ..html = '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #1976D2, #2196F3); padding: 30px; border-radius: 12px; text-align: center; margin-bottom: 20px;">
    <h1 style="color: white; margin: 0; font-size: 24px;">Selamat! Akun Disetujui</h1>
  </div>
  
  <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
    <h3 style="color: #1976D2; margin-top: 0;">Detail Akun Anda:</h3>
    <p><strong>Email:</strong> $email</p>
    <p><strong>Status:</strong> <span style="color: #10B981; font-weight: bold;">Approved</span></p>
    <p><strong>Role:</strong> <span style="color: #2196F3; font-weight: bold;">${_isProtectedAdmin(email) ? 'Admin' : 'User'}</span></p>
    <p><strong>Tanggal Persetujuan:</strong> ${DateTime.now().toString().split('.')[0]}</p>
  </div>
  
  <p style="color: #4a5568; line-height: 1.6;">
    Akun Anda telah disetujui oleh administrator. Anda sekarang dapat mengakses semua fitur aplikasi dengan penuh.
  </p>
  
  <p style="color: #4a5568; line-height: 1.6;">
    Selamat bergabung dengan kami!
  </p>
  
  <div style="background: #e3f2fd; padding: 15px; border-radius: 8px; border-left: 4px solid #2196F3;">
    <p style="margin: 0; color: #1976D2; font-weight: 500;">
      Jika Anda memiliki pertanyaan, jangan ragu untuk menghubungi tim administrator.
    </p>
  </div>
  
  <p style="color: #718096; font-size: 14px; margin-top: 30px;">
    Salam,<br>
    <strong>Tim Administrator</strong>
  </p>
</div>
        ''';

      await send(message, smtpServer);

      _hideLoadingDialog();
      _showSnackBar(
        'Akun berhasil disetujui dan email notifikasi telah dikirim.',
        isSuccess: true,
      );
    } catch (e) {
      _hideLoadingDialog();
      print('Gagal menyetujui akun atau mengirim email: $e');
      _showSnackBar('Gagal menyetujui akun: ${e.toString()}', isError: true);
    }
  }

  Future<void> _rejectUser(String userId, String email) async {
    print('Mencoba menolak pengguna dengan ID: $userId, email: $email');

    // Tidak bisa menolak protected admin
    if (_isProtectedAdmin(email)) {
      _showSnackBar('Admin utama tidak dapat ditolak.', isError: true);
      return;
    }

    // Enhanced confirmation dialog
    final confirm = await _showEnhancedConfirmDialog(
      title: 'Konfirmasi Penolakan',
      content:
          'Apakah Anda yakin ingin menolak akun pengguna ini?\n\n'
          'Tindakan ini akan:\n'
          '• Menghapus akun dari sistem\n'
          '• Mengirim email notifikasi penolakan\n'
          '• Tidak dapat dibatalkan',
      confirmText: 'Tolak',
      isDestructive: true,
      icon: Icons.cancel,
    );

    if (confirm != true) return;

    _showLoadingDialog('Menolak pengguna...');

    try {
      if (dotenv.env['EMAIL_USER'] == null ||
          dotenv.env['EMAIL_PASSWORD'] == null) {
        throw Exception(
          'Kredensial email tidak ditemukan di .env. Pastikan file .env ada dan terisi.',
        );
      }

      // Send rejection email first
      final smtpServer = SmtpServer(
        'smtp.gmail.com',
        port: 587,
        ssl: false,
        username: dotenv.env['EMAIL_USER'],
        password: dotenv.env['EMAIL_PASSWORD'],
      );

      final message =
          Message()
            ..from = Address(dotenv.env['EMAIL_USER']!, 'Admin Tools')
            ..recipients.add(email)
            ..subject = 'Informasi Status Akun Anda'
            ..text = '''
Halo,

Terima kasih atas minat Anda untuk bergabung dengan aplikasi kami.

Mohon maaf, setelah melalui proses review, akun Anda tidak dapat disetujui pada saat ini.

Jika Anda merasa ini adalah kesalahan atau memiliki pertanyaan lebih lanjut, silakan hubungi tim administrator untuk informasi lebih detail.

Terima kasih atas pengertian Anda.

Salam,
Tim Administrator
        '''
            ..html = '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #EF4444, #F87171); padding: 30px; border-radius: 12px; text-align: center; margin-bottom: 20px;">
    <h1 style="color: white; margin: 0; font-size: 24px;">Informasi Status Akun</h1>
  </div>
  
  <p style="color: #4a5568; line-height: 1.6;">
    Terima kasih atas minat Anda untuk bergabung dengan aplikasi kami.
  </p>
  
  <div style="background: #fef2f2; padding: 20px; border-radius: 8px; border-left: 4px solid #EF4444; margin: 20px 0;">
    <p style="margin: 0; color: #7f1d1d;">
      Mohon maaf, setelah melalui proses review, akun Anda tidak dapat disetujui pada saat ini.
    </p>
  </div>
  
  <p style="color: #4a5568; line-height: 1.6;">
    Jika Anda merasa ini adalah kesalahan atau memiliki pertanyaan lebih lanjut, silakan hubungi tim administrator untuk informasi lebih detail.
  </p>
  
  <div style="background: #f0f9ff; padding: 15px; border-radius: 8px; border-left: 4px solid #0ea5e9;">
    <p style="margin: 0; color: #0c4a6e; font-weight: 500;">
      Terima kasih atas pengertian Anda.
    </p>
  </div>
  
  <p style="color: #718096; font-size: 14px; margin-top: 30px;">
    Salam,<br>
    <strong>Tim Administrator</strong>
  </p>
</div>
        ''';

      await send(message, smtpServer);

      // Delete account after email is sent
      await _firestore.collection('users').doc(userId).delete();

      _hideLoadingDialog();
      _showSnackBar(
        'Akun ditolak, email notifikasi telah dikirim, dan akun telah dihapus.',
        isSuccess: true,
      );
    } catch (e) {
      _hideLoadingDialog();
      print('Gagal menolak akun atau mengirim email: $e');
      _showSnackBar('Gagal menolak akun: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteUser(String userId, String email) async {
    print('Mencoba menghapus pengguna dengan ID: $userId, email: $email');

    // Tidak bisa menghapus protected admin
    if (_isProtectedAdmin(email)) {
      _showSnackBar('Admin utama tidak dapat dihapus.', isError: true);
      return;
    }

    final confirm = await _showEnhancedConfirmDialog(
      title: 'Konfirmasi Penghapusan',
      content:
          'Apakah Anda yakin ingin menghapus pengguna ini?\n\n'
          'Tindakan ini akan:\n'
          '• Menghapus akun secara permanen\n'
          '• Menghapus semua data terkait\n'
          '• Tidak dapat dibatalkan',
      confirmText: 'Hapus',
      isDestructive: true,
      icon: Icons.delete,
    );

    if (confirm != true) return;

    _showLoadingDialog('Menghapus pengguna...');

    try {
      await _firestore.collection('users').doc(userId).delete();

      _hideLoadingDialog();
      _showSnackBar('Pengguna berhasil dihapus.', isSuccess: true);
    } catch (e) {
      _hideLoadingDialog();
      print('Gagal menghapus pengguna: $e');
      if (e is FirebaseException) {
        _showSnackBar(
          'Gagal menghapus pengguna: ${e.message} (Kode: ${e.code})',
          isError: true,
        );
      } else {
        _showSnackBar(
          'Gagal menghapus pengguna: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _editRole(
    String userId,
    String email,
    String currentRole,
  ) async {
    print(
      'Mencoba mengubah role pengguna dengan ID: $userId, email: $email, role saat ini: $currentRole',
    );

    // Tidak bisa mengubah role protected admin
    if (_isProtectedAdmin(email)) {
      _showSnackBar('Role admin utama tidak dapat diubah.', isError: true);
      return;
    }

    // Hanya protected admin yang bisa mengubah role admin lain
    if (currentRole == 'admin' && !_isCurrentUserProtectedAdmin()) {
      _showSnackBar(
        'Hanya admin utama yang dapat mengubah role Administrator.',
        isError: true,
      );
      return;
    }

    String newRole = currentRole;
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: EdgeInsets.zero,
            content: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.2, 0.5, 0.9],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ubah Role Pengguna',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email: $email',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StatefulBuilder(
                          builder: (context, setState) {
                            return DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Role',
                                labelStyle: TextStyle(color: _textSecondary),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _primaryBlue.withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _primaryBlue.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _primaryBlue,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  newRole == 'admin'
                                      ? Icons.admin_panel_settings
                                      : Icons.person,
                                  color: _primaryBlue,
                                ),
                              ),
                              style: TextStyle(color: _textPrimary),
                              value: newRole,
                              items: [
                                DropdownMenuItem(
                                  value: 'user',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: _primaryBlue,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('User'),
                                    ],
                                  ),
                                ),
                                // Hanya protected admin yang bisa menambah admin baru
                                if (_isCurrentUserProtectedAdmin())
                                  DropdownMenuItem(
                                    value: 'admin',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.admin_panel_settings,
                                          color: _primaryBlue,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Admin'),
                                      ],
                                    ),
                                  ),
                              ],
                              onChanged: (String? value) {
                                setState(() {
                                  newRole = value!;
                                });
                              },
                            );
                          },
                        ),
                        if (!_isCurrentUserProtectedAdmin())
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Catatan: Hanya admin utama yang dapat mengubah role menjadi Admin.',
                              style: TextStyle(
                                color: _warningColor,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Batal',
                            style: TextStyle(color: _textSecondary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_darkBlue, _primaryBlue],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryBlue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('Simpan'),
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

    if (result != true) return;

    _showLoadingDialog('Mengubah role...');

    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      });

      final smtpServer = SmtpServer(
        'smtp.gmail.com',
        port: 587,
        ssl: false,
        username: dotenv.env['EMAIL_USER'],
        password: dotenv.env['EMAIL_PASSWORD'],
      );

      final roleDisplayName = newRole == 'admin' ? 'Administrator' : 'User';

      final message =
          Message()
            ..from = Address(dotenv.env['EMAIL_USER']!, 'Admin Tools')
            ..recipients.add(email)
            ..subject = 'Perubahan Role Akun Anda'
            ..html = '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #1976D2, #2196F3); padding: 30px; border-radius: 12px; text-align: center; margin-bottom: 20px;">
    <h1 style="color: white; margin: 0; font-size: 24px;">Perubahan Role Akun</h1>
  </div>
  
  <div style="background: #f8f9fa; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
    <h3 style="color: #1976D2; margin-top: 0;">Informasi Akun:</h3>
    <p><strong>Email:</strong> $email</p>
    <p><strong>Role Baru:</strong> <span style="color: #10B981; font-weight: bold;">$roleDisplayName</span></p>
    <p><strong>Tanggal Perubahan:</strong> ${DateTime.now().toString().split('.')[0]}</p>
  </div>
  
  <p style="color: #4a5568; line-height: 1.6;">
    Role akun Anda telah diperbarui oleh administrator. Perubahan ini akan berlaku segera.
  </p>
  
  <div style="background: #e3f2fd; padding: 15px; border-radius: 8px;">
    <p style="margin: 0; color: #1976D2; font-weight: 500;">
      Jika Anda memiliki pertanyaan tentang perubahan ini, silakan hubungi tim administrator.
    </p>
  </div>
  
  <p style="color: #718096; font-size: 14px; margin-top: 30px;">
    Salam,<br>
    <strong>Tim Administrator</strong>
  </p>
</div>
        ''';

      await send(message, smtpServer);

      _hideLoadingDialog();
      _showSnackBar(
        'Role berhasil diubah dan email notifikasi telah dikirim.',
        isSuccess: true,
      );
    } catch (e) {
      _hideLoadingDialog();
      print('Gagal mengubah role: $e');
      _showSnackBar('Gagal mengubah role: ${e.toString()}', isError: true);
    }
  }

  Future<bool?> _showEnhancedConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required IconData icon,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: EdgeInsets.zero,
            content: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            isDestructive
                                ? [
                                  const Color(0xFFEF4444),
                                  const Color(0xFFF87171),
                                ]
                                : _gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      content,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Batal',
                            style: TextStyle(color: _textSecondary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors:
                                  isDestructive
                                      ? [
                                        const Color(0xFFEF4444),
                                        const Color(0xFFF87171),
                                      ]
                                      : [_darkBlue, _primaryBlue],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (isDestructive
                                        ? Colors.red
                                        : _primaryBlue)
                                    .withOpacity(0.3),
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(confirmText),
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

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();
    if (user == null) {
      return const LoginScreen();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;

        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
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

            if (userSnapshot.hasError ||
                !userSnapshot.hasData ||
                !userSnapshot.data!.exists) {
              return Scaffold(
                backgroundColor: _backgroundColor,
                appBar: AppBar(
                  title: Text(
                    'Kelola Pengguna',
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

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            if (userData['role'] != 'admin') {
              return Scaffold(
                backgroundColor: _backgroundColor,
                appBar: AppBar(
                  title: Text(
                    'Kelola Pengguna',
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
                        'Hanya administrator yang dapat mengelola pengguna.',
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

            // Auto-approve current admin if needed
            if (userData['status'] != 'approved') {
              _firestore.collection('users').doc(user.uid).update({
                'status': 'approved',
              });
            }

            // Auto-set protected admin role if needed
            if (_isProtectedAdmin(user.email ?? '') &&
                userData['role'] != 'admin') {
              _firestore.collection('users').doc(user.uid).update({
                'role': 'admin',
              });
            }

            return Scaffold(
              backgroundColor: _backgroundColor,
              appBar: AppBar(
                title: Text(
                  'Kelola Pengguna',
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
                    child: Column(
                      children: [
                        // Users list
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _firestore.collection('users').snapshots(),
                            builder: (context, usersSnapshot) {
                              if (usersSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        color: _primaryBlue,
                                      ),
                                      SizedBox(height: isMobile ? 12 : 16),
                                      Text(
                                        'Memuat daftar pengguna...',
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: isMobile ? 14 : 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (usersSnapshot.hasError) {
                                return Center(
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
                                        'Terjadi kesalahan saat memuat daftar pengguna.',
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontSize: isMobile ? 14 : 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (!usersSnapshot.hasData ||
                                  usersSnapshot.data!.docs.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: isMobile ? 48 : 64,
                                        color: _textSecondary.withOpacity(0.5),
                                      ),
                                      SizedBox(height: isMobile ? 12 : 16),
                                      Text(
                                        'Tidak ada pengguna yang tersedia.',
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontSize: isMobile ? 16 : 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final allUsers = usersSnapshot.data!.docs;

                              if (allUsers.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: isMobile ? 48 : 64,
                                        color: _textSecondary.withOpacity(0.5),
                                      ),
                                      SizedBox(height: isMobile ? 12 : 16),
                                      Text(
                                        'Tidak ada pengguna yang tersedia.',
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontSize: isMobile ? 16 : 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return RefreshIndicator(
                                color: _primaryBlue,
                                onRefresh: () async {
                                  setState(() {});
                                },
                                child: ListView.builder(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 20,
                                    vertical: isMobile ? 8 : 12,
                                  ),
                                  itemCount: allUsers.length,
                                  itemBuilder: (context, index) {
                                    final userDoc = allUsers[index];
                                    final userId = userDoc.id;
                                    final data =
                                        userDoc.data() as Map<String, dynamic>;
                                    final userEmail =
                                        data['email'] ?? 'Unknown';
                                    final userStatus =
                                        data['status'] ?? 'pending';
                                    final userRole = data['role'] ?? 'user';

                                    final isCurrentAdmin = userId == user.uid;
                                    final isProtectedAdmin = _isProtectedAdmin(
                                      userEmail,
                                    );
                                    final canApprove =
                                        userStatus == 'pending' &&
                                        !isCurrentAdmin &&
                                        !isProtectedAdmin;

                                    return _buildUserCard(
                                      userId,
                                      userEmail,
                                      userStatus,
                                      userRole,
                                      isCurrentAdmin,
                                      isProtectedAdmin,
                                      canApprove,
                                      isMobile,
                                    );
                                  },
                                ),
                              );
                            },
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

  Widget _buildUserCard(
    String userId,
    String userEmail,
    String userStatus,
    String userRole,
    bool isCurrentAdmin,
    bool isProtectedAdmin,
    bool canApprove,
    bool isMobile,
  ) {
    Color statusColor;
    IconData statusIcon;

    switch (userStatus) {
      case 'approved':
        statusColor = _successColor;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = _errorColor;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = _warningColor;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border:
            isProtectedAdmin
                ? Border.all(color: _primaryBlue.withOpacity(0.5), width: 2)
                : null,
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
                  ? _buildMobileUserContent(
                    userId,
                    userEmail,
                    userStatus,
                    userRole,
                    isCurrentAdmin,
                    isProtectedAdmin,
                    canApprove,
                    statusColor,
                    statusIcon,
                  )
                  : _buildDesktopUserContent(
                    userId,
                    userEmail,
                    userStatus,
                    userRole,
                    isCurrentAdmin,
                    isProtectedAdmin,
                    canApprove,
                    statusColor,
                    statusIcon,
                  ),
        ),
      ),
    );
  }

  Widget _buildMobileUserContent(
    String userId,
    String userEmail,
    String userStatus,
    String userRole,
    bool isCurrentAdmin,
    bool isProtectedAdmin,
    bool canApprove,
    Color statusColor,
    IconData statusIcon,
  ) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User avatar
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradientColors),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isProtectedAdmin
                    ? Icons.security
                    : userRole == 'admin'
                    ? Icons.admin_panel_settings
                    : Icons.person,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userEmail,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        userStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isProtectedAdmin && userRole == 'admin'
                              ? 'ADMIN UTAMA'
                              : userRole.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _primaryBlue,
                          ),
                        ),
                      ),
                      if (isCurrentAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _successColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        // Actions untuk mobile
        if (canApprove || (!isCurrentAdmin && !isProtectedAdmin)) ...[
          const SizedBox(height: 12),
          if (canApprove)
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: _successColor.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _approveUser(userId, userEmail),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text(
                        'Setujui',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: _errorColor.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () => _rejectUser(userId, userEmail),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text(
                        'Tolak',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (!isCurrentAdmin && !isProtectedAdmin)
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
                    onPressed: () => _editRole(userId, userEmail, userRole),
                    tooltip: 'Edit Role',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: _errorColor),
                    iconSize: 20,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () => _deleteUser(userId, userEmail),
                    tooltip: 'Hapus User',
                  ),
                ),
              ],
            ),
        ],
        // Message for protected admin
        if (isProtectedAdmin && !isCurrentAdmin) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _primaryBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, size: 14, color: _primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Admin utama tidak dapat diubah',
                    style: TextStyle(
                      fontSize: 11,
                      color: _primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopUserContent(
    String userId,
    String userEmail,
    String userStatus,
    String userRole,
    bool isCurrentAdmin,
    bool isProtectedAdmin,
    bool canApprove,
    Color statusColor,
    IconData statusIcon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // User avatar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _gradientColors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isProtectedAdmin
                ? Icons.security
                : userRole == 'admin'
                ? Icons.admin_panel_settings
                : Icons.person,
            size: 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        // User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      userEmail,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  if (isCurrentAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'YOU',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _successColor,
                        ),
                      ),
                    ),
                  if (isProtectedAdmin) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.security, size: 12, color: _primaryBlue),
                          const SizedBox(width: 4),
                          Text(
                            'UTAMA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    'Status: ${userStatus.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Role: ${isProtectedAdmin && userRole == 'admin' ? 'ADMIN UTAMA' : userRole.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Actions
        if (canApprove)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _successColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => _approveUser(userId, userEmail),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Setujui'),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _errorColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => _rejectUser(userId, userEmail),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Tolak'),
                ),
              ),
            ],
          )
        else if (!isCurrentAdmin && !isProtectedAdmin)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: _primaryBlue, size: 24),
                onPressed: () => _editRole(userId, userEmail, userRole),
                tooltip: 'Edit Role',
              ),
              IconButton(
                icon: Icon(Icons.delete, color: _errorColor, size: 24),
                onPressed: () => _deleteUser(userId, userEmail),
                tooltip: 'Hapus User',
              ),
            ],
          )
        else if (isProtectedAdmin && !isCurrentAdmin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primaryBlue.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 16, color: _primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'Admin utama tidak dapat diubah',
                  style: TextStyle(
                    fontSize: 12,
                    color: _primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
