import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tools/admin/models/retake_request.dart';
import 'package:tools/admin/services/retake_request_services.dart';
import 'package:tools/auth/auth_service.dart';

class RetakeApprovalPage extends StatefulWidget {
  const RetakeApprovalPage({super.key});

  @override
  State<RetakeApprovalPage> createState() => _RetakeApprovalPageState();
}

class _RetakeApprovalPageState extends State<RetakeApprovalPage>
    with SingleTickerProviderStateMixin {
  final RetakeRequestService _requestService = RetakeRequestService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _selectedUserId;
  String? _selectedCompanyName;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  List<String> _companies = [];
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
    _loadUsersAndCompanies();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUsersAndCompanies() async {
    try {
      final userDocs =
          await FirebaseFirestore.instance.collection('users').get();
      final companies = <String>{};
      setState(() {
        _users =
            userDocs.docs.map((doc) {
              final data = doc.data();
              final companyName =
                  data['companyName'] as String? ?? 'Tidak Diketahui';
              if (companyName.isNotEmpty && companyName != 'Tidak Diketahui') {
                companies.add(companyName);
              }
              return {
                'userId': doc.id,
                'email': data['email'] ?? doc.id,
                'displayName': data['displayName'] ?? '',
                'companyName': companyName,
              };
            }).toList();
        _companies = companies.toList()..sort();
        _filteredUsers = _users;
      });
      print('Loaded ${_users.length} users and ${_companies.length} companies');
    } catch (e) {
      print('Error loading users and companies: $e');
      _showSnackBar('Gagal memuat daftar pengguna dan perusahaan: $e');
    }
  }

  void _updateFilteredUsers() {
    setState(() {
      if (_selectedCompanyName == null) {
        _filteredUsers = _users;
      } else {
        _filteredUsers =
            _users
                .where((user) => user['companyName'] == _selectedCompanyName)
                .toList();
      }
      if (_selectedUserId != null &&
          !_filteredUsers.any((user) => user['userId'] == _selectedUserId)) {
        _selectedUserId = null;
      }
      print(
        'Filtered users: ${_filteredUsers.length} for company: $_selectedCompanyName',
      );
    });
  }

  Future<bool> _checkAdmin() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      print('Tidak ada pengguna yang login');
      return false;
    }
    print('Memeriksa pengguna: ${user.uid}, email: ${user.email}');
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    final userData = userDoc.data();
    print('Data pengguna: $userData');
    final isAdmin = userDoc.exists && userData?['role'] == 'admin';
    print('Pengguna ${user.uid} adalah admin: $isAdmin');
    return isAdmin;
  }

  Future<void> _updateStatus(String requestId, String status) async {
    final user = _authService.getCurrentUser();
    print(
      'Mencoba update requestId: $requestId, status: $status oleh pengguna: ${user?.uid}',
    );
    if (!(await _checkAdmin())) {
      _showSnackBar('Hanya admin yang dapat mengelola permintaan retake');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _requestService.updateRetakeRequestStatus(requestId, status);
      final requestDoc =
          await FirebaseFirestore.instance
              .collection('retakeRequests')
              .doc(requestId)
              .get();
      if (!requestDoc.exists) {
        throw Exception('Dokumen retake tidak ditemukan');
      }
      final userId = requestDoc['userId'] as String;
      final levelId = requestDoc['levelId'] as String;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'message':
                'Permintaan retake untuk level $levelId telah ${status == 'approved' ? 'disetujui' : 'ditolak'}.',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
      _showSnackBar(
        'Permintaan retake ${status == 'approved' ? 'disetujui' : 'ditolak'}',
      );
    } catch (e) {
      print('Gagal memperbarui status permintaan: $e');
      _showSnackBar('Gagal memperbarui: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRequest(String requestId) async {
    final user = _authService.getCurrentUser();
    print('Mencoba hapus requestId: $requestId oleh pengguna: ${user?.uid}');
    if (!(await _checkAdmin())) {
      _showSnackBar('Hanya admin yang dapat menghapus permintaan retake');
      return;
    }

    final confirm = await _showConfirmDialog(
      'Hapus Permintaan',
      'Apakah Anda yakin ingin menghapus permintaan ini?',
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      await _requestService.deleteRetakeRequest(requestId);
      _showSnackBar('Permintaan retake dihapus');
    } catch (e) {
      print('Gagal menghapus permintaan: $e');
      _showSnackBar('Gagal menghapus: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            final isMobile = MediaQuery.of(context).size.width < 600;

            return AlertDialog(
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
                          Expanded(
                            child: Text(
                              title,
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
                    // Content
                    Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      child: Text(
                        content,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                    ),
                    // Actions
                    Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(
                                isMobile ? 8 : 12,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
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
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                'Hapus',
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
          },
        ) ??
        false;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      final isMobile = MediaQuery.of(context).size.width < 600;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16),
          ),
          backgroundColor: _darkBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          ),
          margin: EdgeInsets.all(isMobile ? 12 : 16),
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _fetchRequestDetails(
    RetakeRequestModel request,
  ) async {
    try {
      final levelDoc =
          await FirebaseFirestore.instance
              .collection('levels')
              .doc(request.levelId)
              .get();
      if (!levelDoc.exists) {
        return {'error': 'Level tidak ditemukan'};
      }
      final levelData = levelDoc.data()!;
      final categoryId = levelData['categoryId'] as String;
      final levelNumber = levelData['levelNumber'] as int;

      final categoryDoc =
          await FirebaseFirestore.instance
              .collection('categories')
              .doc(categoryId)
              .get();
      if (!categoryDoc.exists) {
        return {'error': 'Category tidak ditemukan'};
      }
      final categoryData = categoryDoc.data()!;
      final domainId = categoryData['domainId'] as String;
      final categoryName = categoryData['name'] as String;

      final domainDoc =
          await FirebaseFirestore.instance
              .collection('domains')
              .doc(domainId)
              .get();
      if (!domainDoc.exists) {
        return {'error': 'Domain tidak ditemukan'};
      }
      final domainName = domainDoc.data()!['name'] as String;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(request.userId)
              .get();
      final userEmail =
          userDoc.exists
              ? userDoc.data()!['email'] ?? request.userId
              : request.userId;
      final displayName =
          userDoc.exists ? userDoc.data()!['displayName'] ?? '' : '';

      return {
        'userEmail': userEmail,
        'displayName': displayName,
        'domainId': domainId,
        'domainName': domainName,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'levelNumber': levelNumber,
      };
    } catch (e) {
      print('Error fetching request details for request ${request.id}: $e');
      return {'error': 'Gagal memuat detail'};
    }
  }

  List<RetakeRequestModel> _filterRequests(List<RetakeRequestModel> requests) {
    var filtered = requests;

    if (_selectedCompanyName != null) {
      final companyUsers =
          _users
              .where((user) => user['companyName'] == _selectedCompanyName)
              .map((u) => u['userId'])
              .toSet();
      filtered =
          filtered.where((r) => companyUsers.contains(r.userId)).toList();
    }

    if (_selectedUserId != null) {
      filtered = filtered.where((r) => r.userId == _selectedUserId).toList();
    }

    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return _textSecondary;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Tidak Diketahui';
    }
  }

  Widget _buildRequestCard(
    RetakeRequestModel request,
    Map<String, dynamic> details,
    bool isMobile,
    bool isTablet,
  ) {
    if (details.containsKey('error')) {
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
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Text(
            'Error: ${details['error']}',
            style: TextStyle(color: Colors.red, fontSize: isMobile ? 12 : 14),
          ),
        ),
      );
    }

    final userEmail = details['userEmail'] as String;
    final displayName = details['displayName'] as String;
    final domainName = details['domainName'] as String;
    final categoryName = details['categoryName'] as String;
    final levelNumber = details['levelNumber'] as int;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user info and status
              isMobile
                  ? _buildMobileHeader(
                    userEmail,
                    displayName,
                    request.status,
                    isMobile,
                  )
                  : _buildDesktopHeader(
                    userEmail,
                    displayName,
                    request.status,
                    isTablet,
                  ),
              SizedBox(height: isMobile ? 12 : 16),

              // Request details
              Container(
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.domain,
                      'Domain',
                      domainName,
                      isMobile,
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                    _buildDetailRow(
                      Icons.category,
                      'Category',
                      categoryName,
                      isMobile,
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                    _buildDetailRow(
                      Icons.layers,
                      'Level',
                      'Level $levelNumber',
                      isMobile,
                    ),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 12 : 16),

              // Action buttons
              _buildActionButtons(request, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(
    String userEmail,
    String displayName,
    String status,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 8 : 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradientColors),
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
              ),
              child: Icon(
                Icons.person,
                size: isMobile ? 18 : 24,
                color: Colors.white,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName.isNotEmpty ? displayName : userEmail,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                      color: _textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (displayName.isNotEmpty)
                    Text(
                      userEmail,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: isMobile ? 10 : 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12,
            vertical: isMobile ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(isMobile ? 12 : 20),
            border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
          ),
          child: Text(
            _getStatusText(status),
            style: TextStyle(
              color: _getStatusColor(status),
              fontWeight: FontWeight.w500,
              fontSize: isMobile ? 10 : 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(
    String userEmail,
    String displayName,
    String status,
    bool isTablet,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isTablet ? 10 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _gradientColors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.person,
            size: isTablet ? 20 : 24,
            color: Colors.white,
          ),
        ),
        SizedBox(width: isTablet ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isNotEmpty ? displayName : userEmail,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 14 : 16,
                  color: _textPrimary,
                ),
              ),
              if (displayName.isNotEmpty)
                Text(
                  userEmail,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: isTablet ? 11 : 12,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 10 : 12,
            vertical: isTablet ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
          ),
          child: Text(
            _getStatusText(status),
            style: TextStyle(
              color: _getStatusColor(status),
              fontWeight: FontWeight.w500,
              fontSize: isTablet ? 11 : 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    bool isMobile,
  ) {
    return Row(
      children: [
        Icon(icon, size: isMobile ? 14 : 16, color: _textSecondary),
        SizedBox(width: isMobile ? 6 : 8),
        Text(
          '$label:',
          style: TextStyle(color: _textSecondary, fontSize: isMobile ? 11 : 13),
        ),
        SizedBox(width: isMobile ? 6 : 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: isMobile ? 11 : 13,
              color: _textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(RetakeRequestModel request, bool isMobile) {
    if (isMobile) {
      // Stack buttons vertically on mobile for pending requests
      if (request.status == 'pending') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed:
                    _isLoading
                        ? null
                        : () => _updateStatus(request.id, 'approved'),
                child: Text(
                  'Setujui',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed:
                    _isLoading
                        ? null
                        : () => _updateStatus(request.id, 'rejected'),
                child: Text(
                  'Tolak',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        );
      } else {
        // Delete button for completed requests
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFF87171)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(8),
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
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _isLoading ? null : () => _deleteRequest(request.id),
            child: Text(
              'Hapus',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        );
      }
    } else {
      // Horizontal layout for tablet/desktop
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (request.status == 'pending') ...[
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
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
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onPressed:
                    _isLoading
                        ? null
                        : () => _updateStatus(request.id, 'rejected'),
                child: const Text('Tolak'),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
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
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onPressed:
                    _isLoading
                        ? null
                        : () => _updateStatus(request.id, 'approved'),
                child: const Text('Setujui'),
              ),
            ),
          ],
          if (request.status != 'pending')
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
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
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onPressed: _isLoading ? null : () => _deleteRequest(request.id),
                child: const Text('Hapus'),
              ),
            ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        final horizontalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 24.0);

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            title: Text(
              isMobile ? 'Retake' : 'Kelola Permintaan Retake',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
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
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Filter section
                Container(
                  padding: EdgeInsets.all(horizontalPadding),
                  child:
                      isMobile
                          ? Column(
                            children: [
                              _buildCompanyDropdown(isMobile),
                              const SizedBox(height: 12),
                              _buildUserDropdown(isMobile),
                            ],
                          )
                          : Row(
                            children: [
                              Expanded(child: _buildCompanyDropdown(isMobile)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildUserDropdown(isMobile)),
                            ],
                          ),
                ),

                // Request list
                Expanded(
                  child: StreamBuilder<List<RetakeRequestModel>>(
                    stream: _requestService.getAllRetakeRequests(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print(
                          'Kesalahan saat mengambil data: ${snapshot.error}',
                        );
                        if ('${snapshot.error}'.contains('index')) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(horizontalPadding),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: _primaryBlue,
                                  ),
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
                            ),
                          );
                        }
                        return _buildErrorState(isMobile, '${snapshot.error}');
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingState(isMobile);
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return _buildEmptyState(
                          isMobile,
                          'Belum ada permintaan retake',
                        );
                      }

                      final allRequests = snapshot.data!;
                      final filteredRequests = _filterRequests(allRequests);

                      if (filteredRequests.isEmpty) {
                        String emptyMessage = _getEmptyFilterMessage();
                        return _buildEmptyState(isMobile, emptyMessage);
                      }

                      return FutureBuilder<List<Map<String, dynamic>>>(
                        future: Future.wait(
                          filteredRequests.map((r) => _fetchRequestDetails(r)),
                        ),
                        builder: (context, detailSnapshot) {
                          if (detailSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildLoadingState(isMobile);
                          }
                          if (detailSnapshot.hasError) {
                            return _buildErrorState(
                              isMobile,
                              '${detailSnapshot.error}',
                            );
                          }

                          final details = detailSnapshot.data!;

                          return RefreshIndicator(
                            color: _primaryBlue,
                            onRefresh: () async {
                              setState(() {});
                            },
                            child: ListView.builder(
                              padding: EdgeInsets.all(horizontalPadding),
                              itemCount: filteredRequests.length,
                              itemBuilder: (context, index) {
                                final request = filteredRequests[index];
                                final detail = details[index];
                                return _buildRequestCard(
                                  request,
                                  detail,
                                  isMobile,
                                  isTablet,
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompanyDropdown(bool isMobile) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Pilih Perusahaan',
        labelStyle: TextStyle(
          color: _textSecondary,
          fontSize: isMobile ? 14 : 16,
        ),
        filled: true,
        fillColor: _surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          borderSide: BorderSide(color: _primaryBlue.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          borderSide: BorderSide(color: _primaryBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          borderSide: BorderSide(color: _primaryBlue),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 12 : 16,
        ),
      ),
      style: TextStyle(color: _textPrimary, fontSize: isMobile ? 14 : 16),
      value: _selectedCompanyName,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(
            'Semua Perusahaan',
            style: TextStyle(color: _textPrimary, fontSize: isMobile ? 14 : 16),
          ),
        ),
        ..._companies.map(
          (company) => DropdownMenuItem<String>(
            value: company,
            child: Text(
              company,
              style: TextStyle(
                color: _textPrimary,
                fontSize: isMobile ? 14 : 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCompanyName = value;
          _updateFilteredUsers();
        });
      },
    );
  }

  Widget _buildUserDropdown(bool isMobile) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Pilih Pengguna',
        labelStyle: TextStyle(
          color: _textSecondary,
          fontSize: isMobile ? 14 : 16,
        ),
        filled: true,
        fillColor: _surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          borderSide: BorderSide(color: _primaryBlue.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          borderSide: BorderSide(color: _primaryBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          borderSide: BorderSide(color: _primaryBlue),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 12 : 16,
        ),
      ),
      style: TextStyle(color: _textPrimary, fontSize: isMobile ? 14 : 16),
      value: _selectedUserId,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(
            'Semua Pengguna',
            style: TextStyle(color: _textPrimary, fontSize: isMobile ? 14 : 16),
          ),
        ),
        ..._filteredUsers.map(
          (user) => DropdownMenuItem<String>(
            value: user['userId'],
            child: Text(
              user['displayName'].isNotEmpty
                  ? (isMobile
                      ? user['displayName']
                      : '${user['displayName']} (${user['email']})')
                  : user['email'],
              style: TextStyle(
                color: _textPrimary,
                fontSize: isMobile ? 14 : 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedUserId = value;
        });
      },
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primaryBlue),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'Memuat permintaan retake...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: isMobile ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isMobile, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
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
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile, String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedCompanyName == null && _selectedUserId == null
                  ? Icons.inbox_outlined
                  : Icons.filter_list_off,
              size: isMobile ? 48 : 64,
              color: _textSecondary.withOpacity(0.5),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyFilterMessage() {
    if (_selectedCompanyName == null && _selectedUserId == null) {
      return 'Tidak ada permintaan retake';
    } else if (_selectedCompanyName != null && _selectedUserId == null) {
      return 'Tidak ada permintaan retake untuk perusahaan ini';
    } else if (_selectedCompanyName == null && _selectedUserId != null) {
      return 'Tidak ada permintaan retake untuk pengguna ini';
    } else {
      return 'Tidak ada permintaan retake untuk pengguna dan perusahaan ini';
    }
  }
}
