import 'dart:io';
import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:flutter/material.dart';
typedef FormCallback = Future<void> Function(String password);

class UserPasswordSheet extends StatefulWidget {
  final FormCallback onSubmit;

  const UserPasswordSheet({super.key, required this.onSubmit});

  @override
  State<UserPasswordSheet> createState() => _UserPasswordSheetState();
}

class _UserPasswordSheetState extends State<UserPasswordSheet> {
  late final TextEditingController _password;
  bool _obscure = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.trim().isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _password.text,
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
                      Icons.password,
                      color: UMTheme.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Change Password',
                    style: UMTheme.sheetTitle,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 14),
              _FormField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                trailing: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: UMTheme.textSub,
                    size: 20,
                  ),
                ),
              ),

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
                         'Change Password',
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
    this.obscure = false,
    this.enabled = true,
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
