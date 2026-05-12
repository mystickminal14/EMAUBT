import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/access_grant_view_model_v2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ema_app/constants/base_url.dart';

// ── Action mode ────────────────────────────────────────────────────────────
enum _ActionMode { grant, revoke }

class GrantAccessFilesPage extends StatelessWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final bool isAdmin;

  const GrantAccessFilesPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AccessControlViewModel()..fetchAllUserGrantData(userId),
      child: _GrantAccessFilesPageContent(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        isAdmin: isAdmin,
      ),
    );
  }
}

// ── Converted to StatefulWidget to hold local action-mode state ────────────
class _GrantAccessFilesPageContent extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final bool isAdmin;

  const _GrantAccessFilesPageContent({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.isAdmin,
  });

  @override
  State<_GrantAccessFilesPageContent> createState() =>
      _GrantAccessFilesPageContentState();
}

class _GrantAccessFilesPageContentState
    extends State<_GrantAccessFilesPageContent> {
  _ActionMode _actionMode = _ActionMode.grant;

  // Scroll controllers for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _setupScrollListeners();
  }

  void _setupScrollListeners() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - 200) return;

      final vm = context.read<AccessControlViewModel>();
      final isRevoke = _actionMode == _ActionMode.revoke;

      // Load more files
      if (isRevoke) {
        if (vm.grantedFilesPagination?.hasNextPage == true &&
            !vm.isGrantedFilesLoadingMore &&
            !vm.isGrantedFilesLoading) {
          vm.fetchGrantedFiles(widget.userId);
        }
      } else {
        if (vm.notGrantedFilesPagination?.hasNextPage == true &&
            !vm.isNotGrantedFilesLoadingMore &&
            !vm.isNotGrantedFilesLoading) {
          vm.fetchNotGrantedFiles(widget.userId);
        }
      }

      // Load more quiz sets
      if (isRevoke) {
        if (vm.grantedQuizSetsPagination?.hasNextPage == true &&
            !vm.isGrantedQuizSetsLoadingMore &&
            !vm.isGrantedQuizSetsLoading) {
          vm.fetchGrantedQuizSets(widget.userId);
        }
      } else {
        if (vm.notGrantedQuizSetsPagination?.hasNextPage == true &&
            !vm.isNotGrantedQuizSetsLoadingMore &&
            !vm.isNotGrantedQuizSetsLoading) {
          vm.fetchNotGrantedQuizSets(widget.userId);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {required bool isError}) {
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

  Widget _buildItemIcon(String? iconPath, IconData fallback) {
    if (iconPath != null && iconPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          '${BaseUrl.baseUrl}$iconPath',
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

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: FolderTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FolderTheme.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _ModeTab(
            label: 'Grant Access',
            icon: Icons.lock_open_rounded,
            selected: _actionMode == _ActionMode.grant,
            selectedColor: FolderTheme.accent,
            onTap: () {
              if (_actionMode != _ActionMode.grant) {
                setState(() => _actionMode = _ActionMode.grant);
              }
            },
          ),
          const SizedBox(width: 4),
          _ModeTab(
            label: 'Revoke Access',
            icon: Icons.lock_rounded,
            selected: _actionMode == _ActionMode.revoke,
            selectedColor: const Color(0xFFEF4444),
            onTap: () {
              if (_actionMode != _ActionMode.revoke) {
                setState(() => _actionMode = _ActionMode.revoke);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(AccessControlViewModel viewModel) {
    final isRevoke = _actionMode == _ActionMode.revoke;
    final color = isRevoke ? const Color(0xFFEF4444) : FolderTheme.accent;
    final label =
    isRevoke ? 'Revoke Selected Items' : 'Grant Access to Selected Items';
    final icon = isRevoke ? Icons.lock_rounded : Icons.lock_open_rounded;

    final hasSelection = viewModel.selectedFiles.values.any((v) => v) ||
        viewModel.selectedQuizSets.values.any((v) => v);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (viewModel.isActionLoading || !hasSelection)
            ? null
            : () async {
          if (isRevoke) {
            await _handleRevoke(viewModel);
          } else {
            await _handleGrant(viewModel);
          }
        },
        icon: viewModel.isActionLoading
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2),
        )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: FolderTheme.border,
          elevation: 0,
          padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _handleGrant(AccessControlViewModel viewModel) async {
    final selectedFileIds = viewModel.selectedFiles.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final selectedQuizIds = viewModel.selectedQuizSets.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedFileIds.isEmpty && selectedQuizIds.isEmpty) {
      _showSnackBar('Please select at least one item to grant',
          isError: true);
      return;
    }

    final accessTimesText = viewModel.accessTimesController.text;
    final accessTimes = int.tryParse(accessTimesText);

    // Process files
    for (final fileId in selectedFileIds) {
      await viewModel.grantAccess(
        context,
        userId: widget.userId,
        itemId: fileId,
        itemType: 'file',
        action: 'grant',
      );
    }

    // Process quiz sets
    for (final quizId in selectedQuizIds) {
      await viewModel.grantAccess(
        context,
        userId: widget.userId,
        itemId: quizId,
        itemType: 'quiz_set',
        action: 'grant',
      );
    }

    _showSnackBar('Access granted successfully', isError: false);
    viewModel.clearSelections();

    // Refresh data
    await viewModel.refreshAllData(widget.userId);
  }

  Future<void> _handleRevoke(AccessControlViewModel viewModel) async {
    final selectedFileIds = viewModel.selectedFiles.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final selectedQuizIds = viewModel.selectedQuizSets.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedFileIds.isEmpty && selectedQuizIds.isEmpty) {
      _showSnackBar('Please select at least one item to revoke',
          isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Revoke',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: FolderTheme.textMain)),
        content: Text(
          'Revoke access for ${selectedFileIds.length + selectedQuizIds.length} selected item(s)?',
          style: const TextStyle(color: FolderTheme.textSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: FolderTheme.textSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Revoke',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Process files revoke
    for (final fileId in selectedFileIds) {
      await viewModel.grantAccess(
        context,
        userId: widget.userId,
        itemId: fileId,
        itemType: 'file',
        action: 'revoke',
      );
    }

    // Process quiz sets revoke
    for (final quizId in selectedQuizIds) {
      await viewModel.grantAccess(
        context,
        userId: widget.userId,
        itemId: quizId,
        itemType: 'quiz_set',
        action: 'revoke',
      );
    }

    _showSnackBar('Access revoked successfully', isError: false);
    viewModel.clearSelections();

    // Refresh data
    await viewModel.refreshAllData(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccessControlViewModel>(
      builder: (context, viewModel, child) {
        final isRevoke = _actionMode == _ActionMode.revoke;

        // Get the appropriate data based on mode
        final files =
        isRevoke ? viewModel.grantedFiles : viewModel.notGrantedFiles;
        final filesLoading = isRevoke
            ? viewModel.isGrantedFilesLoading
            : viewModel.isNotGrantedFilesLoading;
        final filesLoadingMore = isRevoke
            ? viewModel.isGrantedFilesLoadingMore
            : viewModel.isNotGrantedFilesLoadingMore;

        final quizSets =
        isRevoke ? viewModel.grantedQuizSets : viewModel.notGrantedQuizSets;
        final quizSetsLoading = isRevoke
            ? viewModel.isGrantedQuizSetsLoading
            : viewModel.isNotGrantedQuizSetsLoading;
        final quizSetsLoadingMore = isRevoke
            ? viewModel.isGrantedQuizSetsLoadingMore
            : viewModel.isNotGrantedQuizSetsLoadingMore;

        final isLoading = (filesLoading && files.isEmpty) ||
            (quizSetsLoading && quizSets.isEmpty);

        return Scaffold(
          backgroundColor: FolderTheme.surface,
          appBar: AppBar(
            backgroundColor: FolderTheme.primary,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Manage File Access',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // ── Sticky bottom bar ──────────────────────────────────────────
          bottomNavigationBar: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: FolderTheme.surface,
              border: Border(
                top: BorderSide(color: FolderTheme.border),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SelectionSummary(viewModel: viewModel),
                if (viewModel.selectedFiles.values.any((v) => v) ||
                    viewModel.selectedQuizSets.values.any((v) => v))
                  const SizedBox(height: 10),
                _buildActionButton(viewModel),
              ],
            ),
          ),

          body: isLoading
              ? const Center(
              child: CircularProgressIndicator(
                  color: FolderTheme.accent, strokeWidth: 2.5))
              : RefreshIndicator(
            color: FolderTheme.accent,
            onRefresh: () => viewModel.refreshAllData(widget.userId),
            child: SingleChildScrollView(
              controller: _scrollController,
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
                            color:
                            FolderTheme.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: FolderTheme.accent
                                    .withOpacity(0.3),
                                width: 1.5),
                          ),
                          child: Icon(
                            widget.isAdmin
                                ? Icons.admin_panel_settings_rounded
                                : Icons.person_rounded,
                            color: FolderTheme.accent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isAdmin ? 'Admin' : 'User',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: FolderTheme.accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.userName,
                                style: FolderTheme.screenTitle
                                    .copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.userEmail,
                                style: FolderTheme.cardSubtitle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildModeToggle(),
                  const SizedBox(height: 16),
                  if (isRevoke)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFEF4444)
                                .withOpacity(0.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Only items with an existing permission can be revoked.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFEF4444),
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  // ── Files section ────────────────────────────────
                  _SectionHeader(
                      label: 'Files', count: files.length),
                  const SizedBox(height: 12),
                  files.isEmpty
                      ? const _EmptyCard(
                      icon: Icons.insert_drive_file_outlined,
                      message: 'No files available')
                      : ListView.builder(
                    shrinkWrap: true,
                    physics:
                    const NeverScrollableScrollPhysics(),
                    itemCount: files.length +
                        (filesLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == files.length &&
                          filesLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          ),
                        );
                      }
                      final item = files[index];
                      final itemId = item.id;
                      final selected =
                          viewModel.selectedFiles[itemId] ??
                              false;

                      return _SelectableItemCard(
                        index: index,
                        icon: _buildItemIcon(item.iconPath,
                            Icons.insert_drive_file_rounded),
                        title: item.name,
                        subtitle: isRevoke &&
                            item is dynamic &&
                            item.accessType != null
                            ? 'Access Type: ${item.accessType}'
                            : null,
                        selected: selected,
                        enabled: true,
                        actionMode: _actionMode,
                        onChanged: (v) =>
                            viewModel.toggleFileSelection(
                                itemId, v ?? false),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(height: 1, color: FolderTheme.border),
                  const SizedBox(height: 24),
                  // ── Quiz Sets section ────────────────────────────
                  _SectionHeader(
                      label: 'Quiz Sets', count: quizSets.length),
                  const SizedBox(height: 12),
                  quizSets.isEmpty
                      ? const _EmptyCard(
                      icon: Icons.quiz_outlined,
                      message: 'No quiz sets available')
                      : ListView.builder(
                    shrinkWrap: true,
                    physics:
                    const NeverScrollableScrollPhysics(),
                    itemCount: quizSets.length +
                        (quizSetsLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == quizSets.length &&
                          quizSetsLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          ),
                        );
                      }
                      final item = quizSets[index];
                      final itemId = item.id;
                      final selected =
                          viewModel.selectedQuizSets[itemId] ??
                              false;

                      return _SelectableItemCard(
                        index: index,
                        icon: _buildItemIcon(
                            item.iconPath, Icons.quiz_rounded),
                        title: item.name,
                        subtitle: isRevoke &&
                            item is dynamic &&
                            item.accessType != null
                            ? 'Access Type: ${item.accessType}'
                            : null,
                        selected: selected,
                        enabled: true,
                        actionMode: _actionMode,
                        onChanged: (v) =>
                            viewModel.toggleQuizSetSelection(
                                itemId, v ?? false),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Mode Tab Widget ─────────────────────────────────────────────────────────
class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? selectedColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? selectedColor : FolderTheme.textSub,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? selectedColor : FolderTheme.textSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header Widget ───────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: FolderTheme.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: FolderTheme.textMain,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: FolderTheme.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FolderTheme.accent,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Selectable Item Card Widget ─────────────────────────────────────────────
class _SelectableItemCard extends StatelessWidget {
  final int index;
  final Widget icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final _ActionMode actionMode;
  final ValueChanged<bool?> onChanged;

  const _SelectableItemCard({
    required this.index,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.enabled,
    required this.actionMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index.clamp(0, 8) * 40)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: FolderTheme.cardDecoration,
        child: CheckboxListTile(
          value: selected,
          onChanged: enabled ? onChanged : null,
          activeColor: actionMode == _ActionMode.revoke
              ? const Color(0xFFEF4444)
              : FolderTheme.accent,
          checkboxShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          secondary: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: FolderTheme.iconBg,
            ),
            child: icon,
          ),
          title: Text(
            title,
            style: FolderTheme.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle != null
              ? Text(
            subtitle!,
            style: FolderTheme.cardSubtitle.copyWith(fontSize: 11),
          )
              : null,
          controlAffinity: ListTileControlAffinity.trailing,
        ),
      ),
    );
  }
}

// ── Empty Card Widget ───────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: FolderTheme.cardDecoration,
      child: Column(
        children: [
          Icon(icon,
              size: 48, color: FolderTheme.textSub.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: FolderTheme.textSub,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selection Summary Widget ────────────────────────────────────────────────
class _SelectionSummary extends StatelessWidget {
  final AccessControlViewModel viewModel;

  const _SelectionSummary({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final selectedFilesCount =
        viewModel.selectedFiles.values.where((v) => v).length;
    final selectedQuizCount =
        viewModel.selectedQuizSets.values.where((v) => v).length;
    final totalSelected = selectedFilesCount + selectedQuizCount;

    if (totalSelected == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FolderTheme.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FolderTheme.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FolderTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.checklist_rounded,
              size: 20,
              color: FolderTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalSelected item(s) selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: FolderTheme.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${selectedFilesCount != 0 ? '$selectedFilesCount file(s)' : ''}'
                      '${selectedFilesCount != 0 && selectedQuizCount != 0 ? ', ' : ''}'
                      '${selectedQuizCount != 0 ? '$selectedQuizCount quiz set(s)' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: FolderTheme.textSub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}