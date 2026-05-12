import 'dart:io';

import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/screens/play_quiz/user_play_quiz.dart';
import 'package:ema_app/screens/users/home_page.dart';
import 'package:ema_app/screens/users/user_home_page.dart';
import 'package:ema_app/utils/get_headers.dart';
import 'package:ema_app/view_model/access_grant_view_model_v2.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// ─── Entry point (provides ViewModel) ────────────────────────────────────────
class UserFolderDetailsPage extends StatelessWidget {
  final String folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final int userId; // needed to fetch granted items for this user

  const UserFolderDetailsPage({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final folderIdInt = int.tryParse(folderId);

    if (folderIdInt == null) {
      return Scaffold(
        backgroundColor: FolderTheme.surface,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Invalid folder ID', style: FolderTheme.emptyTitle),
                const SizedBox(height: 8),
                Text('Expected a number, got: $folderId',
                    style: FolderTheme.emptySubtitle),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FolderTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => AccessControlViewModel()..fetchUserGrantData(userId),
      child: _UserFolderDetailsContent(
        folderId: folderIdInt,
        folderName: folderName,
        userIdentifier: userIdentifier,
        isAdmin: isAdmin,
        userId: userId,
      ),
    );
  }
}

// ─── Inner stateful content ───────────────────────────────────────────────────
class _UserFolderDetailsContent extends StatefulWidget {
  final int folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final int userId;

  const _UserFolderDetailsContent({
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    required this.userId,
  });

  @override
  State<_UserFolderDetailsContent> createState() =>
      _UserFolderDetailsContentState();
}

class _UserFolderDetailsContentState
    extends State<_UserFolderDetailsContent> {
  // ── Cached user info ──────────────────────────────────────────────────────
  String _cachedFullName = '';
  String _cachedProfileImage = '';
  String _cachedUserEmail = '';

  // ── Scroll ────────────────────────────────────────────────────────────────
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _initUserInfo();
  }

  Future<void> _initUserInfo() async {
    final userVm = UserViewModel();
    final user = await userVm.getUser();
    if (user != null && mounted) {
      setState(() {
        _cachedFullName     = user.fullName ?? '';
        _cachedProfileImage = user.image    ?? '';
        _cachedUserEmail    = user.email    ?? '';
      });
    }
  }

  // ── Scroll near bottom → load next pages ─────────────────────────────────
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos       = _scrollCtrl.position;
    final maxScroll = pos.maxScrollExtent;
    final current   = pos.pixels;
    if (maxScroll <= 0) return;

    final threshold = maxScroll > 200 ? maxScroll - 200 : maxScroll * 0.9;
    if (current < threshold) return;

    final vm = context.read<AccessControlViewModel>();

    if (!vm.isGrantedFilesLoadingMore &&
        !vm.isGrantedFilesLoading &&
        vm.grantedFilesPagination?.hasNextPage == true) {
      vm.fetchGrantedFiles(widget.userId);
    }

    if (!vm.isGrantedQuizSetsLoadingMore &&
        !vm.isGrantedQuizSetsLoading &&
        vm.grantedQuizSetsPagination?.hasNextPage == true) {
      vm.fetchGrantedQuizSets(widget.userId);
    }
  }

  // ── Refresh ───────────────────────────────────────────────────────────────
  Future<void> _refresh() async {
    await context.read<AccessControlViewModel>().refreshAllData(widget.userId);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─── Download & open file ─────────────────────────────────────────────────
  Future<void> _downloadAndOpenFile(
      BuildContext ctx, UserGrantedFile file) async {
    final messenger = ScaffoldMessenger.of(ctx);
    messenger.showSnackBar(SnackBar(
      content: Text('Opening: ${file.name}…'),
      backgroundColor: FolderTheme.accent,
      duration: const Duration(seconds: 2),
    ));

    try {
      final headers     = await getAuthHeaders();
      final downloadUrl = '${BaseUrl.baseUrl}/${file.filePath}';
      final response    =
      await http.get(Uri.parse(downloadUrl), headers: headers);

      if (response.statusCode != 200) {
        if (!ctx.mounted) return;
        messenger.showSnackBar(SnackBar(
          content: Text('Download failed (${response.statusCode})'),
          backgroundColor: Colors.red.shade600,
        ));
        return;
      }

      final safeName =
      file.name.replaceAll(RegExp(r'[^\w\-.]'), '_');

      final dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();
      if (!await dir.exists()) await dir.create(recursive: true);

      final savePath = '${dir.path}/$safeName';
      await File(savePath).writeAsBytes(response.bodyBytes);

      if (!ctx.mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Saved to $savePath'),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 3),
      ));
      await OpenFile.open(savePath);
    } catch (e) {
      if (!ctx.mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red.shade600,
      ));
    }
  }

  // ─── Open quiz set ────────────────────────────────────────────────────────
  void _openQuizSet(BuildContext ctx, UserGrantedQuizSet item) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => UserQuizLoadPage(
          quizSetId:      item.id,
          quizSetName:    item.name,
          folderId:       widget.folderId.toString(),
          folderName:     widget.folderName,
          userIdentifier: widget.userIdentifier,
          isAdmin:        widget.isAdmin,
          fullName:       _cachedFullName,
          userEmail:      _cachedUserEmail,
        ),
      ),
    ).then((_) => _refresh());
  }

  // ─── Navigate home ────────────────────────────────────────────────────────
  void _goHome(BuildContext ctx) {
    if (widget.userIdentifier.isNotEmpty &&
        !widget.userIdentifier.contains('guest')) {
      Navigator.pushAndRemoveUntil(
        ctx,
        MaterialPageRoute(
          builder: (_) => UserHomePage(
            userIdentifier: widget.userIdentifier,
            isAdmin:        widget.isAdmin,
            fullName:       _cachedFullName,
            profileImage:   _cachedProfileImage,
            userEmail:      _cachedUserEmail.isNotEmpty
                ? _cachedUserEmail
                : widget.userIdentifier,
            folderId:   null,
            folderName: '',
          ),
        ),
            (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        ctx,
        MaterialPageRoute(
          builder: (_) => HomePage(
            userIdentifier: '',
            isAdmin:        false,
            fullName:       _cachedFullName,
          ),
        ),
            (route) => false,
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolderTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Consumer<AccessControlViewModel>(
      builder: (_, vm, __) {
        final isLoading =
            vm.isGrantedFilesLoading || vm.isGrantedQuizSetsLoading;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: FolderTheme.card,
            border: Border(
                bottom: BorderSide(color: FolderTheme.border, width: 1)),
          ),
          child: Row(
            children: [
              // Back
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FolderTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FolderTheme.border),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: FolderTheme.textMain, size: 16),
                ),
              ),
              const SizedBox(width: 12),

              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.folderName,
                      style: FolderTheme.screenTitle.copyWith(fontSize: 20),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.isAdmin ? 'Admin view' : 'Your content',
                      style: FolderTheme.screenSubtitle,
                    ),
                  ],
                ),
              ),

              // Refresh
              IconButton(
                onPressed: isLoading ? null : _refresh,
                icon: AnimatedRotation(
                  turns: isLoading ? 1 : 0,
                  duration: const Duration(seconds: 1),
                  child: const Icon(Icons.refresh_rounded,
                      color: FolderTheme.textSub, size: 22),
                ),
              ),

              // Home
              IconButton(
                onPressed: () => _goHome(context),
                icon: const Icon(Icons.home_rounded,
                    color: FolderTheme.textSub, size: 22),
                tooltip: 'Home',
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context) {
    return Consumer<AccessControlViewModel>(
      builder: (ctx, vm, _) {
        // ── Initial loading ──
        final isInitialLoading =
            (vm.isGrantedFilesLoading && vm.grantedFiles.isEmpty) ||
                (vm.isGrantedQuizSetsLoading && vm.grantedQuizSets.isEmpty);

        if (isInitialLoading) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        // ── Filter by active status + private access type ──
        final visibleFiles = vm.grantedFiles
            .where((f) =>
        f.status.toLowerCase() == 'active' &&
            f.accessType == 'private' &&
            f.folderId == widget.folderId)          // ← add this
            .toList();

        final visibleQuiz = vm.grantedQuizSets
            .where((q) =>
        q.status == "published" &&
            q.accessType == 'private' &&
            q.folderId == widget.folderId)          // ← add this
            .toList();

        // ── Empty state ──
        if (visibleFiles.isEmpty &&
            visibleQuiz.isEmpty &&
            !vm.isGrantedFilesLoading &&
            !vm.isGrantedQuizSetsLoading) {
          return _EmptyState(onRetry: _refresh);
        }

        final isFetchingMore =
            vm.isGrantedFilesLoadingMore || vm.isGrantedQuizSetsLoadingMore;

        return RefreshIndicator(
          color: FolderTheme.accent,
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // ── Quiz Sets ──────────────────────────────────────────────
              if (visibleQuiz.isNotEmpty) ...[
                _SectionHeader(
                  icon:  Icons.quiz_rounded,
                  title: 'Quiz Sets',
                  count: visibleQuiz.length,
                ),
                const SizedBox(height: 10),
                ...visibleQuiz.asMap().entries.map(
                      (e) => _QuizSetCard(
                    item:  e.value,
                    index: e.key,
                    onTap: () => _openQuizSet(ctx, e.value),
                  ),
                ),
                if (visibleFiles.isNotEmpty) const SizedBox(height: 20),
              ],

              // ── Files ──────────────────────────────────────────────────
              if (visibleFiles.isNotEmpty) ...[
                _SectionHeader(
                  icon:  Icons.insert_drive_file_rounded,
                  title: 'Files',
                  count: visibleFiles.length,
                ),
                const SizedBox(height: 10),
                ...visibleFiles.asMap().entries.map(
                      (e) => _FileCard(
                    item:  e.value,
                    index: e.key,
                    onTap: () => _downloadAndOpenFile(ctx, e.value),
                  ),
                ),
              ],

              // ── Pagination spinner ──────────────────────────────────────
              if (isFetchingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: FolderTheme.accent, strokeWidth: 2.5),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: FolderTheme.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: FolderTheme.accent),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: FolderTheme.textMain)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: FolderTheme.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FolderTheme.accent)),
        ),
      ],
    );
  }
}

// ─── File Card ────────────────────────────────────────────────────────────────
class _FileCard extends StatelessWidget {
  final UserGrantedFile item;
  final int index;
  final VoidCallback onTap;

  const _FileCard({
    required this.item,
    required this.index,
    required this.onTap,
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
            leading: _ItemIconBox(iconPath: item.iconPath, isQuiz: false),
            title: Text(
              item.name,
              style: FolderTheme.cardTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.open_in_full,
                      size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.folderName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueAccent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: FolderTheme.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quiz Set Card ────────────────────────────────────────────────────────────
class _QuizSetCard extends StatelessWidget {
  final UserGrantedQuizSet item;
  final int index;
  final VoidCallback onTap;

  const _QuizSetCard({
    required this.item,
    required this.index,
    required this.onTap,
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
            leading: _ItemIconBox(iconPath: item.iconPath, isQuiz: true),
            title: Text(
              item.name,
              style: FolderTheme.cardTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.lock_open_outlined,
                      size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${item.questionCount} questions · ${item.durationMinutes} min · ${item.folderName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blueAccent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: FolderTheme.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Open',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Item Icon Box ────────────────────────────────────────────────────────────
class _ItemIconBox extends StatelessWidget {
  final String? iconPath;
  final bool isQuiz;

  const _ItemIconBox({this.iconPath, required this.isQuiz});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: FolderTheme.iconContainerDecoration,
      clipBehavior: Clip.antiAlias,
      child: _buildChild(),
    );
  }

  Widget _buildChild() {
    final raw = iconPath;
    if (raw == null || raw.isEmpty) {
      return _FallbackIcon(isQuiz: isQuiz);
    }
    final fullUrl = Uri.parse('${BaseUrl.imageUrl}/$raw').toString();
    return FutureBuilder<Map<String, String>>(
      future: getAuthHeaders(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return Image.network(
          fullUrl,
          headers: snap.data,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _FallbackIcon(isQuiz: isQuiz),
        );
      },
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final bool isQuiz;
  const _FallbackIcon({required this.isQuiz});

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      isQuiz
          ? Icons.quiz_rounded
          : Icons.insert_drive_file_rounded,
      size: 28,
      color: FolderTheme.accent,
    ),
  );
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: FolderTheme.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_open_rounded,
                size: 38, color: FolderTheme.accent),
          ),
          const SizedBox(height: 16),
          const Text('No content available', style: FolderTheme.emptyTitle),
          const SizedBox(height: 6),
          const Text(
            'This folder has no granted files or quiz sets.',
            style: FolderTheme.emptySubtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: FolderTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}