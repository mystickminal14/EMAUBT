
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/folder_mode_v2/folder_model_v2.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:flutter/material.dart';

class FolderCard extends StatelessWidget {
  final FolderModelv2 folder;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const FolderCard({
    super.key,
    required this.folder,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 10) * 30)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: FolderTheme.cardDecoration,
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: _FolderIconBox(iconBase64: folder.iconPath),
            title: Text(
              folder.name ?? '—',
              style: FolderTheme.cardTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.insert_drive_file_outlined,
                    size: 13,
                    color: FolderTheme.textSub,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    folder.fileCount != null
                        ? '${folder.fileCount} file${folder.fileCount == 1 ? '' : 's'}'
                        : 'No files',
                    style: FolderTheme.cardSubtitle,
                  ),
                ],
              ),
            ),
            trailing: _FolderCardMenu(onEdit: onEdit, onDelete: onDelete),
          ),
        ),
      ),
    );
  }
}

// ─── Icon Box — renders base64, URL, or fallback folder icon ──────────────────
class _FolderIconBox extends StatelessWidget {
  final String? iconBase64;

  const _FolderIconBox({this.iconBase64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: FolderTheme.iconContainerDecoration,
      clipBehavior: Clip.antiAlias,
      child: _buildIconChild(),
    );
  }

  Widget _buildIconChild() {
    final raw = iconBase64;

    if (raw == null || raw.isEmpty) {
      debugPrint("📁 No icon, using fallback");
      return const _FallbackIcon();
    }

    final fullUrl = Uri.parse("${BaseUrl.imageUrl}/$raw").toString();

    // 🔥 PRINT IMAGE URL
    debugPrint("🖼️ Folder Icon URL => $fullUrl");

    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) {
        debugPrint("❌ Image load failed => $fullUrl");
        debugPrint("Error: $error");
        return const _FallbackIcon();
      },
    );
  }}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.folder_rounded,
        size: 28,
        color: FolderTheme.accent,
      ),
    );
  }
}

// ─── Popup Menu ───────────────────────────────────────────────────────────────
class _FolderCardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FolderCardMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: FolderTheme.textSub),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 18, color: FolderTheme.accent),
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