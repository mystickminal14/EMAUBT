import 'package:ema_app/grant_access_files.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:ema_app/view_model/access_grant_view_model_v2.dart';
import 'package:ema_app/view_model/user_management/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GiveAccessPage extends StatefulWidget {
  const GiveAccessPage({super.key});

  @override
  _GiveAccessPageState createState() => _GiveAccessPageState();
}

class _GiveAccessPageState extends State<GiveAccessPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 1, vsync: this, animationDuration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) => fetch());
  }

  Future<void> fetch() async {
    final userVM = Provider.of<ManageUserViewModel>(context, listen: false);
    userVM.roleFilter = 'user';
    await userVM.fetchUsers(context, refresh: true);
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FolderTheme.surface,
      appBar: AppBar(
        backgroundColor: FolderTheme.primary,
        elevation: 0,
        title: const Text(
          'Grant Access',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FolderTheme.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          tabs: const [
            Tab(text: 'Users & Admins'),
            Tab(text: 'Files & Quizs'),
            Tab(text: 'Activated'),
          ],
        ),
      ),
        body: Consumer2<AccessControlViewModel, ManageUserViewModel>(
          builder: (context, accessVM, userVM, child) => accessVM.isLoading || userVM.isLoading
              ? const Center(
              child: CircularProgressIndicator(
                  color: FolderTheme.accent, strokeWidth: 2.5))
              : TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: [
              UsersAdminsTab(viewModel: accessVM, userViewModel: userVM),
              // FilesQuizSetsTab(viewModel: accessVM),
              // ActivatedGrantedTab(viewModel: accessVM),
            ],
          ),
        ),
    );
  }
}

// ─── Tab 1: Users & Admins ────────────────────────────────────────────────────


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
      animationDuration: Duration.zero,
    );
    _innerTabController.addListener(_onInnerTabChanged);
  }

// In _UsersAdminsTabState, add this to initState:
  void _onInnerTabChanged() {
    if (_innerTabController.indexIsChanging) return;

    setState(() {}); // ← ADD THIS to rebuild the header UI

    final userVM = context.read<ManageUserViewModel>();
    userVM.roleFilter = _innerTabController.index == 0 ? 'user' : 'admin';
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
            color: FolderTheme.card,          // use your card background
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
          child: ListenableBuilder(  // ← CHANGE from Consumer<ManageUserViewModel>
            listenable: _innerTabController, // ← listens to tab controller directly
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

class _RoleUserList extends StatelessWidget {
  final AccessControlViewModel viewModel;
  final String role;

  const _RoleUserList({
    required this.viewModel,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ManageUserViewModel>(
      builder: (context, userVM, _) {
        final filtered = userVM.filteredUsers;

        if (userVM.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: FolderTheme.accent,
              strokeWidth: 2.5,
            ),
          );
        }

        if (filtered.isEmpty) {
          return _EmptyState(
            icon: role == 'admin'
                ? Icons.admin_panel_settings_outlined
                : Icons.people_outline_rounded,
            title: 'No ${role == 'admin' ? 'admins' : 'users'} found',
            subtitle: 'Try a different search term.',
          );
        }

        return ListView.builder(
          key: ValueKey('${role}_list'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final entity = filtered[index];
            return _PersonCard(
              entity: entity,
              isAdmin: role == 'admin',
              matchingUsers: const [],
              viewModel: viewModel,
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
class _UserAdminList extends StatelessWidget {
  final AccessControlViewModel viewModel;
  const _UserAdminList({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final userVM = context.watch<ManageUserViewModel>();
    final allUsers = userVM.filteredUsers;

    final admins = allUsers.where((u) => u.role == 'admin').toList();
    final pureUsers = allUsers.where((u) => u.role != 'admin').toList();

    if (allUsers.isEmpty) {
      return const _EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No results found',
        subtitle: 'Try a different name or email address.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (admins.isNotEmpty) ...[
          _SectionLabel(label: 'Admins', count: admins.length),
          const SizedBox(height: 10),
          ListView.builder(
            key: const Key('admin_list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: admins.length,
            itemBuilder: (context, index) {
              final admin = admins[index];
              return _PersonCard(
                entity: admin,
                isAdmin: true,
                matchingUsers: const [],
                viewModel: viewModel,
                index: index,
              );
            },
          ),
          const SizedBox(height: 20),
        ],
        if (pureUsers.isNotEmpty) ...[
          _SectionLabel(label: 'Users', count: pureUsers.length),
          const SizedBox(height: 10),
          ListView.builder(
            key: const Key('user_list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pureUsers.length,
            itemBuilder: (context, index) {
              final user = pureUsers[index];
              return _PersonCard(
                entity: user,
                isAdmin: false,
                matchingUsers: const [],
                viewModel: viewModel,
                index: index,
              );
            },
          ),
        ],
      ],
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

// ─── Tab 2: Files & Quiz Sets ─────────────────────────────────────────────────

// class FilesQuizSetsTab extends StatefulWidget {
//   final AccessControlViewModel viewModel;
//   const FilesQuizSetsTab({super.key, required this.viewModel});
//
//   @override
//   _FilesQuizSetsTabState createState() => _FilesQuizSetsTabState();
// }
//
// class _FilesQuizSetsTabState extends State<FilesQuizSetsTab>
//     with AutomaticKeepAliveClientMixin {
//   @override
//   bool get wantKeepAlive => true;
//
//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//     return SingleChildScrollView(
//       physics: const AlwaysScrollableScrollPhysics(),
//       padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
//       child: Consumer<AccessControlViewModel>(
//         builder: (context, viewModel, child) => Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Header row
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text('Content Library', style: FolderTheme.screenTitle),
//                     const SizedBox(height: 2),
//                     const Text('Activate items for access control',
//                         style: FolderTheme.screenSubtitle),
//                   ],
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: () async => await _handleAsyncAction(
//                     context,
//                     action: viewModel.activateAll,
//                     successMessage:
//                     'Activated ${viewModel.files.length + viewModel.quizSets.where((q) => !(q.folderId == 1 && viewModel.quizSets.isNotEmpty && q.id == viewModel.quizSets.first.id)).length} items',
//                     loadingMessage: 'Activating all items…',
//                   ),
//                   icon: const Icon(Icons.flash_on_rounded, size: 16),
//                   label: const Text('Activate All',
//                       style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: FolderTheme.accent,
//                     foregroundColor: Colors.white,
//                     elevation: 0,
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 16, vertical: 10),
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10)),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 24),
//
//             // Files section
//             _SectionLabel(label: 'Files', count: viewModel.files.length),
//             const SizedBox(height: 10),
//             viewModel.files.isEmpty
//                 ? _EmptyState(
//                 icon: Icons.insert_drive_file_outlined,
//                 title: 'No files available',
//                 subtitle: 'Upload files to manage access.')
//                 : ListView.builder(
//               key: const Key('file_list'),
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: viewModel.files.length,
//               itemBuilder: (context, index) {
//                 final file = viewModel.files[index];
//                 final isActivated = file.isActivated ?? false;
//                 return _ContentItemCard(
//                   icon: Icons.insert_drive_file_rounded,
//                   iconColor: FolderTheme.accent,
//                   title: file.name ?? 'Unnamed File',
//                   subtitle: 'ID: ${file.id}',
//                   isActivated: isActivated,
//                   index: index,
//                   onActivate: () async => await _handleAsyncAction(
//                     context,
//                     action: () =>
//                         viewModel.toggleFileActivation(file.id!, false),
//                     successMessage: 'File activated',
//                     loadingMessage: 'Activating…',
//                   ),
//                   onDeactivate: () async => await _handleAsyncAction(
//                     context,
//                     action: () =>
//                         viewModel.toggleFileActivation(file.id!, true),
//                     successMessage: 'File deactivated',
//                     loadingMessage: 'Deactivating…',
//                   ),
//                 );
//               },
//             ),
//
//             const SizedBox(height: 24),
//
//             // Quiz Sets section
//             _SectionLabel(
//                 label: 'Quiz Sets', count: viewModel.quizSets.length),
//             const SizedBox(height: 10),
//             viewModel.quizSets.isEmpty
//                 ? _EmptyState(
//                 icon: Icons.quiz_outlined,
//                 title: 'No quiz sets available',
//                 subtitle: 'Create quiz sets to manage access.')
//                 : ListView.builder(
//               key: const Key('quiz_list'),
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: viewModel.quizSets.length,
//               itemBuilder: (context, index) {
//                 final quizSet = viewModel.quizSets[index];
//                 final isFree = quizSet.folderId == 1 &&
//                     viewModel.quizSets.isNotEmpty &&
//                     quizSet.id == viewModel.quizSets.first.id;
//                 final isActivated = quizSet.isActivated ?? false;
//                 return _ContentItemCard(
//                   icon: Icons.quiz_rounded,
//                   iconColor: const Color(0xFF22C55E),
//                   title: quizSet.name ?? 'Unnamed Quiz Set',
//                   subtitle: isFree
//                       ? 'Free for all · Folder 1, First Quiz'
//                       : 'ID: ${quizSet.id}',
//                   subtitleColor:
//                   isFree ? const Color(0xFFF59E0B) : null,
//                   isActivated: isActivated,
//                   isFree: isFree,
//                   index: index,
//                   onActivate: isFree
//                       ? null
//                       : () async => await _handleAsyncAction(
//                     context,
//                     action: () => viewModel
//                         .toggleQuizSetActivation(quizSet.id!, false),
//                     successMessage: 'Quiz set activated',
//                     loadingMessage: 'Activating…',
//                   ),
//                   onDeactivate: isFree
//                       ? null
//                       : () async => await _handleAsyncAction(
//                     context,
//                     action: () => viewModel
//                         .toggleQuizSetActivation(quizSet.id!, true),
//                     successMessage: 'Quiz set deactivated',
//                     loadingMessage: 'Deactivating…',
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class _ContentItemCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final bool isActivated;
  final bool isFree;
  final int index;
  final VoidCallback? onActivate;
  final VoidCallback? onDeactivate;

  const _ContentItemCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    required this.isActivated,
    this.isFree = false,
    required this.index,
    this.onActivate,
    this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index.clamp(0, 8) * 30)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: FolderTheme.cardDecoration,
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withOpacity(0.25)),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(title,
              style: FolderTheme.cardTitle
                  .copyWith(color: isFree ? FolderTheme.textSub : null),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: FolderTheme.cardSubtitle.copyWith(
                  color: subtitleColor ?? FolderTheme.textSub),
            ),
          ),
          trailing: isFree
              ? Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Free',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B))),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status indicator
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isActivated
                      ? const Color(0xFF22C55E)
                      : FolderTheme.border,
                  shape: BoxShape.circle,
                ),
              ),
              _SmallButton(
                label: 'On',
                color: const Color(0xFF22C55E),
                enabled: !isActivated,
                onPressed: onActivate,
              ),
              const SizedBox(width: 6),
              _SmallButton(
                label: 'Off',
                color: const Color(0xFFEF4444),
                enabled: isActivated,
                onPressed: onDeactivate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onPressed;

  const _SmallButton({
    required this.label,
    required this.color,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: FolderTheme.border,
        foregroundColor: Colors.white,
        disabledForegroundColor: FolderTheme.textSub,
        elevation: 0,
        minimumSize: const Size(42, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Tab 3: Activated & Granted ───────────────────────────────────────────────

// class ActivatedGrantedTab extends StatefulWidget {
//   final AccessControlViewModel viewModel;
//   const ActivatedGrantedTab({super.key, required this.viewModel});
//
//   @override
//   _ActivatedGrantedTabState createState() => _ActivatedGrantedTabState();
// }
//
// class _ActivatedGrantedTabState extends State<ActivatedGrantedTab>
//     with AutomaticKeepAliveClientMixin {
//   @override
//   bool get wantKeepAlive => true;
//
//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
//     return SingleChildScrollView(
//       physics: const AlwaysScrollableScrollPhysics(),
//       padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
//       child: Consumer<AccessControlViewModel>(
//         builder: (context, viewModel, child) => Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Activated Items header
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text('Activated Items', style: FolderTheme.screenTitle),
//                     const SizedBox(height: 2),
//                     const Text('Manage active content',
//                         style: FolderTheme.screenSubtitle),
//                   ],
//                 ),
//                 if (viewModel.selectedItems.isNotEmpty)
//                   ElevatedButton.icon(
//                     onPressed: () => showDialog(
//                       context: context,
//                       builder: (ctx) => _ConfirmDialog(
//                         title: 'Delete Selected',
//                         message:
//                         'Remove ${viewModel.selectedItems.length} selected item(s)? This cannot be undone.',
//                         onConfirm: () async {
//                           Navigator.pop(ctx);
//                           await _handleAsyncAction(
//                             context,
//                             action: viewModel.deleteSelectedItems,
//                             successMessage: 'Selected items deleted',
//                             loadingMessage: 'Deleting…',
//                           );
//                         },
//                       ),
//                     ),
//                     icon: const Icon(Icons.delete_rounded, size: 16),
//                     label: Text('Delete (${viewModel.selectedItems.length})',
//                         style: const TextStyle(
//                             fontSize: 13, fontWeight: FontWeight.w600)),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFFEF4444),
//                       foregroundColor: Colors.white,
//                       elevation: 0,
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 14, vertical: 10),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10)),
//                     ),
//                   ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             _ActivatedItems(viewModel: viewModel),
//
//             const SizedBox(height: 28),
//             Container(height: 1, color: FolderTheme.border),
//             const SizedBox(height: 24),
//
//             // Granted section
//             const Text('Granted Permissions', style: FolderTheme.screenTitle),
//             const SizedBox(height: 4),
//             const Text('Files and quiz sets with granted access',
//                 style: FolderTheme.screenSubtitle),
//             const SizedBox(height: 16),
//             viewModel.grantedItems.isEmpty
//                 ? _EmptyState(
//                 icon: Icons.security_outlined,
//                 title: 'No permissions granted yet',
//                 subtitle: 'Use the Users tab to grant access.')
//                 : ListView.builder(
//               key: const Key('granted_list'),
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: viewModel.grantedItems.length,
//               itemBuilder: (context, index) {
//                 final permission = viewModel.grantedItems[index];
//                 final isFile = permission.itemType == 'file';
//                 final itemName = permission.itemName ??
//                     'Unnamed ${isFile ? 'File' : 'Quiz Set'}';
//                 return TweenAnimationBuilder<double>(
//                   tween: Tween(begin: 0, end: 1),
//                   duration: Duration(
//                       milliseconds: 200 + (index.clamp(0, 8) * 30)),
//                   curve: Curves.easeOutCubic,
//                   builder: (_, v, child) =>
//                       Opacity(opacity: v, child: child),
//                   child: Container(
//                     margin: const EdgeInsets.only(bottom: 10),
//                     decoration: FolderTheme.cardDecoration,
//                     child: ListTile(
//                       contentPadding: const EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 8),
//                       leading: Container(
//                         width: 44,
//                         height: 44,
//                         decoration: BoxDecoration(
//                           color: isFile
//                               ? FolderTheme.accent.withOpacity(0.1)
//                               : const Color(0xFF22C55E).withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(
//                               color: isFile
//                                   ? FolderTheme.accent.withOpacity(0.25)
//                                   : const Color(0xFF22C55E)
//                                   .withOpacity(0.25)),
//                         ),
//                         child: Icon(
//                           isFile
//                               ? Icons.insert_drive_file_rounded
//                               : Icons.quiz_rounded,
//                           color: isFile
//                               ? FolderTheme.accent
//                               : const Color(0xFF22C55E),
//                           size: 22,
//                         ),
//                       ),
//                       title: Text(
//                         itemName,
//                         style: FolderTheme.cardTitle,
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       subtitle: Text(
//                         isFile ? 'File' : 'Quiz Set',
//                         style: FolderTheme.cardSubtitle,
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _ActivatedItems extends StatelessWidget {
//   final AccessControlViewModel viewModel;
//   const _ActivatedItems({required this.viewModel});
//
//   @override
//   Widget build(BuildContext context) {
//     if (viewModel.activatedItems.isEmpty) {
//       return _EmptyState(
//         icon: Icons.inbox_outlined,
//         title: 'No activated items',
//         subtitle: 'Activate content in the Files & Quizzes tab.',
//       );
//     }
//
//     return ListView.builder(
//       key: const Key('activated_list'),
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       itemCount: viewModel.activatedItems.length,
//       itemBuilder: (context, index) {
//         final item = viewModel.activatedItems[index];
//         final isSelected = viewModel.selectedItems.contains(item.itemId);
//         final isFile = item.itemType == 'file';
//         return TweenAnimationBuilder<double>(
//           tween: Tween(begin: 0, end: 1),
//           duration:
//           Duration(milliseconds: 200 + (index.clamp(0, 8) * 30)),
//           curve: Curves.easeOutCubic,
//           builder: (_, v, child) => Opacity(opacity: v, child: child),
//           child: Container(
//             margin: const EdgeInsets.only(bottom: 10),
//             decoration: FolderTheme.cardDecoration.copyWith(
//               border: Border.all(
//                 color: isSelected
//                     ? FolderTheme.accent
//                     : FolderTheme.border,
//                 width: isSelected ? 2 : 1,
//               ),
//             ),
//             child: ListTile(
//               contentPadding:
//               const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               leading: Checkbox(
//                 value: isSelected,
//                 onChanged: (_) =>
//                     viewModel.toggleItemSelection(item.itemId!),
//                 activeColor: FolderTheme.accent,
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(4)),
//               ),
//               title: Text(
//                 '${isFile ? 'File' : 'Quiz Set'}: ${item.itemName ?? 'Unnamed'}',
//                 style: FolderTheme.cardTitle,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//               ),
//               trailing: IconButton(
//                 icon: const Icon(Icons.delete_outline_rounded,
//                     color: Color(0xFFEF4444), size: 20),
//                 onPressed: () async => await _handleAsyncAction(
//                   context,
//                   action: () => viewModel.deleteActivatedItem(
//                       item.itemId!, item.itemType!),
//                   successMessage: '${item.itemType} removed',
//                   loadingMessage: 'Removing…',
//                 ),
//                 tooltip: 'Remove',
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// ─── Shared Helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: FolderTheme.sheetTitle.copyWith(fontSize: 16)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: FolderTheme.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FolderTheme.accent,
            ),
          ),
        ),
      ],
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

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;
  const _ConfirmDialog(
      {required this.title,
        required this.message,
        required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: FolderTheme.textMain)),
      content: Text(message,
          style: const TextStyle(
              color: FolderTheme.textSub, height: 1.5, fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: FolderTheme.textSub)),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Confirm',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
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
        'Grant access to ${isAdmin ? 'admin' : 'user'} ${entity.fullName}?',
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
                    entity: entity.toJson(), isAdmin: isAdmin),
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

// ─── Async Action Helper ──────────────────────────────────────────────────────

Future<void> _handleAsyncAction(
    BuildContext context, {
      required Future<void> Function() action,
      required String successMessage,
      required String loadingMessage,
    }) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Row(
        children: [
          const CircularProgressIndicator(
              color: FolderTheme.accent, strokeWidth: 2.5),
          const SizedBox(width: 20),
          Text(loadingMessage,
              style: const TextStyle(color: FolderTheme.textMain)),
        ],
      ),
    ),
  );
  try {
    await action();
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(successMessage),
          ]),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(e
                    .toString()
                    .replaceFirst('FetchDataException: ', ''))),
          ]),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}