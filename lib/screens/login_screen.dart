import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';

import '../services/auth_controller.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final auth = context.read<AuthController>();
    try {
      await auth.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on AppwriteException catch (e) {
      if (!mounted) return;
      final message = (e.message == null || e.message!.trim().isEmpty)
          ? 'Sign in failed'
          : e.message!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.white : Colors.black;
    final fieldBg = isDark ? const Color(0xFF171717) : const Color(0xFFF2F2F5);
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    if (_emailController.text.isEmpty && auth.rememberedEmail.isNotEmpty) {
      _emailController.text = auth.rememberedEmail;
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Center(
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.auto_awesome,
                        color: accent,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Welcome.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign in to your premium studio profile.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: muted,
                      ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    hintText: 'Email address',
                    fillColor: fieldBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: accent.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: accent, width: 1.4),
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return 'Email is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    hintText: 'Password',
                    fillColor: fieldBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: accent.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: accent, width: 1.4),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return 'Password is required';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Remember me', style: TextStyle(color: muted)),
                    const Spacer(),
                    TextButton(
                      onPressed: auth.isBusy
                          ? null
                          : () async {
                              final email = _emailController.text.trim();
                              if (email.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Enter email for recovery.')),
                                );
                                return;
                              }
                              try {
                                await context
                                    .read<AuthController>()
                                    .sendPasswordRecovery(email: email);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Recovery email sent.')),
                                );
                              } on AppwriteException catch (e) {
                                if (!mounted) return;
                                final message =
                                    (e.message == null || e.message!.trim().isEmpty)
                                        ? 'Recovery failed'
                                        : e.message!;
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(message)));
                              }
                            },
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.isBusy ? null : _submit,
                    child: auth.isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: Divider(thickness: 0.8)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'or',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(thickness: 0.8)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: auth.isBusy
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await context.read<AuthController>().signInWithGoogle();
                            } on AppwriteException catch (e) {
                              if (!mounted) return;
                              final message = (e.message == null || e.message!.trim().isEmpty)
                                  ? 'Google sign in failed'
                                  : e.message!;
                              messenger.showSnackBar(SnackBar(content: Text(message)));
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'G',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ),
                    label: const Text('Continue with Google'),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: Text(
                      "Create a new profile",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
}
