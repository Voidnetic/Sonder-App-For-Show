import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A password box in Sonder's style, with an eye button to show or hide what's typed.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;

  /// Key for the text field itself (tests type into it).
  final Key? fieldKey;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<String> autofillHints;

  const PasswordField({
    super.key,
    required this.controller,
    this.hint = '••••••••',
    this.fieldKey,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.kBorder, width: 2),
        boxShadow: [BoxShadow(color: AppTheme.kLavender, offset: const Offset(4, 4))],
      ),
      child: TextField(
        key: widget.fieldKey,
        controller: widget.controller,
        obscureText: !_visible,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: widget.autofillHints,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        cursorColor: AppTheme.kTextPrimary,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: AppTheme.kTextSecondary.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 4, 16),
          suffixIcon: IconButton(
            key: widget.fieldKey == null ? null : Key('${(widget.fieldKey as ValueKey).value}-eye'),
            tooltip: _visible ? 'Hide password' : 'Show password',
            icon: Icon(
              _visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: AppTheme.kTextSecondary,
            ),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ),
      ),
    );
  }
}
