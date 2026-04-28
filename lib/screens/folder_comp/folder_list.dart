import 'package:ema_app/model/folder_mode_v2/folder_model_v2.dart';
import 'package:ema_app/screens/admin/folder_detail_screen.dart';
import 'package:ema_app/screens/folder_comp/folder_card.dart';
import 'package:ema_app/screens/folder_comp/folder_form_sheet.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FolderList extends StatelessWidget {
  final ScrollController scrollController;

  const FolderList({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdatedFolderViewModel>(
      builder: (_, vm, __) {
        // Full-page initial loader
        if (vm.isLoading && vm.filteredFolders.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }

        if (vm.filteredFolders.isEmpty) {
          return const FolderEmptyState();
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount:
          vm.filteredFolders.length + (vm.isFetchingMore ? 1 : 0),
          itemBuilder: (_, i) {
            // Bottom pagination spinner
            if (i == vm.filteredFolders.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                      color: FolderTheme.accent, strokeWidth: 2),
                ),
              );
            }

            final folder = vm.filteredFolders[i];
            return FolderCard(
              folder: folder,
              index: i,
              onTap: ()=>{
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FolderDetailScreen(folder: folder),
                ))
              },
              onEdit: () => _showEditSheet(context, vm, folder),
              onDelete: () => _confirmDelete(context, vm, folder),
            );
          },
        );
      },
    );
  }

  // ── Edit sheet ─────────────────────────────────────────────────────────────
  void _showEditSheet(
      BuildContext context, UpdatedFolderViewModel vm, FolderModelv2 folder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FolderFormSheet(
        existing: folder,
        onSubmit: (name, icon) async {
          vm.setFields(name: name, iconBase64: icon);
          await vm.editFolder(context, folder);
        },
      ),
    );
  }

  // ── Delete confirm ─────────────────────────────────────────────────────────
  void _confirmDelete(
      BuildContext context, UpdatedFolderViewModel vm, FolderModelv2 folder) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Folder',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(
          'Remove "${folder.name ?? 'this folder'}" permanently? '
              'This cannot be undone.',
          style:
          const TextStyle(color: FolderTheme.textSub, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: FolderTheme.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.deleteFolder(context, folder);
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
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class FolderEmptyState extends StatelessWidget {
  const FolderEmptyState({super.key});

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
              color: FolderTheme.accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_open_rounded,
                size: 38, color: FolderTheme.accent),
          ),
          const SizedBox(height: 16),
          const Text('No folders found', style: FolderTheme.emptyTitle),
          const SizedBox(height: 6),
          const Text(
            'Try a different search or create a new folder.',
            style: FolderTheme.emptySubtitle,
          ),
        ],
      ),
    );
  }
}