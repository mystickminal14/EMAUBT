import 'package:ema_app/model/folder_mode_v2/new_file_model.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/screens/folder_comp/in_app_file_viewer.dart';
import 'package:ema_app/utils/get_headers.dart';
import 'package:ema_app/utils/responsive.dart';
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
                Builder(builder: (_) {
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
                      else
                        GestureDetector(
                          onTap: () async {
                            await vm.pickFile();
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

// ─── Change Status Sheet ──────────────────────────────────────────────────────

/// Represents a single status option shown in the picker.
class _FileStatus {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _FileStatus({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

/// All available statuses. Adjust [value] strings to match your API.
const _kFileStatuses = [
  _FileStatus(
    label: 'Active',
    value: 'active',
    icon: Icons.check_circle_rounded,
    color: Color(0xFF10B981),
  ),
  _FileStatus(
    label: 'Inactive',
    value: 'inactive',
    icon: Icons.cancel_rounded,
    color: Color(0xFF6B7280),
  ),
];

class _ChangeStatusSheet extends StatefulWidget {
  final FileModel file;
  final int folderId;

  const _ChangeStatusSheet({required this.file, required this.folderId});

  @override
  State<_ChangeStatusSheet> createState() => _ChangeStatusSheetState();
}

class _ChangeStatusSheetState extends State<_ChangeStatusSheet> {
  late String _selectedValue;

  @override
  void initState() {
    super.initState();
    // Pre-select the file's current status, fallback to 'active'
    _selectedValue = widget.file.status ?? 'active';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Consumer<FolderFilesViewModel>(
        builder: (_, vm, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────────────────
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

            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FolderTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.toggle_on_rounded,
                    color: FolderTheme.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change Status',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: FolderTheme.textMain),
                      ),
                      Text(
                        widget.file.name ?? '',
                        style: FolderTheme.cardSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Status options ────────────────────────────────────────────
            ..._kFileStatuses.map((status) {
              final isSelected = _selectedValue == status.value;
              return GestureDetector(
                onTap: () => setState(() => _selectedValue = status.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? status.color.withOpacity(0.08)
                        : FolderTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? status.color.withOpacity(0.5)
                          : FolderTheme.border,
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Status colour dot + icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: status.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(status.icon,
                            color: status.color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      // Label
                      Expanded(
                        child: Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? status.color
                                : FolderTheme.textMain,
                          ),
                        ),
                      ),
                      // Checkmark
                      AnimatedOpacity(
                        opacity: isSelected ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: status.color,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // ── Confirm button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: vm.isActionLoading
                    ? null
                    : () async {
                  await vm.changeStatus(
                    context,
                    widget.file,
                    widget.folderId,
                    _selectedValue,
                  );
                  await Future.delayed(
                      const Duration(milliseconds: 600));
                  if (context.mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
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
                    : const Text(
                  'Update Status',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

        return ResponsiveCenter(
          tabletMaxWidth: 640,
          desktopMaxWidth: 800,
          child: ListView.builder(
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
          ),
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

  // ── View helper ────────────────────────────────────────────────────────────
  // Files open inside the app; they are never saved to the device.
  void _viewFile(BuildContext context) {
    final path = file.filePath ?? '';
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No file attached to: ${file.name ?? 'file'}'),
        backgroundColor: Colors.red.shade600,
      ));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppFileViewerPage(
          fileName: file.name ?? 'file',
          filePath: path,
        ),
      ),
    );
  }

  // ── Edit helper ────────────────────────────────────────────────────────────
  void _showEditSheet(BuildContext context) {
    final vm = context.read<FolderFilesViewModel>();
    vm.clearSelectionOnly();
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

  // ── Change Status helper ───────────────────────────────────────────────────
  void _showChangeStatusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<FolderFilesViewModel>(),
        child: _ChangeStatusSheet(file: file, folderId: folderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Resolve current status appearance for the badge
    final currentStatus = _kFileStatuses.firstWhere(
          (s) => s.value == (file.status ?? 'active'),
      orElse: () => _kFileStatuses.first,
    );

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
                // File type badge
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
                const SizedBox(width: 6),
                // ── Status badge ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: currentStatus.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(currentStatus.icon,
                          size: 9, color: currentStatus.color),
                      const SizedBox(width: 3),
                      Text(
                        currentStatus.label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: currentStatus.color),
                      ),
                    ],
                  ),
                ),
                if (file.createdAt != null) ...[
                  const SizedBox(width: 6),
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
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: FolderTheme.textSub, size: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 3,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'view',
                child: _PopupItem(
                  icon: Icons.visibility_rounded,
                  label: 'View',
                  color: FolderTheme.accent,
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: _PopupItem(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: FolderTheme.accent,
                ),
              ),
              PopupMenuItem(
                value: 'status',
                child: _PopupItem(
                  icon: Icons.toggle_on_rounded,
                  label: 'Change Status',
                  color: currentStatus.color,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: _PopupItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
                  color: Colors.red,
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'view':     _viewFile(context); break;
                case 'edit':     _showEditSheet(context); break;
                case 'status':   _showChangeStatusSheet(context); break;
                case 'delete':   onDelete(); break;
              }
            },
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
        future: getAuthHeaders(),
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
              imageUrl,
              headers: snapshot.data,
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

class _PopupItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PopupItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}