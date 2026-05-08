import 'package:flutter/material.dart';
import 'notice_theme.dart';

class NoticeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const NoticeSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style:
        const TextStyle(fontSize: 14, color: NoticeTheme.textMain),
        decoration: InputDecoration(
          hintText: 'Search notices…',
          hintStyle:
          const TextStyle(color: NoticeTheme.textSub, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: NoticeTheme.textSub, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close_rounded,
                color: NoticeTheme.textSub, size: 18),
            onPressed: () {
              controller.clear();
              onChanged('');
            },
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: NoticeTheme.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
            const BorderSide(color: NoticeTheme.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}