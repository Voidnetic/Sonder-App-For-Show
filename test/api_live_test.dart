// Runs the real API client against a running backend that has the demo data loaded.
// Skipped unless SONDER_API_URL is set, e.g. (macOS/Linux):
//   SONDER_API_URL=http://localhost:8000 flutter test test/api_live_test.dart
// Windows PowerShell:
//   $env:SONDER_API_URL="http://localhost:8000"; flutter test test/api_live_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonder_app/data/api_client.dart';

final serverUrl = Platform.environment['SONDER_API_URL'];

// Smallest valid JPEG header bytes; the backend only checks type and size.
final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]);

Future<SonderApi> loginAs(String email) async {
  final api = SonderApi(client: http.Client());
  await api.setServerUrl(serverUrl!);
  await api.login(email, 'sonderpass123');
  return api;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('demo data is visible through the app client', () async {
    final api = await loginAs('hassan@sonder.app');
    expect(api.currentUser.value!.name, 'Hassan');

    final profile = await api.getProfile();
    expect(profile.friendCount, 4);

    final active = await api.getActiveMoments();
    expect(active.map((m) => m.title), containsAll(['Birthday Night', 'Murree Trip']));
    expect(active.every((m) => !m.isUnlocked), isTrue);

    final archived = await api.getArchivedMoments();
    expect(archived.map((m) => m.title), contains('University Farewell'));

    final friends = await api.getFriends();
    expect(friends.map((f) => f.name), containsAll(['Ali', 'Ahmed', 'Hajra', 'Manaal']));

    final birthday = active.firstWhere((m) => m.title == 'Birthday Night');
    final messages = await api.getMessages(birthday.id);
    expect(messages.first.isSystem, isTrue);
    expect(messages.map((m) => m.text), contains("We're outside 😂"));
  }, skip: serverUrl == null ? 'Set SONDER_API_URL to run against a live backend' : false);

  test('create, capture (hidden), live chat between two users', () async {
    final hassan = await loginAs('hassan@sonder.app');
    final ali = await loginAs('ali@sonder.app');
    final aliId = ali.currentUser.value!.id;

    final moment = await hassan.createMoment(
      title: 'Live Test ${DateTime.now().millisecondsSinceEpoch}',
      participantIds: [aliId],
      unlockAt: DateTime.now().add(const Duration(hours: 1)),
      accentColor: '#E0F8E6',
    );
    expect(moment.isUnlocked, isFalse);
    expect(moment.participants.map((p) => p.id), contains(aliId));

    final memory = await hassan.uploadMemory(moment.id, jpegBytes, 'photo.jpg', caption: 'secret');
    expect(memory.imageUrl, startsWith('/uploads/'));

    final seenByAli = await ali.getMemories(moment.id);
    expect(seenByAli.single.locked, isTrue);
    expect(seenByAli.single.imageUrl, isNull);
    expect(seenByAli.single.author.name, 'Hassan');

    final received = Completer<String>();
    final sub = ali.hangoutStream(moment.id).listen((m) {
      if (!received.isCompleted) received.complete(m.text);
    });
    await Future<void>.delayed(const Duration(milliseconds: 500)); // let the socket connect
    final sent = await hassan.sendMessage(moment.id, 'hello from flutter 👋');
    expect(sent.author!.name, 'Hassan');
    expect(await received.future.timeout(const Duration(seconds: 10)), 'hello from flutter 👋');
    await sub.cancel();
  }, skip: serverUrl == null ? 'Set SONDER_API_URL to run against a live backend' : false);

  test('a moment unlocks, reveals, and its photo can be downloaded', () async {
    final api = await loginAs('hassan@sonder.app');
    final moment = await api.createMoment(
      title: 'Quick Unlock',
      participantIds: const [],
      unlockAt: DateTime.now().add(const Duration(seconds: 2)),
      accentColor: '#FFFACD',
    );
    await api.uploadMemory(moment.id, jpegBytes, 'quick.jpg');
    await Future<void>.delayed(const Duration(seconds: 3));

    final memories = await api.getMemories(moment.id);
    expect(memories.single.locked, isFalse);
    final photo = await http.get(Uri.parse(api.imageUrl(memories.single.imageUrl!)));
    expect(photo.statusCode, 200);
    expect(photo.bodyBytes, jpegBytes);

    final revealed = await api.revealMoment(moment.id);
    expect(revealed.revealedAt, isNotNull);
    expect((await api.getArchivedMoments()).map((m) => m.id), contains(moment.id));
  }, skip: serverUrl == null ? 'Set SONDER_API_URL to run against a live backend' : false);

  test('errors are readable', () async {
    final api = SonderApi(client: http.Client());
    await api.setServerUrl(serverUrl!);
    await expectLater(
      api.login('hassan@sonder.app', 'wrong-password'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid email or password')),
    );
    expect(api.currentUser.value, isNull);

    await api.setServerUrl('http://127.0.0.1:9');
    await expectLater(
      api.login('hassan@sonder.app', 'sonderpass123'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains("Can't reach the server"))),
    );
  }, skip: serverUrl == null ? 'Set SONDER_API_URL to run against a live backend' : false);
}
