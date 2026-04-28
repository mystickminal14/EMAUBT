import 'package:ema_app/screens/folder_comp/folder_form_sheet.dart';
import 'package:ema_app/screens/folder_comp/folder_list.dart';
import 'package:ema_app/screens/folder_comp/folder_search_bar.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FolderManagementScreen extends StatefulWidget {
  const FolderManagementScreen({super.key});

  @override
  State<FolderManagementScreen> createState() =>
      _FolderManagementScreenState();
}

class _FolderManagementScreenState extends State<FolderManagementScreen>
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
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UpdatedFolderViewModel>().fetchFolders(context, refresh: true);
      _fabAnim.forward();
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels <
        _scrollCtrl.position.maxScrollExtent - 200) {
      return;
    }

    final vm = context.read<UpdatedFolderViewModel>();
    if (vm.isFetchingMore || vm.isLoading || !vm.hasMorePages) return;
    vm.fetchNextPage(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolderTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FolderHeader(),
            FolderSearchBar(controller: _searchCtrl),
            const SizedBox(height: 8),
            Expanded(child: FolderList(scrollController: _scrollCtrl)),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddSheet(context),
          backgroundColor: FolderTheme.accent,
          icon: const Icon(Icons.create_new_folder_rounded,
              color: Colors.white),
          label: const Text('New Folder', style: FolderTheme.fabLabel),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FolderFormSheet(
        onSubmit: (name, icon) async {
          final vm = context.read<UpdatedFolderViewModel>();
          vm.setFields(name: name, iconBase64: icon);
          await vm.addFolder(context);
        },
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _FolderHeader extends StatelessWidget {
  const _FolderHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Consumer<UpdatedFolderViewModel>(
        builder: (_, vm, __) => Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Folders', style: FolderTheme.screenTitle),
                Text(
                  '${vm.totalFolders} folders total',
                  style: FolderTheme.screenSubtitle,
                ),
              ],
            ),
            const Spacer(),
            _RefreshButton(),
          ],
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<UpdatedFolderViewModel>(
      builder: (_, vm, __) => IconButton(
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
    );
  }
}