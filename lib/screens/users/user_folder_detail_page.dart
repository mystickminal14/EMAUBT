import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/folder_mode_v2/new_file_model.dart';
import 'package:ema_app/model/folder_mode_v2/new_quiz_set_model.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/screens/play_quiz/user_play_quiz.dart';
import 'package:ema_app/screens/users/home_page.dart';
import 'package:ema_app/screens/users/user_home_page.dart';
import 'package:ema_app/screens/viewer/in_app_file_viewer.dart';
import 'package:ema_app/utils/get_headers.dart';
import 'package:ema_app/utils/responsive.dart';
import 'package:ema_app/view_model/access_grant_view_model_v2.dart';
import 'package:ema_app/view_model/folders/new_files_vm.dart';
import 'package:ema_app/view_model/folders/new_folder_quiz.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─── Entry point (provides ViewModels) ───────────────────────────────────────
class UserFolderDetailsPage extends StatelessWidget {
  final String folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final int userId;

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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final vm = AccessControlViewModel();
            if (!isAdmin) {
              vm.fetchAllUserGrantData(userId);
            }
            return vm;
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final vm = FolderFilesViewModel();
            if (isAdmin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                vm.fetchFiles(ctx, folderIdInt, refresh: true);
              });
            }
            return vm;
          },
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final vm = FolderQuizSetsViewModel();
            if (isAdmin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                vm.fetchQuizSets(ctx, folderIdInt, refresh: true);
              });
            }
            return vm;
          },
        ),
      ],
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

class _UserFolderDetailsContentState extends State<_UserFolderDetailsContent>
    with SingleTickerProviderStateMixin {
  // ── Cached user info ──────────────────────────────────────────────────────
  String _cachedFullName = '';
  String _cachedProfileImage = '';
  String _cachedUserEmail = '';

  // ── Scroll & Tabs ─────────────────────────────────────────────────────────
  late final ScrollController _filesScrollCtrl;
  late final ScrollController _quizScrollCtrl;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _filesScrollCtrl = ScrollController()..addListener(_onFilesScroll);
    _quizScrollCtrl = ScrollController()..addListener(_onQuizScroll);
    _tabController = TabController(length: 2, vsync: this);
    _initUserInfo();
  }

  Future<void> _initUserInfo() async {
    final userVm = UserViewModel();
    final user = await userVm.getUser();
    if (user != null && mounted) {
      setState(() {
        _cachedFullName = user.fullName ?? '';
        _cachedProfileImage = user.image ?? '';
        _cachedUserEmail = user.email ?? '';
      });
    }
  }

  // ── Scroll handlers ──────────────────────────────────────────────────────
  bool _isNearBottom(ScrollController ctrl) {
    if (!ctrl.hasClients) return false;
    final pos = ctrl.position;
    final maxScroll = pos.maxScrollExtent;
    final current = pos.pixels;
    if (maxScroll <= 0) return false;
    final threshold = maxScroll > 200 ? maxScroll - 200 : maxScroll * 0.9;
    return current >= threshold;
  }

  void _onFilesScroll() {
    if (!_isNearBottom(_filesScrollCtrl)) return;

    if (widget.isAdmin) {
      final filesVm = context.read<FolderFilesViewModel>();
      if (filesVm.hasMorePages &&
          !filesVm.isFetchingMore &&
          !filesVm.isLoading) {
        filesVm.fetchNextPage(context, widget.folderId);
      }
    } else {
      final vm = context.read<AccessControlViewModel>();
      if (!vm.isGrantedFilesLoadingMore &&
          !vm.isGrantedFilesLoading &&
          vm.grantedFilesPagination?.hasNextPage == true) {
        vm.fetchGrantedFiles(widget.userId);
      }
      if (!vm.isNotGrantedFilesLoadingMore &&
          !vm.isNotGrantedFilesLoading &&
          vm.notGrantedFilesPagination?.hasNextPage == true) {
        vm.fetchNotGrantedFiles(widget.userId);
      }
    }
  }

  void _onQuizScroll() {
    if (!_isNearBottom(_quizScrollCtrl)) return;

    if (widget.isAdmin) {
      final quizVm = context.read<FolderQuizSetsViewModel>();
      if (quizVm.hasMorePages &&
          !quizVm.isFetchingMore &&
          !quizVm.isLoading) {
        quizVm.fetchNextPage(context, widget.folderId);
      }
    } else {
      final vm = context.read<AccessControlViewModel>();
      if (!vm.isGrantedQuizSetsLoadingMore &&
          !vm.isGrantedQuizSetsLoading &&
          vm.grantedQuizSetsPagination?.hasNextPage == true) {
        vm.fetchGrantedQuizSets(widget.userId);
      }
      if (!vm.isNotGrantedQuizSetsLoadingMore &&
          !vm.isNotGrantedQuizSetsLoading &&
          vm.notGrantedQuizSetsPagination?.hasNextPage == true) {
        vm.fetchNotGrantedQuizSets(widget.userId);
      }
    }
  }

  // ── Refresh ───────────────────────────────────────────────────────────────
  Future<void> _refresh() async {
    if (widget.isAdmin) {
      await Future.wait([
        context
            .read<FolderFilesViewModel>()
            .fetchFiles(context, widget.folderId, refresh: true),
        context
            .read<FolderQuizSetsViewModel>()
            .fetchQuizSets(context, widget.folderId, refresh: true),
      ]);
    } else {
      await context
          .read<AccessControlViewModel>()
          .refreshAllData(widget.userId);
    }
  }

  @override
  void dispose() {
    _filesScrollCtrl.dispose();
    _quizScrollCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ─── View helpers (in-app only — files are never downloaded) ──────────────
  void _viewGrantedFile(BuildContext ctx, UserGrantedFile file) {
    _viewFile(ctx, file.name, file.filePath);
  }

  void _viewAdminFile(BuildContext ctx, FileModel file) {
    final path = file.filePath ?? '';
    if (path.isEmpty) return;
    _viewFile(ctx, file.name ?? 'file', path);
  }

  void _viewFile(BuildContext ctx, String name, String filePath) {
    // Static assets live behind the `/api/res` route.
    final url =
        '${BaseUrl.baseUrl}/res/${filePath.replaceFirst(RegExp(r'^/+'), '')}';

    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => InAppFileViewerPage(url: url, fileName: name),
      ),
    );
  }

  // ─── Show locked message ──────────────────────────────────────────────────
  void _showLockedMessage(BuildContext ctx, String itemName) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Access not granted: $itemName',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Open quiz set helpers ────────────────────────────────────────────────
  void _openGrantedQuizSet(BuildContext ctx, UserGrantedQuizSet item) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => UserQuizLoadPage(
          quizSetId: item.id,
          quizSetName: item.name,
          folderId: widget.folderId.toString(),
          folderName: widget.folderName,
          userIdentifier: widget.userIdentifier,
          isAdmin: widget.isAdmin,
          fullName: _cachedFullName,
          userEmail: _cachedUserEmail,
        ),
      ),
    ).then((_) => _refresh());
  }

  void _openAdminQuizSet(BuildContext ctx, QuizSetModel item) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => UserQuizLoadPage(
          quizSetId: item.id ?? 0,
          quizSetName: item.name ?? '',
          folderId: widget.folderId.toString(),
          folderName: widget.folderName,
          userIdentifier: widget.userIdentifier,
          isAdmin: widget.isAdmin,
          fullName: _cachedFullName,
          userEmail: _cachedUserEmail,
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
            isAdmin: widget.isAdmin,
            fullName: _cachedFullName,
            profileImage: _cachedProfileImage,
            userEmail: _cachedUserEmail.isNotEmpty
                ? _cachedUserEmail
                : widget.userIdentifier,
            folderId: null,
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
            isAdmin: false,
            fullName: _cachedFullName,
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
            _buildTabBar(context),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0 — Files
                  widget.isAdmin ? _buildAdminFilesTab() : _buildUserFilesTab(),
                  // Tab 1 — Quiz Sets
                  widget.isAdmin ? _buildAdminQuizTab() : _buildUserQuizTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: FolderTheme.card,
        border:
        Border(bottom: BorderSide(color: FolderTheme.border, width: 1)),
      ),
      child: Row(
        children: [
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
                  widget.isAdmin ? 'Admin view · Full access' : 'Your content',
                  style: FolderTheme.screenSubtitle,
                ),
              ],
            ),
          ),
          _RefreshButton(isAdmin: widget.isAdmin, onRefresh: _refresh),
          IconButton(
            onPressed: () => _goHome(context),
            icon: const Icon(Icons.home_rounded,
                color: FolderTheme.textSub, size: 22),
            tooltip: 'Home',
          ),
        ],
      ),
    );
  }

  // ─── Tab Bar (reactive counts) ────────────────────────────────────────────
  // NOTE: Status filtering is now handled server-side via query params
  // (status=active for files, status=published for quiz sets), so we only
  // filter client-side by folderId here.
  Widget _buildTabBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FolderTheme.card,
        border:
        Border(bottom: BorderSide(color: FolderTheme.border, width: 1)),
      ),
      child: widget.isAdmin
          ? Consumer2<FolderFilesViewModel, FolderQuizSetsViewModel>(
        builder: (_, filesVm, quizVm, __) {
          return _tabBarWidget(
            fileCount: filesVm.files.length,
            quizCount: quizVm.quizSets.length,
          );
        },
      )
          : Consumer<AccessControlViewModel>(
        builder: (_, vm, __) {
          final filesTotal = vm.grantedFiles
              .where((f) => f.folderId == widget.folderId)
              .length +
              vm.notGrantedFiles
                  .where((f) => f.folderId == widget.folderId)
                  .length;
          final quizTotal = vm.grantedQuizSets
              .where((q) => q.folderId == widget.folderId)
              .length +
              vm.notGrantedQuizSets
                  .where((q) => q.folderId == widget.folderId)
                  .length;
          return _tabBarWidget(
              fileCount: filesTotal, quizCount: quizTotal);
        },
      ),
    );
  }

  Widget _tabBarWidget({required int fileCount, required int quizCount}) {
    return TabBar(
      controller: _tabController,
      indicatorColor: FolderTheme.accent,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: FolderTheme.accent,
      unselectedLabelColor: FolderTheme.textSub,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      tabs: [
        Tab(
          height: 48,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_rounded, size: 18),
              const SizedBox(width: 6),
              const Text('Files'),
              const SizedBox(width: 6),
              _tabCountBadge(fileCount),
            ],
          ),
        ),
        Tab(
          height: 48,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.quiz_rounded, size: 18),
              const SizedBox(width: 6),
              const Text('Quiz Sets'),
              const SizedBox(width: 6),
              _tabCountBadge(quizCount),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: FolderTheme.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: FolderTheme.accent,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ADMIN — FILES TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildAdminFilesTab() {
    return Consumer<FolderFilesViewModel>(
      builder: (ctx, filesVm, _) {
        if (filesVm.isLoading && filesVm.files.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        final adminFiles = filesVm.files;
        if (adminFiles.isEmpty && !filesVm.isLoading) {
          return _EmptyState(
            onRetry: _refresh,
            message: 'No files in this folder.',
          );
        }

        return RefreshIndicator(
          color: FolderTheme.accent,
          onRefresh: _refresh,
          child: ResponsiveCenter(
            tabletMaxWidth: 640,
            desktopMaxWidth: 800,
            child: ListView(
              controller: _filesScrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                ...adminFiles.asMap().entries.map(
                      (e) => _AdminFileCard(
                    item: e.value,
                    index: e.key,
                    folderName: widget.folderName,
                    onTap: () => _viewAdminFile(ctx, e.value),
                  ),
                ),
                if (filesVm.isFetchingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: FolderTheme.accent, strokeWidth: 2.5),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ADMIN — QUIZ TAB
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildAdminQuizTab() {
    return Consumer<FolderQuizSetsViewModel>(
      builder: (ctx, quizVm, _) {
        if (quizVm.isLoading && quizVm.quizSets.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        final adminQuiz = quizVm.quizSets;
        if (adminQuiz.isEmpty && !quizVm.isLoading) {
          return _EmptyState(
            onRetry: _refresh,
            message: 'No quiz sets in this folder.',
          );
        }

        return RefreshIndicator(
          color: FolderTheme.accent,
          onRefresh: _refresh,
          child: ResponsiveCenter(
            tabletMaxWidth: 640,
            desktopMaxWidth: 800,
            child: ListView(
              controller: _quizScrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                ...adminQuiz.asMap().entries.map(
                      (e) => _AdminQuizSetCard(
                    item: e.value,
                    index: e.key,
                    folderName: widget.folderName,
                    onTap: () => _openAdminQuizSet(ctx, e.value),
                  ),
                ),
                if (quizVm.isFetchingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: FolderTheme.accent, strokeWidth: 2.5),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // USER — FILES TAB (granted + not-granted)
  // Status filter (active) is applied server-side; we only filter by folderId.
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildUserFilesTab() {
    return Consumer<AccessControlViewModel>(
      builder: (ctx, vm, _) {
        final isInitial = vm.isGrantedFilesLoading &&
            vm.grantedFiles.isEmpty &&
            vm.notGrantedFiles.isEmpty;

        if (isInitial) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        final grantedFiles = vm.grantedFiles
            .where((f) => f.folderId == widget.folderId)
            .toList();

        final notGrantedFiles = vm.notGrantedFiles
            .where((f) => f.folderId == widget.folderId)
            .toList();

        if (grantedFiles.isEmpty &&
            notGrantedFiles.isEmpty &&
            !vm.isGrantedFilesLoading &&
            !vm.isNotGrantedFilesLoading) {
          return _EmptyState(
            onRetry: _refresh,
            message: 'No files available in this folder.',
          );
        }

        final allFiles = <_FileEntry>[
          ...grantedFiles.map((f) => _FileEntry(file: f, granted: true)),
          ...notGrantedFiles.map((f) => _FileEntry(file: f, granted: false)),
        ];

        final isFetchingMore =
            vm.isGrantedFilesLoadingMore || vm.isNotGrantedFilesLoadingMore;

        return RefreshIndicator(
          color: FolderTheme.accent,
          onRefresh: _refresh,
          child: ResponsiveCenter(
            tabletMaxWidth: 640,
            desktopMaxWidth: 800,
            child: ListView(
              controller: _filesScrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                if (allFiles.isNotEmpty)
                  _LegendRow(
                    grantedCount: grantedFiles.length,
                    lockedCount: notGrantedFiles.length,
                  ),
                ...allFiles.asMap().entries.map(
                      (e) => _FileCard(
                    item: e.value.file,
                    index: e.key,
                    granted: e.value.granted,
                    onTap: () {
                      if (e.value.granted) {
                        _viewGrantedFile(ctx, e.value.file);
                      } else {
                        _showLockedMessage(ctx, e.value.file.name);
                      }
                    },
                  ),
                ),
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
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // USER — QUIZ TAB (granted + not-granted)
  // Status filter (published) is applied server-side; we only filter by folderId.
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildUserQuizTab() {
    return Consumer<AccessControlViewModel>(
      builder: (ctx, vm, _) {
        final isInitial = vm.isGrantedQuizSetsLoading &&
            vm.grantedQuizSets.isEmpty &&
            vm.notGrantedQuizSets.isEmpty;

        if (isInitial) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        final grantedQuiz = vm.grantedQuizSets
            .where((q) => q.folderId == widget.folderId)
            .toList();

        final notGrantedQuiz = vm.notGrantedQuizSets
            .where((q) => q.folderId == widget.folderId)
            .toList();

        if (grantedQuiz.isEmpty &&
            notGrantedQuiz.isEmpty &&
            !vm.isGrantedQuizSetsLoading &&
            !vm.isNotGrantedQuizSetsLoading) {
          return _EmptyState(
            onRetry: _refresh,
            message: 'No quiz sets available in this folder.',
          );
        }

        final allQuiz = <_QuizEntry>[
          ...grantedQuiz.map((q) => _QuizEntry(quiz: q, granted: true)),
          ...notGrantedQuiz.map((q) => _QuizEntry(quiz: q, granted: false)),
        ];

        final isFetchingMore = vm.isGrantedQuizSetsLoadingMore ||
            vm.isNotGrantedQuizSetsLoadingMore;

        return RefreshIndicator(
          color: FolderTheme.accent,
          onRefresh: _refresh,
          child: ResponsiveCenter(
            tabletMaxWidth: 640,
            desktopMaxWidth: 800,
            child: ListView(
              controller: _quizScrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                if (allQuiz.isNotEmpty)
                  _LegendRow(
                    grantedCount: grantedQuiz.length,
                    lockedCount: notGrantedQuiz.length,
                  ),
                ...allQuiz.asMap().entries.map(
                      (e) => _QuizSetCard(
                    item: e.value.quiz,
                    index: e.key,
                    granted: e.value.granted,
                    onTap: () {
                      if (e.value.granted) {
                        _openGrantedQuizSet(ctx, e.value.quiz);
                      } else {
                        _showLockedMessage(ctx, e.value.quiz.name);
                      }
                    },
                  ),
                ),
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
          ),
        );
      },
    );
  }
}

// ─── Internal merge wrappers ────────────────────────────────────────────────
class _FileEntry {
  final UserGrantedFile file;
  final bool granted;
  _FileEntry({required this.file, required this.granted});
}

class _QuizEntry {
  final UserGrantedQuizSet quiz;
  final bool granted;
  _QuizEntry({required this.quiz, required this.granted});
}

// ─── Legend Row (above lists in user view) ──────────────────────────────────
class _LegendRow extends StatelessWidget {
  final int grantedCount;
  final int lockedCount;
  const _LegendRow({required this.grantedCount, required this.lockedCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _LegendChip(
            color: const Color(0xFF10B981),
            label: '$grantedCount accessible',
          ),
          const SizedBox(width: 8),
          _LegendChip(
            color: Colors.red.shade400,
            label: '$lockedCount locked',
          ),
        ],
      ),
    );
  }
}

// ─── Refresh Button ─────────────────────────────────────────────────────────
class _RefreshButton extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onRefresh;
  const _RefreshButton({required this.isAdmin, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (isAdmin) {
      return Consumer2<FolderFilesViewModel, FolderQuizSetsViewModel>(
        builder: (_, fVm, qVm, __) {
          final loading = fVm.isLoading || qVm.isLoading;
          return _buildButton(loading);
        },
      );
    }
    return Consumer<AccessControlViewModel>(
      builder: (_, vm, __) {
        final loading = vm.isGrantedFilesLoading ||
            vm.isNotGrantedFilesLoading ||
            vm.isGrantedQuizSetsLoading ||
            vm.isNotGrantedQuizSetsLoading;
        return _buildButton(loading);
      },
    );
  }

  Widget _buildButton(bool loading) => IconButton(
    onPressed: loading ? null : onRefresh,
    icon: AnimatedRotation(
      turns: loading ? 1 : 0,
      duration: const Duration(seconds: 1),
      child: const Icon(Icons.refresh_rounded,
          color: FolderTheme.textSub, size: 22),
    ),
  );
}

// ─── Legend Chip ────────────────────────────────────────────────────────────
class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── File Card (USER — granted/not-granted aware) ───────────────────────────
class _FileCard extends StatelessWidget {
  final UserGrantedFile item;
  final int index;
  final bool granted;
  final VoidCallback onTap;

  const _FileCard({
    required this.item,
    required this.index,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
    granted ? const Color(0xFF10B981) : Colors.red.shade400;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 10) * 30)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: FolderTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withOpacity(0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
              ),
              ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: Opacity(
                  opacity: granted ? 1.0 : 0.55,
                  child: _ItemIconBox(iconPath: item.iconPath, isQuiz: false),
                ),
                title: Text(
                  item.name,
                  style: FolderTheme.cardTitle.copyWith(
                    color: granted
                        ? FolderTheme.textMain
                        : FolderTheme.textMain.withOpacity(0.65),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        granted ? Icons.lock_open_rounded : Icons.lock_rounded,
                        size: 12,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          granted
                              ? item.folderName
                              : 'Locked · ${item.folderName}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: accentColor,
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
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    granted ? 'View' : 'Locked',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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
}

// ─── Quiz Set Card (USER — granted/not-granted aware) ───────────────────────
class _QuizSetCard extends StatelessWidget {
  final UserGrantedQuizSet item;
  final int index;
  final bool granted;
  final VoidCallback onTap;

  const _QuizSetCard({
    required this.item,
    required this.index,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
    granted ? const Color(0xFF10B981) : Colors.red.shade400;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 10) * 30)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: FolderTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withOpacity(0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
              ),
              ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: Opacity(
                  opacity: granted ? 1.0 : 0.55,
                  child: _ItemIconBox(iconPath: item.iconPath, isQuiz: true),
                ),
                title: Text(
                  item.name,
                  style: FolderTheme.cardTitle.copyWith(
                    color: granted
                        ? FolderTheme.textMain
                        : FolderTheme.textMain.withOpacity(0.65),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        granted ? Icons.lock_open_rounded : Icons.lock_rounded,
                        size: 12,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          granted
                              ? '${item.questionCount} questions · ${item.durationMinutes} min · ${item.folderName}'
                              : 'Locked · ${item.questionCount} questions · ${item.durationMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: accentColor,
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
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    granted ? 'Open' : 'Locked',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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
}

// ─── Admin File Card (FileModel) ────────────────────────────────────────────
class _AdminFileCard extends StatelessWidget {
  final FileModel item;
  final int index;
  final String folderName;
  final VoidCallback onTap;

  const _AdminFileCard({
    required this.item,
    required this.index,
    required this.folderName,
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
              item.name ?? 'Untitled',
              style: FolderTheme.cardTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      folderName,
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

// ─── Admin Quiz Card (QuizSetModel) ─────────────────────────────────────────
class _AdminQuizSetCard extends StatelessWidget {
  final QuizSetModel item;
  final int index;
  final String folderName;
  final VoidCallback onTap;

  const _AdminQuizSetCard({
    required this.item,
    required this.index,
    required this.folderName,
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
              item.name ?? 'Untitled',
              style: FolderTheme.cardTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${item.questionCount ?? 0} questions · ${item.durationMinutes ?? 0} min · $folderName',
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

// ─── Item Icon Box ──────────────────────────────────────────────────────────
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
      isQuiz ? Icons.quiz_rounded : Icons.insert_drive_file_rounded,
      size: 28,
      color: FolderTheme.accent,
    ),
  );
}

// ─── Empty State ────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;
  const _EmptyState({
    required this.onRetry,
    this.message = 'No content available.',
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
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
              const Text('Nothing here', style: FolderTheme.emptyTitle),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message,
                  style: FolderTheme.emptySubtitle,
                  textAlign: TextAlign.center,
                ),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}