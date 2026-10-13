import 'package:flutter_test/flutter_test.dart';
import 'package:sonder_app/screens/create_moment_screen.dart';
import 'package:sonder_app/utils/time_format.dart';

void main() {
  final now = DateTime(2026, 10, 8, 20, 30); // local time

  test('countdown is zero-padded hours : minutes : seconds', () {
    expect(formatCountdown(const Duration(hours: 2, minutes: 14, seconds: 37)), '02 : 14 : 37');
    expect(formatCountdown(const Duration(seconds: -5)), '00 : 00 : 00');
  });

  test('unlock label: countdown inside 24h, readable time after that', () {
    expect(unlockLabel(now.add(const Duration(hours: 3, minutes: 5)), now: now), '03 : 05 : 00');
    expect(unlockLabel(DateTime(2026, 10, 9, 21), now: now), 'tomorrow at 9 PM');
    expect(unlockLabel(DateTime(2026, 10, 12, 9, 30), now: now), 'October 12 at 9:30 AM');
  });

  test('clock and date formatting', () {
    expect(formatClock(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
    expect(formatClock(DateTime(2026, 1, 1, 12)), '12 PM');
    expect(formatClock(DateTime(2026, 1, 1, 22, 42), alwaysShowMinutes: true), '10:42 PM');
    expect(formatMonthDay(DateTime(2026, 6, 12)), 'June 12');
  });

  test('reveal presets', () {
    expect(tonightRevealTime(now), DateTime(2026, 10, 8, 23));
    expect(tonightRevealTime(DateTime(2026, 10, 8, 22, 30)), DateTime(2026, 10, 8, 23, 30));
    expect(tomorrowRevealTime(now), DateTime(2026, 10, 9, 9));
    expect(tomorrowRevealTime(DateTime(2026, 12, 31, 10)), DateTime(2027, 1, 1, 9));
    expect(revealDescription(DateTime(2026, 10, 9, 9), now: now), 'Reveals tomorrow at 9 AM');
  });
}
