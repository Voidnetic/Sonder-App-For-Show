import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonder_app/data/api_client.dart';
import 'package:sonder_app/data/models.dart';
import 'package:sonder_app/main.dart';

// ----------------------------------------------------------------- fixtures

Map<String, dynamic> userJson(String id, String name) => {
      'id': id,
      'name': name,
      'email': '${name.toLowerCase()}@sonder.app',
      'avatar_color': '#FFFACD',
    };

final hassan = userJson('u1', 'Hassan');
final ali = userJson('u2', 'Ali');
final ahmed = userJson('u3', 'Ahmed');
final hajra = userJson('u4', 'Hajra');

Map<String, dynamic> momentJson({
  required String id,
  required String title,
  required DateTime unlockAt,
  DateTime? revealedAt,
  int memoryCount = 0,
}) =>
    {
      'id': id,
      'title': title,
      'creator': hassan,
      'participants': [hassan, ali, ahmed, hajra],
      'accent_color': '#E6E6FA',
      'unlock_at': unlockAt.toUtc().toIso8601String(),
      'revealed_at': revealedAt?.toUtc().toIso8601String(),
      'is_locked': unlockAt.isAfter(DateTime.now()),
      'memory_count': memoryCount,
      'friend_count': 4,
    };

Map<String, dynamic> messageJson(String id, Map<String, dynamic>? author, String text, {String type = 'user'}) => {
      'id': id,
      'moment_id': 'm1',
      'author': author,
      'type': type,
      'text': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

// ----------------------------------------------------------------- fake backend

class FakeBackend {
  final List<http.Request> requests = [];
  final Map<String, Object? Function(http.Request)> routes = {};
  bool offline = false;

  FakeBackend() {
    final now = DateTime.now();
    routes.addAll({
      'POST /api/auth/login': (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body['password'] != 'sonderpass123') {
          return http.Response(jsonEncode({'detail': 'Invalid email or password'}), 401);
        }
        return {'user': hassan, 'access_token': 'tok', 'token_type': 'bearer'};
      },
      'GET /api/moments/active': (_) => [
            momentJson(id: 'm1', title: 'Birthday Night', unlockAt: now.add(const Duration(hours: 2)), memoryCount: 2),
            // More than 24h away (except in the last minute of the day), so it shows "tomorrow at".
            momentJson(id: 'm2', title: 'Murree Trip', unlockAt: DateTime(now.year, now.month, now.day + 1, 23, 59)),
          ],
      'GET /api/moments/archive': (_) => [
            momentJson(
              id: 'farewell',
              title: 'University Farewell',
              unlockAt: now.subtract(const Duration(days: 7)),
              revealedAt: now.subtract(const Duration(days: 7)),
              memoryCount: 12,
            ),
            momentJson(id: 'party', title: 'Last Night Party', unlockAt: now.subtract(const Duration(hours: 1))),
          ],
      'GET /api/friends': (_) => [ali, ahmed, hajra],
      'GET /api/users/me': (_) => {...hassan, 'memory_count': 91, 'active_moment_count': 2, 'friend_count': 3},
      'GET /api/moments/m1': (_) =>
          momentJson(id: 'm1', title: 'Birthday Night', unlockAt: now.add(const Duration(hours: 2)), memoryCount: 2),
      'GET /api/moments/m1/memories': (_) => [
            {'id': 'mem1', 'moment_id': 'm1', 'author': ali, 'locked': true, 'captured_at': '2026-10-01T10:00:00Z'},
            {'id': 'mem2', 'moment_id': 'm1', 'author': hassan, 'locked': true, 'captured_at': '2026-10-01T10:05:00Z'},
          ],
      'GET /api/moments/m1/messages': (_) => [
            messageJson('msg1', null, 'Ali joined the Moment', type: 'system'),
            messageJson('msg2', ali, 'Where are you guys?'),
          ],
      'POST /api/moments/m1/messages': (req) =>
          messageJson('sent-1', hassan, (jsonDecode(req.body) as Map<String, dynamic>)['text'] as String),
      'POST /api/moments': (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return momentJson(id: 'm9', title: body['title'] as String, unlockAt: DateTime.parse(body['unlock_at'] as String));
      },
      'GET /api/moments/m9/memories': (_) => [],
      'GET /api/moments/m9/messages': (_) => [],
      'POST /api/moments/party/reveal': (_) => momentJson(
            id: 'party',
            title: 'Last Night Party',
            unlockAt: now.subtract(const Duration(hours: 1)),
            revealedAt: DateTime.now(),
            memoryCount: 1,
          ),
      'GET /api/moments/party/memories': (_) => [
            {
              'id': 'mem9',
              'moment_id': 'party',
              'author': ali,
              'image_url': '/uploads/a.jpg',
              'caption': null,
              'captured_at': '2026-10-01T10:00:00Z',
            },
          ],
    });
  }

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    if (offline) throw http.ClientException('Connection refused');
    final key = '${request.method} ${request.url.path}';
    final handler = routes[key];
    if (handler == null) return http.Response(jsonEncode({'detail': 'No fake route for $key'}), 404);
    final result = handler(request);
    if (result is http.Response) return result;
    return http.Response.bytes(utf8.encode(jsonEncode(result)), 200, headers: {'content-type': 'application/json'});
  });

  Map<String, dynamic> lastBody(String method, String path) =>
      jsonDecode(requests.lastWhere((r) => r.method == method && r.url.path == path).body) as Map<String, dynamic>;

  bool called(String method, String path) => requests.any((r) => r.method == method && r.url.path == path);
}

/// Replaces the WebSocket with a stream the test controls.
class TestApi extends SonderApi {
  TestApi(http.Client client) : super(client: client);

  final live = StreamController<ChatMessage>.broadcast();

  @override
  Stream<ChatMessage> hangoutStream(String momentId) => live.stream;
}

Future<TestApi> setUpApi(FakeBackend backend, {bool signedIn = true}) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'http://test.local',
    if (signedIn) 'access_token': 'tok',
    if (signedIn) 'user': jsonEncode(hassan),
  });
  final api = TestApi(backend.client);
  SonderApi.instance = api;
  await api.restoreSession();
  return api;
}

/// A typical Android phone screen (411 x 914), so layout overflows show up as test failures.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

/// Lets network futures resolve and page transitions finish. (pumpAndSettle never settles here
/// because countdowns tick every second.)
Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> startApp(WidgetTester tester) async {
  usePhoneScreen(tester);
  await tester.pumpWidget(const SonderApp());
  await settle(tester);
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder, [int frames = 8]) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester, frames);
}

// ----------------------------------------------------------------- tests

void main() {
  testWidgets('signed out: shows login, logs in, and lands on home with real moments', (tester) async {
    final backend = FakeBackend();
    await setUpApi(backend, signedIn: false);
    await startApp(tester);

    expect(find.text('Welcome back 👋'), findsOneWidget);
    expect(find.text('Server: http://test.local'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('email-field')), 'hassan@sonder.app');
    await tester.enterText(find.byKey(const Key('password-field')), 'sonderpass123');
    await tapAndSettle(tester, find.text('LOG IN'));

    expect(backend.lastBody('POST', '/api/auth/login'), {'email': 'hassan@sonder.app', 'password': 'sonderpass123'});
    expect(find.text('Hey, Hassan 👋'), findsOneWidget);
    expect(find.text('BIRTHDAY NIGHT'), findsOneWidget);
    expect(find.text('2 memories • 4 friends'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d\d : \d\d : \d\d$')), findsOneWidget);
    expect(find.text('MURREE TRIP'), findsOneWidget);
    expect(find.text('tomorrow at 11:59 PM'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), 'tok');
  });

  testWidgets('wrong password shows the server error on the login screen', (tester) async {
    final backend = FakeBackend();
    await setUpApi(backend, signedIn: false);
    await startApp(tester);

    await tester.enterText(find.byKey(const Key('email-field')), 'hassan@sonder.app');
    await tester.enterText(find.byKey(const Key('password-field')), 'nope');
    await tapAndSettle(tester, find.text('LOG IN'));

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.text('Welcome back 👋'), findsOneWidget);
  });

  testWidgets('create moment sends title, invited friends and a future reveal time', (tester) async {
    final backend = FakeBackend();
    await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.text('CREATE MOMENT'));
    expect(find.text('Create a moment'), findsOneWidget);
    expect(find.text('Ahmed'), findsOneWidget); // friends come from the API

    await tester.enterText(find.byKey(const Key('moment-title-field')), 'Eid Dinner');
    await tapAndSettle(tester, find.text('Ali'), 2);
    await tapAndSettle(tester, find.text('Tomorrow'), 2);
    expect(find.text('🔒 Reveals tomorrow at 9 AM'), findsOneWidget);

    await tapAndSettle(tester, find.text('CREATE MOMENT'), 12);

    final body = backend.lastBody('POST', '/api/moments');
    expect(body['title'], 'Eid Dinner');
    expect(body['participant_ids'], ['u2']);
    final unlockAt = DateTime.parse(body['unlock_at'] as String).toLocal();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect([unlockAt.year, unlockAt.month, unlockAt.day, unlockAt.hour], [tomorrow.year, tomorrow.month, tomorrow.day, 9]);
    expect(body['accent_color'], matches(RegExp(r'^#[0-9A-F]{6}$')));

    // Opens the new moment straight away.
    expect(find.text('EID DINNER'), findsOneWidget);
    expect(find.text('No memories yet'), findsOneWidget);
  });

  testWidgets('active moment: hidden memories, chat history, sending, and live messages', (tester) async {
    final backend = FakeBackend();
    final api = await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.text('BIRTHDAY NIGHT'));
    expect(find.text('LOCKED STATE'), findsOneWidget);
    expect(find.text('🔒 2 memories are currently locked.'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Hassan (you)'), findsOneWidget);
    expect(find.text('Memory hidden securely'), findsNWidgets(2));
    expect(find.text('CAPTURE MEMORY'), findsOneWidget);

    await tapAndSettle(tester, find.text('💬 Hangout'));
    expect(find.text('Ali joined the Moment'), findsOneWidget);
    expect(find.text('Where are you guys?'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chat-field')), 'Cominggg');
    await tapAndSettle(tester, find.text('Send'));
    expect(backend.lastBody('POST', '/api/moments/m1/messages'), {'text': 'Cominggg'});
    expect(find.text('Cominggg'), findsOneWidget);

    // A friend's message arrives over the live connection.
    api.live.add(ChatMessage.fromJson(messageJson('msg3', ahmed, 'Someone save me food')));
    await settle(tester, 3);
    expect(find.text('Someone save me food'), findsOneWidget);

    // Our own message echoed back by the server is not shown twice.
    api.live.add(ChatMessage.fromJson(messageJson('sent-1', hassan, 'Cominggg')));
    await settle(tester, 3);
    expect(find.text('Cominggg'), findsOneWidget);
  });

  testWidgets('archive: reveal an unlocked moment, then explore its photos', (tester) async {
    final backend = FakeBackend();
    await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.text('Moments'));
    expect(find.text('Past Vault ✨'), findsOneWidget);
    expect(find.text('University Farewell'), findsOneWidget);
    expect(find.text('12 memories captured'), findsOneWidget);
    expect(find.textContaining('Unlocked '), findsOneWidget);
    expect(find.text('Ready to reveal ✨'), findsOneWidget);

    await tapAndSettle(tester, find.text('Last Night Party'));
    expect(find.text('THE MOMENT IS READY'), findsOneWidget);

    await tapAndSettle(tester, find.text('REVEAL'), 15);
    expect(backend.called('POST', '/api/moments/party/reveal'), isTrue);
    expect(find.text('THE MOMENT IS UNLOCKED!'), findsOneWidget);

    await tapAndSettle(tester, find.text('EXPLORE MEMORIES ✨'));
    expect(find.text('LAST NIGHT PARTY'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget); // photo card caption
  });

  testWidgets('profile shows real stats and friends; log out returns to login', (tester) async {
    final backend = FakeBackend();
    await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.text('Profile'));
    expect(find.text('hassan@sonder.app'), findsOneWidget);
    expect(find.text('91'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    for (final name in ['Ali', 'Ahmed', 'Hajra']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('test.local'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('LOG OUT'), 300, scrollable: find.byType(Scrollable).first);
    await tapAndSettle(tester, find.text('LOG OUT'));
    expect(find.text('Welcome back 👋'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
  });

  testWidgets('an expired session sends the user back to login', (tester) async {
    final backend = FakeBackend();
    backend.routes['GET /api/moments/active'] =
        (_) => http.Response(jsonEncode({'detail': 'Invalid or expired token'}), 401);
    await setUpApi(backend);
    await startApp(tester);

    expect(find.text('Welcome back 👋'), findsOneWidget);
  });

  testWidgets('an unreachable server shows a clear message with a retry button', (tester) async {
    final backend = FakeBackend()..offline = true;
    await setUpApi(backend);
    await startApp(tester);

    expect(find.text("Can't reach the server at http://test.local. Is the backend running?"), findsOneWidget);

    backend.offline = false;
    await tapAndSettle(tester, find.text('RETRY'));
    expect(find.text('BIRTHDAY NIGHT'), findsOneWidget);
  });
}
