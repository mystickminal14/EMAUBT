import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─── Search Bar ───────────────────────────────────────────────────────────────
class FolderSearchBar extends StatelessWidget {
  final TextEditingController controller;

  const FolderSearchBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 48,
        decoration: FolderTheme.searchDecoration,
        child: TextField(
          controller: controller,
          onChanged: (v) =>
              context.read<UpdatedFolderViewModel>().searchFolders(v),
          style: FolderTheme.fieldInput,
          decoration: const InputDecoration(
            hintText: 'Search folders…',
            hintStyle:
            TextStyle(color: FolderTheme.textSub, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded,
                color: FolderTheme.textSub, size: 20),
            border: InputBorder.none,
            contentPadding:
            EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
    );
  }
}