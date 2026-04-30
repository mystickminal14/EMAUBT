import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/folder_mode_v2/new_file_model.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/utils/get_headers.dart';
import 'package:ema_app/view_model/folders/new_files_vm.dart';
import 'package:flutter/foundation.dart';
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
        onChanged: (v) => context.read<FolderFilesViewModel>().searchFiles(v),
        style: FolderTheme.fieldInput,
        decoration: const InputDecoration(
          hintText: 'Search files…',
          hintStyle: TextStyle(color: FolderTheme.textSub, fontSize: 13),
          prefixIcon:
          Icon(Icons.search_rounded, color: FolderTheme.textSub, size: 18),
          border: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    );
  }
}

// ─── Upload Button — opens bottom sheet ──────────────────────────────────────
class _UploadButton extends StatelessWidget {
  final int folderId;
  const _UploadButton({required this.folderId});

  @override
  Widget build(BuildContext context) {
    return Consumer<FolderFilesViewModel>(
      builder: (_, vm, __) => ElevatedButton.icon(
        onPressed: vm.isActionLoading
            ? null
            : () => _showUploadSheet(context, folderId),
        style: ElevatedButton.styleFrom(
          backgroundColor: FolderTheme.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          elevation: 0,
        ),
        icon: const Icon(Icons.upload_rounded, size: 18),
        label: const Text('Upload',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }

  void _showUploadSheet(BuildContext context, int folderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadFileSheet(folderId: folderId),
    );
  }
}

// ─── Upload File Sheet ────────────────────────────────────────────────────────
class _UploadFileSheet extends StatefulWidget {
  final int folderId;
  const _UploadFileSheet({required this.folderId});

  @override
  State<_UploadFileSheet> createState() => _UploadFileSheetState();
}

class _UploadFileSheetState extends State<_UploadFileSheet> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: context.read<FolderFilesViewModel>().uploadFileName ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Consumer<FolderFilesViewModel>(
          builder: (_, vm, __) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: FolderTheme.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: FolderTheme.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.upload_file_rounded,
                          color: FolderTheme.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Upload File',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: FolderTheme.textMain)),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Icon picker ───────────────────────────────────────────
                Row(
                  children: [
                    const Text('Icon',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: FolderTheme.textSub)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        await vm.pickIcon();
                        if (vm.selectedIcon != null) {
                          setState(() {});
                        }
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: FolderTheme.accent.withOpacity(0.08),
                              border: Border.all(
                                  color: FolderTheme.accent.withOpacity(0.3),
                                  width: 2),
                              image: vm.selectedIcon != null
                                  ? DecorationImage(
                                  image: FileImage(vm.selectedIcon!),
                                  fit: BoxFit.cover)
                                  : null,
                            ),
                            child: vm.selectedIcon == null
                                ? const Icon(Icons.image_outlined,
                                size: 28, color: FolderTheme.accent)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: FolderTheme.accent,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── File name field ───────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: FolderTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FolderTheme.border),
                  ),
                  child: TextField(
                    controller: _nameCtrl,
                    onChanged: vm.setFileName,
                    style: FolderTheme.fieldInput,
                    decoration: const InputDecoration(
                      labelText: 'File Name',
                      labelStyle: TextStyle(
                          fontSize: 13, color: FolderTheme.textSub),
                      prefixIcon: Icon(Icons.drive_file_rename_outline_rounded,
                          color: FolderTheme.accent, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── File picker tile ──────────────────────────────────────
                GestureDetector(
                  onTap: () async {
                    await vm.pickFile();
                    // Sync name field if user hasn't typed yet
                    if (vm.uploadFileName != null &&
                        _nameCtrl.text.isEmpty) {
                      _nameCtrl.text = vm.uploadFileName!;
                    }
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: vm.selectedFile != null
                          ? FolderTheme.accent.withOpacity(0.06)
                          : FolderTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: vm.selectedFile != null
                            ? FolderTheme.accent.withOpacity(0.4)
                            : FolderTheme.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: FolderTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            vm.selectedFile != null
                                ? Icons.insert_drive_file_rounded
                                : Icons.attach_file_rounded,
                            color: FolderTheme.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: vm.selectedFile != null
                              ? Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                vm.selectedFile!.name,
                                style: FolderTheme.cardTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _formatSize(vm.selectedFile!.size),
                                style: FolderTheme.cardSubtitle,
                              ),
                            ],
                          )
                              : const Text(
                            'Tap to select a file',
                            style: TextStyle(
                                color: FolderTheme.textSub,
                                fontSize: 14),
                          ),
                        ),
                        if (vm.selectedFile != null)
                          IconButton(
                            onPressed: vm.clearSelectedFile,
                            icon: const Icon(Icons.close_rounded,
                                color: FolderTheme.textSub, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Upload button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: vm.isActionLoading
                        ? null
                        : () async {
                      await vm.uploadFile(context, widget.folderId);
                      if (vm.selectedFile == null && context.mounted) {
                        await Future.delayed(
                            const Duration(milliseconds: 400));
                        if (context.mounted &&
                            Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FolderTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: vm.isActionLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                        : const Text('Upload File',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
          // Show custom icon if available, otherwise file-type icon
          leading: _FileLeading(file: file),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: FolderTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    file.fileTypeName,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: FolderTheme.accent),
                  ),
                ),
                if (file.createdAt != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.createdAt!.split(' ').first,
                      style: FolderTheme.cardSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Downloading: \${file.name ?? ""}'),
                      backgroundColor: FolderTheme.accent,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  // TODO: launchUrl(Uri.parse(file.downloadUrl));
                },
                icon: const Icon(Icons.download_rounded,
                    color: FolderTheme.accent, size: 20),
                tooltip: 'Download',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 20),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── File Leading — custom icon or type icon ──────────────────────────────────

class _FileLeading extends StatelessWidget {
  final FileModel file;
  const _FileLeading({required this.file});

  @override
  Widget build(BuildContext context) {
    if (file.iconUrl != null && file.iconUrl!.isNotEmpty) {
      final imageUrl =  file.iconUrl!;

      if (kDebugMode) {
        print("Icon URL: $imageUrl");
      }

      return FutureBuilder<Map<String, String>>(
        future: getAuthHeaders(), // ✅ USE YOUR UTIL
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FolderTheme.border, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              imageUrl, // ✅ FIXED (was wrong before)
              headers: snapshot.data, // 🔥 THIS FIXES 401
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Center(
                  child: Icon(
                    _iconData,
                    color: _iconColor,
                    size: 22,
                  ),
                );
              },
            ),
          );
        },
      );
    }

    // ── Fallback (UNCHANGED DESIGN) ──
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _iconColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: _iconColor.withOpacity(0.25), width: 1.5),
      ),
      child: Icon(_iconData, color: _iconColor, size: 24),
    );
  }

  // ── SAME AS YOUR ORIGINAL ──
  Color get _iconColor {
    if (file.isImage)    return const Color(0xFF10B981);
    if (file.isPdf)      return const Color(0xFFEF4444);
    if (file.isAudio)    return const Color(0xFF8B5CF6);
    if (file.isVideo)    return const Color(0xFFF59E0B);
    if (file.isDocument) return const Color(0xFF3B82F6);
    return FolderTheme.accent;
  }

  IconData get _iconData {
    if (file.isImage)    return Icons.image_rounded;
    if (file.isPdf)      return Icons.picture_as_pdf_rounded;
    if (file.isAudio)    return Icons.audio_file_rounded;
    if (file.isVideo)    return Icons.video_file_rounded;
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
          const Text('Tap Upload to add a file.',
              style: FolderTheme.emptySubtitle),
        ],
      ),
    );
  }
}