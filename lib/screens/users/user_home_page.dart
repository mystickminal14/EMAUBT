import 'package:ema_app/eps_section_page.dart';
import 'package:ema_app/model/user_model.dart';
import 'package:ema_app/screens/admin/admin_dashboard_page.dart';
import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:ema_app/screens/users/contactuspage.dart';
import 'package:ema_app/screens/users/login_user_free_files_quiz_sets.dart';
import 'package:ema_app/screens/users/user_notices_page.dart';
import 'package:ema_app/view_model/auth_view_model/auth_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'dart:io' show Platform;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

class UserHomePage extends StatefulWidget {
  final String fullName;
  final String profileImage;
  final bool isAdmin;
  final bool accessedFromAdminDashboard;
  final String userEmail;
  final String userIdentifier;
  final String? folderId;
  final String folderName;

  const UserHomePage({
    super.key,
    required this.fullName,
    required this.profileImage,
    required this.isAdmin,
    required this.userEmail,
    this.accessedFromAdminDashboard = false,
    required this.userIdentifier,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage>
    with SingleTickerProviderStateMixin {
  final UserViewModel _userViewModel = UserViewModel();
  String? _cachedFullName;
  String? _cachedProfileImage;
  String? _cachedUserEmail;

  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final log = Logger();
    log.d(widget.userIdentifier);
    log.d(widget.userEmail);
    final UserModel? user = await _userViewModel.getUser();
    log.d('cached ${user?.email}');
    if (user != null && user.success == true) {
      setState(() {
        _cachedFullName     = user.fullName    ?? widget.fullName;
        _cachedProfileImage = user.image       ?? widget.profileImage;
        _cachedUserEmail    = user.email       ?? widget.userEmail;
      });
    } else {
      setState(() {
        _cachedFullName     = widget.fullName;
        _cachedProfileImage = widget.profileImage;
        _cachedUserEmail    = widget.userEmail;
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Responsive helpers ─────────────────────────────────────────────────────
  ScreenSize _getScreenSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 600) return ScreenSize.small;
    if (w < 1024) return ScreenSize.medium;
    return ScreenSize.large;
  }

  ResponsiveDimensions _getDimensions(BuildContext context) {
    final ss = _getScreenSize(context);
    final w  = MediaQuery.of(context).size.width;
    final h  = MediaQuery.of(context).size.height;
    switch (ss) {
      case ScreenSize.small:
        return ResponsiveDimensions(
          padding: w * 0.04,
          logoHeight: h * 0.15, logoWidth: w * 0.6,
          titleFontSize: w * 0.045,
          buttonWidth: w * 0.42, buttonHeight: h * 0.12,
          buttonFontSize: w * 0.028, iconSize: w * 0.08,
          crossAxisCount: 2,
          childAspectRatio: 0.78, // was 0.85 — taller cards = more breathing room
        );
      case ScreenSize.medium:
        return ResponsiveDimensions(
          padding: w * 0.03,
          logoHeight: h * 0.18, logoWidth: w * 0.4,
          titleFontSize: w * 0.035,
          buttonWidth: w * 0.28, buttonHeight: h * 0.14,
          buttonFontSize: w * 0.022, iconSize: w * 0.06,
          crossAxisCount: 3, childAspectRatio: 0.8,
        );
      case ScreenSize.large:
        return ResponsiveDimensions(
          padding: 24, logoHeight: 200, logoWidth: 300,
          titleFontSize: 24,
          buttonWidth: 180, buttonHeight: 140,
          buttonFontSize: 13, iconSize: 32,
          crossAxisCount: 4, childAspectRatio: 1.0,
        );
    }
  }

  // ── Nav items ──────────────────────────────────────────────────────────────
  List<_NavItem> _navItems(String cachedEmail) => [
    _NavItem(
      icon: Icons.campaign_rounded,
      label: 'Important\nInformation',
      color: const Color(0xFF7C6CF7),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const UserNoticesPage())),
    ),
    _NavItem(
      icon: Icons.file_copy_rounded,
      label: 'Free Files &\nQuiz Sets',
      color: const Color(0xFF4F8EF7),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginUserFreeFilesQuizSets(
              userIdentifier: cachedEmail, isAdmin: widget.isAdmin),
        ),
      ),
    ),
    if (widget.isAdmin || widget.accessedFromAdminDashboard)
      _NavItem(
        icon: Icons.admin_panel_settings_rounded,
        label: 'Admin\nDashboard',
        color: const Color(0xFF3DB88B),
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboardPage(
              fullName:     _cachedFullName     ?? widget.fullName,
              profileImage: _cachedProfileImage ?? widget.profileImage,
              isAdmin:      widget.isAdmin,
              userEmail:    cachedEmail,
            ),
          ),
        ),
      ),
    _NavItem(
      icon: Icons.quiz_rounded,
      label: 'EPS TOPIK\nNew UBT',
      color: const Color(0xFFF7956C),
      assetIcon: 'assets/ema.jpg',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EPSSectionPage(
            userIdentifier: widget.userEmail.isNotEmpty
                ? widget.userEmail
                : cachedEmail,
            isAdmin: widget.isAdmin,
            fullName: '', profileImage: '',
            userEmail: '', folderId: null, folderName: '',
          ),
        ),
      ),
    ),
    _NavItem(
      icon: Icons.contact_mail_rounded,
      label: 'Contact Us',
      color: const Color(0xFFE06CF7),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ContactUsPage())),
    ),
    _NavItem(
      icon: Icons.logout_rounded,
      label: 'Logout',
      color: const Color(0xFFE05C5C),
      onTap: () => _handleLogout(context),
    ),
  ];

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dim         = _getDimensions(context);
    final cachedEmail = _cachedUserEmail ?? widget.userEmail;
    final name        = _cachedFullName  ?? widget.fullName;
    final items       = _navItems(cachedEmail);

    return Scaffold(
      backgroundColor: UMTheme.surface,
      drawer: _Drawer(
        name: name,
        email: cachedEmail,
        imageUrl: _cachedProfileImage ?? widget.profileImage,
        isAdmin: widget.isAdmin,
        items: items,
      ),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── App bar ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _TopBar(name: name, email: cachedEmail,
                    imageUrl: _cachedProfileImage ?? widget.profileImage),
              ),

              // ── Logo + welcome ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: dim.padding, vertical: 8),
                  child: Column(
                    children: [
                      Container(
                        height: dim.logoHeight,
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/ema.jpeg',
                          width: dim.logoWidth,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.image_not_supported,
                              size: dim.logoWidth * 0.3,
                              color: UMTheme.textSub),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome, $name 👋',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: UMTheme.textMain,
                          fontSize: dim.titleFontSize,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('What would you like to do today?',
                          style: UMTheme.screenSubtitle),
                    ],
                  ),
                ),
              ),

              // ── Section label ────────────────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Text('Quick Access', style: UMTheme.screenTitle),
                ),
              ),

              // ── Grid ─────────────────────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    dim.padding + 4, 0, dim.padding + 4, 40),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _AnimatedCard(item: items[i], index: i,
                        iconSize: dim.iconSize),
                    childCount: items.length,
                  ),
                  gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: dim.crossAxisCount,
                    crossAxisSpacing: dim.crossAxisCount == 2 ? 14 : 16,
                    mainAxisSpacing:  dim.crossAxisCount == 2 ? 14 : 16,
                    childAspectRatio: dim.crossAxisCount == 2 ? 1.1 : dim.childAspectRatio,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logout dialog ──────────────────────────────────────────────────────────
  Future<void> _handleLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Logout',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: UMTheme.textSub, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: UMTheme.textSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok == true) {
      Provider.of<AuthViewModel>(context, listen: false).logout(context);
    }
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String name;
  final String email;
  final String imageUrl;

  const _TopBar({required this.name, required this.email, required this.imageUrl});

  String _initials(String n) {
    if (n.isEmpty) return 'U';
    final p = n.trim().split(' ');
    return p.length == 1
        ? p[0][0].toUpperCase()
        : '${p[0][0]}${p.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Hamburger
          Builder(
            builder: (ctx) => IconButton(
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              icon: const Icon(Icons.menu_rounded,
                  color: UMTheme.textMain, size: 24),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: UMTheme.border),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EMA UBT', style: UMTheme.screenTitle),
                Text('Empower Your Future',
                    style: UMTheme.screenSubtitle),
              ],
            ),
          ),
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: UMTheme.avatarDecoration(
                imageUrl: imageUrl.isNotEmpty ? imageUrl : null),
            child: imageUrl.isEmpty
                ? Center(
                child: Text(_initials(name),
                    style: const TextStyle(
                        color: UMTheme.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)))
                : null,
          ),
        ],
      ),
    );
  }
}

// ─── Drawer ───────────────────────────────────────────────────────────────────
class _Drawer extends StatelessWidget {
  final String name;
  final String email;
  final String imageUrl;
  final bool isAdmin;
  final List<_NavItem> items;

  const _Drawer({
    required this.name,
    required this.email,
    required this.imageUrl,
    required this.isAdmin,
    required this.items,
  });

  String _initials(String n) {
    if (n.isEmpty) return 'U';
    final p = n.trim().split(' ');
    return p.length == 1
        ? p[0][0].toUpperCase()
        : '${p[0][0]}${p.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: BoxDecoration(
              color: UMTheme.accent.withOpacity(0.06),
              border: const Border(
                  bottom: BorderSide(color: UMTheme.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: UMTheme.avatarDecoration(
                      imageUrl: imageUrl.isNotEmpty ? imageUrl : null),
                  child: imageUrl.isEmpty
                      ? Center(
                      child: Text(_initials(name),
                          style: const TextStyle(
                              color: UMTheme.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? 'User' : name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: UMTheme.textMain),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(email,
                          style: UMTheme.cardSubtitle,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? UMTheme.adminBadgeBg
                              : UMTheme.userBadgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isAdmin ? 'Admin' : 'User',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isAdmin
                                ? UMTheme.adminBadgeText
                                : UMTheme.userBadgeText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final item = items[i];
                return ListTile(
                  onTap: () {
                    Navigator.pop(context);
                    item.onTap();
                  },
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: item.assetIcon != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(item.assetIcon!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              item.icon,
                              color: item.color,
                              size: 18)),
                    )
                        : Icon(item.icon, color: item.color, size: 18),
                  ),
                  title: Text(
                    item.label.replaceAll('\n', ' '),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: UMTheme.textMain,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  tileColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  horizontalTitleGap: 10,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated grid card ───────────────────────────────────────────────────────
class _AnimatedCard extends StatelessWidget {
  final _NavItem item;
  final int index;
  final double iconSize;

  const _AnimatedCard(
      {required this.item, required this.index, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index.clamp(0, 8) * 45)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
            offset: Offset(0, 20 * (1 - v)), child: child),
      ),
      child: _HomeCard(item: item, iconSize: iconSize),
    );
  }
}

class _HomeCard extends StatefulWidget {
  final _NavItem item;
  final double iconSize;
  const _HomeCard({required this.item, required this.iconSize});

  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        item.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: UMTheme.border),
            boxShadow: [
              BoxShadow(
                color: item.color.withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: item.assetIcon != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(item.assetIcon!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          item.icon,
                          color: item.color,
                          size: widget.iconSize + 8)),
                )
                    : Icon(item.icon, color: item.color, size: widget.iconSize + 8),
              ),
              const SizedBox(height: 10),
              // Label
              Text(
                item.label.replaceAll('\n', ' '),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: UMTheme.textMain,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  final String? assetIcon;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    this.assetIcon,
    required this.onTap,
  });
}

// ─── Enums / responsive models (unchanged) ────────────────────────────────────
enum ScreenSize { small, medium, large }

class ResponsiveDimensions {
  final double padding;
  final double logoHeight;
  final double logoWidth;
  final double titleFontSize;
  final double buttonWidth;
  final double buttonHeight;
  final double buttonFontSize;
  final double iconSize;
  final int crossAxisCount;
  final double childAspectRatio;

  ResponsiveDimensions({
    required this.padding,
    required this.logoHeight,
    required this.logoWidth,
    required this.titleFontSize,
    required this.buttonWidth,
    required this.buttonHeight,
    required this.buttonFontSize,
    required this.iconSize,
    required this.crossAxisCount,
    required this.childAspectRatio,
  });
}