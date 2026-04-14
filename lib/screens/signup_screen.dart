import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_controller.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _agreed = false;
  bool _emailRequested = false;
  bool _emailVerified = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email first.')),
      );
      return;
    }

    try {
      await context.read<AuthController>().requestEmailOtp(email: email);
      if (!mounted) return;
      setState(() => _emailRequested = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent to your email.')),
      );
    } on AppwriteException catch (e) {
      if (!mounted) return;
      final message =
          (e.message == null || e.message!.trim().isEmpty) ? 'OTP request failed' : e.message!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter OTP.')),
      );
      return;
    }
    try {
      await context.read<AuthController>().verifyEmailOtp(otp: otp);
      if (!mounted) return;
      setState(() => _emailVerified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified successfully.')),
      );
    } on AppwriteException catch (e) {
      if (!mounted) return;
      final message = (e.message == null || e.message!.trim().isEmpty)
          ? 'OTP verification failed'
          : e.message!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept terms to continue.')),
      );
      return;
    }
    if (!_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify email first.')),
      );
      return;
    }

    try {
      await context.read<AuthController>().completeProfile(
            fullName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AppwriteException catch (e) {
      if (!mounted) return;
      final message = (e.message == null || e.message!.trim().isEmpty)
          ? 'Profile setup failed'
          : e.message!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  InputDecoration _fieldDecoration({
    required BuildContext context,
    required IconData icon,
    required String hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.white : Colors.black;
    final fieldBg = isDark ? const Color(0xFF171717) : const Color(0xFFF2F2F5);
    return InputDecoration(
      prefixIcon: Icon(icon),
      hintText: hint,
      fillColor: fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.white : Colors.black;
    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: SizedBox(
                    width: 126,
                    height: 126,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.auto_awesome, color: accent, size: 44),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Join.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Verify email by OTP, then complete your profile.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: muted),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _fieldDecoration(
                          context: context,
                          icon: Icons.alternate_email_rounded,
                          hint: 'Email address',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) return 'Email is required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        onPressed: auth.isBusy ? null : _requestOtp,
                        child: const Text('Verify'),
                      ),
                    ),
                  ],
                ),
                if (_emailRequested || auth.hasPendingOtp) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(
                      context: context,
                      icon: Icons.password_rounded,
                      hint: 'Enter OTP from email',
                    ),
                    validator: (value) {
                      if ((_emailRequested || auth.hasPendingOtp) &&
                          (value ?? '').trim().isEmpty) {
                        return 'OTP is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: auth.isBusy ? null : _verifyOtp,
                      child: Text(_emailVerified ? 'Verified' : 'Confirm OTP'),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: _fieldDecoration(
                    context: context,
                    icon: Icons.person_outline_rounded,
                    hint: 'Full Name',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return 'Full name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDecoration(
                    context: context,
                    icon: Icons.phone_outlined,
                    hint: 'Phone number (+91...)',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) return 'Phone number is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _fieldDecoration(
                    context: context,
                    icon: Icons.lock_outline_rounded,
                    hint: 'Password',
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'I agree to the Terms and Privacy Policy',
                        style: GoogleFonts.inter(fontSize: 13, color: muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                        : const Text('Create Profile'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
