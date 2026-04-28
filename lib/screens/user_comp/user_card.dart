import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:flutter/material.dart';
import 'package:ema_app/model/user_model.dart';

class UserCard extends StatelessWidget {
  final UserModel user;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const UserCard({
    super.key,
    required this.user,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.fullName);
    final isAdmin  = user.role?.toLowerCase() == 'admin';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // Cap delay so deep-page items don't take forever
      duration: Duration(milliseconds: 250 + (index.clamp(0, 10) * 30)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: UMTheme.cardDecoration,
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: UserAvatar(imageUrl: user.image, initials: initials),
          title: Text(user.fullName ?? '—', style: UMTheme.cardTitle),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(user.email ?? '', style: UMTheme.cardSubtitle),
              if (user.phone != null && user.phone!.isNotEmpty)
                Text(user.phone!, style: UMTheme.cardPhone),
              const SizedBox(height: 6),
              RoleBadge(isAdmin: isAdmin),
            ],
          ),
          trailing: CardMenu(onEdit: onEdit, onDelete: onDelete),
        ),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;

  const UserAvatar({super.key, this.imageUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: UMTheme.avatarDecoration(imageUrl: imageUrl),
      child: imageUrl == null || imageUrl!.isEmpty
          ? Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: UMTheme.accent,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      )
          : null,
    );
  }
}

// ─── Role Badge ───────────────────────────────────────────────────────────────
class RoleBadge extends StatelessWidget {
  final bool isAdmin;

  const RoleBadge({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: UMTheme.roleBadgeDecoration(isAdmin: isAdmin),
      child: Text(
        isAdmin ? 'Admin' : 'User',
        style: UMTheme.roleBadge.copyWith(
          color: isAdmin ? UMTheme.adminBadgeText : UMTheme.userBadgeText,
        ),
      ),
    );
  }
}

// ─── Popup Menu ───────────────────────────────────────────────────────────────
class CardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CardMenu({super.key, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: UMTheme.textSub),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 18, color: UMTheme.accent),
            SizedBox(width: 10),
            Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Delete',
                style:
                TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
          ]),
        ),
      ],
    );
  }
}