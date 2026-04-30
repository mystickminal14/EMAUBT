import 'package:ema_app/screens/user_comp/user_card.dart';
import 'package:ema_app/screens/user_comp/user_form_sheet.dart';
import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:ema_app/screens/user_comp/user_password_form.dart';
import 'package:ema_app/model/user_model.dart';
import 'package:ema_app/view_model/user_management/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserList extends StatelessWidget {
  final ScrollController scrollController;

  const UserList({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<ManageUserViewModel>(
      builder: (_, vm, __) {
        // Full-page initial loader
        if (vm.isLoading && vm.filteredUsers.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: UMTheme.accent, strokeWidth: 2.5),
          );
        }

        if (!vm.isLoading && vm.filteredUsers.isEmpty) {
          return const UserEmptyState();
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount: vm.filteredUsers.length + (vm.isFetchingMore ? 1 : 0),
          itemBuilder: (_, i) {
            // Bottom pagination spinner
            if (i == vm.filteredUsers.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                      color: UMTheme.accent, strokeWidth: 2),
                ),
              );
            }

            final user = vm.filteredUsers[i];
            return UserCard(
              user: user,
              index: i,
              changePassword: () =>
                  _showChangePasswordSheet(context, vm, user),
              makeAdmin: () => _makeAdmin(context, vm, user),
              removeAdmin: () => _removeAdmin(context, vm, user),
              onEdit: () => _showEditSheet(context, vm, user),
              onDelete: () => _confirmDelete(context, vm, user),
            );
          },
        );
      },
    );
  }

  // ── Edit sheet ─────────────────────────────────────────────────────────────
  void _showEditSheet(
      BuildContext context, ManageUserViewModel vm, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserFormSheet(
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

  // ── Change password sheet ─────────────────────────────────────────────────
  void _showChangePasswordSheet(
      BuildContext context, ManageUserViewModel vm, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserPasswordSheet(
        onSubmit: (password) async {
          vm.setFields(password: password);
          await vm.changeUserPassword(
              context, {'user_id': user.id, 'new_password': password});
        },
      ),
    );
  }

  // ── Delete confirm ─────────────────────────────────────────────────────────
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
          'Remove ${user.fullName ?? 'this user'} permanently? '
              'This cannot be undone.',
          style: const TextStyle(color: UMTheme.textSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Cancel', style: TextStyle(color: UMTheme.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.deleteUser(context, user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
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

  // ── Remove admin confirm ──────────────────────────────────────────────────
  void _removeAdmin(
      BuildContext context, ManageUserViewModel vm, UserModel user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Admin',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(
          'Remove the Admin role of ${user.fullName ?? 'this user'}?',
          style: const TextStyle(color: UMTheme.textSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Cancel', style: TextStyle(color: UMTheme.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.removeAdmin(context, user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ── Make admin confirm ────────────────────────────────────────────────────
  void _makeAdmin(
      BuildContext context, ManageUserViewModel vm, UserModel user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Make Admin',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(
          'Grant Admin role to ${user.fullName ?? 'this user'}?',
          style: const TextStyle(color: UMTheme.textSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Cancel', style: TextStyle(color: UMTheme.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.makeAdmin(context, user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: UMTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Make Admin'),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class UserEmptyState extends StatelessWidget {
  const UserEmptyState({super.key});

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
              color: UMTheme.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded,
                size: 38, color: UMTheme.accent),
          ),
          const SizedBox(height: 16),
          const Text('No users found', style: UMTheme.emptyTitle),
          const SizedBox(height: 6),
          const Text(
            'Try a different search or add a new user.',
            style: UMTheme.emptySubtitle,
          ),
        ],
      ),
    );
  }
}