import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/screens/users/user_folder_detail_page.dart';
import 'package:ema_app/shared_manager_utility.dart';
import 'package:ema_app/utils/get_headers.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:ema_app/view_model/user_view_model/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EPSSectionPage extends StatefulWidget {
  final String userIdentifier;
  final bool isAdmin;

  const EPSSectionPage({
    super.key,
    required this.userIdentifier,
    required this.isAdmin,
  });

  @override
  _EPSSectionPageState createState() => _EPSSectionPageState();
}

class _EPSSectionPageState extends State<EPSSectionPage> {
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<UpdatedFolderViewModel>();
      // Listen so we can auto-load when a page fits entirely on screen
      vm.addListener(_onViewModelChanged);
      vm.fetchFolders(context, refresh: true);
    });
  }

  /// Called every time the ViewModel notifies (data loaded, page appended, etc.).
  /// If the freshly loaded page fits entirely inside the viewport with no
  /// overflow, maxScrollExtent stays 0 and the scroll listener never fires —
  /// so we check here and auto-fetch the next page.
  void _onViewModelChanged() {
    if (!mounted) return;
    // Wait one frame so the ListView has rebuilt with the new items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<UpdatedFolderViewModel>();
      if (vm.isFetchingMore || vm.isLoading || !vm.hasMorePages) return;
      if (!_scrollCtrl.hasClients) return;

      final maxScroll = _scrollCtrl.position.maxScrollExtent;
      // maxScrollExtent == 0  →  all items fit on screen, nothing to scroll
      if (maxScroll == 0) {
        vm.fetchNextPage(context);
      }
    });
  }

  /// Triggered by ScrollController when the user physically scrolls.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final maxScroll = pos.maxScrollExtent;
    final current  = pos.pixels;

    if (maxScroll <= 0) return; // handled by _onViewModelChanged instead

    // Trigger 200 px before the bottom (or 90 % for very short lists)
    final threshold = maxScroll > 200 ? maxScroll - 200 : maxScroll * 0.9;
    if (current < threshold) return;

    final vm = context.read<UpdatedFolderViewModel>();
    if (!vm.isFetchingMore && !vm.isLoading && vm.hasMorePages) {
      vm.fetchNextPage(context);
    }
  }

  @override
  void dispose() {
    // Remove the ViewModel listener we added in initState
    try {
      context.read<UpdatedFolderViewModel>().removeListener(_onViewModelChanged);
    } catch (_) {}
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Navigate into a folder ─────────────────────────────────────────────────
  void _openFolder(String folderId, String folderName) async {
    final user = await UserViewModel().getUser();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserFolderDetailsPage(
          folderId: folderId,
          folderName: folderName,
          userIdentifier: widget.userIdentifier,
          isAdmin: widget.isAdmin,
          userId: user?.id ?? 0,
        ),
      ),
    );
  }

  // ── Single folder row card ─────────────────────────────────────────────────
  Widget _buildFolderCard(Map<String, dynamic> folder, int index) {
    final iconPath = folder['icon_path'] as String?;
    final name = folder['name'] as String? ?? 'Unnamed Folder';
    final id = folder['id']?.toString() ?? '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index.clamp(0, 12) * 25)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 1.5,
          shadowColor: Colors.black12,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openFolder(id, name),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // ── Folder icon ──────────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: _FolderIcon(iconPath: iconPath),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ── Folder name ──────────────────────────────────────────
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // ── Chevron ──────────────────────────────────────────────
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.grey, size: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading skeleton card ──────────────────────────────────────────────────
  Widget _buildSkeletonCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 14,
                        width: double.infinity,
                        color: Colors.grey[200]),
                    const SizedBox(height: 6),
                    Container(
                        height: 12, width: 100, color: Colors.grey[200]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 2,
        backgroundColor: Colors.blue[700],
        centerTitle: true,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'EPS TOPIK NEW UBT SESSION',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          Consumer<UpdatedFolderViewModel>(
            builder: (_, vm, __) => IconButton(
              icon: AnimatedRotation(
                turns: vm.isLoading ? 1 : 0,
                duration: const Duration(seconds: 1),
                child: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 22),
              ),
              tooltip: 'Refresh',
              onPressed: vm.isLoading
                  ? null
                  : () => vm.fetchFolders(context, refresh: true),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<UpdatedFolderViewModel>(
          builder: (context, vm, _) {
            // ── Initial full-screen loading ──────────────────────────────
            if (vm.isLoading && vm.filteredFolders.isEmpty) {
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                itemBuilder: (_, __) => _buildSkeletonCard(),
              );
            }

            // ── Empty state ──────────────────────────────────────────────
            if (!vm.isLoading && vm.filteredFolders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_off_rounded,
                        size: 56, color: Colors.blue[200]),
                    const SizedBox(height: 16),
                    const Text(
                      'No folders available',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          vm.fetchFolders(context, refresh: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // ── Folder list with paginated footer ────────────────────────
            // itemCount = folders + optional pagination spinner slot
            final itemCount = vm.filteredFolders.length +
                (vm.isFetchingMore ? 1 : 0);

            return Column(
              children: [
                // Page info strip
                if (vm.totalFolders > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    color: Colors.blue[50],
                    child: Text(
                      'Showing ${vm.filteredFolders.length} of ${vm.totalFolders} folders'
                          '  •  Page ${vm.currentPage} / ${vm.totalPages}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    // Belt-and-suspenders: catches scroll events even when
                    // ScrollController listeners are swallowed by a Column/Expanded.
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification ||
                          notification is UserScrollNotification) {
                        _onScroll();
                      }
                      return false; // don't absorb — let the ListView handle it too
                    },
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: itemCount,
                      itemBuilder: (_, i) {
                        // Last slot → pagination spinner
                        if (i == vm.filteredFolders.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue),
                              ),
                            ),
                          );
                        }

                        final folder = vm.filteredFolders[i];
                        return _buildFolderCard(folder.toJson(), i);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Folder Icon Widget ────────────────────────────────────────────────────────
/// Uses auth headers for the network image (same pattern as the rest of the app).
class _FolderIcon extends StatelessWidget {
  final String? iconPath;

  const _FolderIcon({this.iconPath});

  @override
  Widget build(BuildContext context) {
    final raw = iconPath;

    if (raw == null || raw.isEmpty) {
      return const _FallbackIcon();
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
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Image.network(
          fullUrl,
          headers: snap.data,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _FallbackIcon(),
        );
      },
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.folder_rounded, color: Colors.blue, size: 30),
  );
}