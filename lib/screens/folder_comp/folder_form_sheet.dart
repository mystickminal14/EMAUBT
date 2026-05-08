import 'dart:convert';
import 'dart:typed_data';
import 'package:ema_app/constants/base_url.dart';
import 'package:ema_app/model/folder_mode_v2/folder_model_v2.dart';
import 'package:ema_app/screens/admin/quizSet_details.dart';
import 'package:ema_app/screens/folder_comp/folder_theme.dart';
import 'package:ema_app/view_model/folders/folder_vm2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

typedef FolderFormCallback = Future<void> Function(String name, String? iconBase64);

class FolderFormSheet extends StatefulWidget {
  final FolderModelv2? existing;
  final FolderFormCallback onSubmit;
  final VoidCallback? onClose;

  const FolderFormSheet({super.key, this.existing, required this.onSubmit,this.onClose,});

  @override
  State<FolderFormSheet> createState() => _FolderFormSheetState();
}

class _FolderFormSheetState extends State<FolderFormSheet> {
  late final TextEditingController _name;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final vm = context.read<UpdatedFolderViewModel>();
    await vm.pickIcon();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;

    final vm = context.read<UpdatedFolderViewModel>();
    setState(() => _submitting = true);
    FocusScope.of(context).unfocus();

    try {
      await widget.onSubmit(
        _name.text.trim(),
        vm.selectedIconBase64,
      );
      if (mounted) widget.onClose?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: FolderTheme.sheetDecoration,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FolderTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Title row ───────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: FolderTheme.sheetIconDecoration,
                    child: Icon(
                      _isEditing
                          ? Icons.drive_file_rename_outline_rounded
                          : Icons.create_new_folder_rounded,
                      color: FolderTheme.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit Folder' : 'New Folder',
                    style: FolderTheme.sheetTitle,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Icon uploader ────────────────────────────────────────────
              Consumer<UpdatedFolderViewModel>(
                builder: (_, vm, __) {
                  // Priority: newly picked bytes > existing base64 from API
                  final Uint8List? previewBytes = vm.selectedIconBytes;
                  final String? existingBase64 = widget.existing?.iconPath;

                  return Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                  FolderTheme.accent.withOpacity(0.08),

                                  border: Border.all(
                                    color:
                                    FolderTheme.accent.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  image: _buildPreviewImage(
                                      previewBytes, existingBase64),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _buildIconChild(previewBytes, existingBase64),
                              ),
                              // Camera badge
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: FolderTheme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          previewBytes != null
                              ? 'Tap to change icon'
                              : 'Tap to upload icon',
                          style: FolderTheme.fieldLabel,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Folder name field ────────────────────────────────────────
              _FolderTextField(
                controller: _name,
                label: 'Folder Name',
                icon: Icons.folder_outlined,
              ),
              const SizedBox(height: 28),

              // ── Submit button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FolderTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                      : Text(
                    _isEditing ? 'Save Changes' : 'Create Folder',
                    style: FolderTheme.submitButton,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildIconChild(Uint8List? pickedBytes, String? iconPath) {
    // 1. Newly picked image takes priority
    if (pickedBytes != null) {
      return Image.memory(pickedBytes, fit: BoxFit.cover);
    }

    // 2. Existing icon from server
    if (iconPath != null && iconPath.isNotEmpty) {
      final fullUrl = '${BaseUrl.imageUrl}/$iconPath';

      return FutureBuilder<Map<String, String>>(
        future: getAuthHeaders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return Image.network(
            fullUrl,
            headers: snapshot.data,   // ← fixes 401
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.folder_rounded,
              size: 40,
              color: FolderTheme.accent,
            ),
          );
        },
      );
    }

    // 3. No icon — show placeholder
    return const Icon(
      Icons.folder_rounded,
      size: 40,
      color: FolderTheme.accent,
    );
  }

  /// Builds a [DecorationImage] from newly picked bytes (priority)
  /// or falls back to decoding the existing base64 string from the API.
  DecorationImage? _buildPreviewImage(
      Uint8List? pickedBytes, String? existingBase64) {
    if (pickedBytes != null) {
      return DecorationImage(
        image: MemoryImage(pickedBytes),
        fit: BoxFit.cover,
      );
    }
    if (existingBase64 != null && existingBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(existingBase64);
        return DecorationImage(
          image: MemoryImage(bytes),
          fit: BoxFit.cover,
        );
      } catch (_) {
        // If it's a URL instead of base64, fall back to NetworkImage
        if (existingBase64.startsWith('http')) {
          return DecorationImage(
            image: NetworkImage(existingBase64),
            fit: BoxFit.cover,
          );
        }
      }
    }
    return null;
  }
}

// ─── Reusable text field ──────────────────────────────────────────────────────
class _FolderTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _FolderTextField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FolderTheme.fieldDecoration(),
      child: TextField(
        controller: controller,
        style: FolderTheme.fieldInput,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: FolderTheme.fieldLabel,
          prefixIcon: Icon(icon, color: FolderTheme.accent, size: 20),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}