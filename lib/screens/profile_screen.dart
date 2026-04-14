import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (_nameController.text.isEmpty) {
      _nameController.text = auth.displayName;
    }

    final muted = Theme.of(context).colorScheme.onSurface.withOpacity(0.62);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: auth.isBusy
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await context.read<AuthController>().signOut();
                      if (!mounted) return;
                      Navigator.pop(context);
                    } on AppwriteException catch (e) {
                      if (!mounted) return;
                      final message = (e.message == null || e.message!.trim().isEmpty)
                          ? 'Log out failed'
                          : e.message!;
                      messenger.showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    child: Text(
                      auth.displayName.isEmpty ? 'I' : auth.displayName[0].toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.displayName.isEmpty ? 'IVEX User' : auth.displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.email,
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Account',
              style: GoogleFonts.inter(
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
            const SizedBox(height: 10),
            _profileCard(
              context: context,
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: auth.isBusy
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await context
                                    .read<AuthController>()
                                    .updateProfileName(_nameController.text);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Profile updated.')),
                                );
                              } on AppwriteException catch (e) {
                                if (!mounted) return;
                                final message = (e.message == null || e.message!.trim().isEmpty)
                                    ? 'Profile update failed'
                                    : e.message!;
                                messenger.showSnackBar(SnackBar(content: Text(message)));
                              }
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Preferences',
              style: GoogleFonts.inter(
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
            const SizedBox(height: 10),
            _profileCard(
              context: context,
              child: Column(
                children: [
                  _infoRow('Email verified', auth.isEmailVerified ? 'Yes' : 'No'),
                  const Divider(height: 20),
                  _infoRow('AI style reports', 'Enabled'),
                  const Divider(height: 20),
                  _infoRow('Data region', 'FRA (Europe)'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Danger zone',
              style: GoogleFonts.inter(
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
            const SizedBox(height: 10),
            _profileCard(
              context: context,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeleteAccountScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete account'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard({required BuildContext context, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(value),
      ],
    );
  }
}

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  String _reason = 'No longer needed';
  bool _confirm = false;

  final _reasons = const [
    'No longer needed',
    'Too expensive',
    'App is difficult to use',
    'Privacy concerns',
    'Found a better alternative',
  ];

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell us why you are leaving',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              items: _reasons
                  .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              decoration: const InputDecoration(
                labelText: 'Reason',
                prefixIcon: Icon(Icons.feedback_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _confirm,
                    onChanged: (v) => setState(() => _confirm = v ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'I understand this action is permanent and cannot be undone.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: auth.isBusy
                    ? null
                    : () async {
                        if (!_confirm) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please confirm deletion.')),
                          );
                          return;
                        }
                        if (_passwordController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password is required.')),
                          );
                          return;
                        }
                        try {
                          await context.read<AuthController>().deleteCurrentAccount(
                                password: _passwordController.text,
                              );
                          if (!mounted) return;
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        } on AppwriteException catch (e) {
                          if (!mounted) return;
                          final message = (e.message == null || e.message!.trim().isEmpty)
                              ? 'Delete failed'
                              : e.message!;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(message)));
                        }
                      },
                child: auth.isBusy ? const Text('Deleting...') : const Text('Delete account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
