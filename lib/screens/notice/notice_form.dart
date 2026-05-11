import 'package:ema_app/model/notice_model.dart';
import 'package:ema_app/screens/notice/notice_theme.dart';
import 'package:ema_app/view_model/folders/notice_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminNoticeFormScreen extends StatefulWidget {
  final NoticeModel? existing;
  const AdminNoticeFormScreen({super.key, this.existing});

  @override
  State<AdminNoticeFormScreen> createState() => _AdminNoticeFormScreenState();
}

class _AdminNoticeFormScreenState extends State<AdminNoticeFormScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  final _formKey = GlobalKey<FormState>();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl   = TextEditingController(text: widget.existing?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.existing?.content ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<AdminNoticeViewModel>();
      if (_isEdit) {
        vm.setFormFromNotice(widget.existing!);
      } else {
        vm.clearForm();
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<AdminNoticeViewModel>();
    vm.formTitle   = _titleCtrl.text.trim();
    vm.formContent = _contentCtrl.text.trim();

    final bool success;
    if (_isEdit) {
      success = await vm.updateNotice(context, widget.existing!);
    } else {
      success = await vm.createNotice(context);
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Notice updated successfully' : 'Notice created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _titleCtrl.clear();
      _contentCtrl.clear();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Failed to update notice.' : 'Failed to create notice.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NoticeTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: NoticeTheme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? 'Edit Notice' : 'New Notice',
          style: const TextStyle(
            color: NoticeTheme.textMain,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: NoticeTheme.divider),
        ),
      ),
      body: Consumer<AdminNoticeViewModel>(
        builder: (_, vm, __) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title ──────────────────────────────────────────────
                  const _SectionLabel('Title'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _titleCtrl,
                    hint: 'Enter notice title…',
                    maxLines: 1,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Content ────────────────────────────────────────────
                  const _SectionLabel('Content'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _contentCtrl,
                    hint: 'Write the notice body…',
                    maxLines: 8,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Content is required'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // ── Attachments ────────────────────────────────────────
                  const _SectionLabel('Attachments'),
                  const SizedBox(height: 8),

                  // Existing server attachments shown in edit mode
                  if (vm.existingAttachments.isNotEmpty) ...[
                    _ExistingAttachmentList(vm: vm),
                    const SizedBox(height: 12),
                  ],

                  // New files to upload
                  _NewAttachmentPicker(vm: vm),
                  const SizedBox(height: 32),

                  // ── Submit ─────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: vm.isActionLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NoticeTheme.accent,
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
                        _isEdit ? 'Save Changes' : 'Publish Notice',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: NoticeTheme.textMain),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        const TextStyle(color: NoticeTheme.textSub, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NoticeTheme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NoticeTheme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: NoticeTheme.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NoticeTheme.danger),
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: NoticeTheme.textSub,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ─── Existing attachments (server) ────────────────────────────────────────────
class _ExistingAttachmentList extends StatelessWidget {
  final AdminNoticeViewModel vm;
  const _ExistingAttachmentList({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Current files',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: NoticeTheme.textSub,
          ),
        ),
        const SizedBox(height: 8),
        ...vm.existingAttachments.map(
              (a) => _ExistingAttachmentTile(
            attachment: a,
            onRemove: () => vm.removeExistingAttachment(a),
          ),
        ),
      ],
    );
  }
}

class _ExistingAttachmentTile extends StatelessWidget {
  final NoticeAttachment attachment;
  final VoidCallback onRemove;
  const _ExistingAttachmentTile(
      {required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NoticeTheme.divider),
      ),
      child: Column(
        children: [
          // ── Header row ───────────────────────────────────────────────
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _fileIcon(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.displayName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: NoticeTheme.textMain,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (attachment.displaySize.isNotEmpty)
                        Text(
                          attachment.displaySize,
                          style: const TextStyle(
                              fontSize: 11, color: NoticeTheme.textSub),
                        ),
                    ],
                  ),
                ),
                // Open button
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded,
                      size: 18, color: NoticeTheme.accent),
                  tooltip: 'Open file',
                  onPressed: () => _openFile(context),
                ),
                // Remove button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: NoticeTheme.danger),
                  tooltip: 'Remove',
                  onPressed: () => _confirmRemove(context),
                ),
              ],
            ),
          ),

          // ── PDF strip ────────────────────────────────────────────────
          if (attachment.isPdf)
            _PdfPreviewStrip(attachment: attachment),

          // ── Image preview ────────────────────────────────────────────
          if (attachment.isImage)
            _ImagePreviewStrip(attachment: attachment),
        ],
      ),
    );
  }

  Widget _fileIcon() {
    final IconData icon;
    final Color color;
    if (attachment.isPdf) {
      icon = Icons.picture_as_pdf_rounded;
      color = Colors.red;
    } else if (attachment.isVideo) {
      icon = Icons.videocam_rounded;
      color = Colors.purple;
    } else if (attachment.isAudio) {
      icon = Icons.audiotrack_rounded;
      color = Colors.orange;
    } else if (attachment.isImage) {
      icon = Icons.image_rounded;
      color = Colors.teal;
    } else {
      icon = Icons.insert_drive_file_rounded;
      color = NoticeTheme.accent;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    final url = attachment.isPdf
        ? (attachment.downloadUrl ?? attachment.fileUrl)
        : attachment.fileUrl;
    if (url == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File URL not available')),
        );
      }
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Attachment',
            style:
            TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'Remove "${attachment.displayName}" from this notice?',
          style: const TextStyle(color: NoticeTheme.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: NoticeTheme.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRemove();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: NoticeTheme.danger,
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
}

// ─── PDF preview strip ────────────────────────────────────────────────────────
class _PdfPreviewStrip extends StatelessWidget {
  final NoticeAttachment attachment;
  const _PdfPreviewStrip({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final downloadUrl = attachment.downloadUrl;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF3F3),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      padding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_rounded,
              color: Colors.red, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'PDF — tap the button to download',
              style: TextStyle(fontSize: 11, color: Colors.red),
            ),
          ),
          if (downloadUrl != null)
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(downloadUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Download',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Image preview strip ──────────────────────────────────────────────────────
class _ImagePreviewStrip extends StatelessWidget {
  final NoticeAttachment attachment;
  const _ImagePreviewStrip({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final url = attachment.fileUrl;
    if (url == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: Image.network(
        url,
        height: 140,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
          height: 140,
          color: NoticeTheme.chip,
          child: const Center(
            child: CircularProgressIndicator(
                color: NoticeTheme.accent, strokeWidth: 2),
          ),
        ),
        errorBuilder: (_, __, ___) => Container(
          height: 60,
          color: NoticeTheme.chip,
          child: const Center(
            child: Icon(Icons.broken_image_rounded,
                color: NoticeTheme.textSub),
          ),
        ),
      ),
    );
  }
}

// ─── New file picker ──────────────────────────────────────────────────────────
class _NewAttachmentPicker extends StatelessWidget {
  final AdminNoticeViewModel vm;
  const _NewAttachmentPicker({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vm.selectedFiles.isNotEmpty) ...[
          const Text(
            'New files to upload',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: NoticeTheme.textSub,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(vm.selectedFiles.length, (i) {
              final f = vm.selectedFiles[i];
              return Chip(
                backgroundColor: NoticeTheme.chip,
                label: Text(
                  f.name,
                  style: const TextStyle(
                      fontSize: 12, color: NoticeTheme.accent),
                  overflow: TextOverflow.ellipsis,
                ),
                deleteIcon: const Icon(Icons.close_rounded,
                    size: 14, color: NoticeTheme.accent),
                onDeleted: () => vm.removeFile(i),
              );
            }),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: vm.pickFiles,
          icon: const Icon(Icons.attach_file_rounded,
              size: 18, color: NoticeTheme.accent),
          label: const Text('Attach Files',
              style: TextStyle(color: NoticeTheme.accent, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: NoticeTheme.accent),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }
}