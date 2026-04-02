import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';

class GeneralScreen extends ConsumerStatefulWidget {
  const GeneralScreen({super.key});

  @override
  ConsumerState<GeneralScreen> createState() => _GeneralScreenState();
}

class _GeneralScreenState extends ConsumerState<GeneralScreen> {
  final _supabase = Supabase.instance.client;

  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;

  bool _savingUsername = false;
  bool _savingEmail = false;
  String? _usernameError;
  String? _emailError;
  String? _usernameSuccess;
  String? _emailSuccess;

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    _usernameCtrl = TextEditingController(
      text: user?.userMetadata?['display_username'] as String? ?? '',
    );
    _emailCtrl = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final displayValue = _usernameCtrl.text.trim();
    if (displayValue.isEmpty) return;
    final lowerValue = displayValue.toLowerCase();

    setState(() { _savingUsername = true; _usernameError = null; _usernameSuccess = null; });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in');

      // Update profiles table — this is what get_email_by_username RPC queries,
      // so it must be updated for login and web-app display to stay in sync.
      await _supabase
          .from('profiles')
          .update({'username': lowerValue, 'display_username': displayValue})
          .eq('id', userId);

      // Also update auth user metadata for in-app display consistency.
      await _supabase.auth.updateUser(
        UserAttributes(data: {
          'display_username': displayValue,
          'username': lowerValue,
        }),
      );

      if (mounted) setState(() => _usernameSuccess = 'Username updated');
    } on PostgrestException catch (e) {
      final msg = (e.message.contains('duplicate') || e.message.contains('unique'))
          ? 'That username is already taken'
          : e.message;
      if (mounted) setState(() => _usernameError = msg);
    } on AuthException catch (e) {
      if (mounted) setState(() => _usernameError = e.message);
    } catch (e) {
      if (mounted) setState(() => _usernameError = e.toString());
    } finally {
      if (mounted) setState(() => _savingUsername = false);
    }
  }

  Future<void> _saveEmail() async {
    final value = _emailCtrl.text.trim();
    if (value.isEmpty || !value.contains('@')) return;
    setState(() { _savingEmail = true; _emailError = null; _emailSuccess = null; });
    try {
      await _supabase.auth.updateUser(UserAttributes(email: value));
      if (mounted) {
        setState(() => _emailSuccess = 'Confirmation sent to $value');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _emailError = e.message);
    } catch (e) {
      if (mounted) setState(() => _emailError = e.toString());
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final newPwCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPwCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New password',
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscure,
                decoration: const InputDecoration(labelText: 'Confirm password'),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (newPwCtrl.text.length < 6) {
                  setDialogState(() => error = 'Password must be at least 6 characters');
                  return;
                }
                if (newPwCtrl.text != confirmCtrl.text) {
                  setDialogState(() => error = 'Passwords do not match');
                  return;
                }
                try {
                  await _supabase.auth
                      .updateUser(UserAttributes(password: newPwCtrl.text));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated')),
                    );
                  }
                } on AuthException catch (e) {
                  setDialogState(() => error = e.message);
                } catch (e) {
                  setDialogState(() => error = e.toString());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    newPwCtrl.dispose();
    confirmCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('General'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // ── Account ────────────────────────────────────────────────────────
          _SectionLabel('Account'),
          _SettingsCard(children: [
            // Username
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Username',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usernameCtrl,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            hintText: 'your_username',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _savingUsername ? null : _saveUsername,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _savingUsername
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  if (_usernameError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_usernameError!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12)),
                    ),
                  if (_usernameSuccess != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_usernameSuccess!,
                          style: const TextStyle(
                              color: AppColors.success, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const Divider(height: 20, indent: 16),
            // Email
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Email',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            hintText: 'you@example.com',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _savingEmail ? null : _saveEmail,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _savingEmail
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  if (_emailError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_emailError!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12)),
                    ),
                  if (_emailSuccess != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_emailSuccess!,
                          style: const TextStyle(
                              color: AppColors.success, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const Divider(height: 20, indent: 16),
            // Change password
            _TappableRow(
              icon: Icons.lock_outline,
              label: 'Change Password',
              onTap: _showChangePasswordDialog,
              isLast: true,
            ),
          ]),

          const SizedBox(height: 24),

          // ── Appearance ─────────────────────────────────────────────────────
          _SectionLabel('Appearance'),
          _SettingsCard(children: [
            _ThemeRow(
              value: 'system',
              icon: Icons.brightness_auto_outlined,
              label: 'System default',
              current: settings.theme,
              onTap: () => ref.read(settingsProvider.notifier)
                  .update(settings.copyWith(theme: 'system')),
            ),
            const Divider(height: 1, indent: 56),
            _ThemeRow(
              value: 'dark',
              icon: Icons.dark_mode_outlined,
              label: 'Dark',
              current: settings.theme,
              onTap: () => ref.read(settingsProvider.notifier)
                  .update(settings.copyWith(theme: 'dark')),
            ),
            const Divider(height: 1, indent: 56),
            _ThemeRow(
              value: 'light',
              icon: Icons.light_mode_outlined,
              label: 'Light',
              current: settings.theme,
              onTap: () => ref.read(settingsProvider.notifier)
                  .update(settings.copyWith(theme: 'light')),
              isLast: true,
            ),
          ]),

          const SizedBox(height: 24),

          // ── Language ───────────────────────────────────────────────────────
          _SectionLabel('Language'),
          _SettingsCard(children: [
            _LanguageRow(
              flag: '🇬🇧',
              label: 'English',
              code: 'en',
              current: settings.language,
              onTap: () => ref.read(settingsProvider.notifier)
                  .update(settings.copyWith(language: 'en')),
            ),
            const Divider(height: 1, indent: 56),
            _LanguageRow(
              flag: '🇫🇷',
              label: 'Français',
              code: 'fr',
              current: settings.language,
              onTap: () => ref.read(settingsProvider.notifier)
                  .update(settings.copyWith(language: 'fr')),
              isLast: true,
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: children),
    );
  }
}

class _TappableRow extends StatelessWidget {
  const _TappableRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.value,
    required this.icon,
    required this.label,
    required this.current,
    required this.onTap,
    this.isLast = false,
  });

  final String value;
  final IconData icon;
  final String label;
  final String current;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.protein : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.protein : AppColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: AppColors.protein, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.flag,
    required this.label,
    required this.code,
    required this.current,
    required this.onTap,
    this.isLast = false,
  });

  final String flag;
  final String label;
  final String code;
  final String current;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final selected = current == code;
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.protein : AppColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: AppColors.protein, size: 20),
          ],
        ),
      ),
    );
  }
}
