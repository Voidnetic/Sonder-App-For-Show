import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';

/// "Check your email": the 6-digit code step after signing up with email and password.
/// Shown by AuthGate until the account is verified (only when the server sends email).
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _resendAfter = 60;

  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;
  int _cooldown = _resendAfter;
  Timer? _timer;

  SonderApi get _api => SonderApi.instance;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    // A code went out at sign-up. For an existing account opening this screen, ask for one now
    // (the server ignores the request if one was sent in the last minute).
    _api.sendVerificationCode().catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await _api.verifyEmail(code); // AuthGate moves on to the app once this succeeds
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await _api.sendVerificationCode();
      if (mounted) setState(() => _info = 'New code sent. Check your inbox (and spam).');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final email = _api.currentUser.value?.email ?? 'your email';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('SONDER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 3)),
            const SizedBox(height: 32),
            const BubblyText('Check your email ✉️'),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
                children: [
                  const TextSpan(text: 'We sent a 6-digit code to '),
                  TextSpan(
                    text: email,
                    style: TextStyle(color: AppTheme.kTextPrimary, fontWeight: FontWeight.w900),
                  ),
                  const TextSpan(text: '. Enter it to start adding friends and making moments.'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.kBorder, width: 2),
                boxShadow: [BoxShadow(color: AppTheme.kSunshine, offset: const Offset(5, 5))],
              ),
              child: TextField(
                key: const Key('code-field'),
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                cursorColor: AppTheme.kTextPrimary,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  if (v.length == 6 && !_busy) _verify(); // verify as soon as all six digits are in
                },
                style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 40, letterSpacing: 14),
                decoration: InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  hintText: '••••••',
                  hintStyle: TextStyle(color: AppTheme.kTextSecondary.withValues(alpha: 0.4), letterSpacing: 14),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: TextStyle(color: AppTheme.kDanger, fontWeight: FontWeight.bold),
              ),
            ],
            if (_info != null) ...[
              const SizedBox(height: 14),
              Text(
                _info!,
                style: TextStyle(color: AppTheme.kTextSecondary, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 28),
            Pressable(
              onTap: _busy ? null : _verify,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppTheme.kTextPrimary,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.kBorder, width: 2),
                  boxShadow: [BoxShadow(color: AppTheme.kSoftMint, offset: const Offset(6, 6))],
                ),
                child: Center(
                  child: _busy
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: AppTheme.kOnPrimary, strokeWidth: 3),
                        )
                      : Text(
                          'VERIFY',
                          style: TextStyle(
                            color: AppTheme.kOnPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                key: const Key('resend-code'),
                onPressed: _cooldown > 0 ? null : _resend,
                child: Text(
                  _cooldown > 0 ? 'Resend code in ${_cooldown}s' : "Didn't get it? Resend code",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _cooldown > 0 ? AppTheme.kTextSecondary : AppTheme.kTextPrimary,
                  ),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => _api.logout(),
                child: Text(
                  'Wrong email? Log out',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kTextSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
