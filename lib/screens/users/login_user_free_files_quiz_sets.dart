import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/screens/users/user_quiz_sets.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:ema_app/view_model/folders/free_files_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController();
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
                    '${vm.totalFolders} folders available',
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
          onChanged: (v) => setState(() => _searchQuery = v),
          style: FolderTheme.fieldInput,
          decoration: const InputDecoration(
            hintText: 'Search folders…',
            hintStyle: TextStyle(color: FolderTheme.textSub, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded,
                color: FolderTheme.textSub, size: 20),
            border: InputBorder.none,
            contentPadding:
            EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
    );
  }

  // ─── Folder List ──────────────────────────────────────────────────────────
  Widget _buildFolderList() {
    return Consumer<UpdatedFolderViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading && vm.folders.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        final folders = _searchQuery.isEmpty
            ? vm.folders
            : vm.folders
            .where((f) => (f.name ?? '')
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
            .toList();

        if (folders.isEmpty) {
          return _FolderEmptyState(
            onRetry: () => vm.fetchFolders(context, refresh: true),
          );
        }

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          itemCount: folders.length,
          itemBuilder: (_, i) {
            final folder = folders[i];
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
      child: (iconPath != null && iconPath!.isNotEmpty)
          ? CachedNetworkImage(
        imageUrl: '${BaseUrl.imageUrl}/$iconPath',
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: FolderTheme.accent),
          ),
        ),
        errorWidget: (_, __, ___) => const Center(
          child: Icon(Icons.folder_rounded,
              size: 28, color: FolderTheme.accent),
        ),
      )
          : const Center(
        child: Icon(Icons.folder_rounded,
            size: 28, color: FolderTheme.accent),
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
    return ChangeNotifierProvider(
      create: (_) =>
      FreeAccessViewModel()..fetchGrantedAccessItems(folderId),
      child: Scaffold(
        backgroundColor: FolderTheme.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: Consumer<FreeAccessViewModel>(
                  builder: (context, vm, _) {
                    if (vm.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: FolderTheme.accent, strokeWidth: 2.5),
                      );
                    }
                    if (vm.errorMessage != null) {
                      return _ErrorState(
                        message: vm.errorMessage!,
                        onRetry: () =>
                            vm.fetchGrantedAccessItems(folderId),
                      );
                    }
                    if (vm.files.isEmpty && vm.quizSets.isEmpty) {
                      return const _ContentEmptyState();
                    }
                    return _ContentList(
                      vm: vm,
                      folderId: folderId,
                      folderName: folderName,
                      userIdentifier: userIdentifier,
                      isAdmin: isAdmin,
                      fullName: fullName,
                      userEmail: userEmail,
                    );
                  },
                ),
              ),
            ],
          ),
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
                  folderName,
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

// ─── Content List ─────────────────────────────────────────────────────────────
class _ContentList extends StatelessWidget {
  final FreeAccessViewModel vm;
  final String folderId;
  final String folderName;
  final String userIdentifier;
  final bool isAdmin;
  final String? fullName;
  final String? userEmail;

  const _ContentList({
    required this.vm,
    required this.folderId,
    required this.folderName,
    required this.userIdentifier,
    required this.isAdmin,
    this.fullName,
    this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        // ── Quiz Sets section ──────────────────────────────────────────
        if (vm.quizSets.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.quiz_rounded,
            title: 'Quiz Sets',
            count: vm.quizSets.length,
          ),
          const SizedBox(height: 10),
          ...vm.quizSets.asMap().entries.map((e) => _ContentCard(
            item: e.value,
            index: e.key,
            itemType: 'quiz_set',
            onTap: () => _openQuizSet(context, e.value),
          )),
          if (vm.files.isNotEmpty) const SizedBox(height: 20),
        ],

        // ── Files section ──────────────────────────────────────────────
        if (vm.files.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.insert_drive_file_rounded,
            title: 'Files',
            count: vm.files.length,
          ),
          const SizedBox(height: 10),
          ...vm.files.asMap().entries.map((e) => _ContentCard(
            item: e.value,
            index: e.key,
            itemType: 'file',
            onTap: () {
              // TODO: implement file open
            },
          )),
        ],
      ],
    );
  }

  void _openQuizSet(BuildContext context, Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserQuizSetsPage(
          quizSetId: item['id'],
          quizSetName: item['name'],
          userId: isAdmin
              ? ''
              : userIdentifier.isEmpty
              ? 'guest'
              : userIdentifier,
          userName: fullName ?? '',
          userEmail:
          isAdmin ? userIdentifier : (userEmail ?? userIdentifier),
          role: isAdmin ? 'admin' : 'user',
          folderId: folderId,
          folderName: folderName,
          isAdmin: isAdmin,
          userIdentifier: userIdentifier,
          preStart: true,
          cachedFiles: {},
          quizData: {},
        ),
      ),
    ).then((_) {
      Provider.of<FreeAccessViewModel>(context, listen: false)
          .fetchGrantedAccessItems(folderId);
    });
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
                  const Text(
                    'Can Use',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
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
      child: (iconPath != null && iconPath!.isNotEmpty)
          ? CachedNetworkImage(
        imageUrl: '${BaseUrl.imageUrl}/$iconPath',
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: FolderTheme.accent),
          ),
        ),
        errorWidget: (_, __, ___) => Center(
          child: Icon(
            isQuiz
                ? Icons.quiz_rounded
                : Icons.insert_drive_file_rounded,
            size: 28,
            color: FolderTheme.accent,
          ),
        ),
      )
          : Center(
        child: Icon(
          isQuiz
              ? Icons.quiz_rounded
              : Icons.insert_drive_file_rounded,
          size: 28,
          color: FolderTheme.accent,
        ),
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
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

// ─── Error State ──────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
              color: Colors.red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child:
            const Icon(Icons.error_outline_rounded, size: 38, color: Colors.red),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: FolderTheme.emptyTitle, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: FolderTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
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

// ─── Content Empty State ──────────────────────────────────────────────────────
class _ContentEmptyState extends StatelessWidget {
  const _ContentEmptyState();

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
        ],
      ),
    );
  }
}