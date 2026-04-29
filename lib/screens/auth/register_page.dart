import 'package:ema_app/utils/utils.dart';
import 'package:ema_app/view_model/auth_view_model/auth_view_model.dart';
import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey                  = GlobalKey<FormState>();
  final _nameController           = TextEditingController();
  final _emailController          = TextEditingController();
  final _phoneController          = TextEditingController();
  final _passwordController       = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  File? _imageFile;
  bool _obscurePassword        = true;
  bool _obscureConfirm         = true;
  bool _passwordTouched        = false;

  final _picker      = ImagePicker();
  final _logger      = Logger();
  final _phoneRegex  = RegExp(r'^[0-9]{10}$');

  late final AnimationController _fadeCtrl;

  // ── Live password rules ────────────────────────────────────────────────────
  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasLetter    => _passwordController.text.contains(RegExp(r'[A-Za-z]'));
  bool get _hasDigit     => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial   => _passwordController.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _passwordController.addListener(() {
      setState(() => _passwordTouched =
          _passwordTouched || _passwordController.text.isNotEmpty);
    });
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Register ───────────────────────────────────────────────────────────────
  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      Utils.flushBarErrorMessage('Please select a profile image.', context);
      return;
    }
    final fields = {
      'full_name': _nameController.text.trim(),
      'email':     _emailController.text.trim(),
      'phone':     _phoneController.text.trim(),
      'password':  _passwordController.text,
    };
    await Provider.of<AuthViewModel>(context, listen: false)
        .register(fields, _imageFile!, context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, auth, _) => Scaffold(
        backgroundColor: UMTheme.surface,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeCtrl,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 36),

                  // ── Back + heading ─────────────────────────────────────
                  Row(
                    children: [
                      _BackButton(),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Account', style: UMTheme.screenTitle),
                          Text('Fill in your details to get started.',
                              style: UMTheme.screenSubtitle),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // ── Form card ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: UMTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: UMTheme.primary.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full name
                          _Label('Full Name'),
                          _Field(
                            controller: _nameController,
                            hint: 'Enter your full name',
                            icon: Icons.person_outline_rounded,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter your name';
                              if (v.trim().length < 2) return 'At least 2 characters';
                              if (v.trim().length > 100) return 'At most 100 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          _Label('Email'),
                          _Field(
                            controller: _emailController,
                            hint: 'Enter your email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter your email';
                              final re = RegExp(
                                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                              if (!re.hasMatch(v)) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone
                          _Label('Phone Number'),
                          _Field(
                            controller: _phoneController,
                            hint: 'Enter 10-digit number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.number,
                            maxLength: 10,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter your phone';
                              if (!_phoneRegex.hasMatch(v))
                                return 'Enter a valid 10-digit number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password
                          _Label('Password'),
                          _Field(
                            controller: _passwordController,
                            hint: 'Create a password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            trailing: IconButton(
                              onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: UMTheme.textSub,
                                size: 20,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter a password';
                              if (v.length < 8) return 'At least 8 characters';
                              if (!RegExp(r'[A-Za-z]').hasMatch(v))
                                return 'Must contain a letter';
                              if (!RegExp(r'[0-9]').hasMatch(v))
                                return 'Must contain a number';
                              if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(v))
                                return 'Must contain a special character';
                              return null;
                            },
                          ),

                          // Live password hints
                          if (_passwordTouched) ...[
                            const SizedBox(height: 10),
                            _PasswordHints(
                              hasMinLength: _hasMinLength,
                              hasLetter:    _hasLetter,
                              hasDigit:     _hasDigit,
                              hasSpecial:   _hasSpecial,
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Confirm password
                          _Label('Confirm Password'),
                          _Field(
                            controller: _confirmPasswordController,
                            hint: 'Re-enter your password',
                            icon: Icons.lock_reset_rounded,
                            obscure: _obscureConfirm,
                            trailing: IconButton(
                              onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: UMTheme.textSub,
                                size: 20,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Confirm your password';
                              if (v != _passwordController.text)
                                return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // Register button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: UMTheme.accent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                UMTheme.accent.withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5),
                              )
                                  : const Text('Create Account',
                                  style: UMTheme.submitButton),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Sign in link ───────────────────────────────────────
                  const SizedBox(height: 24),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Already have an account?',
                            style:
                            TextStyle(fontSize: 14, color: UMTheme.textSub)),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 6)),
                          child: const Text('Sign In',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: UMTheme.accent,
                              )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Back button ──────────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_ios_new_rounded,
          color: UMTheme.textMain, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: UMTheme.border),
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: UMTheme.textMain,
          )),
    );
  }
}

// ─── Reusable field ───────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final int? maxLength;
  final String? Function(String?)? validator;
  final Widget? trailing;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure    = false,
    this.maxLength,
    this.validator,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: UMTheme.fieldDecoration(),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        maxLength: maxLength,
        style: UMTheme.fieldInput,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: UMTheme.fieldLabel,
          prefixIcon: Icon(icon, color: UMTheme.accent, size: 20),
          suffixIcon: trailing,
          border: InputBorder.none,
          counterText: '',
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          errorStyle: const TextStyle(fontSize: 11.5, color: Colors.redAccent),
        ),
      ),
    );
  }
}

// ─── Live password hints ──────────────────────────────────────────────────────
class _PasswordHints extends StatelessWidget {
  final bool hasMinLength;
  final bool hasLetter;
  final bool hasDigit;
  final bool hasSpecial;

  const _PasswordHints({
    required this.hasMinLength,
    required this.hasLetter,
    required this.hasDigit,
    required this.hasSpecial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UMTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: UMTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hint(met: hasMinLength, label: 'At least 8 characters'),
          _Hint(met: hasLetter,    label: 'Contains a letter'),
          _Hint(met: hasDigit,     label: 'Contains a number (0–9)'),
          _Hint(met: hasSpecial,   label: 'Contains a special character'),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final bool met;
  final String label;
  const _Hint({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              met
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              key: ValueKey(met),
              size: 15,
              color: met ? const Color(0xFF22C55E) : UMTheme.border,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
              color: met ? const Color(0xFF166534) : UMTheme.textSub,
            ),
          ),
        ],
      ),
    );
  }
}