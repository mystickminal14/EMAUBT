import 'dart:io';
import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ema_app/model/user_model.dart';
import 'package:ema_app/view_model/user_management/user_view_model.dart';


typedef FormCallback = Future<void> Function(
    String name, String email, String phone, String? password, File? image);

class UserFormSheet extends StatefulWidget {
  final UserModel? existing;
  final FormCallback onSubmit;

  const UserFormSheet({super.key, this.existing, required this.onSubmit});

  @override
  State<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<UserFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;

  File? _image;
  bool _obscure    = true;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u  = widget.existing;
    _name     = TextEditingController(text: u?.fullName ?? '');
    _email    = TextEditingController(text: u?.email    ?? '');
    _phone    = TextEditingController(text: u?.phone    ?? '');
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final vm = context.read<ManageUserViewModel>();
    await vm.pickImage();
    if (mounted) setState(() => _image = vm.selectedImage);
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty  ||
        _email.text.trim().isEmpty ||
        _phone.text.trim().isEmpty) return;
    if (!_isEditing && _password.text.trim().isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _name.text.trim(),
        _email.text.trim(),
        _phone.text.trim(),
        _password.text.isEmpty ? null : _password.text,
        _image,
      );
      // Give flushbar time to finish its own route pop before we close
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
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
        decoration: UMTheme.sheetDecoration,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: UMTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: UMTheme.sheetIconDecoration,
                    child: Icon(
                      _isEditing
                          ? Icons.edit_rounded
                          : Icons.person_add_rounded,
                      color: UMTheme.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit User' : 'Add New User',
                    style: UMTheme.sheetTitle,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Avatar picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: UMTheme.accent.withOpacity(0.08),
                          border: Border.all(
                              color: UMTheme.accent.withOpacity(0.3),
                              width: 2),
                          image: _image != null
                              ? DecorationImage(
                              image: FileImage(_image!),
                              fit: BoxFit.cover)
                              : (widget.existing?.image != null &&
                              widget.existing!.image!.isNotEmpty
                              ? DecorationImage(
                              image: NetworkImage(
                                  widget.existing!.image!),
                              fit: BoxFit.cover)
                              : null),
                        ),
                        child: (_image == null &&
                            (widget.existing?.image == null ||
                                widget.existing!.image!.isEmpty))
                            ? const Icon(Icons.person_rounded,
                            size: 36, color: UMTheme.accent)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: UMTheme.cameraBadgeDecoration,
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Form fields
              _FormField(
                  controller: _name,
                  label: 'Full Name',
                  icon: Icons.person_outline_rounded),
              const SizedBox(height: 14),
              _FormField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isEditing),
              const SizedBox(height: 14),
              _FormField(
                  controller: _phone,
                  label: 'Phone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              if (!_isEditing) ...[
                const SizedBox(height: 14),
                _FormField(
                  controller: _password,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  trailing: IconButton(
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: UMTheme.textSub,
                      size: 20,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UMTheme.accent,
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
                    _isEditing ? 'Save Changes' : 'Create User',
                    style: UMTheme.submitButton,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable text field ──────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool enabled;
  final Widget? trailing;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure  = false,
    this.enabled  = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: UMTheme.fieldDecoration(enabled: enabled),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        enabled: enabled,
        style: UMTheme.fieldInput,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: UMTheme.fieldLabel,
          prefixIcon: Icon(icon, color: UMTheme.accent, size: 20),
          suffixIcon: trailing,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}