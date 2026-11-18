import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import '../widgets/password_field.dart';
import '../widgets/safety_sheets.dart';
import 'forgot_password_screen.dart';

/// Profile → Change password. Accounts made with Google (no password yet) set their first one here.
class ChangePasswordScreen extends StatefulWidget {
  final bool hasPassword;
  final String email;

  const ChangePasswordScreen({super.key, required this.hasPassword, required this.email});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String? problem;
    if (widget.hasPassword && _current.text.isEmpty) {
      problem = 'Enter your current password.';
    } else if (_new.text.length < 8) {
      problem = 'Your new password needs at least 8 characters.';
    } else if (_new.text != _confirm.text) {
      problem = "The new passwords don't match.";
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SonderApi.instance.changePassword(
        currentPassword: widget.hasPassword ? _current.text : null,
        newPassword: _new.text,
      );
      if (!mounted) return;
      showSnack(context, widget.hasPassword ? 'Password changed 🔒' : 'Password set. You can log in with it too 🔒');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppTheme.kCanvas, surfaceTintColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            BubblyText(widget.hasPassword ? 'Change password 🔑' : 'Set a password 🔑'),
            const SizedBox(height: 10),
            Text(
              widget.hasPassword
                  ? 'Enter your current password, then pick a new one.'
                  : 'You signed up with Google. Add a password to also log in with ${widget.email}.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
            ),
            const SizedBox(height: 32),
            if (widget.hasPassword) ...[
              _label('CURRENT PASSWORD'),
              PasswordField(controller: _current, fieldKey: const Key('current-password')),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('change-forgot'),
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ForgotPasswordScreen(initialEmail: widget.email)),
                        ),
                  child: Text(
                    "Don't remember it?",
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kTextSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            _label('NEW PASSWORD'),
            PasswordField(
              controller: _new,
              hint: 'At least 8 characters',
              fieldKey: const Key('new-password'),
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 22),
            _label('CONFIRM NEW PASSWORD'),
            PasswordField(
              controller: _confirm,
              hint: 'Type it again',
              fieldKey: const Key('confirm-new-password'),
              autofillHints: const [AutofillHints.newPassword],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: AppTheme.kDanger, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 30),
            Pressable(
              onTap: _busy ? null : _save,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.kBorder, width: 2),
                  boxShadow: [BoxShadow(color: AppTheme.kLavender, offset: const Offset(6, 6))],
                ),
                child: Center(
                  child: _busy
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: AppTheme.kOnPrimary, strokeWidth: 3),
                        )
                      : Text(
                          widget.hasPassword ? 'CHANGE PASSWORD' : 'SET PASSWORD',
                          style: TextStyle(
                            color: AppTheme.kOnPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    ),
  );
}
