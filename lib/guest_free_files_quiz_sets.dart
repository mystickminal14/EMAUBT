import 'dart:io';

import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/folder_mode_v2/new_file_model.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/screens/play_quiz/user_play_quiz.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:ema_app/view_model/folders/new_files_vm.dart';
import 'package:ema_app/view_model/folders/new_folder_quiz.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// ─── Access type constant ─────────────────────────────────────────────────────
const String _kAccessAll = 'all';

// ─── Guest Folder List Screen ─────────────────────────────────────────────────
/// Shown to logged-out (guest) users.
/// Fetches folders via [UpdatedFolderViewModel] and, inside each folder,
/// shows only items whose [access_type] == "all".
class GuestFreeFilesQuizSets extends StatefulWidget {
  const GuestFreeFilesQuizSets({super.key});

  @override
  _GuestFreeFilesQuizSetsState createState() => _GuestFreeFilesQuizSetsState();
}

class _GuestFreeFilesQuizSetsState extends State<GuestFreeFilesQuizSets>
    with SingleTickerProviderStateMixin {
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

  void _openFolder(String folderId, String folderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuestFolderContentPage(
          folderId: folderId,
          folderName: folderName,
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
            // Guest badge
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: FolderTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: FolderTheme.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Guest',
                    style: FolderTheme.screenSubtitle.copyWith(
                      color: FolderTheme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Refresh
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
          return _GuestFolderEmptyState(
            onRetry: () => vm.fetchFolders(context, refresh: true),
          );
        }

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          itemCount:
          vm.filteredFolders.length + (vm.isFetchingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == vm.filteredFolders.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                      color: FolderTheme.accent, strokeWidth: 2.5),
                ),
              );
            }
            final folder = vm.filteredFolders[i];
            return _GuestFolderCard(
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

// ─── Guest Folder Card ────────────────────────────────────────────────────────
class _GuestFolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final int index;
  final VoidCallback onTap;

  const _GuestFolderCard({
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
            leading: _GuestFolderIconBox(iconPath: folder['icon_path']),
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
                  const Icon(Icons.public_rounded,
                      size: 12, color: Color(0xFF6366F1)),
                  const SizedBox(width: 4),
                  Text(
                    'Public access',
                    style: FolderTheme.cardSubtitle.copyWith(
                      color: const Color(0xFF6366F1),
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

// ─── Folder Icon Box (no auth headers for guest) ──────────────────────────────
class _GuestFolderIconBox extends StatelessWidget {
  final String? iconPath;

  const _GuestFolderIconBox({this.iconPath});

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
    if (raw == null || raw.isEmpty) return const _GuestFallbackFolderIcon();

    final fullUrl = Uri.parse("${BaseUrl.imageUrl}/$raw").toString();

    // Guest users — no auth headers required
    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _GuestFallbackFolderIcon(),
    );
  }
}

class _GuestFallbackFolderIcon extends StatelessWidget {
  const _GuestFallbackFolderIcon();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.folder_rounded, size: 28, color: FolderTheme.accent),
  );
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _GuestFolderEmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const _GuestFolderEmptyState({required this.onRetry});

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

// ─── Guest Folder Content Page ────────────────────────────────────────────────
/// Shows files + quiz sets inside a folder, filtered to access_type == "all".
class GuestFolderContentPage extends StatelessWidget {
  final String folderId;
  final String folderName;

  const GuestFolderContentPage({
    super.key,
    required this.folderId,
    required this.folderName,
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
      child: _GuestFolderContentBody(
        folderId: folderIdInt,
        folderName: folderName,
      ),
    );
  }
}

class _GuestFolderContentBody extends StatefulWidget {
  final int folderId;
  final String folderName;

  const _GuestFolderContentBody({
    required this.folderId,
    required this.folderName,
  });

  @override
  State<_GuestFolderContentBody> createState() =>
      _GuestFolderContentBodyState();
}

class _GuestFolderContentBodyState extends State<_GuestFolderContentBody> {
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
              child: _GuestContentArea(
                folderId: widget.folderId,
                folderName: widget.folderName,
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
                const Text('Public content', style: FolderTheme.screenSubtitle),
              ],
            ),
          ),
          // "All access" chip
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.public_rounded, size: 13, color: Color(0xFF6366F1)),
                SizedBox(width: 4),
                Text(
                  'All access',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
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

// ─── Guest Content Area ───────────────────────────────────────────────────────
class _GuestContentArea extends StatelessWidget {
  final int folderId;
  final String folderName;

  const _GuestContentArea({
    required this.folderId,
    required this.folderName,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<FolderFilesViewModel, FolderQuizSetsViewModel>(
      builder: (context, filesVm, quizVm, _) {
        // Both loading + empty → spinner
        if (filesVm.isLoading &&
            filesVm.files.isEmpty &&
            quizVm.isLoading &&
            quizVm.quizSets.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        // Filter: access_type == 'all' AND status == 'active'
        final publicFiles = filesVm.filteredFiles
            .where((f) =>
        f.accessType?.toLowerCase() == _kAccessAll &&
            f.status?.toLowerCase() == 'active')
            .toList();

        final publicQuizSets = quizVm.filteredQuizSets
            .where((q) => q.access_type?.toLowerCase() == _kAccessAll)
            .toList();

        // Both filtered lists empty + not loading → empty state
        if (publicFiles.isEmpty &&
            publicQuizSets.isEmpty &&
            !filesVm.isLoading &&
            !quizVm.isLoading) {
          return _GuestContentEmptyState(
            onRetry: () {
              filesVm.fetchFiles(context, folderId, refresh: true);
              quizVm.fetchQuizSets(context, folderId, refresh: true);
            },
          );
        }

        return _GuestContentList(
          filesVm: filesVm,
          quizVm: quizVm,
          publicFiles: publicFiles,
          publicQuizSets: publicQuizSets,
          folderId: folderId,
          folderName: folderName,
        );
      },
    );
  }
}

// ─── Guest Content List ───────────────────────────────────────────────────────
class _GuestContentList extends StatefulWidget {
  final FolderFilesViewModel filesVm;
  final FolderQuizSetsViewModel quizVm;
  final List<FileModel> publicFiles;
  final List<dynamic> publicQuizSets; // same model type as FolderQuizSetsViewModel items
  final int folderId;
  final String folderName;

  const _GuestContentList({
    required this.filesVm,
    required this.quizVm,
    required this.publicFiles,
    required this.publicQuizSets,
    required this.folderId,
    required this.folderName,
  });

  @override
  State<_GuestContentList> createState() => _GuestContentListState();
}

class _GuestContentListState extends State<_GuestContentList> {
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final threshold = _scrollCtrl.position.maxScrollExtent - 200;
    if (_scrollCtrl.position.pixels >= threshold) {
      widget.filesVm.fetchNextPage(context, widget.folderId);
      widget.quizVm.fetchNextPage(context, widget.folderId);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Download & open (no auth headers for guest) ───────────────────────────
  Future<void> _downloadAndOpenFile(
      BuildContext context, FileModel file) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(SnackBar(
      content: Text('Opening: ${file.name ?? ""}…'),
      backgroundColor: FolderTheme.accent,
      duration: const Duration(seconds: 2),
    ));

    try {
      // Guest users — no auth headers
      final response = await http.get(Uri.parse(file.downloadUrl));

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

  // ── Open quiz set ─────────────────────────────────────────────────────────
  void _openQuizSet(BuildContext context, dynamic item) {
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
          userIdentifier: 'guest',
          isAdmin: false,
          fullName: 'Guest',
          userEmail: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFetchingMore =
        widget.filesVm.isFetchingMore || widget.quizVm.isFetchingMore;

    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        // ── Guest info banner ──────────────────────────────────────────────
        _GuestInfoBanner(),
        const SizedBox(height: 16),

        // ── Quiz Sets ──────────────────────────────────────────────────────
        if (widget.publicQuizSets.isNotEmpty) ...[
          _GuestSectionHeader(
            icon: Icons.quiz_rounded,
            title: 'Quiz Sets',
            count: widget.publicQuizSets.length,
          ),
          const SizedBox(height: 10),
          ...widget.publicQuizSets.asMap().entries.map(
                (e) => _GuestContentCard(
              item: e.value.toJson(),
              index: e.key,
              itemType: 'quiz_set',
              onTap: () => _openQuizSet(context, e.value),
            ),
          ),
          if (widget.publicFiles.isNotEmpty) const SizedBox(height: 20),
        ],

        // ── Files ──────────────────────────────────────────────────────────
        if (widget.publicFiles.isNotEmpty) ...[
          _GuestSectionHeader(
            icon: Icons.insert_drive_file_rounded,
            title: 'Files',
            count: widget.publicFiles.length,
          ),
          const SizedBox(height: 10),
          ...widget.publicFiles.asMap().entries.map(
                (e) => _GuestContentCard(
              item: e.value.toJson(),
              index: e.key,
              itemType: 'file',
              onTap: () => _downloadAndOpenFile(context, e.value),
            ),
          ),
        ],

        // ── Fetch-more spinner ─────────────────────────────────────────────
        if (isFetchingMore)
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

// ─── Guest Info Banner ────────────────────────────────────────────────────────
class _GuestInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6366F1)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You\'re browsing as a guest. Only publicly available content is shown.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Guest Content Card ───────────────────────────────────────────────────────
class _GuestContentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final String itemType;
  final VoidCallback onTap;

  const _GuestContentCard({
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
            leading: _GuestContentIconBox(
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
                children: const [
                  Icon(Icons.public_rounded,
                      size: 12, color: Color(0xFF6366F1)),
                  SizedBox(width: 4),
                  Text(
                    'Open access',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6366F1),
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

// ─── Guest Content Icon Box (no auth headers) ─────────────────────────────────
class _GuestContentIconBox extends StatelessWidget {
  final String? iconPath;
  final bool isQuiz;

  const _GuestContentIconBox({this.iconPath, required this.isQuiz});

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
      return _GuestFallbackContentIcon(isQuiz: isQuiz);
    }

    final fullUrl = Uri.parse("${BaseUrl.imageUrl}/$raw").toString();

    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _GuestFallbackContentIcon(isQuiz: isQuiz),
    );
  }
}

class _GuestFallbackContentIcon extends StatelessWidget {
  final bool isQuiz;

  const _GuestFallbackContentIcon({required this.isQuiz});

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

// ─── Guest Section Header ─────────────────────────────────────────────────────
class _GuestSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _GuestSectionHeader({
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

// ─── Guest Content Empty State ────────────────────────────────────────────────
class _GuestContentEmptyState extends StatelessWidget {
  final VoidCallback onRetry;

  const _GuestContentEmptyState({required this.onRetry});

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
          const Text('No public content', style: FolderTheme.emptyTitle),
          const SizedBox(height: 6),
          const Text(
            'This folder has no publicly accessible\nfiles or quiz sets.',
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