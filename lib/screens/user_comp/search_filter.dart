import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:ema_app/view_model/user_management/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─── Search Bar ───────────────────────────────────────────────────────────────
class UserSearchBar extends StatelessWidget {
  final TextEditingController controller;

  const UserSearchBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 48,
        decoration: UMTheme.searchDecoration,
        child: TextField(
          controller: controller,
          // Debounce is handled inside searchUsers() in the VM
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

// ─── Filter Chips ─────────────────────────────────────────────────────────────
class UserFilterChips extends StatelessWidget {
  const UserFilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ManageUserViewModel>(
      builder: (_, vm, __) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              selected: vm.roleFilter == null,
              onTap: () {
                vm.roleFilter = null;
                vm.fetchUsers(context, refresh: true);
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Users',
              selected: vm.roleFilter == 'user',
              onTap: () {
                vm.roleFilter = 'user';
                vm.fetchUsers(context, refresh: true);
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Admins',
              selected: vm.roleFilter == 'admin',
              onTap: () {
                vm.roleFilter = 'admin';
                vm.fetchUsers(context, refresh: true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? UMTheme.accent : UMTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? UMTheme.accent : UMTheme.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: UMTheme.chipLabel.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : UMTheme.textSub,
          ),
        ),
      ),
    );
  }
}