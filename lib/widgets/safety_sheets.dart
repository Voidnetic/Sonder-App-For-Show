import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
}

/// Asks for a reason and sends a report. Returns true if the person who posted it was also blocked.
Future<bool> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required String targetId,
  required AppUser author,
}) async {
  final blocked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.kBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: AppTheme.kBorder, width: 2),
    ),
    builder: (context) => _ReportSheet(target: target, targetId: targetId, author: author),
  );
  return blocked ?? false;
}

class _ReportSheet extends StatefulWidget {
  final ReportTarget target;
  final String targetId;
  final AppUser author;

  const _ReportSheet({required this.target, required this.targetId, required this.author});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  String? _reason;
  bool _alsoBlock = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String get _what => switch (widget.target) {
    ReportTarget.user => widget.author.name,
    ReportTarget.memory => 'this photo',
    ReportTarget.message => 'this message',
  };

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await SonderApi.instance.report(
        target: widget.target,
        targetId: widget.targetId,
        reason: _reason!,
        details: _details.text,
        alsoBlock: _alsoBlock,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, _alsoBlock);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _alsoBlock
                ? "Thanks. We'll review it within 24 hours, and ${widget.author.name} is blocked."
                : "Thanks for telling us. We'll review it within 24 hours.",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Report $_what', style: AppTheme.display(26)),
              const SizedBox(height: 6),
              Text(
                "Your report is private. The person won't know it was you.",
                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.kTextSecondary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in reportReasons.entries)
                    ChoiceChip(
                      label: Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _reason == entry.key ? AppTheme.kInk : AppTheme.kTextPrimary,
                        ),
                      ),
                      selected: _reason == entry.key,
                      onSelected: _sending ? null : (_) => setState(() => _reason = entry.key),
                      selectedColor: AppTheme.kSunshine,
                      backgroundColor: AppTheme.kSurface,
                      showCheckmark: false,
                      side: BorderSide(color: AppTheme.kBorder, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _details,
                maxLength: 1000,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Anything else we should know? (optional)',
                  filled: true,
                  fillColor: AppTheme.kSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppTheme.kBorder, width: 2),
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _alsoBlock,
                onChanged: _sending ? null : (v) => setState(() => _alsoBlock = v ?? false),
                activeColor: AppTheme.kTextPrimary,
                title: Text('Also block ${widget.author.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text("You won't see each other's photos, messages or profile."),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppTheme.kDanger, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _reason == null || _sending ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.kTextPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _sending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: AppTheme.kOnPrimary, strokeWidth: 3),
                        )
                      : const Text('SEND REPORT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms and blocks [user]. Returns true once they are blocked.
Future<bool> confirmBlock(BuildContext context, AppUser user) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.kBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: AppTheme.kBorder, width: 2),
      ),
      title: Text('Block ${user.name}?', style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(
        "${user.name} won't be able to find you, add you, or see your photos and messages, and you won't see "
        "theirs. You'll stop being friends. They aren't told. You can unblock them in Profile.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kTextPrimary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Block',
            style: TextStyle(color: AppTheme.kDanger, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await SonderApi.instance.blockUser(user.id);
    if (context.mounted) showSnack(context, '${user.name} is blocked.');
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, e.toString());
    return false;
  }
}

/// The "⋯" menu for something another person posted: report it, or block them.
/// Returns true if the person ended up blocked (so the caller can hide their content).
Future<bool> showContentActions(
  BuildContext context, {
  required ReportTarget target,
  required String targetId,
  required AppUser author,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTheme.kBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: AppTheme.kBorder, width: 2),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(
              target == ReportTarget.memory ? 'Report photo' : 'Report message',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onTap: () => Navigator.pop(context, 'report'),
          ),
          ListTile(
            leading: Icon(Icons.block_rounded, color: AppTheme.kDanger),
            title: Text(
              'Block ${author.name}',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kDanger),
            ),
            onTap: () => Navigator.pop(context, 'block'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return false;
  if (choice == 'report') return showReportSheet(context, target: target, targetId: targetId, author: author);
  if (choice == 'block') return confirmBlock(context, author);
  return false;
}
