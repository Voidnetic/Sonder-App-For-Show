const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "02 : 14 : 37"
String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  return '${_two(d.inHours)} : ${_two(d.inMinutes % 60)} : ${_two(d.inSeconds % 60)}';
}

/// "9 AM", "10:42 PM"
String formatClock(DateTime time, {bool alwaysShowMinutes = false}) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 12 ? 'AM' : 'PM';
  if (local.minute == 0 && !alwaysShowMinutes) return '$hour $period';
  return '$hour:${_two(local.minute)} $period';
}

/// "June 12"
String formatMonthDay(DateTime time) {
  final local = time.toLocal();
  return '${_months[local.month - 1]} ${local.day}';
}

/// What follows "Unlocks in" on a moment: a live countdown inside the last 24 hours,
/// otherwise a readable time such as "tomorrow at 9 AM" or "October 12 at 9 AM".
String unlockLabel(DateTime unlockAt, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final target = unlockAt.toLocal();
  final remaining = target.difference(current);
  if (remaining < const Duration(hours: 24)) return formatCountdown(remaining);

  final today = DateTime(current.year, current.month, current.day);
  final targetDay = DateTime(target.year, target.month, target.day);
  final days = targetDay.difference(today).inDays;
  if (days == 1) return 'tomorrow at ${formatClock(target)}';
  return '${formatMonthDay(target)} at ${formatClock(target)}';
}

/// Human description of a chosen reveal time on the Create Moment screen.
String revealDescription(DateTime unlockAt, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final target = unlockAt.toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final days = DateTime(target.year, target.month, target.day).difference(today).inDays;
  final clock = formatClock(target);
  if (days == 0) return 'Reveals today at $clock';
  if (days == 1) return 'Reveals tomorrow at $clock';
  return 'Reveals ${formatMonthDay(target)} at $clock';
}

/// "just now", "10 min ago", "3 h ago", "yesterday", "4 days ago", then the date.
String timeAgo(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).toUtc().difference(time.toUtc());
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 2) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return formatMonthDay(time);
}

/// "Ahmed added a memory 10 min ago" for a moment's newest photo (the photo itself stays hidden).
String? lastCapturedLabel(String? name, DateTime? at, {String? myId, String? authorId, DateTime? now}) {
  if (name == null || at == null) return null;
  final who = authorId != null && authorId == myId ? 'You' : name;
  return '$who added a memory ${timeAgo(at, now: now)}';
}

/// "1 memory", "3 memories", "1 friend", "4 friends".
String countLabel(int n, String one, String many) => '$n ${n == 1 ? one : many}';
