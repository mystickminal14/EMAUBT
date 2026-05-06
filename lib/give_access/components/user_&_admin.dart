import 'package:ema_app/give_access/grant_access_files_v2.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:ema_app/view_model/access_grant_view_model_v2.dart';
import 'package:ema_app/view_model/user_management/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UsersAdminsTab extends StatefulWidget {
  final AccessControlViewModel viewModel;
  final ManageUserViewModel userViewModel;

  const UsersAdminsTab({
    super.key,
    required this.viewModel,
    required this.userViewModel,
  });

  @override
  _UsersAdminsTabState createState() => _UsersAdminsTabState();
}

class _UsersAdminsTabState extends State<UsersAdminsTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late TabController _innerTabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(
      length: 2,
      vsync: this,
    );
    _innerTabController.addListener(_onInnerTabChanged);
  }

  void _onInnerTabChanged() {
    if (!_innerTabController.indexIsChanging) return;

    final userVM = context.read<ManageUserViewModel>();

    userVM.roleFilter =
    _innerTabController.index == 0 ? 'user' : 'admin';

    userVM.fetchUsers(context, refresh: true);
  }

  @override
  void dispose() {
    _innerTabController.removeListener(_onInnerTabChanged);
    _innerTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search ──
        const _SearchField(),

        // ── Inner Tab Bar ──
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          decoration: BoxDecoration(
            color: FolderTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FolderTheme.border),
          ),
          child: TabBar(
            controller: _innerTabController,
            indicator: BoxDecoration(
              color: FolderTheme.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: FolderTheme.textSub,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Users'),
              Tab(text: 'Admins'),
            ],
          ),
        ),

        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: ListenableBuilder(
            listenable: _innerTabController,
            builder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _innerTabController.index == 0 ? 'Users' : 'Admins',
                  style: FolderTheme.screenTitle,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Select a person to grant content access',
                  style: FolderTheme.screenSubtitle,
                ),
              ],
            ),
          ),
        ),

        // ── Tab Views ──
        Expanded(
          child: TabBarView(
            controller: _innerTabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Users list
              _RoleUserList(
                viewModel: widget.viewModel,
                role: 'user',
              ),
              // Admins list
              _RoleUserList(
                viewModel: widget.viewModel,
                role: 'admin',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleUserList extends StatefulWidget {
  final AccessControlViewModel viewModel;
  final String role;

  const _RoleUserList({
    required this.viewModel,
    required this.role,
  });

  @override
  _RoleUserListState createState() => _RoleUserListState();
}

class _RoleUserListState extends State<_RoleUserList> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.position.pixels > _controller.position.maxScrollExtent - 200) {
      final userVM = Provider.of<ManageUserViewModel>(context, listen: false);
      if (!userVM.isLoading) {
        userVM.fetchUsers(context, refresh: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ManageUserViewModel>(
      builder: (context, userVM, _) {
        final filtered = userVM.filteredUsers;

        if (userVM.isLoading && filtered.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: FolderTheme.accent,
              strokeWidth: 2.5,
            ),
          );
        }

        if (filtered.isEmpty) {
          return _EmptyState(
            icon: widget.role == 'admin'
                ? Icons.admin_panel_settings_outlined
                : Icons.people_outline_rounded,
            title: 'No ${widget.role == 'admin' ? 'admins' : 'users'} found',
            subtitle: 'Try a different search term.',
          );
        }

        return ListView.builder(
          key: ValueKey('${widget.role}_list'),
          controller: _controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          itemCount: filtered.length + (userVM.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == filtered.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    color: FolderTheme.accent,
                    strokeWidth: 2.5,
                  ),
                ),
              );
            }
            final entity = filtered[index];
            return _PersonCard(
              entity: entity,
              isAdmin: widget.role == 'admin',
              matchingUsers: const [],
              viewModel: widget.viewModel,
              index: index,
            );
          },
        );
      },
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 48,
        decoration: UMTheme.searchDecoration,
        child: TextField(
          controller: _controller,
          onChanged: (v) =>
              context.read<ManageUserViewModel>().searchUsers(context, v),
          style: UMTheme.fieldInput,
          decoration: const InputDecoration(
            hintText: 'Search by name or email…',
            hintStyle: TextStyle(color: UMTheme.textSub, fontSize: 14),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: UMTheme.textSub,
              size: 20,
            ),
            border: InputBorder.none,
            contentPadding:
            EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final dynamic entity;
  final bool isAdmin;
  final Iterable<dynamic> matchingUsers;
  final AccessControlViewModel viewModel;
  final int index;

  const _PersonCard({
    required this.entity,
    required this.isAdmin,
    required this.matchingUsers,
    required this.viewModel,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index.clamp(0, 8) * 40)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: FolderTheme.cardDecoration,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? FolderTheme.accent.withOpacity(0.12)
                        : FolderTheme.iconBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAdmin
                          ? FolderTheme.accent.withOpacity(0.3)
                          : FolderTheme.iconBgAccent,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isAdmin
                        ? Icons.admin_panel_settings_rounded
                        : Icons.person_rounded,
                    color: FolderTheme.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entity.fullName ?? '—',
                          style: FolderTheme.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(entity.email ?? '—',
                          style: FolderTheme.cardSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _GrantButton(
                  onPressed: () => _showGrantAccessDialog(
                      context, entity, isAdmin, viewModel),
                ),
              ],
            ),
            if (matchingUsers.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: FolderTheme.border, height: 1),
              const SizedBox(height: 10),
              Text('Also matches:',
                  style: FolderTheme.cardSubtitle
                      .copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: 6),
              ...matchingUsers.map(
                    (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_right_rounded,
                          size: 16, color: FolderTheme.textSub),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName ?? '—',
                                style: FolderTheme.cardTitle
                                    .copyWith(fontSize: 13)),
                            Text(user.email ?? '—',
                                style: FolderTheme.cardSubtitle),
                          ],
                        ),
                      ),
                      _GrantButton(
                        onPressed: () => _showGrantAccessDialog(
                            context, user, false, viewModel),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GrantButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GrantButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.lock_open_rounded, size: 14),
      label: const Text('Grant', style: TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: FolderTheme.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: FolderTheme.cardDecoration,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: FolderTheme.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: FolderTheme.accent),
          ),
          const SizedBox(height: 14),
          Text(title, style: FolderTheme.emptyTitle),
          const SizedBox(height: 4),
          Text(subtitle,
              style: FolderTheme.emptySubtitle,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Grant Access Dialog ──────────────────────────────────────────────────────

void _showGrantAccessDialog(BuildContext context, dynamic entity, bool isAdmin,
    AccessControlViewModel viewModel) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FolderTheme.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_open_rounded,
                size: 20, color: FolderTheme.accent),
          ),
          const SizedBox(width: 10),
          const Text('Grant Access',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: FolderTheme.textMain)),
        ],
      ),
      content: Text(
        'Grant access to ${isAdmin ? 'admin' : 'user'} ${entity.fullName ?? entity['full_name']}?',
        style: const TextStyle(
            color: FolderTheme.textSub, height: 1.5, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel',
              style: TextStyle(color: FolderTheme.textSub)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GrantAccessFilesPage(
                    userId: entity.id,           // ✅ Use property getter
                    userEmail: entity.email,     // ✅ Use property getter
                    userName: entity.fullName,   // ✅ Use property getter
                    isAdmin: isAdmin
                ),
              ),
            ).then((result) {
              // if (result == true) viewModel.fetchGrantedItems();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: FolderTheme.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Continue',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}