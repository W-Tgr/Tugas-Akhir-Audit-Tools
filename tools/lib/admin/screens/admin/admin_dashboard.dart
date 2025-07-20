import 'package:flutter/material.dart';
import 'package:tools/admin/screens/admin/domain_pages.dart';
import 'package:tools/admin/screens/admin/progress_user.dart';
import 'package:tools/admin/screens/admin/upload_excel.dart';
import 'package:tools/admin/screens/admin/user_management.dart';
import 'package:tools/admin/screens/admin/admin_profile_page.dart';
import 'package:tools/admin/screens/admin/retake_approval_page.dart';
import 'package:tools/auth/auth_service.dart';
import 'package:tools/auth/login_screen.dart';
import 'package:tools/admin/screens/user/user_dashboard_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  // Enhanced color scheme
  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _darkBlue = Color(0xFF1976D2);
  static const Color _lightBlue = Color(0xFF42A5F5);
  static const Color _accentBlue = Color(0xFF64B5F6);
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const Color _surfaceColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  static final List<Color> _gradientColors = [
    _darkBlue,
    _primaryBlue,
    _lightBlue,
  ];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String? _profileImageBase64;
  bool _isLoadingProfile = true;
  String _adminName = '';

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

    _setupProfileListener();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupProfileListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted && snapshot.exists) {
              final data = snapshot.data();
              if (data != null) {
                setState(() {
                  _profileImageBase64 = data['photoBase64'];
                  _adminName =
                      data['displayName'] ??
                      user.displayName ??
                      user.email!.split('@')[0];
                  _isLoadingProfile = false;
                });
              }
            }
          },
          onError: (e) {
            print('Error in profile listener: $e');
            if (mounted) {
              setState(() {
                _isLoadingProfile = false;
                _adminName = user.displayName ?? user.email!.split('@')[0];
              });
              _showSnackBar('Gagal memuat profil', isError: true);
            }
          },
        );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16),
          ),
          backgroundColor: isError ? Colors.red.shade700 : _darkBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          ),
          margin: EdgeInsets.all(isMobile ? 12 : 16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.getCurrentUser();

    if (user == null) {
      return const LoginScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.2, 0.5, 0.9],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          print('Error fetching user role: ${snapshot.error}');
          _showSnackBar('Gagal memuat data pengguna', isError: true);
          return const LoginScreen();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final role = userData['role']?.toString() ?? '';

        if (role == 'admin') {
          return _buildAdminDashboard(context, _adminName);
        } else {
          return const UserDashboardPage();
        }
      },
    );
  }

  Widget _buildAdminDashboard(BuildContext context, String adminName) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final isMobile = screenWidth < 600;
        final isTablet = screenWidth >= 600 && screenWidth < 1024;
        final isDesktop = screenWidth >= 1024;

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: isMobile ? _buildMobileAppBar() : null,
          drawer: isMobile ? _buildDrawer(context, adminName) : null,
          body: SafeArea(
            child: Row(
              children: [
                // Desktop/Tablet Sidebar
                if (!isMobile)
                  Container(
                    width: isTablet ? 260 : 300,
                    constraints: BoxConstraints(maxHeight: screenHeight),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      boxShadow: [
                        BoxShadow(
                          color: _darkBlue.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(5, 0),
                        ),
                      ],
                    ),
                    child: _buildSidebar(context, adminName, isTablet),
                  ),

                // Main Content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildMainContent(
                      context,
                      adminName,
                      isMobile,
                      isTablet,
                      isDesktop,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      title: Text(
        'Dashboard Admin',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildSidebar(BuildContext context, String adminName, bool isTablet) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: IntrinsicHeight(
          child: Column(
            children: [
              // Profile Header
              Container(
                padding: EdgeInsets.all(isTablet ? 20 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.2, 0.5, 0.9],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.7),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _darkBlue.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: isTablet ? 30 : 35,
                        backgroundColor: Colors.white,
                        backgroundImage:
                            _profileImageBase64 != null
                                ? MemoryImage(
                                  base64Decode(_profileImageBase64!),
                                )
                                : null,
                        child:
                            _profileImageBase64 == null
                                ? Text(
                                  adminName.isNotEmpty
                                      ? adminName[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(
                                    fontSize: isTablet ? 20 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryBlue,
                                  ),
                                )
                                : null,
                      ),
                    ),
                    SizedBox(height: isTablet ? 12 : 16),
                    Text(
                      adminName,
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 16,
                        vertical: isTablet ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Administrator',
                        style: TextStyle(
                          fontSize: isTablet ? 10 : 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Navigation
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildSidebarItem(
                        icon: Icons.dashboard_rounded,
                        text: 'Dashboard',
                        isSelected: true,
                        onTap: () {},
                        isTablet: isTablet,
                      ),
                      _buildSidebarItem(
                        icon: Icons.person_outline_rounded,
                        text: 'Profile',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminProfilePage(),
                            ),
                          );
                        },
                        isTablet: isTablet,
                      ),
                    ],
                  ),
                ),
              ),

              // Logout Button
              Padding(
                padding: EdgeInsets.all(isTablet ? 12 : 16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_darkBlue, _primaryBlue]),
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
                    onPressed: () => _showLogoutDialog(context),
                    icon: Icon(Icons.logout_rounded, size: isTablet ? 18 : 20),
                    label: Text(
                      'Logout',
                      style: TextStyle(fontSize: isTablet ? 14 : 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      minimumSize: Size(double.infinity, isTablet ? 44 : 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String text,
    bool isSelected = false,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 16,
              vertical: isTablet ? 10 : 14,
            ),
            decoration: BoxDecoration(
              gradient:
                  isSelected
                      ? LinearGradient(
                        colors: [
                          _primaryBlue.withOpacity(0.1),
                          _lightBlue.withOpacity(0.1),
                        ],
                      )
                      : null,
              borderRadius: BorderRadius.circular(12),
              border:
                  isSelected
                      ? Border.all(color: _primaryBlue.withOpacity(0.3))
                      : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? _primaryBlue : _textSecondary,
                  size: isTablet ? 18 : 20,
                ),
                SizedBox(width: isTablet ? 12 : 16),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isSelected ? _primaryBlue : _textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: isTablet ? 14 : 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    String adminName,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return CustomScrollView(
      slivers: [
        // Header Section
        SliverToBoxAdapter(
          child: _buildModernHeader(context, adminName, isMobile, isTablet),
        ),

        // Main Content
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Quick Actions'),
                SizedBox(height: isMobile ? 12 : 16),
                _buildQuickActionGrid(context, isMobile, isTablet, isDesktop),
                SizedBox(height: isMobile ? 24 : 32),
                _buildSectionTitle('Statistics'),
                SizedBox(height: isMobile ? 12 : 16),
                _buildStatsSection(context, isMobile, isTablet, isDesktop),
                SizedBox(height: isMobile ? 16 : 24), // Bottom padding
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernHeader(
    BuildContext context,
    String adminName,
    bool isMobile,
    bool isTablet,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: isMobile ? 180 : (isTablet ? 200 : 220),
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
          // Wave Background
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              painter: ModernWavePainter(),
              size: Size(screenWidth, isMobile ? 60 : 80),
            ),
          ),

          // Content
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
            child:
                isMobile
                    ? _buildMobileHeaderContent(adminName)
                    : _buildDesktopHeaderContent(adminName, screenWidth),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeaderContent(String adminName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _getGreeting(),
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          adminName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildHeaderInfoCard(
                icon: Icons.access_time_rounded,
                text: _getCurrentTime(),
                isMobile: true,
              ),
              const SizedBox(width: 12),
              _buildHeaderInfoCard(
                icon: Icons.calendar_today_rounded,
                text: _getCurrentDate(),
                isMobile: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeaderContent(String adminName, double screenWidth) {
    return Row(
      children: [
        // Left Content
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                adminName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: _darkBlue.withOpacity(0.5),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildHeaderInfoCard(
                    icon: Icons.access_time_rounded,
                    text: _getCurrentTime(),
                    isMobile: false,
                  ),
                  _buildHeaderInfoCard(
                    icon: Icons.calendar_today_rounded,
                    text: _getCurrentDate(),
                    isMobile: false,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Right Illustration
        if (screenWidth > 800)
          Expanded(
            flex: 1,
            child: Container(
              alignment: Alignment.centerRight,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderInfoCard({
    required IconData icon,
    required String text,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 14,
        vertical: isMobile ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 14 : 16, color: Colors.white),
          SizedBox(width: isMobile ? 6 : 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          height: 20,
          width: 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_darkBlue, _primaryBlue]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionGrid(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final actions = [
      {
        'title': 'Domain',
        'icon': Icons.domain_rounded,
        'gradient': [_primaryBlue, _lightBlue],
        'onTap':
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DomainPage()),
            ),
      },
      {
        'title': 'Users',
        'icon': Icons.people_rounded,
        'gradient': [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
        'onTap':
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserManagementScreen()),
            ),
      },
      {
        'title': 'Upload',
        'icon': Icons.upload_file_rounded,
        'gradient': [const Color(0xFF10B981), const Color(0xFF34D399)],
        'onTap':
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const UploadQuestionnaireScreen(),
              ),
            ),
      },
      {
        'title': 'Progress',
        'icon': Icons.show_chart_rounded,
        'gradient': [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
        'onTap':
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProgressScreenAdmin()),
            ),
      },
      {
        'title': 'Retake',
        'icon': Icons.assignment_turned_in_rounded,
        'gradient': [const Color(0xFFEF4444), const Color(0xFFF87171)],
        'onTap':
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RetakeApprovalPage()),
            ),
      },
    ];

    int crossAxisCount;
    double childAspectRatio;

    if (isMobile) {
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    } else if (isTablet) {
      crossAxisCount = 3;
      childAspectRatio = 1.0;
    } else {
      crossAxisCount = 5;
      childAspectRatio = 0.9;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isMobile ? 10 : 12,
        mainAxisSpacing: isMobile ? 10 : 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _buildModernActionCard(
          title: action['title'] as String,
          icon: action['icon'] as IconData,
          gradient: action['gradient'] as List<Color>,
          onTap: action['onTap'] as VoidCallback,
          isMobile: isMobile,
        );
      },
    );
  }

  Widget _buildModernActionCard({
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.1),
            blurRadius: isMobile ? 15 : 18,
            offset: Offset(0, isMobile ? 6 : 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: isMobile ? 22 : 26,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final stats = [
      {
        'title': 'Total Users',
        'icon': Icons.people_rounded,
        'gradient': [_primaryBlue, _lightBlue],
        'stream':
            FirebaseFirestore.instance
                .collection('users')
                .where('role', isNotEqualTo: 'admin')
                .snapshots(),
      },
      {
        'title': 'Pending Approval',
        'icon': Icons.hourglass_empty_rounded,
        'gradient': [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
        'stream':
            FirebaseFirestore.instance
                .collection('users')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
      },
      {
        'title': 'Pending Retake',
        'icon': Icons.assignment_turned_in_rounded,
        'gradient': [const Color(0xFFEF4444), const Color(0xFFF87171)],
        'stream':
            FirebaseFirestore.instance
                .collection('retakeRequests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
      },
      {
        'title': 'Total Domains',
        'icon': Icons.domain_rounded,
        'gradient': [const Color(0xFF10B981), const Color(0xFF34D399)],
        'stream': FirebaseFirestore.instance.collection('domains').snapshots(),
      },
    ];

    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < stats.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < stats.length ? 12 : 0),
              child: Row(
                children: [
                  Expanded(child: _buildModernStatCard(stats[i], isMobile)),
                  const SizedBox(width: 12),
                  if (i + 1 < stats.length)
                    Expanded(
                      child: _buildModernStatCard(stats[i + 1], isMobile),
                    )
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      );
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: isTablet ? 160 : 180,
                  maxWidth: isTablet ? 200 : 220,
                ),
                child: _buildModernStatCard(stats[i], isMobile),
              ),
              if (i < stats.length - 1) const SizedBox(width: 16),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildModernStatCard(Map<String, dynamic> stat, bool isMobile) {
    final gradient = stat['gradient'] as List<Color>;
    final stream = stat['stream'] as Stream<QuerySnapshot>;

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String value = '0';
        bool isLoading = false;
        bool hasError = false;

        if (snapshot.connectionState == ConnectionState.waiting) {
          isLoading = true;
        } else if (snapshot.hasError) {
          print('Error in stream for ${stat['title']}: ${snapshot.error}');
          hasError = true;
        } else if (snapshot.hasData) {
          value = snapshot.data!.docs.length.toString();
        }

        return Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.08),
                blurRadius: isMobile ? 15 : 18,
                offset: Offset(0, isMobile ? 6 : 8),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 14 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    stat['icon'] as IconData,
                    size: isMobile ? 18 : 20,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isMobile ? 10 : 12),
                isLoading
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: _primaryBlue,
                        strokeWidth: 2,
                      ),
                    )
                    : Text(
                      hasError ? 'Error' : value,
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: hasError ? Colors.red.shade700 : _textPrimary,
                      ),
                    ),
                SizedBox(height: isMobile ? 4 : 6),
                Text(
                  stat['title'] as String,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, String adminName) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Drawer(
      child: Column(
        children: [
          Container(
            height: 180 + statusBarHeight,
            padding: EdgeInsets.only(
              top: statusBarHeight + 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.2, 0.5, 0.9],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        _profileImageBase64 != null
                            ? MemoryImage(base64Decode(_profileImageBase64!))
                            : null,
                    child:
                        _profileImageBase64 == null
                            ? Text(
                              adminName.isNotEmpty
                                  ? adminName[0].toUpperCase()
                                  : 'A',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _primaryBlue,
                              ),
                            )
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        adminName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard_rounded,
                  text: 'Dashboard',
                  isSelected: true,
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerItem(
                  icon: Icons.person_outline_rounded,
                  text: 'Profil',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminProfilePage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_darkBlue, _primaryBlue]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Logout', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? _primaryBlue : _textSecondary,
          size: 20,
        ),
        title: Text(
          text,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? _primaryBlue : _textPrimary,
            fontSize: 14,
          ),
        ),
        tileColor:
            isSelected ? _primaryBlue.withOpacity(0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        dense: true,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          ),
          title: Text(
            'Konfirmasi Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _textPrimary,
              fontSize: isMobile ? 16 : 18,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari aplikasi?',
            style: TextStyle(
              color: _textSecondary,
              fontSize: isMobile ? 14 : 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: isMobile ? 14 : 16,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_darkBlue, _primaryBlue]),
                borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 20,
                    vertical: isMobile ? 8 : 12,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
                child: Text(
                  'Logout',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Selamat Pagi';
    } else if (hour < 15) {
      return 'Selamat Siang';
    } else if (hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${now.day} ${months[now.month - 1]}';
  }
}

// Modern Wave Painter
class ModernWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // First wave layer
    Paint paint1 =
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.3);
    path1.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.1,
      size.width * 0.6,
      size.height * 0.3,
    );
    path1.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.5,
      size.width,
      size.height * 0.4,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Second wave layer
    Paint paint2 =
        Paint()
          ..color = Colors.white.withOpacity(0.15)
          ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.5);
    path2.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.3,
      size.width * 0.5,
      size.height * 0.5,
    );
    path2.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.7,
      size.width,
      size.height * 0.5,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
