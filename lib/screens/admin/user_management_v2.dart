import 'dart:io';
import 'package:ema_app/model/user_model.dart';
import 'package:ema_app/view_model/user_management/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CONSTANTS & THEME
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1A1A2E);
const _kAccent = Color(0xFF4F8EF7);
const _kSurface = Color(0xFFF5F7FF);
const _kCard = Colors.white;
const _kBorder = Color(0xFFE3E8F0);
const _kTextMain = Color(0xFF1A1A2E);
const _kTextSub = Color(0xFF6B7A99);
const _kAdminBadge = Color(0xFFFFEDD5);
const _kAdminText = Color(0xFFB45309);
const _kUserBadge = Color(0xFFDCFCE7);
const _kUserText = Color(0xFF166534);

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────
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
    _scrollCtrl = ScrollController();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scrollCtrl.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ManageUserViewModel>().fetchUsers(context, refresh: true);
      _fabAnim.forward();
    });
  }

  void _onScroll() {
    final vm = context.read<ManageUserViewModel>();
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      vm.fetchNextPage(context);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(),
            _SearchBar(controller: _searchCtrl),
            _FilterChips(),
            const SizedBox(height: 8),
            Expanded(child: _UserList(scrollController: _scrollCtrl)),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
        child: FloatingActionButton.extended(
          onPressed: () => _showUserSheet(context, null),
          backgroundColor: _kAccent,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text('Add User',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
        ),
      ),
    );
  }

  void _showUserSheet(BuildContext context, UserModel? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserFormSheet(
        existing: existing,
        onSubmit: (name, email, phone, password, image) async {
          final vm = context.read<ManageUserViewModel>();
          vm.setFields(
              name: name, email: email, phone: phone, password: password, image: image);
          if (existing == null) {
            await vm.addUser(context);
          } else {
            await vm.editUser(context, existing);
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
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
                const Text('Users',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _kTextMain,
                        letterSpacing: -0.5)),
                Text('${vm.totalUsers} members total',
                    style: const TextStyle(fontSize: 13, color: _kTextSub)),
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
              color: _kTextSub, size: 22),
        ),
        tooltip: 'Refresh',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color: _kPrimary.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: TextField(
          controller: controller,
          onChanged: (v) =>
              context.read<ManageUserViewModel>().searchUsers(v),
          style:
          const TextStyle(fontSize: 14, color: _kTextMain),
          decoration: const InputDecoration(
            hintText: 'Search by name or email…',
            hintStyle: TextStyle(color: _kTextSub, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: _kTextSub, size: 20),
            border: InputBorder.none,
            contentPadding:
            EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FILTER CHIPS
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ManageUserViewModel>(
      builder: (_, vm, __) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _Chip(
                  label: 'All',
                  selected: vm.roleFilter == null,
                  onTap: () {
                    vm.roleFilter = null;
                    vm.fetchUsers(context, refresh: true);
                  }),
              const SizedBox(width: 8),
              _Chip(
                  label: 'Users',
                  selected: vm.roleFilter == 'user',
                  onTap: () {
                    vm.roleFilter = 'user';
                    vm.fetchUsers(context, refresh: true);
                  }),
              const SizedBox(width: 8),
              _Chip(
                  label: 'Admins',
                  selected: vm.roleFilter == 'admin',
                  onTap: () {
                    vm.roleFilter = 'admin';
                    vm.fetchUsers(context, refresh: true);
                  }),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kAccent : _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? _kAccent : _kBorder, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight:
              selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : _kTextSub),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  USER LIST
// ─────────────────────────────────────────────────────────────────────────────
class _UserList extends StatelessWidget {
  final ScrollController scrollController;
  const _UserList({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<ManageUserViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading && vm.filteredUsers.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(
                  color: _kAccent, strokeWidth: 2.5));
        }
        if (vm.filteredUsers.isEmpty) {
          return _EmptyState();
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount:
          vm.filteredUsers.length + (vm.isFetchingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == vm.filteredUsers.length) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: CircularProgressIndicator(
                        color: _kAccent, strokeWidth: 2)),
              );
            }
            final user = vm.filteredUsers[i];
            return _UserCard(
              user: user,
              index: i,
              onEdit: () => _showEditSheet(context, vm, user),
              onDelete: () => _confirmDelete(context, vm, user),
            );
          },
        );
      },
    );
  }

  void _showEditSheet(
      BuildContext context, ManageUserViewModel vm, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserFormSheet(
        existing: user,
        onSubmit: (name, email, phone, password, image) async {
          vm.setFields(
              name: name,
              email: email,
              phone: phone,
              password: password,
              image: image);
          await vm.editUser(context, user);
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, ManageUserViewModel vm, UserModel user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete User',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(
            'Remove ${user.fullName ?? 'this user'} permanently? This cannot be undone.',
            style:
            const TextStyle(color: _kTextSub, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: _kTextSub))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.deleteUser(context, user);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  USER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final UserModel user;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.fullName);
    final isAdmin = user.role?.toLowerCase() == 'admin';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) =>
          Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color: _kPrimary.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _Avatar(imageUrl: user.image, initials: initials),
          title: Text(
            user.fullName ?? '—',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _kTextMain),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(user.email ?? '',
                  style: const TextStyle(
                      fontSize: 12.5, color: _kTextSub)),
              if (user.phone != null && user.phone!.isNotEmpty)
                Text(user.phone!,
                    style: const TextStyle(
                        fontSize: 12, color: _kTextSub)),
              const SizedBox(height: 6),
              _RoleBadge(isAdmin: isAdmin),
            ],
          ),
          trailing: _CardMenu(onEdit: onEdit, onDelete: onDelete),
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

class _Avatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  const _Avatar({this.imageUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kAccent.withOpacity(0.12),
        border: Border.all(color: _kAccent.withOpacity(0.3), width: 2),
        image: imageUrl != null && imageUrl!.isNotEmpty
            ? DecorationImage(
            image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? Center(
          child: Text(initials,
              style: const TextStyle(
                  color: _kAccent,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)))
          : null,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final bool isAdmin;
  const _RoleBadge({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin ? _kAdminBadge : _kUserBadge,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'User',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isAdmin ? _kAdminText : _kUserText),
      ),
    );
  }
}

class _CardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CardMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: _kTextSub),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_rounded, size: 18, color: _kAccent),
            SizedBox(width: 10),
            Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Delete',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.red)),
          ]),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
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
              color: _kAccent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded,
                size: 38, color: _kAccent),
          ),
          const SizedBox(height: 16),
          const Text('No users found',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _kTextMain)),
          const SizedBox(height: 6),
          const Text('Try a different search or add a new user.',
              style: TextStyle(fontSize: 13, color: _kTextSub)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  USER FORM SHEET  (Add / Edit)
// ─────────────────────────────────────────────────────────────────────────────
typedef _FormCallback = Future<void> Function(
    String name, String email, String phone, String? password, File? image);

class _UserFormSheet extends StatefulWidget {
  final UserModel? existing;
  final _FormCallback onSubmit;

  const _UserFormSheet({this.existing, required this.onSubmit});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  File? _image;
  bool _obscure = true;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _name = TextEditingController(text: u?.fullName ?? '');
    _email = TextEditingController(text: u?.email ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final vm = context.read<ManageUserViewModel>();
    await vm.pickImage();
    setState(() => _image = vm.selectedImage);
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _phone.text.trim().isEmpty) return;
    if (!_isEditing && _password.text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _name.text.trim(),
        _email.text.trim(),
        _phone.text.trim(),
        _password.text.isEmpty ? null : _password.text,
        _image,
      );
      // Wait for any flushbar/snackbar route to finish its own pop before
      // we attempt to close the bottom sheet. Without this delay the
      // navigator assertion fires because another_flushbar is still in the
      // middle of its own route lifecycle.
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: _kAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(
                        _isEditing
                            ? Icons.edit_rounded
                            : Icons.person_add_rounded,
                        color: _kAccent,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit User' : 'Add New User',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _kTextMain),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Avatar picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kAccent.withOpacity(0.08),
                          border: Border.all(
                              color: _kAccent.withOpacity(0.3), width: 2),
                          image: _image != null
                              ? DecorationImage(
                              image: FileImage(_image!),
                              fit: BoxFit.cover)
                              : (widget.existing?.image != null
                              ? DecorationImage(
                              image: NetworkImage(
                                  widget.existing!.image!),
                              fit: BoxFit.cover)
                              : null),
                        ),
                        child: (_image == null &&
                            (widget.existing?.image == null ||
                                widget.existing!.image!.isEmpty))
                            ? const Icon(Icons.person_rounded,
                            size: 36, color: _kAccent)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                              color: _kAccent, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Fields
              _Field(
                  controller: _name,
                  label: 'Full Name',
                  icon: Icons.person_outline_rounded),
              const SizedBox(height: 14),
              _Field(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isEditing),
              const SizedBox(height: 14),
              _Field(
                  controller: _phone,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              _Field(
                controller: _password,
                label: _isEditing
                    ? 'New Password (optional)'
                    : 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                trailing: IconButton(
                  onPressed: () =>
                      setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _kTextSub,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : Text(
                    _isEditing ? 'Save Changes' : 'Create User',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  REUSABLE TEXT FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool enabled;
  final Widget? trailing;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.enabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? _kSurface : _kBorder.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        enabled: enabled,
        style: const TextStyle(fontSize: 14, color: _kTextMain),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
          const TextStyle(fontSize: 13, color: _kTextSub),
          prefixIcon: Icon(icon, color: _kAccent, size: 20),
          suffixIcon: trailing,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}