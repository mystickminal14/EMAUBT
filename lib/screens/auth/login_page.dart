import 'package:ema_app/view_model/auth_view_model/auth_view_model.dart';
import 'package:ema_app/screens/user_comp/user_manage_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey             = GlobalKey<FormState>();
  final _emailController     = TextEditingController();
  final _passwordController  = TextEditingController();
  bool _obscurePassword      = true;
  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _login() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      final body = {
        "email":    _emailController.text.trim(),
        "password": _passwordController.text.trim(),
      };
      Provider.of<AuthViewModel>(context, listen: false).login(body, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: UMTheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // ── Logo / icon ────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: UMTheme.accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: UMTheme.accent.withOpacity(0.25), width: 1.5),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: UMTheme.accent, size: 34),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Heading ────────────────────────────────────────────────
                const Center(
                  child: Text('Welcome back', style: UMTheme.screenTitle),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Sign in to your account to continue.',
                    style: UMTheme.screenSubtitle,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),

                // ── Form card ──────────────────────────────────────────────
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
                        // Email
                        const Text('Email',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: UMTheme.textMain,
                            )),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _emailController,
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Please enter your email'
                              : !v.contains('@')
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: 20),

                        // Password
                        const Text('Password',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: UMTheme.textMain,
                            )),
                        const SizedBox(height: 8),
                        _Field(
                          controller: _passwordController,
                          hint: 'Enter your password',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscurePassword,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Please enter your password'
                              : null,
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
                        ),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const ForgotPasswordPage())),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 0),
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: UMTheme.accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _login,
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
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                                : const Text('Sign In',
                                style: UMTheme.submitButton),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Register link ──────────────────────────────────────────
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Don't have an account?",
                          style: TextStyle(
                              fontSize: 14, color: UMTheme.textSub)),
                      TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterPage())),
                        style: TextButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: UMTheme.accent,
                          ),
                        ),
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
  final String? Function(String?)? validator;
  final Widget? trailing;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure   = false,
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
        style: UMTheme.fieldInput,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: UMTheme.fieldLabel,
          prefixIcon: Icon(icon, color: UMTheme.accent, size: 20),
          suffixIcon: trailing,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          errorStyle: const TextStyle(
            fontSize: 11.5,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }
}