import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/folder_mode_v2/new_file_model.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/folders/new_files_vm.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FilesTab extends StatefulWidget {
  final int folderId;

  const FilesTab({super.key, required this.folderId});

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _searchCtrl;
  late final ScrollController _scrollCtrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _scrollCtrl = ScrollController()..addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<FolderFilesViewModel>()
          .fetchFiles(context, widget.folderId, refresh: true);
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels <
        _scrollCtrl.position.maxScrollExtent - 200) return;

    final vm = context.read<FolderFilesViewModel>();
    if (vm.isFetchingMore || vm.isLoading || !vm.hasMorePages) return;
    vm.fetchNextPage(context, widget.folderId);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<FolderFilesViewModel>(
      builder: (_, vm, __) {
        return Column(
          children: [
            // Search + upload row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(child: _SearchBar(controller: _searchCtrl)),
                  const SizedBox(width: 10),
                  _UploadButton(folderId: widget.folderId),
                ],
              ),
            ),
            // Upload preview
            if (vm.selectedFile != null)
              _UploadPreviewTile(
                file: vm.selectedFile!,
                folderId: widget.folderId,
              ),
            const SizedBox(height: 8),
            // File list
            Expanded(
              child: _FileListBody(
                scrollController: _scrollCtrl,
                folderId: widget.folderId,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Search Bar ───────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: FolderTheme.searchDecoration,
      child: TextField(
        controller: controller,
        onChanged: (v) =>
            context.read<FolderFilesViewModel>().searchFiles(v),
        style: FolderTheme.fieldInput,
        decoration: const InputDecoration(
          hintText: 'Search files…',
          hintStyle: TextStyle(color: FolderTheme.textSub, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: FolderTheme.textSub, size: 18),
          border: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    );
  }
}

// ─── Upload Button ────────────────────────────────────────────────────────────
class _UploadButton extends StatelessWidget {
  final int folderId;

  const _UploadButton({required this.folderId});

  @override
  Widget build(BuildContext context) {
    return Consumer<FolderFilesViewModel>(
      builder: (_, vm, __) => ElevatedButton.icon(
        onPressed: vm.isActionLoading ? null : () => vm.pickFile(),
        style: ElevatedButton.styleFrom(
          backgroundColor: FolderTheme.accent,
          foregroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          elevation: 0,
        ),
        icon: const Icon(Icons.upload_rounded, size: 18),
        label: const Text(
          'Upload',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}

// ─── Upload Preview Tile ──────────────────────────────────────────────────────
class _UploadPreviewTile extends StatelessWidget {
  final PlatformFile file;
  final int folderId;

  const _UploadPreviewTile({required this.file, required this.folderId});

  @override
  Widget build(BuildContext context) {
    return Consumer<FolderFilesViewModel>(
      builder: (_, vm, __) => Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FolderTheme.accent.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FolderTheme.accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: FolderTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.insert_drive_file_rounded,
                  color: FolderTheme.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: FolderTheme.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatSize(file.size),
                    style: FolderTheme.cardSubtitle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (vm.isActionLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: FolderTheme.accent, strokeWidth: 2.5),
              )
            else ...[
              IconButton(
                onPressed: () => vm.uploadFile(context, folderId),
                icon: const Icon(Icons.cloud_upload_rounded,
                    color: FolderTheme.accent, size: 22),
                tooltip: 'Upload',
              ),
              IconButton(
                onPressed: vm.clearSelectedFile,
                icon: const Icon(Icons.close_rounded,
                    color: FolderTheme.textSub, size: 20),
                tooltip: 'Cancel',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── File List Body ───────────────────────────────────────────────────────────
class _FileListBody extends StatelessWidget {
  final ScrollController scrollController;
  final int folderId;

  const _FileListBody(
      {required this.scrollController, required this.folderId});

  @override
  Widget build(BuildContext context) {
    return Consumer<FolderFilesViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading && vm.filteredFiles.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
                color: FolderTheme.accent, strokeWidth: 2.5),
          );
        }
        if (vm.filteredFiles.isEmpty) {
          return const _FilesEmptyState();
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount:
          vm.filteredFiles.length + (vm.isFetchingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == vm.filteredFiles.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(
                        color: FolderTheme.accent, strokeWidth: 2)),
              );
            }
            final file = vm.filteredFiles[i];
            return FileCard(
              file: file,
              index: i,
              onDelete: () => _confirmDelete(context, vm, file),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, FolderFilesViewModel vm, FileModel file) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete File',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text(
          'Remove "${file.name ?? 'this file'}" permanently? This cannot be undone.',
          style: const TextStyle(color: FolderTheme.textSub, height: 1.5),
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
              vm.deleteFile(context, file, folderId);
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

// ─── File Card ────────────────────────────────────────────────────────────────
class FileCard extends StatelessWidget {
  final FileModel file;
  final int index;
  final VoidCallback onDelete;

  const FileCard({
    super.key,
    required this.file,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 10) * 30)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: FolderTheme.cardDecoration,
        child: ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: _FileIconBox(file: file),
          title: Text(
            file.name ?? '—',
            style: FolderTheme.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(file.formattedSize, style: FolderTheme.cardSubtitle),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: FolderTheme.textSub,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file.fileType ?? '',
                    style: FolderTheme.cardSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          trailing: IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 20),
            tooltip: 'Delete',
          ),
        ),
      ),
    );
  }
}

// ─── File Icon Box ────────────────────────────────────────────────────────────
class _FileIconBox extends StatelessWidget {
  final FileModel file;

  const _FileIconBox({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _bgColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bgColor.withOpacity(0.25), width: 1.5),
      ),
      child: Icon(_icon, color: _bgColor, size: 24),
    );
  }

  Color get _bgColor {
    if (file.isImage) return const Color(0xFF10B981);
    if (file.isPdf) return const Color(0xFFEF4444);
    if (file.isAudio) return const Color(0xFF8B5CF6);
    if (file.isVideo) return const Color(0xFFF59E0B);
    if (file.isDocument) return const Color(0xFF3B82F6);
    return FolderTheme.accent;
  }

  IconData get _icon {
    if (file.isImage) return Icons.image_rounded;
    if (file.isPdf) return Icons.picture_as_pdf_rounded;
    if (file.isAudio) return Icons.audio_file_rounded;
    if (file.isVideo) return Icons.video_file_rounded;
    if (file.isDocument) return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _FilesEmptyState extends StatelessWidget {
  const _FilesEmptyState();

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
          const Text('No files found', style: FolderTheme.emptyTitle),
          const SizedBox(height: 6),
          const Text(
            'Upload a file using the button above.',
            style: FolderTheme.emptySubtitle,
          ),
        ],
      ),
    );
  }
}