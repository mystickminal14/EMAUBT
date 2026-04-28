import 'package:ema_app/view_model/user_management/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user_comp/search_filter.dart';
import '../user_comp/user_form_sheet.dart';
import '../user_comp/user_list.dart';
import '../user_comp/user_manage_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchCtrl;
  late final ScrollController _scrollCtrl;
  late final AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _fabAnim    = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ManageUserViewModel>().fetchUsers(context, refresh: true);
      _fabAnim.forward();
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels <
        _scrollCtrl.position.maxScrollExtent - 200) return;

    final vm = context.read<ManageUserViewModel>();
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
      backgroundColor: UMTheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            UserSearchBar(controller: _searchCtrl),
            const UserFilterChips(),
            const SizedBox(height: 8),
            Expanded(child: UserList(scrollController: _scrollCtrl)),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddSheet(context),
          backgroundColor: UMTheme.accent,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text('Add User', style: UMTheme.fabLabel),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserFormSheet(
        onSubmit: (name, email, phone, password, image) async {
          final vm = context.read<ManageUserViewModel>();
          vm.setFields(
              name: name, email: email, phone: phone,
              password: password, image: image);
          await vm.addUser(context);
        },
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Consumer<ManageUserViewModel>(
        builder: (_, vm, __) => Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Users', style: UMTheme.screenTitle),
                Text(
                  '${vm.totalUsers} members total',
                  style: UMTheme.screenSubtitle,
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
    return Consumer<ManageUserViewModel>(
      builder: (_, vm, __) => IconButton(
        onPressed: vm.isLoading
            ? null
            : () => vm.fetchUsers(context, refresh: true),
        icon: AnimatedRotation(
          turns: vm.isLoading ? 1 : 0,
          duration: const Duration(seconds: 1),
          child: const Icon(Icons.refresh_rounded,
              color: UMTheme.textSub, size: 22),
        ),
        tooltip: 'Refresh',
      ),
    );
  }
}