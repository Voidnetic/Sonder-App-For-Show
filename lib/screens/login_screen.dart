import 'package:flutter/material.dart';

import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api_client.dart';
import '../data/google_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;

  SonderApi get _api => SonderApi.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty || (_isSignUp && name.isEmpty)) {
      setState(() => _error = 'Please fill in every field.');
      return;
    }
    if (_isSignUp && password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await _api.register(name, email, password);
      } else {
        await _api.login(email, password);
      }
      // AuthGate in main.dart switches to the app as soon as currentUser is set.
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final idToken = await GoogleAuth.getIdToken();
      if (idToken == null) return; // closed the account picker
      // The server checks the token with Google, then signs in or creates the account.
      await _api.loginWithGoogle(idToken);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openLink(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).ignore();
  }

  Future<void> _editServer() async {
    final controller = TextEditingController(text: _api.serverUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Server address', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'http://192.168.1.20:8000'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Testing with your computer: http://<computer IP>:8000 (same Wi-Fi)\n'
              'Android emulator: http://10.0.2.2:8000',
              style: TextStyle(fontSize: 12, color: AppTheme.kTextSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, defaultServerUrl),
            child: const Text('Use Sonder server'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _api.setServerUrl(result);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('SONDER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 3)),
            const SizedBox(height: 32),
            BubblyText(_isSignUp ? 'Create account ✨' : 'Welcome back 👋', key: ValueKey(_isSignUp)),
            const SizedBox(height: 8),
            const Text(
              'Capture moments together. Reveal them later.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.kTextSecondary),
            ),
            const SizedBox(height: 40),
            if (_isSignUp) ...[
              _label('NAME'),
              _field(_nameController, hint: 'e.g. Hassan', key: const Key('name-field')),
              const SizedBox(height: 24),
            ],
            _label('EMAIL'),
            _field(
              _emailController,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              key: const Key('email-field'),
            ),
            const SizedBox(height: 24),
            _label('PASSWORD'),
            _field(_passwordController, hint: '••••••••', obscure: true, key: const Key('password-field')),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB00020), fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _busy ? null : _submit,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppTheme.kTextPrimary,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.kBorder, width: 2),
                  boxShadow: const [BoxShadow(color: AppTheme.kSoftMint, offset: Offset(6, 6))],
                ),
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : Text(
                          _isSignUp ? 'SIGN UP' : 'LOG IN',
                          style: const TextStyle(
                            color: AppTheme.kBackground,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Expanded(child: Divider(color: AppTheme.kBorder, thickness: 1.5)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR',
                    style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kTextSecondary),
                  ),
                ),
                Expanded(child: Divider(color: AppTheme.kBorder, thickness: 1.5)),
              ],
            ),
            const SizedBox(height: 24),
            Pressable(
              onTap: _busy ? null : _continueWithGoogle,
              child: Container(
                key: const Key('google-button'),
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.kBorder, width: 2),
                  boxShadow: const [BoxShadow(color: AppTheme.kPeriwinkle, offset: Offset(6, 6))],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleMark(),
                    SizedBox(width: 12),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Continue with Google',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                      }),
                child: Text(
                  _isSignUp ? 'Already have an account? Log in' : 'New here? Create an account',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.kTextPrimary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12, color: AppTheme.kTextSecondary, fontWeight: FontWeight.w600),
                children: [
                  const TextSpan(text: 'By continuing you agree to the '),
                  TextSpan(
                    text: 'Terms',
                    style: const TextStyle(color: AppTheme.kTextPrimary, fontWeight: FontWeight.w900),
                    recognizer: TapGestureRecognizer()..onTap = () => _openLink(_api.termsUrl),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(color: AppTheme.kTextPrimary, fontWeight: FontWeight.w900),
                    recognizer: TapGestureRecognizer()..onTap = () => _openLink(_api.privacyPolicyUrl),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: _busy ? null : _editServer,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.kPaleYellow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.kBorder, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.dns_outlined, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Server: ${_api.serverUrl}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit_rounded, size: 14),
                    ],
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
      style: const TextStyle(
        color: AppTheme.kTextSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller, {
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Key? key,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.kBorder, width: 2),
        boxShadow: const [BoxShadow(color: AppTheme.kLavender, offset: Offset(4, 4))],
      ),
      child: TextField(
        key: key,
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autocorrect: false,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.kTextSecondary.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

/// Google's "G", drawn in its four colours.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const SweepGradient(
        colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335), Color(0xFF4285F4)],
        stops: [0.0, 0.3, 0.55, 0.8, 1.0],
      ).createShader(bounds),
      child: const Text('G', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
    );
  }
}
