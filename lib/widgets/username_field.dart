import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_client.dart';
import '../theme/app_theme.dart';

/// Whether the username typed so far can be used.
enum UsernameStatus { empty, checking, available, unavailable, error }

/// A username box with "@" in front that checks, as you type, whether the name is free.
/// Only lowercase letters, numbers, dots and underscores can be typed.
class UsernameField extends StatefulWidget {
  final TextEditingController controller;
  final Key? fieldKey;

  /// The person's current username, which counts as available (Account settings).
  final String? current;
  final ValueChanged<UsernameStatus>? onStatus;

  const UsernameField({super.key, required this.controller, this.fieldKey, this.current, this.onStatus});

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<UsernameField> {
  Timer? _debounce;
  UsernameStatus _status = UsernameStatus.empty;
  String? _message;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    if (widget.controller.text.isNotEmpty) _onChanged();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _set(UsernameStatus status, [String? message]) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _message = message;
    });
    widget.onStatus?.call(status);
  }

  void _onChanged() {
    _debounce?.cancel();
    final name = widget.controller.text.trim();
    final generation = ++_generation;
    if (name.isEmpty) return _set(UsernameStatus.empty);
    if (name == widget.current) return _set(UsernameStatus.available, "That's your username now");
    _set(UsernameStatus.checking);
    // Wait for a pause in typing so it isn't checked on every letter.
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final check = await SonderApi.instance.checkUsername(name);
        if (generation != _generation) return; // they kept typing
        _set(
          check.available ? UsernameStatus.available : UsernameStatus.unavailable,
          check.available ? '@${check.username} is free' : check.reason,
        );
      } catch (_) {
        if (generation == _generation) _set(UsernameStatus.error, "Couldn't check it right now");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (_status) {
      UsernameStatus.available => (Icons.check_circle_rounded, const Color(0xFF2E9D63)),
      UsernameStatus.unavailable => (Icons.cancel_rounded, AppTheme.kDanger),
      UsernameStatus.error => (Icons.wifi_off_rounded, AppTheme.kTextSecondary),
      _ => (null, AppTheme.kTextSecondary),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.kBorder, width: 2),
            boxShadow: [BoxShadow(color: AppTheme.kLavender, offset: const Offset(4, 4))],
          ),
          child: TextField(
            key: widget.fieldKey,
            controller: widget.controller,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 20,
            autofillHints: const [AutofillHints.newUsername],
            inputFormatters: [
              // Typing capitals is fine; they're stored in lowercase.
              TextInputFormatter.withFunction(
                (old, next) => next.copyWith(text: next.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '')),
              ),
            ],
            cursorColor: AppTheme.kTextPrimary,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'yourname',
              hintStyle: TextStyle(color: AppTheme.kTextSecondary.withValues(alpha: 0.5)),
              prefixText: '@',
              prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.kTextSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              suffixIcon: _status == UsernameStatus.checking
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    )
                  : icon == null
                  ? null
                  : Icon(icon, color: color),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            _message ?? 'Letters, numbers, dots and underscores. Friends can find you by it.',
            key: const Key('username-status'),
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}
