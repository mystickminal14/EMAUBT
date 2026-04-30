import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
          decoration: InputDecoration(
            hintText: 'Search folders…',
            hintStyle:
            const TextStyle(color: FolderTheme.textSub, fontSize: 14),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: FolderTheme.textSub,
              size: 20,
            ),
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: FolderTheme.textSub,
                  size: 18,
                ),
                onPressed: () {
                  controller.clear();
                  context
                      .read<UpdatedFolderViewModel>()
                      .searchFolders('');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}