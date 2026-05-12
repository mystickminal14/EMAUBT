import 'dart:io';
import 'package:ema_app/guest_free_files_quiz_sets.dart';
import 'package:ema_app/screens/notice/user_notice_screen.dart';
import 'package:ema_app/screens/users/contactuspage.dart';
import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../auth/login_page.dart';
import '../../eps_section_page.dart';

class HomePage extends StatefulWidget {
  final String userIdentifier;
  final bool isAdmin;
  final String fullName;

  const HomePage({
    super.key,
    required this.userIdentifier,
    required this.isAdmin,
    required this.fullName,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
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
  _ScreenSize _getScreenSize(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 600) return _ScreenSize.small;
    if (w < 1024) return _ScreenSize.medium;
    return _ScreenSize.large;
  }

  _ResponsiveDimensions _getDimensions(BuildContext context) {
    final ss = _getScreenSize(context);
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    switch (ss) {
      case _ScreenSize.small:
        return _ResponsiveDimensions(
          padding: w * 0.04,
          logoHeight: h * 0.15,
          logoWidth: w * 0.6,
          titleFontSize: w * 0.045,
          iconSize: w * 0.08,
          crossAxisCount: 2,
          childAspectRatio: 1.1,
        );
      case _ScreenSize.medium:
        return _ResponsiveDimensions(
          padding: w * 0.03,
          logoHeight: h * 0.18,
          logoWidth: w * 0.4,
          titleFontSize: w * 0.035,
          iconSize: w * 0.06,
          crossAxisCount: 3,
          childAspectRatio: 1.0,
        );
      case _ScreenSize.large:
        return _ResponsiveDimensions(
          padding: 24,
          logoHeight: 200,
          logoWidth: 300,
          titleFontSize: 24,
          iconSize: 32,
          crossAxisCount: 4,
          childAspectRatio: 1.0,
        );
    }
  }

  // ── Nav items ──────────────────────────────────────────────────────────────
  List<_NavItem> get _navItems => [
    _NavItem(
      icon: Icons.login_rounded,
      label: 'Login /\nRegister',
      color: const Color(0xFF3DB88B),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginPage())),
    ),
    _NavItem(
      icon: Icons.campaign_rounded,
      label: 'Important\nInformation',
      color: const Color(0xFF7C6CF7),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const UserNoticeScreen())),
    ),
    _NavItem(
      icon: Icons.explore,
      label: 'Explore',
      color: const Color(0xFFF7956C),
      // assetIcon: 'assets/ema.jpg',
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => GuestFreeFilesQuizSets(),
      )),
    ),
    _NavItem(
      icon: Icons.contact_mail_rounded,
      label: 'Contact Us',
      color: const Color(0xFFE06CF7),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ContactUsPage())),
    ),
  ];

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dim = _getDimensions(context);
    final items = _navItems;
    final displayName =
    widget.fullName.isEmpty ? 'Guest' : widget.fullName;

    return Scaffold(
      backgroundColor: UMTheme.surface,
      drawer: _HomeDrawer(
        name: displayName,
        identifier: widget.userIdentifier,
        isAdmin: widget.isAdmin,
        items: items,
      ),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Top bar ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _TopBar(name: displayName),
              ),

              // ── Logo + welcome ─────────────────────────────────────────
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
                            color: UMTheme.textSub,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome to EMA UBT, $displayName 👋',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: UMTheme.textMain,
                          fontSize: dim.titleFontSize,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'What would you like to do today?',
                        style: UMTheme.screenSubtitle,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Section label ──────────────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Text('Quick Access', style: UMTheme.screenTitle),
                ),
              ),

              // ── Grid ──────────────────────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    dim.padding + 4, 0, dim.padding + 4, 40),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _AnimatedCard(
                      item: items[i],
                      index: i,
                      iconSize: dim.iconSize,
                    ),
                    childCount: items.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: dim.crossAxisCount,
                    crossAxisSpacing: dim.crossAxisCount == 2 ? 14 : 16,
                    mainAxisSpacing: dim.crossAxisCount == 2 ? 14 : 16,
                    childAspectRatio: dim.childAspectRatio,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String name;

  const _TopBar({required this.name});

  String _initials(String n) {
    if (n.isEmpty) return 'G';
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EMA UBT', style: UMTheme.screenTitle),
                Text('Empower Your Future', style: UMTheme.screenSubtitle),
              ],
            ),
          ),
          // Guest avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: UMTheme.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: UMTheme.accent.withOpacity(0.25), width: 1.5),
            ),
            child: Center(
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: UMTheme.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Drawer ───────────────────────────────────────────────────────────────────
class _HomeDrawer extends StatelessWidget {
  final String name;
  final String identifier;
  final bool isAdmin;
  final List<_NavItem> items;

  const _HomeDrawer({
    required this.name,
    required this.identifier,
    required this.isAdmin,
    required this.items,
  });

  String _initials(String n) {
    if (n.isEmpty) return 'G';
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
              border:
              const Border(bottom: BorderSide(color: UMTheme.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: UMTheme.accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: UMTheme.accent.withOpacity(0.25), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _initials(name),
                      style: const TextStyle(
                        color: UMTheme.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: UMTheme.textMain,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (identifier.isNotEmpty)
                        Text(
                          identifier,
                          style: UMTheme.cardSubtitle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: UMTheme.userBadgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Guest',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: UMTheme.userBadgeText,
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
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      child: Image.asset(
                        item.assetIcon!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            item.icon,
                            color: item.color,
                            size: 18),
                      ),
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
        child:
        Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child),
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
              // Icon container
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
                  child: Image.asset(
                    item.assetIcon!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(item.icon,
                        color: item.color,
                        size: widget.iconSize + 8),
                  ),
                )
                    : Icon(item.icon,
                    color: item.color, size: widget.iconSize + 8),
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

// ─── Enums / responsive models ────────────────────────────────────────────────
enum _ScreenSize { small, medium, large }

class _ResponsiveDimensions {
  final double padding;
  final double logoHeight;
  final double logoWidth;
  final double titleFontSize;
  final double iconSize;
  final int crossAxisCount;
  final double childAspectRatio;

  _ResponsiveDimensions({
    required this.padding,
    required this.logoHeight,
    required this.logoWidth,
    required this.titleFontSize,
    required this.iconSize,
    required this.crossAxisCount,
    required this.childAspectRatio,
  });
}