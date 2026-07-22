import 'package:ema_app/model/notice_model.dart';
import 'package:ema_app/screens/notice/detail_screen.dart';
import 'package:ema_app/screens/notice/notice_card.dart';
import 'package:ema_app/screens/notice/notice_search.dart';
import 'package:ema_app/screens/notice/notice_theme.dart';
import 'package:ema_app/utils/responsive.dart';
import 'package:ema_app/view_model/folders/notice_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserNoticeScreen extends StatefulWidget {
  const UserNoticeScreen({super.key});

  @override
  State<UserNoticeScreen> createState() => _UserNoticeScreenState();
}

class _UserNoticeScreenState extends State<UserNoticeScreen> {
  late final TextEditingController _searchCtrl;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController()..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NoticeViewModel>().fetchNotices(context, refresh: true);
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels <
        _scrollCtrl.position.maxScrollExtent - 200) return;
    final vm = context.read<NoticeViewModel>();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NoticeTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UserNoticeHeader(),
            NoticeSearchBar(
              controller: _searchCtrl,
              onChanged: (q) =>
                  context.read<NoticeViewModel>().searchNotices(q),
            ),
            const SizedBox(height: 8),
            Expanded(child: _NoticeListView(scrollController: _scrollCtrl)),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _UserNoticeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Consumer<NoticeViewModel>(
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
                  '${vm.totalNotices} notice${vm.totalNotices == 1 ? '' : 's'}',
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
class _NoticeListView extends StatelessWidget {
  final ScrollController scrollController;
  const _NoticeListView({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<NoticeViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading && vm.filteredNotices.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: NoticeTheme.accent, strokeWidth: 2.5),
          );
        }

        if (vm.filteredNotices.isEmpty) {
          return const _NoticeEmptyState();
        }

        return RefreshIndicator(
          color: NoticeTheme.accent,
          onRefresh: () => vm.fetchNotices(context, refresh: true),
          child: ResponsiveCenter(
            tabletMaxWidth: 640,
            desktopMaxWidth: 800,
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
                  onTap: () => _openDetail(context, notice),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openDetail(BuildContext context, NoticeModel notice) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => NoticeDetailScreen(notice: notice)),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _NoticeEmptyState extends StatelessWidget {
  const _NoticeEmptyState();

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
            'Check back later for announcements.',
            style: NoticeTheme.emptySubtitle,
          ),
        ],
      ),
    );
  }
}