import 'dart:io';

import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/folder_mode_v2/new_file_model.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/screens/play_quiz/user_play_quiz.dart';
import 'package:ema_app/utils/get_headers.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:ema_app/view_model/folders/new_files_vm.dart';
import 'package:ema_app/view_model/folders/new_folder_quiz.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Folder List Screen ───────────────────────────────────────────────────────
class LoginUserFreeFilesQuizSets extends StatefulWidget {
  final String userIdentifier;
  final bool isAdmin;

  const LoginUserFreeFilesQuizSets({
    super.key,
    required this.userIdentifier,
    required this.isAdmin,
  });

  @override
  _LoginUserFreeFilesQuizSetsState createState() =>
      _LoginUserFreeFilesQuizSetsState();
}

class _LoginUserFreeFilesQuizSetsState
    extends State<LoginUserFreeFilesQuizSets>
    with SingleTickerProviderStateMixin {
  late SharedPreferences _prefs;
  String? _cachedFullName;
  String? _cachedUserEmail;
  late final TextEditingController _searchCtrl;
  late final ScrollController _scrollCtrl;
  late final AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _initSharedPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<UpdatedFolderViewModel>(context, listen: false)
            .fetchFolders(context);
        _fabAnim.forward();
      }
    });
  }
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final threshold = _scrollCtrl.position.maxScrollExtent - 200;
    if (_scrollCtrl.position.pixels >= threshold) {
      final vm = context.read<UpdatedFolderViewModel>();
      if (!vm.isFetchingMore && !vm.isLoading && vm.hasMorePages) {
        vm.fetchNextPage(context);
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _cachedFullName = _prefs.getString('fullName') ?? '';
      _cachedUserEmail =
          _prefs.getString('userEmail') ?? widget.userIdentifier;
    });
  }

  void _openFolder(String folderId, String folderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FreeForLoginPage(
          folderId: folderId,
          folderName: folderName,
          userIdentifier: widget.userIdentifier,
          isAdmin: widget.isAdmin,
          fullName: _cachedFullName,
          userEmail: _cachedUserEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolderTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 8),
            Expanded(child: _buildFolderList()),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Consumer<UpdatedFolderViewModel>(
        builder: (_, vm, __) => Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FolderTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FolderTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: FolderTheme.primary.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: FolderTheme.textMain, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Free Content', style: FolderTheme.screenTitle),
                  Text(
                    '${vm.folders.length} folders available',
                    style: FolderTheme.screenSubtitle,
                  ),
                ],
              ),
            ),
            // Refresh button
            IconButton(
              onPressed: vm.isLoading
                  ? null
                  : () => vm.fetchFolders(context, refresh: true),
              icon: AnimatedRotation(
                turns: vm.isLoading ? 1 : 0,
                duration: const Duration(seconds: 1),
                child: const Icon(Icons.refresh_rounded,
                    color: FolderTheme.textSub, size: 22),
              ),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 48,
        decoration: FolderTheme.searchDecoration,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) =>
              context.read<UpdatedFolderViewModel>().searchFolders(v),
          style: FolderTheme.fieldInput,
          decoration: InputDecoration(
            hintText: 'Search folders…',
            hintStyle:
            const TextStyle(color: FolderTheme.textSub, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: FolderTheme.textSub, size: 20),
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchCtrl,
              builder: (_, value, __) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: FolderTheme.textSub, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  context
                      .read<UpdatedFolderViewModel>()
                      .searchFolders('');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Folder List ──────────────────────────────────────────────────────────
  Widget _buildFolderList() {
    return Consumer<UpdatedFolderViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading && vm.filteredFolders.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        if (vm.filteredFolders.isEmpty) {
          return _FolderEmptyState(
            onRetry: () => vm.fetchFolders(context, refresh: true),
          );
        }

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          itemCount: vm.filteredFolders.length,
          itemBuilder: (_, i) {
            if (i == vm.filteredFolders.length) {              // ← last slot = spinner
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                      color: FolderTheme.accent, strokeWidth: 2.5),
                ),
              );
            }
            final folder = vm.filteredFolders[i];
            return _FolderCard(
              folder: folder.toJson(),
              index: i,
              onTap: () =>
                  _openFolder(folder.id.toString(), folder.name ?? ''),
            );
          },
        );
      },
    );
  }
}

// ─── Folder Card ─────────────────────────────────────────────────────────────
class _FolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final int index;
  final VoidCallback onTap;

  const _FolderCard({
    required this.folder,
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
            leading: _FolderIconBox(iconPath: folder['icon_path']),
            title: Text(
              folder['name'] ?? '—',
              style: FolderTheme.cardTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.lock_open_rounded,
                      size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    'Free access',
                    style: FolderTheme.cardSubtitle.copyWith(
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: FolderTheme.textSub, size: 22),
          ),
        ),
      ),
    );
  }
}

// ─── Folder Icon Box ──────────────────────────────────────────────────────────
class _FolderIconBox extends StatelessWidget {
  final String? iconPath;

  const _FolderIconBox({this.iconPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: FolderTheme.iconContainerDecoration,
      clipBehavior: Clip.antiAlias,
      child: _buildIconChild(context),
    );
  }

  Widget _buildIconChild(BuildContext context) {
    final raw = iconPath;

    if (raw == null || raw.isEmpty) {
      return const _FallbackFolderIcon();
    }

    final fullUrl = Uri.parse("${BaseUrl.imageUrl}/$raw").toString();

    return FutureBuilder<Map<String, String>>(
      future: getAuthHeaders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return Image.network(
          fullUrl,
          headers: snapshot.data,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _FallbackFolderIcon(),
        );
      },
    );
  }
}

class _FallbackFolderIcon extends StatelessWidget {
  const _FallbackFolderIcon();

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

// ─── Empty State ──────────────────────────────────────────────────────────────
class _FolderEmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const _FolderEmptyState({required this.onRetry});

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
            child: const Icon(Icons.folder_off_rounded,
                size: 38, color: FolderTheme.accent),
          ),
          const SizedBox(height: 16),
          const Text('No folders available', style: FolderTheme.emptyTitle),
          const SizedBox(height: 6),
          const Text(
            'Pull to refresh or tap retry below.',
            style: FolderTheme.emptySubtitle,
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

// ─── Free For Login Page ──────────────────────────────────────────────────────
class FreeForLoginPage extends StatelessWidget {
  final String folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final String? fullName;
  final String? userEmail;

  const FreeForLoginPage({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    this.fullName,
    this.userEmail,
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
                const Text('Invalid folder', style: FolderTheme.emptyTitle),
                const SizedBox(height: 8),
                Text('Folder ID must be a number: $folderId',
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
        ChangeNotifierProvider(create: (_) => FolderFilesViewModel()),
        ChangeNotifierProvider(create: (_) => FolderQuizSetsViewModel()),
      ],
      child: _FreeForLoginPageContent(
        folderId: folderIdInt,
        folderName: folderName,
        userIdentifier: userIdentifier,
        isAdmin: isAdmin,
        fullName: fullName,
        userEmail: userEmail,
      ),
    );
  }
}

class _FreeForLoginPageContent extends StatefulWidget {
  final int folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final String? fullName;
  final String? userEmail;

  const _FreeForLoginPageContent({
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    this.fullName,
    this.userEmail,
  });

  @override
  State<_FreeForLoginPageContent> createState() =>
      _FreeForLoginPageContentState();
}

class _FreeForLoginPageContentState extends State<_FreeForLoginPageContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<FolderFilesViewModel>()
            .fetchFiles(context, widget.folderId, refresh: true);
        context
            .read<FolderQuizSetsViewModel>()
            .fetchQuizSets(context, widget.folderId, refresh: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolderTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: _ContentBody(
                folderId: widget.folderId,
                folderName: widget.folderName,
                userIdentifier: widget.userIdentifier,
                isAdmin: widget.isAdmin,
                fullName: widget.fullName,
                userEmail: widget.userEmail,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: FolderTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FolderTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: FolderTheme.primary.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: FolderTheme.textMain, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.folderName,
                  style: FolderTheme.screenTitle.copyWith(fontSize: 22),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text('Free content', style: FolderTheme.screenSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentBody extends StatelessWidget {
  final int folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final String? fullName;
  final String? userEmail;

  const _ContentBody({
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    this.fullName,
    this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<FolderFilesViewModel, FolderQuizSetsViewModel>(
      builder: (context, filesVm, quizVm, _) {
        // Show loading if both are loading and empty
        if (filesVm.isLoading &&
            filesVm.files.isEmpty &&
            quizVm.isLoading &&
            quizVm.quizSets.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        // Show empty if both are empty and not loading
        if (filesVm.filteredFiles.isEmpty &&
            quizVm.filteredQuizSets.isEmpty &&
            !filesVm.isLoading &&
            !quizVm.isLoading) {
          return _ContentEmptyStateWithRetry(
            onRetry: () {
              filesVm.fetchFiles(context, folderId, refresh: true);
              quizVm.fetchQuizSets(context, folderId, refresh: true);
            },
          );
        }

        return _ContentList(
          filesVm: filesVm,
          quizVm: quizVm,
          folderId: folderId,
          folderName: folderName,
          userIdentifier: userIdentifier,
          isAdmin: isAdmin,
          fullName: fullName,
          userEmail: userEmail,
        );
      },
    );
  }
}

// ─── Content List ─────────────────────────────────────────────────────────────
class _ContentList extends StatefulWidget {
  final FolderFilesViewModel filesVm;
  final FolderQuizSetsViewModel quizVm;
  final int folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final String? fullName;
  final String? userEmail;

  const _ContentList({
    required this.filesVm,
    required this.quizVm,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    this.fullName,
    this.userEmail,
  });

  @override
  State<_ContentList> createState() => _ContentListState();
}

class _ContentListState extends State<_ContentList> {
  late final ScrollController _scrollCtrl;
  // ── Refresh after returning from a sub-page ────────────────────────────────
  void _loadData() {
    if (!mounted) return;
    widget.filesVm.fetchFiles(context, widget.folderId, refresh: true);
    widget.quizVm.fetchQuizSets(context, widget.folderId, refresh: true);
  }
  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);  // ← ADD
  }
  void _onScroll() {                                            // ← ADD ENTIRE METHOD
    if (!_scrollCtrl.hasClients) return;
    final threshold = _scrollCtrl.position.maxScrollExtent - 200;
    if (_scrollCtrl.position.pixels >= threshold) {
      widget.filesVm.fetchNextPage(context, widget.folderId);
      widget.quizVm.fetchNextPage(context, widget.folderId);
    }
  }
  // ── Download & open a file ─────────────────────────────────────────────────
  Future<void> _downloadAndOpenFile(
      BuildContext context, FileModel file) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(SnackBar(
      content: Text('Opening: ${file.name ?? ""}…'),
      backgroundColor: FolderTheme.accent,
      duration: const Duration(seconds: 2),
    ));

    try {
      final headers = await getAuthHeaders();
      // file.downloadUrl resolves to BaseUrl.baseUrl + /files/{id}/download
      final response =
      await http.get(Uri.parse(file.downloadUrl), headers: headers);

      if (response.statusCode != 200) {
        if (!context.mounted) return;
        messenger.showSnackBar(SnackBar(
          content: Text('Download failed (${response.statusCode})'),
          backgroundColor: Colors.red.shade600,
        ));
        return;
      }

      final ext =
      file.extension.isNotEmpty ? '.${file.extension}' : '';
      final safeName =
      (file.name ?? 'file').replaceAll(RegExp(r'[^\w\-.]'), '_');

      final dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      if (!await dir.exists()) await dir.create(recursive: true);

      final savePath = '${dir.path}/$safeName$ext';
      await File(savePath).writeAsBytes(response.bodyBytes);

      if (!context.mounted) return;

      messenger.showSnackBar(SnackBar(
        content: Text('Saved to $savePath'),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 3),
      ));

      await OpenFile.open(savePath);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red.shade600,
      ));
    }
  }

  // ── Open quiz set (new flow) ───────────────────────────────────────────────
  void _openQuizSetNew(BuildContext context, dynamic item) {
    final quizSetId = item is Map
        ? (item['id'] as num?)?.toInt() ?? 0
        : (item.id as int? ?? 0);
    final quizSetName =
        (item is Map ? item['name'] : item.name) as String? ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserQuizLoadPage(
          quizSetId: quizSetId,
          quizSetName: quizSetName,
          folderId: widget.folderId.toString(),
          folderName: widget.folderName,
          userIdentifier: widget.userIdentifier,
          isAdmin: widget.isAdmin,
          fullName: widget.fullName ?? '',
          userEmail: widget.userEmail ?? '',
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final isFetchingMore =
        widget.filesVm.isFetchingMore || widget.quizVm.isFetchingMore;
    final visibleFiles = widget.filesVm.filteredFiles
        .where((f) => f.status?.toLowerCase() == 'active')
        .toList();
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        // ── Quiz Sets section ──────────────────────────────────────────────
        if (widget.quizVm.filteredQuizSets.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.quiz_rounded,
            title: 'Quiz Sets',
            count: widget.quizVm.filteredQuizSets.length,
          ),
          const SizedBox(height: 10),
          ...widget.quizVm.filteredQuizSets.asMap().entries.map(
                (e) => _ContentCard(
              item: e.value.toJson(),
              index: e.key,
              itemType: 'quiz_set',
              onTap: () => _openQuizSetNew(context, e.value),
            ),
          ),
          if (visibleFiles.isNotEmpty) const SizedBox(height: 20),
        ],

        // ── Files section ──────────────────────────────────────────────────
        if (visibleFiles.isNotEmpty) ...[                          // ← use visibleFiles
          _SectionHeader(
            icon: Icons.insert_drive_file_rounded,
            title: 'Files',
            count: visibleFiles.length,                            // ← use visibleFiles
          ),
          const SizedBox(height: 10),
          ...visibleFiles.asMap().entries.map(                     // ← use visibleFiles
                (e) => _ContentCard(
              item: e.value.toJson(),
              index: e.key,
              itemType: 'file',
              onTap: () => _downloadAndOpenFile(context, e.value),
            ),
          ),
        ],
        if (isFetchingMore)                                    // ← ADD
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                  color: FolderTheme.accent, strokeWidth: 2.5),
            ),
          ),

      ],
    );
  }
}

// ─── Content Card ─────────────────────────────────────────────────────────────
class _ContentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final String itemType;
  final VoidCallback onTap;

  const _ContentCard({
    required this.item,
    required this.index,
    required this.itemType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isQuiz = itemType == 'quiz_set';

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
            leading: _ContentIconBox(
              iconPath: item['icon_path'],
              isQuiz: isQuiz,
            ),
            title: Text(
              item['name'] ??
                  (isQuiz ? 'Unnamed Quiz Set' : 'Unnamed File'),
              style: FolderTheme.cardTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.lock_open_rounded,
                      size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    isQuiz ? 'Can Use' : 'Tap to download',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
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
              child: Text(
                isQuiz ? 'Open' : 'View',
                style: const TextStyle(
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

// ─── Content Icon Box ─────────────────────────────────────────────────────────
class _ContentIconBox extends StatelessWidget {
  final String? iconPath;
  final bool isQuiz;

  const _ContentIconBox({this.iconPath, required this.isQuiz});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: FolderTheme.iconContainerDecoration,
      clipBehavior: Clip.antiAlias,
      child: _buildIconChild(context),
    );
  }

  Widget _buildIconChild(BuildContext context) {
    final raw = iconPath;

    if (raw == null || raw.isEmpty) {
      return _FallbackContentIcon(isQuiz: isQuiz);
    }

    final fullUrl = Uri.parse("${BaseUrl.imageUrl}/$raw").toString();

    return FutureBuilder<Map<String, String>>(
      future: getAuthHeaders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return Image.network(
          fullUrl,
          headers: snapshot.data,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _FallbackContentIcon(isQuiz: isQuiz),
        );
      },
    );
  }
}

class _FallbackContentIcon extends StatelessWidget {
  final bool isQuiz;

  const _FallbackContentIcon({required this.isQuiz});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        isQuiz ? Icons.quiz_rounded : Icons.insert_drive_file_rounded,
        size: 28,
        color: FolderTheme.accent,
      ),
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: FolderTheme.textMain,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: FolderTheme.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
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

// ─── Content Empty State with Retry ──────────────────────────────────────────
class _ContentEmptyStateWithRetry extends StatelessWidget {
  final VoidCallback onRetry;

  const _ContentEmptyStateWithRetry({required this.onRetry});

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
            'This folder has no free files or quiz sets yet.',
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