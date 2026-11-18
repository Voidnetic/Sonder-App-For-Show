import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/motion.dart';
import '../widgets/password_field.dart';
import '../widgets/safety_sheets.dart';
import '../widgets/status_views.dart';
import '../widgets/username_field.dart';
import 'change_password_screen.dart';

/// Profile → Account: your name, username, email and password, each one tap to change.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<UserProfile> _profile = SonderApi.instance.getProfile();

  void _reload() {
    final next = SonderApi.instance.getProfile();
    setState(() {
      _profile = next;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppTheme.kCanvas, surfaceTintColor: Colors.transparent, elevation: 0),
      body: FutureBuilder<UserProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) return ErrorView(message: snapshot.error.toString(), onRetry: _reload);
          final profile = snapshot.data!;
          final user = profile.user;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              const BubblyText('Account 🪪'),
              const SizedBox(height: 8),
              Text(
                'How friends see you, and how you log in.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
              ),
              const SizedBox(height: 28),
              _section('PROFILE'),
              _card([
                _row(
                  key: const Key('account-name'),
                  icon: Icons.badge_outlined,
                  label: 'Name',
                  value: user.name,
                  onTap: () => _open(_EditNameScreen(current: user.name)),
                ),
                _row(
                  key: const Key('account-username'),
                  icon: Icons.alternate_email_rounded,
                  label: 'Username',
                  value: user.handle ?? 'Choose one',
                  onTap: () => _open(_EditUsernameScreen(current: user.username)),
                ),
              ]),
              const SizedBox(height: 28),
              _section('LOGGING IN'),
              _card([
                _row(
                  key: const Key('account-email'),
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: profile.pendingEmail != null
                      ? '${user.email}\nChanging to ${profile.pendingEmail}'
                      : user.email,
                  onTap: () => _open(ChangeEmailScreen(profile: profile)),
                ),
                _row(
                  key: const Key('account-password'),
                  icon: Icons.lock_outline_rounded,
                  label: profile.hasPassword ? 'Password' : 'Set a password',
                  value: profile.hasPassword ? '••••••••' : 'Not set (you use Google)',
                  onTap: () => _open(ChangePasswordScreen(hasPassword: profile.hasPassword, email: user.email)),
                ),
                _row(
                  icon: Icons.g_mobiledata_rounded,
                  label: 'Google',
                  value: profile.googleLinked ? 'Linked: you can use "Continue with Google"' : 'Not linked',
                ),
              ]),
              const SizedBox(height: 16),
              Text(
                'You can log in with your email or your username.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.kTextSecondary),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.kTextSecondary),
    ),
  );

  Widget _card(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: AppTheme.kSurface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppTheme.kBorder, width: 2),
      boxShadow: [BoxShadow(color: AppTheme.kShadow, offset: const Offset(3, 3))],
    ),
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: AppTheme.kBorder, thickness: 1.5),
          rows[i],
        ],
      ],
    ),
  );

  Widget _row({Key? key, required IconData icon, required String label, required String value, VoidCallback? onTap}) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.kTextPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.kTextSecondary),
                  ),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: AppTheme.kTextSecondary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- shared bits for the edit screens

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(
    text,
    style: TextStyle(color: AppTheme.kTextSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
  ),
);

Widget _textBox(TextEditingController controller, {Key? key, String? hint, TextInputType? type, bool words = false}) {
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
      autocorrect: false,
      textCapitalization: words ? TextCapitalization.words : TextCapitalization.none,
      cursorColor: AppTheme.kTextPrimary,
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

Widget _saveButton(String label, {required bool busy, required VoidCallback? onTap}) {
  return Pressable(
    onTap: busy ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.kPrimaryFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.kBorder, width: 2),
        boxShadow: [BoxShadow(color: AppTheme.kLavender, offset: const Offset(6, 6))],
      ),
      child: Center(
        child: busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: AppTheme.kOnPrimary, strokeWidth: 3),
              )
            : Text(
                label,
                style: TextStyle(
                  color: AppTheme.kOnPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
      ),
    ),
  );
}

Widget _errorText(String? error) => error == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          error,
          style: TextStyle(color: AppTheme.kDanger, fontWeight: FontWeight.bold),
        ),
      );

Widget _editPage(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<Widget> children,
}) {
  return Scaffold(
    appBar: AppBar(backgroundColor: AppTheme.kCanvas, surfaceTintColor: Colors.transparent, elevation: 0),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          BubblyText(title),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- name

class _EditNameScreen extends StatefulWidget {
  final String current;

  const _EditNameScreen({required this.current});

  @override
  State<_EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<_EditNameScreen> {
  late final _name = TextEditingController(text: widget.current);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Enter your name.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SonderApi.instance.updateAccount(name: name);
      if (!mounted) return;
      showSnack(context, 'Name updated.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _editPage(
    context,
    title: 'Your name ✏️',
    subtitle: 'What your friends call you. It shows on your photos and messages.',
    children: [
      _label('NAME'),
      _textBox(_name, key: const Key('edit-name'), hint: 'What your friends call you', words: true),
      _errorText(_error),
      const SizedBox(height: 30),
      _saveButton('SAVE', busy: _busy, onTap: _save),
    ],
  );
}

// ---------------------------------------------------------------- username

class _EditUsernameScreen extends StatefulWidget {
  final String? current;

  const _EditUsernameScreen({required this.current});

  @override
  State<_EditUsernameScreen> createState() => _EditUsernameScreenState();
}

class _EditUsernameScreenState extends State<_EditUsernameScreen> {
  late final _username = TextEditingController(text: widget.current ?? '');
  UsernameStatus _status = UsernameStatus.empty;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _username.text.trim();
    if (username.isEmpty) return setState(() => _error = 'Enter a username.');
    if (username == widget.current) return Navigator.pop(context);
    if (_status == UsernameStatus.unavailable) return setState(() => _error = 'Pick a different username.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await SonderApi.instance.updateAccount(username: username);
      if (!mounted) return;
      showSnack(context, 'You are now ${user.handle}.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _editPage(
    context,
    title: 'Username @',
    subtitle: 'Unique to you. Friends can find you by it, and you can log in with it.',
    children: [
      _label('USERNAME'),
      UsernameField(
        controller: _username,
        fieldKey: const Key('edit-username'),
        current: widget.current,
        onStatus: (status) => _status = status,
      ),
      _errorText(_error),
      const SizedBox(height: 30),
      _saveButton('SAVE', busy: _busy, onTap: _save),
    ],
  );
}

// ---------------------------------------------------------------- email

/// Change your email. When the server sends email, a code goes to the new address first.
class ChangeEmailScreen extends StatefulWidget {
  final UserProfile profile;

  const ChangeEmailScreen({super.key, required this.profile});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  late String? _waitingFor = widget.profile.pendingEmail; // a code was sent to this address
  bool _busy = false;
  String? _error;

  SonderApi get _api => SonderApi.instance;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
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

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return setState(() => _error = 'Enter a valid email address.');
    }
    if (widget.profile.hasPassword && _password.text.isEmpty) {
      return setState(() => _error = 'Enter your password to confirm.');
    }
    await _run(() async {
      final changed = await _api.changeEmail(email, password: widget.profile.hasPassword ? _password.text : null);
      if (!mounted) return;
      if (changed) {
        showSnack(context, 'Your email is now $email.');
        Navigator.pop(context);
      } else {
        setState(() => _waitingFor = email);
      }
    });
  }

  Future<void> _confirm() async {
    if (_code.text.trim().length != 6) return setState(() => _error = 'Enter the 6-digit code from the email.');
    await _run(() async {
      await _api.confirmEmailChange(_code.text);
      if (!mounted) return;
      showSnack(context, 'Your email is now $_waitingFor.');
      Navigator.pop(context);
    });
  }

  Future<void> _cancel() async {
    await _run(() async {
      await _api.cancelEmailChange();
      if (mounted) setState(() => _waitingFor = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _waitingFor;
    if (waiting != null) {
      return _editPage(
        context,
        title: 'Check your email ✉️',
        subtitle:
            "We sent a 6-digit code to $waiting. Enter it to switch to that address. Can't see it? "
            'Check your spam folder.',
        children: [
          _label('CODE'),
          _textBox(_code, key: const Key('email-code'), hint: '6-digit code', type: TextInputType.number),
          _errorText(_error),
          const SizedBox(height: 30),
          _saveButton('CONFIRM NEW EMAIL', busy: _busy, onTap: _confirm),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _cancel,
              child: Text(
                'Use a different email',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kTextSecondary),
              ),
            ),
          ),
        ],
      );
    }
    return _editPage(
      context,
      title: 'Change email ✉️',
      subtitle: 'Now: ${widget.profile.user.email}. You can log in with the new one straight after.',
      children: [
        _label('NEW EMAIL'),
        _textBox(_email, key: const Key('new-email'), hint: 'you@example.com', type: TextInputType.emailAddress),
        if (widget.profile.hasPassword) ...[
          const SizedBox(height: 22),
          _label('YOUR PASSWORD'),
          PasswordField(controller: _password, fieldKey: const Key('email-password')),
        ],
        if (widget.profile.googleLinked) ...[
          const SizedBox(height: 14),
          Text(
            '"Continue with Google" keeps working with your Google account either way.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
          ),
        ],
        _errorText(_error),
        const SizedBox(height: 30),
        _saveButton('CHANGE EMAIL', busy: _busy, onTap: _send),
      ],
    );
  }
}
