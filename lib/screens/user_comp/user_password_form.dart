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
  late final TextEditingController _confirm;
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _submitting      = false;
  bool _touched         = false; // show rules only after first keystroke

  // ── Validation rules ────────────────────────────────────────────────────────
  bool get _hasMinLength    => _password.text.length >= 8;
  bool get _hasUppercase    => _password.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase    => _password.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit        => _password.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial      => _password.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
  bool get _passwordsMatch  => _password.text == _confirm.text && _confirm.text.isNotEmpty;
  bool get _allValid        =>
      _hasMinLength && _hasUppercase && _hasLowercase &&
          _hasDigit && _hasSpecial && _passwordsMatch;

  @override
  void initState() {
    super.initState();
    _password = TextEditingController()..addListener(_onPasswordChanged);
    _confirm  = TextEditingController()..addListener(() => setState(() {}));
  }

  void _onPasswordChanged() {
    setState(() => _touched = _touched || _password.text.isNotEmpty);
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _touched = true);
    if (!_allValid) return;

    // Dismiss keyboard before anything else
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));

    // Capture navigator BEFORE any await — context can go stale after async gaps
    final nav = Navigator.of(context);

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_password.text);
      // Let flushbar render before sheet disappears
      await Future.delayed(const Duration(milliseconds: 600));
      nav.pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  width: 40, height: 4,
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
                    child: const Icon(Icons.password, color: UMTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Change Password', style: UMTheme.sheetTitle),
                ],
              ),
              const SizedBox(height: 24),

              // New password field
              _FormField(
                controller: _password,
                label: 'New Password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePassword,
                trailing: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: UMTheme.textSub, size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Confirm password field
              _FormField(
                controller: _confirm,
                label: 'Confirm Password',
                icon: Icons.lock_reset_rounded,
                obscure: _obscureConfirm,
                trailing: IconButton(
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: UMTheme.textSub, size: 20,
                  ),
                ),
              ),

              // ── Validation rules panel ───────────────────────────────────
              if (_touched) ...[
                const SizedBox(height: 16),
                _ValidationPanel(
                  hasMinLength:   _hasMinLength,
                  hasUppercase:   _hasUppercase,
                  hasLowercase:   _hasLowercase,
                  hasDigit:       _hasDigit,
                  hasSpecial:     _hasSpecial,
                  passwordsMatch: _passwordsMatch,
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
                    backgroundColor: _allValid ? UMTheme.accent : UMTheme.border,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                      : Text('Change Password', style: UMTheme.submitButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Validation Panel ─────────────────────────────────────────────────────────
class _ValidationPanel extends StatelessWidget {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecial;
  final bool passwordsMatch;

  const _ValidationPanel({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecial,
    required this.passwordsMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UMTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UMTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: UMTheme.textSub,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _RuleRow(met: hasMinLength,   label: 'At least 8 characters'),
          _RuleRow(met: hasUppercase,   label: 'One uppercase letter (A–Z)'),
          _RuleRow(met: hasLowercase,   label: 'One lowercase letter (a–z)'),
          _RuleRow(met: hasDigit,       label: 'One number (0–9)'),
          _RuleRow(met: hasSpecial,     label: 'One special character (!@#\$…)'),
          _RuleRow(met: passwordsMatch, label: 'Passwords match'),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final bool met;
  final String label;

  const _RuleRow({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = met ? const Color(0xFF166534) : UMTheme.textSub;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              key: ValueKey(met),
              size: 16,
              color: met ? const Color(0xFF22C55E) : UMTheme.border,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
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