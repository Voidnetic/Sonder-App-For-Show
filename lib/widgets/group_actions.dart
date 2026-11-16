import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'safety_sheets.dart';

/// A yes/no dialog in Sonder's style. Returns true when they confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.kBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: AppTheme.kBorder, width: 2),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      content: Text(message),
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
            confirmLabel,
            style: TextStyle(fontWeight: FontWeight.w900, color: danger ? AppTheme.kDanger : AppTheme.kTextPrimary),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The "⋯" menu on a Past Vault capsule: leave it (anyone), or delete it for everyone (whoever made it).
/// Returns true when the capsule is gone from the user's vault, so the list can refresh.
Future<bool> showVaultOptions(BuildContext context, Moment moment) async {
  final api = SonderApi.instance;
  final isCreator = moment.createdBy(api.currentUser.value?.id);
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTheme.kBackground,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: AppTheme.kBorder, width: 2),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(moment.title, style: AppTheme.display(24)),
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('vault-leave'),
              leading: Icon(Icons.logout_rounded, color: AppTheme.kTextPrimary),
              title: const Text('Leave and remove from my vault', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Your photos stay for the others.', style: TextStyle(color: AppTheme.kTextSecondary)),
              onTap: () => Navigator.pop(context, 'leave'),
            ),
            if (isCreator)
              ListTile(
                key: const Key('vault-delete'),
                leading: Icon(Icons.delete_forever_rounded, color: AppTheme.kDanger),
                title: Text(
                  'Delete for everyone',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.kDanger),
                ),
                subtitle: Text(
                  'Removes every photo and the chat, for all friends in it.',
                  style: TextStyle(color: AppTheme.kTextSecondary),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;

  final leaving = choice == 'leave';
  final confirmed = await confirmAction(
    context,
    title: leaving ? 'Leave ${moment.title}?' : 'Delete ${moment.title} for everyone?',
    message: leaving
        ? "It leaves your Past Vault and you won't see its photos or chat any more. Your own photos stay "
              "for the friends still in it. If you're the last one, it's deleted."
        : 'Every photo and message in it is deleted for all ${moment.friendCount} friends. This can’t be undone.',
    confirmLabel: leaving ? 'Leave' : 'Delete',
  );
  if (!confirmed || !context.mounted) return false;
  try {
    if (leaving) {
      await api.leaveMoment(moment.id);
    } else {
      await api.deleteMoment(moment.id);
    }
    if (context.mounted) showSnack(context, leaving ? 'You left ${moment.title}.' : '${moment.title} was deleted.');
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, e.toString());
    return false;
  }
}
