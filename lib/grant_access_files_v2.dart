import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/grant_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ema_app/constants/base_url.dart';

class GrantAccessFilesPage extends StatelessWidget {
  final Map<String, dynamic> entity;
  final bool isAdmin;

  const GrantAccessFilesPage({
    super.key,
    required this.entity,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
      GrantAccessFilesViewModel()..initializeData(entity['email'] ?? ''),
      child: _GrantAccessFilesPageContent(
        entity: entity,
        isAdmin: isAdmin,
      ),
    );
  }
}

class _GrantAccessFilesPageContent extends StatelessWidget {
  final Map<String, dynamic> entity;
  final bool isAdmin;

  const _GrantAccessFilesPageContent({
    required this.entity,
    required this.isAdmin,
  });

  void _showSnackBar(BuildContext context, String message,
      {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
        isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Widget _buildItemIcon(dynamic item, IconData fallback) {
    if (item.iconPath != null && item.iconPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          '${BaseUrl.baseUrl}${item.iconPath}',
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(fallback, size: 28, color: FolderTheme.accent),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                  color: FolderTheme.accent,
                ),
              ),
            );
          },
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: FolderTheme.iconContainerDecoration,
      child: Icon(fallback, size: 24, color: FolderTheme.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GrantAccessFilesViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          backgroundColor: FolderTheme.surface,
          appBar: AppBar(
            backgroundColor: FolderTheme.primary,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Grant File Access',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          body: viewModel.isLoading
              ? const Center(
              child: CircularProgressIndicator(
                  color: FolderTheme.accent, strokeWidth: 2.5))
              : RefreshIndicator(
            color: FolderTheme.accent,
            onRefresh: () =>
                viewModel.initializeData(entity['email'] ?? ''),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Person card ──────────────────────────────────
                  Container(
                    decoration: FolderTheme.cardDecoration,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: FolderTheme.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                FolderTheme.accent.withOpacity(0.3),
                                width: 1.5),
                          ),
                          child: Icon(
                            isAdmin
                                ? Icons.admin_panel_settings_rounded
                                : Icons.person_rounded,
                            color: FolderTheme.accent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isAdmin ? 'Admin' : 'User',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: FolderTheme.accent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entity['full_name'] ?? 'Unknown',
                                style: FolderTheme.screenTitle
                                    .copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entity['email'] ?? 'No email',
                                style: FolderTheme.cardSubtitle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Access times input ───────────────────────────
                  Container(
                    decoration: FolderTheme.fieldDecoration(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: FolderTheme.accent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: viewModel.accessTimesController,
                            keyboardType: TextInputType.number,
                            style: FolderTheme.fieldInput,
                            decoration: const InputDecoration(
                              labelText: 'Number of Access Times',
                              labelStyle: FolderTheme.fieldLabel,
                              hintText: 'How many times can they access?',
                              hintStyle: FolderTheme.fieldLabel,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Files section ────────────────────────────────
                  _SectionHeader(
                      label: 'Files', count: viewModel.files.length),
                  const SizedBox(height: 12),
                  viewModel.files.isEmpty
                      ? _EmptyCard(
                      icon: Icons.insert_drive_file_outlined,
                      message: 'No files available')
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: viewModel.files.length,
                    itemBuilder: (context, index) {
                      final file = viewModel.files[index];
                      final selected =
                          viewModel.selectedFiles[file.id!] ??
                              false;
                      return _SelectableItemCard(
                        index: index,
                        icon: _buildItemIcon(
                            file, Icons.insert_drive_file_rounded),
                        title: file.name ?? 'Unnamed File',
                        selected: selected,
                        enabled: true,
                        onChanged: (v) => viewModel
                            .toggleFileSelection(file.id!, v ?? false),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  Container(height: 1, color: FolderTheme.border),
                  const SizedBox(height: 24),

                  // ── Quiz Sets section ────────────────────────────
                  _SectionHeader(
                      label: 'Quiz Sets',
                      count: viewModel.quizSets.length),
                  const SizedBox(height: 12),
                  viewModel.quizSets.isEmpty
                      ? _EmptyCard(
                      icon: Icons.quiz_outlined,
                      message: 'No quiz sets available')
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: viewModel.quizSets.length,
                    itemBuilder: (context, index) {
                      final quizSet = viewModel.quizSets[index];
                      final isFree = viewModel
                          .isFirstQuizSetInFirstFolder(quizSet);
                      final selected =
                          viewModel.selectedQuizSets[quizSet.id!] ??
                              false;
                      return _SelectableItemCard(
                        index: index,
                        icon: _buildItemIcon(
                            quizSet, Icons.quiz_rounded),
                        title: quizSet.name ?? 'Unnamed Quiz Set',
                        subtitle: isFree
                            ? 'Free for all · Folder 1, First Quiz'
                            : null,
                        subtitleColor: const Color(0xFFF59E0B),
                        selected: selected,
                        enabled: !isFree,
                        onChanged: isFree
                            ? null
                            : (v) => viewModel.toggleQuizSetSelection(
                            quizSet.id!, v ?? false),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Grant button ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: viewModel.isLoading
                          ? null
                          : () async {
                        try {
                          final success =
                          await viewModel.grantFileAccess(
                              entity['email'] ?? '', isAdmin);
                          if (success) {
                            _showSnackBar(context,
                                'Access granted successfully',
                                isError: false);
                            Navigator.pop(context, true);
                          }
                        } catch (e) {
                          _showSnackBar(context, e.toString(),
                              isError: true);
                        }
                      },
                      icon: viewModel.isLoading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                          : const Icon(Icons.lock_open_rounded, size: 20),
                      label: const Text('Grant Access to Selected Items',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FolderTheme.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                        FolderTheme.border,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Container(height: 1, color: FolderTheme.border),
                  const SizedBox(height: 24),

                  // ── Current permissions ──────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Permissions',
                          style: FolderTheme.sheetTitle),
                      IconButton(
                        onPressed: () async {
                          try {
                            await viewModel.fetchAccessPermissions(
                                entity['email'] ?? '');
                          } catch (e) {
                            _showSnackBar(context, e.toString(),
                                isError: true);
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded,
                            color: FolderTheme.accent),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  viewModel.accessPermissions.isEmpty
                      ? _EmptyCard(
                      icon: Icons.shield_outlined,
                      message: 'No permissions granted yet')
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: viewModel.accessPermissions.length,
                    itemBuilder: (context, index) {
                      final permission =
                      viewModel.accessPermissions[index];
                      final isFile =
                          permission['item_type'] == 'file';
                      final itemName = permission['item_name'] ??
                          'Unnamed ${isFile ? 'File' : 'Quiz Set'}';
                      final accessTimes =
                      permission['access_times'] == -1
                          ? 'Unlimited'
                          : permission['access_times']
                          .toString();
                      final timesUsed =
                      permission['times_accessed'].toString();
                      final isDeletable =
                          permission['access_times'] != -1;

                      return _PermissionCard(
                        index: index,
                        isFile: isFile,
                        itemName: itemName,
                        accessTimes: accessTimes,
                        timesUsed: timesUsed,
                        isDeletable: isDeletable,
                        onDelete: () async {
                          final confirmed =
                          await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(20)),
                              title: const Text('Confirm Deletion',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color:
                                      FolderTheme.textMain)),
                              content: Text(
                                'Remove access to this ${isFile ? 'file' : 'quiz set'}?',
                                style: const TextStyle(
                                    color: FolderTheme.textSub,
                                    height: 1.5),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: const Text('Cancel',
                                      style: TextStyle(
                                          color:
                                          FolderTheme.textSub)),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                    const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(
                                            10)),
                                  ),
                                  child: const Text('Delete',
                                      style: TextStyle(
                                          fontWeight:
                                          FontWeight.w600)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              final success = await viewModel
                                  .deleteAccessPermission(
                                permission['item_id'],
                                permission['item_type'],
                                entity['email'] ?? '',
                              );
                              if (success) {
                                _showSnackBar(context,
                                    'Permission removed',
                                    isError: false);
                              }
                            } catch (e) {
                              _showSnackBar(context, e.toString(),
                                  isError: true);
                            }
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: FolderTheme.sheetTitle.copyWith(fontSize: 16)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: FolderTheme.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FolderTheme.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FolderTheme.cardDecoration,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: FolderTheme.textSub, size: 22),
          const SizedBox(width: 12),
          Text(message, style: FolderTheme.cardSubtitle),
        ],
      ),
    );
  }
}

class _SelectableItemCard extends StatelessWidget {
  final int index;
  final Widget icon;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool?>? onChanged;

  const _SelectableItemCard({
    required this.index,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    required this.selected,
    required this.enabled,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
      Duration(milliseconds: 180 + (index.clamp(0, 8) * 30)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: FolderTheme.cardDecoration.copyWith(
          border: Border.all(
            color: selected
                ? FolderTheme.accent
                : FolderTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: CheckboxListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          value: selected,
          onChanged: enabled ? onChanged : null,
          activeColor: FolderTheme.accent,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          secondary: icon,
          title: Text(
            title,
            style: FolderTheme.cardTitle.copyWith(
                color: enabled ? FolderTheme.textMain : FolderTheme.textSub),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle != null
              ? Text(
            subtitle!,
            style: FolderTheme.cardSubtitle
                .copyWith(color: subtitleColor ?? FolderTheme.textSub),
          )
              : null,
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final int index;
  final bool isFile;
  final String itemName;
  final String accessTimes;
  final String timesUsed;
  final bool isDeletable;
  final VoidCallback onDelete;

  const _PermissionCard({
    required this.index,
    required this.isFile,
    required this.itemName,
    required this.accessTimes,
    required this.timesUsed,
    required this.isDeletable,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFile ? FolderTheme.accent : const Color(0xFF22C55E);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
      Duration(milliseconds: 180 + (index.clamp(0, 8) * 30)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: FolderTheme.cardDecoration,
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(
              isFile
                  ? Icons.insert_drive_file_rounded
                  : Icons.quiz_rounded,
              color: color,
              size: 22,
            ),
          ),
          title: Text(
            '${isFile ? 'File' : 'Quiz Set'}: $itemName',
            style: FolderTheme.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.access_time_rounded,
                  label: accessTimes,
                  tooltip: 'Access limit',
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.bar_chart_rounded,
                  label: 'Used: $timesUsed',
                  tooltip: 'Times accessed',
                ),
              ],
            ),
          ),
          trailing: isDeletable
              ? IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFEF4444), size: 22),
            onPressed: onDelete,
            tooltip: 'Remove access',
          )
              : Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FolderTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FolderTheme.border),
            ),
            child: const Text(
              'System',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: FolderTheme.textSub),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  const _StatChip(
      {required this.icon, required this.label, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FolderTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FolderTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: FolderTheme.textSub),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FolderTheme.textSub),
          ),
        ],
      ),
    );
  }
}