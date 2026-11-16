import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';

/// "Forgot password?": email a code, then set a new password with it (which also signs you in).
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  SonderApi get _api => SonderApi.instance;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter the email you signed up with.');
      return;
    }
    await _run(() async {
      await _api.forgotPassword(email);
      if (mounted) setState(() => _codeSent = true);
    });
  }

  Future<void> _reset() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Your new password needs at least 8 characters.');
      return;
    }
    await _run(() async {
      await _api.resetPassword(_email.text, _code.text, _password.text);
      // Signed in now; close this screen and AuthGate shows the app.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
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
            BubblyText(_codeSent ? 'Check your email ✉️' : 'Forgot password? 🔑', key: ValueKey(_codeSent)),
            const SizedBox(height: 10),
            Text(
              _codeSent
                  ? "If there's a Sonder account for ${_email.text.trim()}, we sent it a 6-digit code. "
                        'Enter it with your new password.'
                  : "Enter the email you signed up with and we'll send you a code to set a new password.",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
            ),
            const SizedBox(height: 32),
            if (!_codeSent) ...[
              _label('EMAIL'),
              _field(_email, hint: 'you@example.com', key: const Key('reset-email'), type: TextInputType.emailAddress),
            ] else ...[
              _label('CODE'),
              _field(
                _code,
                hint: '6-digit code',
                key: const Key('reset-code'),
                type: TextInputType.number,
                digitsOnly: true,
              ),
              const SizedBox(height: 22),
              _label('NEW PASSWORD'),
              _field(_password, hint: 'At least 8 characters', key: const Key('reset-password'), obscure: true),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: AppTheme.kDanger, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 30),
            Pressable(
              onTap: _busy ? null : (_codeSent ? _reset : _sendCode),
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
                          _codeSent ? 'SET NEW PASSWORD' : 'SEND CODE',
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
            if (_codeSent) ...[
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => setState(() => _codeSent = false),
                  child: Text(
                    'Use a different email',
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kTextSecondary),
                  ),
                ),
              ),
            ],
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

  Widget _field(
    TextEditingController controller, {
    required String hint,
    required Key key,
    TextInputType? type,
    bool obscure = false,
    bool digitsOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.kBorder, width: 2),
        boxShadow: [BoxShadow(color: AppTheme.kLavender, offset: const Offset(4, 4))],
      ),
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: type,
        obscureText: obscure,
        autocorrect: false,
        cursorColor: AppTheme.kTextPrimary,
        maxLength: digitsOnly ? 6 : null,
        inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.kTextSecondary.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
