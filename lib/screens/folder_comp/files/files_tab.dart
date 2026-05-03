import 'dart:io';

import 'package:ema_app/model/folder_mode_v2/new_file_model.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/utils/get_headers.dart';
import 'package:ema_app/view_model/folders/new_files_vm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
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
    debugPrint('scroll: ${_scrollCtrl.position.pixels} / ${_scrollCtrl.position.maxScrollExtent}');
    if (_scrollCtrl.position.pixels <
    _scrollCtrl.position.maxScrollExtent - 200) return;
    final vm = context.read<FolderFilesViewModel>();
    debugPrint('hasMore: ${vm.hasMorePages} | fetching: ${vm.isFetchingMore} | loading: ${vm.isLoading}');
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
    // Clear any leftover state from a previous session
    context.read<FolderFilesViewModel>().clearSelectedFile();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<FolderFilesViewModel>(),
        child: _FileFormSheet(folderId: folderId, editFile: null),
      ),
    );
  }
}

// ─── Unified Upload / Edit Sheet ─────────────────────────────────────────────
/// Pass [editFile] to open in edit mode; pass null for upload mode.
class _FileFormSheet extends StatefulWidget {
  final int folderId;
  final FileModel? editFile; // null → upload mode

  const _FileFormSheet({required this.folderId, required this.editFile});

  @override
  State<_FileFormSheet> createState() => _FileFormSheetState();
}

class _FileFormSheetState extends State<_FileFormSheet> {
  late final TextEditingController _nameCtrl;
  bool get _isEdit => widget.editFile != null;
  bool _editSuccess = false; // set to true on successful edit, used to close sheet

  @override
  void initState() {
    super.initState();
    // In edit mode, pre-fill with the existing name
    _nameCtrl = TextEditingController(
      text: _isEdit
          ? (widget.editFile!.name ?? '')
          : (context.read<FolderFilesViewModel>().uploadFileName ?? ''),
    );
    if (_isEdit) {
      // Sync VM name so validation passes without the user retyping
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<FolderFilesViewModel>().setFileName(_nameCtrl.text);
      });
    }
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
                      child: Icon(
                        _isEdit
                            ? Icons.edit_rounded
                            : Icons.upload_file_rounded,
                        color: FolderTheme.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isEdit ? 'Edit File' : 'Upload File',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: FolderTheme.textMain),
                    ),
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
                              // In edit mode: show existing icon as fallback
                              image: vm.selectedIcon != null
                                  ? DecorationImage(
                                  image: FileImage(vm.selectedIcon!),
                                  fit: BoxFit.cover)
                                  : (_isEdit &&
                                  widget.editFile!.iconUrl != null &&
                                  widget.editFile!.iconUrl!.isNotEmpty)
                                  ? DecorationImage(
                                  image: NetworkImage(
                                      widget.editFile!.iconUrl!),
                                  fit: BoxFit.cover)
                                  : null,
                            ),
                            child: (vm.selectedIcon == null &&
                                !(_isEdit &&
                                    widget.editFile!.iconUrl != null &&
                                    widget.editFile!.iconUrl!.isNotEmpty))
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
                // In edit mode with no new file picked, show the existing
                // server file as a read-only "current file" tile, plus a
                // separate "Replace" tap target below it.
                Builder(builder: (_) {
                  // Existing server file info (edit mode only)
                  final existingName = _isEdit
                      ? (widget.editFile!.filePath
                      ?.split('/')
                      .last ??
                      widget.editFile!.name ??
                      'Current file')
                      : null;
                  final existingExt =
                  _isEdit ? widget.editFile!.fileTypeName : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Current file row (edit mode, no replacement yet) ──
                      if (_isEdit && vm.selectedFile == null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: FolderTheme.accent.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: FolderTheme.accent.withOpacity(0.25),
                                width: 1.5),
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
                                child: const Icon(
                                    Icons.insert_drive_file_rounded,
                                    color: FolderTheme.accent,
                                    size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      existingName!,
                                      style: FolderTheme.cardTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: FolderTheme.accent
                                                .withOpacity(0.1),
                                            borderRadius:
                                            BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            existingExt!,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: FolderTheme.accent),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text('Current file',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: FolderTheme.textSub)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // "Replace file" tap area
                        GestureDetector(
                          onTap: () async {
                            await vm.pickFile();
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: FolderTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border:
                              Border.all(color: FolderTheme.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.swap_horiz_rounded,
                                    color: FolderTheme.accent, size: 18),
                                SizedBox(width: 8),
                                Text('Replace file (optional)',
                                    style: TextStyle(
                                        color: FolderTheme.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ]
                      // ── New file picked (both upload & edit after picking) ──
                      else
                        GestureDetector(
                          onTap: () async {
                            await vm.pickFile();
                            // Only sync to name field if user hasn't typed anything yet
                            if (_nameCtrl.text.isEmpty && vm.uploadFileName != null) {
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
                                        _formatSize(
                                            vm.selectedFile!.size),
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
                                    onPressed: () {
                                      vm.clearSelectedFile();
                                      if (_isEdit) {
                                        vm.setFileName(_nameCtrl.text);
                                      }
                                    },
                                    icon: const Icon(Icons.close_rounded,
                                        color: FolderTheme.textSub, size: 18),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 28),

                // ── Action button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: vm.isActionLoading
                        ? null
                        : () async {
                      if (_isEdit) {
                        await vm.editFile(
                            context, widget.editFile!, widget.folderId);
                        // Wait for flushbar to finish its own route pop
                        // before we pop the bottom sheet, otherwise
                        // Navigator asserts entry.currentState == popping.
                        await Future.delayed(
                            const Duration(milliseconds: 600));
                        if (context.mounted &&
                            Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      } else {
                        await vm.uploadFile(
                            context, widget.folderId);
                        if (vm.selectedFile == null &&
                            context.mounted) {
                          // Same guard — let flushbar route settle first
                          await Future.delayed(
                              const Duration(milliseconds: 600));
                          if (context.mounted &&
                              Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
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
                        : Text(
                      _isEdit ? 'Save Changes' : 'Upload File',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
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
              folderId: folderId,
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
  final int folderId;
  final VoidCallback onDelete;

  const FileCard({
    super.key,
    required this.file,
    required this.index,
    required this.folderId,
    required this.onDelete,
  });

  // ── Download helper ────────────────────────────────────────────────────────
  Future<void> _downloadFile(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    // Show "starting" snack
    messenger.showSnackBar(SnackBar(
      content: Text('Downloading: ${file.name ?? ""}…'),
      backgroundColor: FolderTheme.accent,
      duration: const Duration(seconds: 2),
    ));

    try {
      final headers = await getAuthHeaders();
      final url     = file.downloadUrl; // uses BaseUrl + /files/{id}/download
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode != 200) {
        messenger.showSnackBar(SnackBar(
          content: Text('Download failed (${response.statusCode})'),
          backgroundColor: Colors.red.shade600,
        ));
        return;
      }

      // Determine file extension from filePath or name
      final ext      = file.extension.isNotEmpty ? '.${file.extension}' : '';
      final safeName = (file.name ?? 'file').replaceAll(RegExp(r'[^\w\-.]'), '_');

      // Save to downloads / temp directory
      final dir      = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      if (!await dir.exists()) await dir.create(recursive: true);

      final savePath = '${dir.path}/$safeName$ext';
      final saved    = File(savePath);
      await saved.writeAsBytes(response.bodyBytes);

      messenger.showSnackBar(SnackBar(
        content: Text('Saved to ${saved.path}'),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 3),
      ));

      // Open the file with the device's default app
      await OpenFile.open(savePath);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Download error: $e'),
        backgroundColor: Colors.red.shade600,
      ));
    }
  }

  // ── Edit helper — opens the same sheet in edit mode ────────────────────────
  void _showEditSheet(BuildContext context) {
    // Reset upload state, then seed name from the existing file
    final vm = context.read<FolderFilesViewModel>();
    vm.clearSelectionOnly();   // preserve nothing — name set below
    vm.setFileName(file.name ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: _FileFormSheet(folderId: folderId, editFile: file),
      ),
    );
  }

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
              // ── Download ────────────────────────────────────────────────
              IconButton(
                onPressed: () => _downloadFile(context),
                icon: const Icon(Icons.download_rounded,
                    color: FolderTheme.accent, size: 20),
                tooltip: 'Download',
              ),
              // ── Edit ────────────────────────────────────────────────────
              IconButton(
                onPressed: () => _showEditSheet(context),
                icon: const Icon(Icons.edit_rounded,
                    color: FolderTheme.accent, size: 20),
                tooltip: 'Edit',
              ),
              // ── Delete ──────────────────────────────────────────────────
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