import 'package:ema_app/screens/admin/add_edit_delete_admins.dart';
import 'package:ema_app/give_access_page.dart';
import 'package:ema_app/free_quiz_and_files_page.dart';
import 'package:ema_app/screens/admin/folder_management_v2.dart';
import 'package:ema_app/screens/admin/user_management_v2.dart';
import 'package:ema_app/screens/users/home_page.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'package:flutter/material.dart';
import '../users/user_home_page.dart';
import 'admin_folders_page.dart';
import 'add_edit_delete_users.dart';
import 'admin_notices_page.dart';
import '../auth/login_page.dart';
import 'package:ema_app/screens/user_comp/user_manage_theme.dart';

class AdminDashboardPage extends StatefulWidget {
  final String fullName;
  final String profileImage;
  final bool isAdmin;
  final String userEmail;

  const AdminDashboardPage({
    super.key,
    required this.fullName,
    required this.profileImage,
    required this.isAdmin,
    required this.userEmail,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Items definition ───────────────────────────────────────────────────────
  List<_DashItem> get _items => [
    _DashItem(
      icon: Icons.home_rounded,
      label: 'User Home',
      color: const Color(0xFF4F8EF7),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserHomePage(
            fullName: widget.fullName,
            profileImage: widget.profileImage,
            isAdmin: widget.isAdmin,
            accessedFromAdminDashboard: true,
            userEmail: widget.userEmail,
            userIdentifier: '',
            folderId: null,
            folderName: '',
          ),
        ),
      ),
    ),
    _DashItem(
      icon: Icons.folder_special_rounded,
      label: 'Manage Folders',
      color: const Color(0xFF7C6CF7),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const FolderManagementScreen()),
      ),
    ),
    _DashItem(
      icon: Icons.folder_open_rounded,
      label: 'Folders',
      color: const Color(0xFFF7956C),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FoldersPage()),
      ),
    ),
    _DashItem(
      icon: Icons.manage_accounts_rounded,
      label: 'User Management',
      color: const Color(0xFF4F8EF7),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const UserManagementScreen()),
      ),
    ),
    _DashItem(
      icon: Icons.group_rounded,
      label: 'Add / Edit Users',
      color: const Color(0xFF3DB88B),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const AddEditDeleteUsersPage()),
      ),
    ),
    _DashItem(
      icon: Icons.campaign_rounded,
      label: 'Notices',
      color: const Color(0xFFF7C26C),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NoticesPage()),
      ),
    ),
    _DashItem(
      icon: Icons.vpn_key_rounded,
      label: 'Give Access',
      color: const Color(0xFFE06CF7),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GiveAccessPage()),
      ),
    ),
    _DashItem(
      icon: Icons.quiz_rounded,
      label: 'Free Quiz & Files',
      color: const Color(0xFFF7956C),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const FreeQuizAndFilesPage()),
      ),
    ),
    _DashItem(
      icon: Icons.logout_rounded,
      label: 'Logout',
      color: const Color(0xFFE05C5C),
      onTap: () => _handleLogout(context),
    ),
  ];

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _handleLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Logout',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: UMTheme.textSub, height: 1.5),
        ),
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
      await UserViewModel().removeUser();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(
            userIdentifier: '',
            isAdmin: false,
            fullName: '',
          ),
        ),
            (r) => false,
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UMTheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: CustomScrollView(
            slivers: [
              // ── Profile header ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: _ProfileHeader(
                  fullName: widget.fullName,
                  email: widget.userEmail,
                  imageUrl: widget.profileImage,
                ),
              ),

              // ── Section label ────────────────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text('Quick Actions', style: UMTheme.screenTitle),
                ),
              ),

              // ── Grid ─────────────────────────────────────────────────────
              SliverPadding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _AnimatedDashCard(item: _items[i], index: i),
                    childCount: _items.length,
                  ),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.1,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile Header ────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String fullName;
  final String email;
  final String imageUrl;

  const _ProfileHeader({
    required this.fullName,
    required this.email,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: UMTheme.border),
        boxShadow: [
          BoxShadow(
            color: UMTheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: UMTheme.avatarDecoration(
              imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
            ),
            child: imageUrl.isEmpty
                ? Center(
              child: Text(
                _initials(fullName),
                style: const TextStyle(
                  color: UMTheme.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            )
                : null,
          ),
          const SizedBox(width: 16),

          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Admin' : fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: UMTheme.textMain,
                  ),
                ),
                const SizedBox(height: 3),
                Text(email, style: UMTheme.cardSubtitle),
              ],
            ),
          ),

          // Admin badge
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: UMTheme.adminBadgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Admin',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: UMTheme.adminBadgeText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return 'A';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

// ─── Animated Dashboard Card ──────────────────────────────────────────────────
class _AnimatedDashCard extends StatelessWidget {
  final _DashItem item;
  final int index;

  const _AnimatedDashCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index.clamp(0, 8) * 40)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: child,
        ),
      ),
      child: _DashCard(item: item),
    );
  }
}

// ─── Dashboard Card ───────────────────────────────────────────────────────────
class _DashCard extends StatefulWidget {
  final _DashItem item;
  const _DashCard({required this.item});

  @override
  State<_DashCard> createState() => _DashCardState();
}

class _DashCardState extends State<_DashCard> {
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
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon container
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color, size: 28),
              ),

              // Label
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 14,
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
class _DashItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DashItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}