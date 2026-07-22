import 'package:ema_app/model/notice_model.dart';
import 'package:ema_app/screens/notice/detail_screen.dart';
import 'package:ema_app/screens/notice/notice_form.dart';
import 'package:ema_app/utils/responsive.dart';
import 'package:ema_app/view_model/folders/notice_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notice/notice_card.dart';
import '../notice/notice_search.dart';
import '../notice/notice_theme.dart';

class AdminNoticeScreen extends StatefulWidget {
  const AdminNoticeScreen({super.key});

  @override
  State<AdminNoticeScreen> createState() => _AdminNoticeScreenState();
}

class _AdminNoticeScreenState extends State<AdminNoticeScreen>
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
      duration: const Duration(milliseconds: 350),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<AdminNoticeViewModel>()
          .fetchNotices(context, refresh: true);
      _fabAnim.forward();
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels <
        _scrollCtrl.position.maxScrollExtent - 200) return;
    final vm = context.read<AdminNoticeViewModel>();
    if (!vm.isFetchingMore && !vm.isLoading && vm.hasMorePages) {
      vm.fetchNextPage(context);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────
  void _goToCreate() {
    final vm = context.read<AdminNoticeViewModel>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: vm,                          // ✅ pass existing instance
          child: const AdminNoticeFormScreen(),
        ),
      ),
    );
  }

  void _goToEdit(NoticeModel notice) {
    final vm = context.read<AdminNoticeViewModel>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: vm,                          // ✅ same instance
          child: AdminNoticeFormScreen(existing: notice),
        ),
      ),
    );
  }
  void _goToDetail(NoticeModel notice) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice)),
    );
  }

  void _confirmDelete(NoticeModel notice) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Notice',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(
          'Remove "${notice.title ?? 'this notice'}" permanently?\nThis cannot be undone.',
          style: const TextStyle(color: NoticeTheme.textSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: NoticeTheme.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AdminNoticeViewModel>().deleteNotice(context, notice);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: NoticeTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NoticeTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdminNoticeHeader(),
            NoticeSearchBar(
              controller: _searchCtrl,
              onChanged: (q) =>
                  context.read<AdminNoticeViewModel>().searchNotices(q),
            ),
            const SizedBox(height: 8),
            Expanded(child: _AdminNoticeList(
              scrollController: _scrollCtrl,
              onTap: _goToDetail,
              onEdit: _goToEdit,
              onDelete: _confirmDelete,
            )),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
        child: FloatingActionButton.extended(
          onPressed: _goToCreate,
          backgroundColor: NoticeTheme.accent,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('New Notice', style: NoticeTheme.fabLabel),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _AdminNoticeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Consumer<AdminNoticeViewModel>(
        builder: (_, vm, __) => Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: NoticeTheme.textSub, size: 20),
              tooltip: 'Back',
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Notices', style: NoticeTheme.screenTitle),
                Text(
                  '${vm.totalNotices} total',
                  style: NoticeTheme.screenSubtitle,
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: vm.isLoading
                  ? null
                  : () => vm.fetchNotices(context, refresh: true),
              icon: AnimatedRotation(
                turns: vm.isLoading ? 1 : 0,
                duration: const Duration(seconds: 1),
                child: const Icon(Icons.refresh_rounded,
                    color: NoticeTheme.textSub, size: 22),
              ),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── List ─────────────────────────────────────────────────────────────────────
class _AdminNoticeList extends StatelessWidget {
  final ScrollController scrollController;
  final void Function(NoticeModel) onTap;
  final void Function(NoticeModel) onEdit;
  final void Function(NoticeModel) onDelete;

  const _AdminNoticeList({
    required this.scrollController,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminNoticeViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading && vm.filteredNotices.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: NoticeTheme.accent, strokeWidth: 2.5),
          );
        }

        if (vm.filteredNotices.isEmpty) {
          return _AdminEmptyState(onAdd: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: vm,
                  child: const AdminNoticeFormScreen(),
                ),
              ),
            );
          });
        }

        return RefreshIndicator(
          color: NoticeTheme.accent,
          onRefresh: () => vm.fetchNotices(context, refresh: true),
          child: ResponsiveCenter(
            tabletMaxWidth: 640,
            desktopMaxWidth: 800,
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount:
              vm.filteredNotices.length + (vm.isFetchingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == vm.filteredNotices.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: NoticeTheme.accent, strokeWidth: 2),
                    ),
                  );
                }
                final notice = vm.filteredNotices[i];
                return NoticeCard(
                  notice: notice,
                  index: i,
                  onTap: () => onTap(notice),
                  onEdit: () => onEdit(notice),
                  onDelete: () => onDelete(notice),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _AdminEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _AdminEmptyState({required this.onAdd});

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
              color: NoticeTheme.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.campaign_outlined,
                size: 38, color: NoticeTheme.accent),
          ),
          const SizedBox(height: 16),
          const Text('No notices yet', style: NoticeTheme.emptyTitle),
          const SizedBox(height: 6),
          const Text(
            'Create your first notice for everyone to see.',
            style: NoticeTheme.emptySubtitle,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Notice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NoticeTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}