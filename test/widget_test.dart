import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonder_app/data/api_client.dart';
import 'package:sonder_app/data/google_auth.dart';
import 'package:sonder_app/data/models.dart';
import 'package:sonder_app/data/photo_store.dart';
import 'package:sonder_app/data/upload_queue.dart';
import 'package:sonder_app/main.dart';
import 'package:sonder_app/screens/intro_splash.dart';
import 'package:sonder_app/screens/story_viewer_screen.dart';
import 'package:sonder_app/theme/app_theme.dart';
import 'package:sonder_app/widgets/aurora_sky.dart';

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
  DateTime? openedAt,
  int memoryCount = 0,
  String myStatus = 'joined',
  Map<String, dynamic>? creator,
  Map<String, dynamic>? invitedBy,
}) => {
  'id': id,
  'title': title,
  'creator': creator ?? hassan,
  'participants': [hassan, ali, ahmed, hajra],
  'accent_color': '#E6E6FA',
  'unlock_at': unlockAt.toUtc().toIso8601String(),
  'revealed_at': revealedAt?.toUtc().toIso8601String(),
  'is_locked': unlockAt.isAfter(DateTime.now()),
  'memory_count': memoryCount,
  'friend_count': 4,
  'opened_at': openedAt?.toUtc().toIso8601String(),
  'my_status': myStatus,
  'invited_by': invitedBy,
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
          openedAt: now.subtract(const Duration(days: 7)),
          memoryCount: 12,
        ),
      ],
      'GET /api/moments/invitations': (_) => [],
      'GET /api/auth/username-available': (req) {
        final name = req.url.queryParameters['username']!.toLowerCase();
        final taken = ['hassan', 'ali'].contains(name);
        return {'username': name, 'available': !taken, 'reason': taken ? 'That username is taken' : null};
      },
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
        return momentJson(
          id: 'm9',
          title: body['title'] as String,
          unlockAt: DateTime.parse(body['unlock_at'] as String),
        );
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

  final live = StreamController<HangoutEvent>.broadcast();

  /// Every typing signal the app sent, in order.
  final typingSent = <bool>[];

  @override
  Stream<HangoutEvent> hangoutStream(String momentId) => live.stream;

  @override
  void sendTyping(String momentId, bool typing) => typingSent.add(typing);
}

Future<TestApi> setUpApi(FakeBackend backend, {bool signedIn = true}) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'http://test.local',
    if (signedIn) 'access_token': 'tok',
    if (signedIn) 'user': jsonEncode(hassan),
  });
  final api = TestApi(backend.client);
  SonderApi.instance = api;
  UploadQueue.instance.stop();
  UploadQueue.instance = UploadQueue(store: MemoryPhotoStore(), retryDelays: const [Duration(milliseconds: 300)]);
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
  MainNavigation.savedTab = 0; // the open tab is remembered across rebuilds (and tests)
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
    expect(find.textContaining('Server'), findsNothing); // users can't change the server

    await tester.enterText(find.byKey(const Key('email-field')), 'hassan@sonder.app');
    await tester.enterText(find.byKey(const Key('password-field')), 'sonderpass123');
    await tapAndSettle(tester, find.text('LOG IN'));

    expect(backend.lastBody('POST', '/api/auth/login'), {'email': 'hassan@sonder.app', 'password': 'sonderpass123'});
    expect(find.text('Hey, Hassan 👋'), findsOneWidget);
    expect(find.text('BIRTHDAY NIGHT'), findsOneWidget);
    expect(find.text('2 memories • 4 friends'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d\d : \d\d : \d\d$')), findsOneWidget);
    // The stat tiles and "next reveal" banner push the second card below the fold.
    await tester.scrollUntilVisible(find.text('MURREE TRIP'), 200, scrollable: find.byType(Scrollable).first);
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
    expect(
      [unlockAt.year, unlockAt.month, unlockAt.day, unlockAt.hour],
      [tomorrow.year, tomorrow.month, tomorrow.day, 9],
    );
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
    api.live.add(HangoutMessage(ChatMessage.fromJson(messageJson('msg3', ahmed, 'Someone save me food'))));
    await settle(tester, 3);
    expect(find.text('Someone save me food'), findsOneWidget);

    // Our own message echoed back by the server is not shown twice.
    api.live.add(HangoutMessage(ChatMessage.fromJson(messageJson('sent-1', hassan, 'Cominggg'))));
    await settle(tester, 3);
    expect(find.text('Cominggg'), findsOneWidget);
  });

  testWidgets('home: an unlocked capsule stays as Ready to Open until opened, then moves to the Past Vault', (
    tester,
  ) async {
    final backend = FakeBackend();
    final now = DateTime.now();
    final party = momentJson(
      id: 'party',
      title: 'Last Night Party',
      unlockAt: now.subtract(const Duration(hours: 1)),
      memoryCount: 1,
    );
    final birthday = momentJson(
      id: 'm1',
      title: 'Birthday Night',
      unlockAt: now.add(const Duration(hours: 2)),
      memoryCount: 2,
    );
    backend.routes['GET /api/moments/active'] = (_) => [
      if (!backend.called('POST', '/api/moments/party/reveal')) party,
      birthday,
    ];
    backend.routes['GET /api/moments/archive'] = (_) => [
      if (backend.called('POST', '/api/moments/party/reveal')) {...party, 'opened_at': now.toUtc().toIso8601String()},
    ];
    await setUpApi(backend);
    await startApp(tester);

    // On Home with a big badge, and the banner says it's ready.
    expect(find.byKey(const Key('ready-badge')), findsOneWidget);
    expect(find.text('READY TO OPEN'), findsOneWidget);
    expect(find.text('TAP TO OPEN 🎁'), findsOneWidget);
    expect(find.text('LAST NIGHT PARTY'), findsOneWidget);

    // Peeking and closing without opening keeps it on Home.
    await tapAndSettle(tester, find.text('LAST NIGHT PARTY'));
    expect(find.text('THE MOMENT IS READY'), findsOneWidget);
    await tapAndSettle(tester, find.byIcon(Icons.close_rounded));
    expect(find.byKey(const Key('ready-badge')), findsOneWidget);
    expect(backend.called('POST', '/api/moments/party/reveal'), isFalse);

    // Opening it for real.
    await tapAndSettle(tester, find.text('LAST NIGHT PARTY'));
    await tapAndSettle(tester, find.text('REVEAL'), 15);
    expect(backend.called('POST', '/api/moments/party/reveal'), isTrue);
    expect(find.text('THE MOMENT IS UNLOCKED!'), findsOneWidget);
    await tapAndSettle(tester, find.text('EXPLORE MEMORIES ✨'));
    expect(find.text('LAST NIGHT PARTY'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget); // photo card caption

    // Back on Home it's gone; it's in the Past Vault now.
    Navigator.of(tester.element(find.text('LAST NIGHT PARTY'))).pop();
    await settle(tester);
    expect(find.byKey(const Key('ready-badge')), findsNothing);
    expect(find.text('LAST NIGHT PARTY'), findsNothing);
    await tapAndSettle(tester, find.text('Moments'));
    expect(find.text('Past Vault ✨'), findsOneWidget);
    expect(find.text('Last Night Party'), findsOneWidget);
  });

  testWidgets('home: an invitation waits for Accept or Decline before you join', (tester) async {
    final backend = FakeBackend();
    final now = DateTime.now();
    final invites = {
      'eid': momentJson(
        id: 'eid',
        title: 'Eid Dinner',
        unlockAt: now.add(const Duration(days: 2)),
        myStatus: 'invited',
        creator: ali,
        invitedBy: ali,
      ),
      'gym': momentJson(
        id: 'gym',
        title: 'Gym Week',
        unlockAt: now.add(const Duration(days: 5)),
        myStatus: 'invited',
        creator: ahmed,
        invitedBy: ahmed,
      ),
    };
    var accepted = false;
    backend.routes['GET /api/moments/invitations'] = (_) => invites.values.toList();
    backend.routes['POST /api/moments/eid/accept'] = (_) {
      accepted = true;
      return {...invites.remove('eid')!, 'my_status': 'joined'};
    };
    backend.routes['POST /api/moments/gym/decline'] = (_) {
      invites.remove('gym');
      return http.Response('', 204);
    };
    final active = backend.routes['GET /api/moments/active']!;
    backend.routes['GET /api/moments/active'] = (req) => [
      ...(active(req) as List),
      if (accepted) momentJson(id: 'eid', title: 'Eid Dinner', unlockAt: now.add(const Duration(days: 2))),
    ];
    await setUpApi(backend);
    await startApp(tester);

    expect(find.text("You're invited 💌"), findsOneWidget);
    expect(find.text('Ali invited you to'), findsOneWidget);
    expect(find.text('Ahmed invited you to'), findsOneWidget);
    // Not one of your moments until you accept.
    expect(find.text('EID DINNER'), findsOneWidget); // only the invitation card

    await tapAndSettle(tester, find.byKey(const Key('invite-decline-gym')));
    expect(backend.called('POST', '/api/moments/gym/decline'), isTrue);
    expect(find.text('GYM WEEK'), findsNothing);
    expect(find.text('Invitation to Gym Week declined.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('invite-accept-eid')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapAndSettle(tester, find.byKey(const Key('invite-accept-eid')));
    expect(backend.called('POST', '/api/moments/eid/accept'), isTrue);
    expect(find.text("You're invited 💌"), findsNothing);
    expect(find.text("You're in Eid Dinner 🎉"), findsOneWidget);
    await tester.scrollUntilVisible(find.text('EID DINNER'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('EID DINNER'), findsOneWidget); // now a moment on Home
    await tester.pump(const Duration(seconds: 5)); // let the snack bar finish
  });

  testWidgets('active moment: you can see and delete your own photo before the reveal', (tester) async {
    final backend = FakeBackend();
    var deleted = false;
    backend.routes['GET /api/moments/m1/memories'] = (_) => [
      {'id': 'mem1', 'moment_id': 'm1', 'author': ali, 'locked': true, 'captured_at': '2026-10-01T10:00:00Z'},
      if (!deleted)
        {
          'id': 'mem2',
          'moment_id': 'm1',
          'author': hassan,
          'locked': true,
          'mine': true,
          'image_url': '/uploads/mine.jpg',
          'captured_at': '2026-10-01T10:05:00Z',
        },
    ];
    backend.routes['DELETE /api/moments/m1/memories/mem2'] = (_) {
      deleted = true;
      return http.Response('', 204);
    };
    await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.text('BIRTHDAY NIGHT'));
    expect(find.text('Memory hidden securely'), findsOneWidget); // Ali's stays hidden
    expect(find.text('Only you can see it until the reveal'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const Key('own-memory-options-mem2')));
    expect(find.byKey(const Key('photo-swap-camera')), findsOneWidget);
    expect(find.byKey(const Key('photo-swap-gallery')), findsOneWidget);
    await tapAndSettle(tester, find.byKey(const Key('photo-delete')));
    expect(find.text('Delete this photo?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Delete'));
    expect(deleted, isTrue);
    expect(find.text('Only you can see it until the reveal'), findsNothing);
    await tester.pump(const Duration(seconds: 5)); // let the snack bar finish
  });

  testWidgets('past vault: hide a photo from your own view, then show it again', (tester) async {
    final backend = FakeBackend();
    var hidden = false;
    backend.routes['GET /api/moments/farewell/memories'] = (req) {
      expect(req.url.queryParameters['include_hidden'], 'true');
      return [
        {
          'id': 'p1',
          'moment_id': 'farewell',
          'author': ali,
          'image_url': '/uploads/a.jpg',
          'caption': null,
          'captured_at': '2026-10-01T10:00:00Z',
          'hidden': hidden,
        },
        {
          'id': 'p2',
          'moment_id': 'farewell',
          'author': ahmed,
          'image_url': '/uploads/b.jpg',
          'caption': null,
          'captured_at': '2026-10-01T10:01:00Z',
        },
      ];
    };
    backend.routes['POST /api/moments/farewell/memories/p1/hide'] = (_) {
      hidden = true;
      return http.Response('', 204);
    };
    backend.routes['DELETE /api/moments/farewell/memories/p1/hide'] = (_) {
      hidden = false;
      return http.Response('', 204);
    };
    await setUpApi(backend);
    await startApp(tester);
    await tapAndSettle(tester, find.text('Moments'));
    await tapAndSettle(tester, find.text('University Farewell'));
    expect(find.text('Ali'), findsOneWidget);
    expect(find.byKey(const Key('toggle-hidden')), findsNothing);

    await tapAndSettle(tester, find.byKey(const Key('photo-options-p1')));
    await tapAndSettle(tester, find.byKey(const Key('photo-hide')));
    expect(hidden, isTrue);
    expect(find.text('Ali'), findsNothing); // gone from your view
    expect(find.text('Ahmed'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const Key('toggle-hidden')));
    expect(find.text('Ali'), findsOneWidget); // shown dimmed
    await tapAndSettle(tester, find.byKey(const Key('photo-options-p1')));
    expect(find.text('Show it again'), findsOneWidget);
    await tapAndSettle(tester, find.byKey(const Key('photo-hide')));
    expect(hidden, isFalse);
    expect(find.byKey(const Key('toggle-hidden')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  Map<String, dynamic> photoJson(String id, Map<String, dynamic> author) => {
    'id': id,
    'moment_id': 'farewell',
    'author': author,
    'image_url': '/uploads/$id.jpg',
    'caption': null,
    'captured_at': '2026-10-01T10:00:00Z',
  };

  testWidgets('past vault: story slideshow with tap navigation, auto-advance, and replies to the chat', (tester) async {
    final backend = FakeBackend();
    backend.routes['GET /api/moments/farewell/memories'] = (_) => [photoJson('p1', ali), photoJson('p2', ahmed)];
    backend.routes['POST /api/moments/farewell/messages'] = (req) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      return {...messageJson('r1', hassan, body['text'] as String), 'memory_id': body['memory_id']};
    };
    await setUpApi(backend);
    await startApp(tester);
    await tapAndSettle(tester, find.text('Moments'));
    await tapAndSettle(tester, find.text('University Farewell'));

    await tapAndSettle(tester, find.byKey(const Key('photo-p1')));
    expect(find.byType(StoryViewerScreen), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('story-author'))).data, 'Ali');
    expect(find.text('1/2'), findsOneWidget);

    // Tap the right side for the next photo, the left side to go back.
    await tester.tapAt(const Offset(350, 450));
    await settle(tester, 3);
    expect(find.text('2/2'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('story-author'))).data, 'Ahmed');
    await tester.tapAt(const Offset(40, 450));
    await settle(tester, 3);
    expect(find.text('1/2'), findsOneWidget);

    // An emoji reaction goes to the chat, linked to this photo.
    await tapAndSettle(tester, find.byKey(const Key('react-❤️')), 3);
    expect(backend.lastBody('POST', '/api/moments/farewell/messages'), {'text': '❤️', 'memory_id': 'p1'});
    expect(find.text('Sent ❤️ to the chat'), findsOneWidget);

    // So does a typed comment.
    await tester.enterText(find.byKey(const Key('story-reply-field')), 'best night ever');
    await tapAndSettle(tester, find.byKey(const Key('story-send')), 3);
    expect(backend.lastBody('POST', '/api/moments/farewell/messages'), {'text': 'best night ever', 'memory_id': 'p1'});
    expect(find.text('Sent to the chat 💬'), findsOneWidget);

    // Plays on by itself, and closes after the last photo.
    await tester.pump(StoryViewerScreen.storyDuration);
    await settle(tester, 3);
    expect(find.text('2/2'), findsOneWidget);
    await tester.pump(StoryViewerScreen.storyDuration);
    await settle(tester, 6);
    expect(find.byType(StoryViewerScreen), findsNothing);
    expect(find.text('Ali'), findsOneWidget); // back on the grid
  });

  testWidgets('chat: a photo reply shows its thumbnail and opens the slideshow at that photo', (tester) async {
    final backend = FakeBackend();
    backend.routes['GET /api/moments/farewell/memories'] = (_) => [photoJson('p1', ali), photoJson('p2', ahmed)];
    backend.routes['GET /api/moments/farewell/messages'] = (_) => [
      {...messageJson('r1', ali, '🔥'), 'memory_id': 'p2', 'memory_image_url': '/uploads/p2.jpg'},
      messageJson('r2', ahmed, 'what a night'),
    ];
    backend.routes['GET /api/blocks'] = (_) => [];
    await setUpApi(backend);
    await startApp(tester);
    await tapAndSettle(tester, find.text('Moments'));
    await tapAndSettle(tester, find.text('University Farewell'));
    await tapAndSettle(tester, find.byKey(const Key('vault-chat')));

    expect(find.text('📸 Memories'), findsNothing); // just the chat
    expect(find.text('what a night'), findsOneWidget);
    expect(find.byKey(const Key('reply-photo-r1')), findsOneWidget);
    expect(find.text('Replied to a photo'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const Key('reply-photo-r1')));
    expect(find.byType(StoryViewerScreen), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('story-author'))).data, 'Ahmed');
    await tapAndSettle(tester, find.byKey(const Key('story-close')));
    expect(find.byType(StoryViewerScreen), findsNothing);
  });

  testWidgets('archive: the Past Vault lists opened capsules and opens their photos', (tester) async {
    final backend = FakeBackend();
    await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.text('Moments'));
    expect(find.text('Past Vault ✨'), findsOneWidget);
    expect(find.text('University Farewell'), findsOneWidget);
    expect(find.text('12 memories captured'), findsOneWidget);
    expect(find.textContaining('Unlocked '), findsOneWidget);
  });

  testWidgets('archive: leave a past group, or delete it for everyone when you made it', (tester) async {
    final backend = FakeBackend();
    final now = DateTime.now();
    final gone = <String>{};
    backend.routes['GET /api/moments/archive'] = (_) => [
      for (final m in [
        momentJson(id: 'farewell', title: 'University Farewell', unlockAt: now, openedAt: now, memoryCount: 12),
        momentJson(id: 'test', title: 'Test Group', unlockAt: now, openedAt: now, creator: ali),
      ])
        if (!gone.contains(m['id'])) m,
    ];
    backend.routes['DELETE /api/moments/farewell'] = (_) {
      gone.add('farewell');
      return http.Response('', 204);
    };
    backend.routes['POST /api/moments/test/leave'] = (_) {
      gone.add('test');
      return http.Response('', 204);
    };
    await setUpApi(backend);
    await startApp(tester);
    await tapAndSettle(tester, find.text('Moments'));

    // Someone else's group: you can only leave it.
    await tapAndSettle(tester, find.byKey(const Key('vault-options-test')));
    expect(find.byKey(const Key('vault-leave')), findsOneWidget);
    expect(find.byKey(const Key('vault-delete')), findsNothing);
    await tapAndSettle(tester, find.byKey(const Key('vault-leave')));
    expect(find.text('Leave Test Group?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Leave'));
    expect(backend.called('POST', '/api/moments/test/leave'), isTrue);
    expect(find.text('Test Group'), findsNothing);

    // Your own group: delete it for everyone (after confirming).
    await tapAndSettle(tester, find.byKey(const Key('vault-options-farewell')));
    await tapAndSettle(tester, find.byKey(const Key('vault-delete')));
    expect(find.text('Delete University Farewell for everyone?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Cancel'));
    expect(backend.called('DELETE', '/api/moments/farewell'), isFalse);
    await tapAndSettle(tester, find.byKey(const Key('vault-options-farewell')));
    await tapAndSettle(tester, find.byKey(const Key('vault-delete')));
    await tapAndSettle(tester, find.text('Delete'));
    expect(backend.called('DELETE', '/api/moments/farewell'), isTrue);
    expect(find.text('University Farewell'), findsNothing);
    expect(find.text('Nothing unlocked yet'), findsOneWidget);
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

    await tester.scrollUntilVisible(find.text('LOG OUT'), 300, scrollable: find.byType(Scrollable).first);
    await tapAndSettle(tester, find.text('LOG OUT'));
    expect(find.text('Welcome back 👋'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
  });

  testWidgets('an expired session sends the user back to login', (tester) async {
    final backend = FakeBackend();
    backend.routes['GET /api/moments/active'] = (_) =>
        http.Response(jsonEncode({'detail': 'Invalid or expired token'}), 401);
    await setUpApi(backend);
    await startApp(tester);

    expect(find.text('Welcome back 👋'), findsOneWidget);
  });

  testWidgets('an unreachable server shows a clear message with a retry button', (tester) async {
    final backend = FakeBackend()..offline = true;
    await setUpApi(backend);
    await startApp(tester);

    expect(find.text("Can't connect to Sonder. Check your internet connection and try again."), findsOneWidget);

    backend.offline = false;
    await tapAndSettle(tester, find.text('RETRY'));
    expect(find.text('BIRTHDAY NIGHT'), findsOneWidget);
  });

  testWidgets('friends: search and add someone, accept a request, cancel a sent one', (tester) async {
    final backend = FakeBackend();
    final sara = userJson('u5', 'Sara');
    final zain = userJson('u6', 'Zain');
    final bilal = userJson('u7', 'Bilal');
    backend.routes.addAll({
      'GET /api/friends/requests': (req) => req.url.queryParameters['direction'] == 'outgoing'
          ? [
              {'id': 'r2', 'requester': hassan, 'recipient': bilal, 'status': 'pending'},
            ]
          : [
              {'id': 'r1', 'requester': zain, 'recipient': hassan, 'status': 'pending'},
            ],
      'GET /api/users/search': (req) => [
        {...sara, 'relationship': 'none', 'request_id': null},
        {...ali, 'relationship': 'friend', 'request_id': null},
      ],
      'POST /api/friends/requests': (req) => {'id': 'r3', 'requester': hassan, 'recipient': sara, 'status': 'pending'},
      'PATCH /api/friends/requests/r1/accept': (_) => {
        'id': 'r1',
        'requester': zain,
        'recipient': hassan,
        'status': 'accepted',
      },
      'DELETE /api/friends/requests/r2': (_) => http.Response('', 204),
    });
    await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.byKey(const Key('home-friends')));
    expect(find.text('Your circle 🫶'), findsOneWidget);
    for (final name in ['Ali', 'Ahmed', 'Hajra']) {
      expect(find.text(name), findsOneWidget);
    }

    await tapAndSettle(tester, find.text('Add'));
    await tester.enterText(find.byKey(const Key('friend-search')), 'sa');
    await settle(tester, 6);
    expect(backend.requests.last.url.queryParameters['q'], 'sa');
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('Friends ✓'), findsOneWidget);
    await tapAndSettle(tester, find.text('ADD'));
    expect(backend.lastBody('POST', '/api/friends/requests'), {'recipient_id': 'u5'});

    await tapAndSettle(tester, find.text('Requests'));
    expect(find.text('Zain'), findsOneWidget);
    expect(find.text('Bilal'), findsOneWidget);
    await tapAndSettle(tester, find.byTooltip('Accept'));
    expect(backend.called('PATCH', '/api/friends/requests/r1/accept'), isTrue);
    await tapAndSettle(tester, find.text('Cancel'));
    expect(backend.called('DELETE', '/api/friends/requests/r2'), isTrue);
  });

  testWidgets('friends: block a friend from their menu', (tester) async {
    final backend = FakeBackend();
    backend.routes.addAll({'GET /api/friends/requests': (_) => [], 'POST /api/blocks': (_) => http.Response('', 204)});
    await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.byKey(const Key('home-friends')));
    await tapAndSettle(tester, find.byTooltip('Options').first);
    await tapAndSettle(tester, find.text('Block'));
    expect(find.text('Block Ali?'), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Block'));
    expect(backend.lastBody('POST', '/api/blocks'), {'user_id': 'u2'});
  });

  testWidgets('hangout: long-press a message to report it and block the sender', (tester) async {
    final backend = FakeBackend();
    backend.routes.addAll({
      'GET /api/blocks': (_) => [],
      'POST /api/reports': (_) => {
        'id': 'rep1',
        'target_type': 'message',
        'target_id': 'msg2',
        'reason': 'harassment',
        'status': 'open',
        'created_at': '2026-11-14T10:00:00Z',
      },
    });
    await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.text('BIRTHDAY NIGHT'));
    await tapAndSettle(tester, find.text('💬 Hangout'));
    await tester.longPress(find.text('Where are you guys?'));
    await settle(tester);
    await tapAndSettle(tester, find.text('Report message'));
    expect(find.text('Report this message'), findsOneWidget);
    await tapAndSettle(tester, find.text('Harassment or bullying'));
    await tapAndSettle(tester, find.text('Also block Ali'));
    await tapAndSettle(tester, find.text('SEND REPORT'));

    expect(backend.lastBody('POST', '/api/reports'), {
      'target_type': 'message',
      'target_id': 'msg2',
      'reason': 'harassment',
      'block': true,
    });
    // Blocking hides their messages straight away.
    expect(find.text('Where are you guys?'), findsNothing);
  });

  testWidgets('profile: deleting the account needs DELETE typed, then signs out', (tester) async {
    final backend = FakeBackend();
    backend.routes['DELETE /api/users/me'] = (_) => http.Response('', 204);
    await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.text('Profile'));
    await tester.scrollUntilVisible(find.text('Delete account'), 300, scrollable: find.byType(Scrollable).first);
    await tapAndSettle(tester, find.text('Delete account'));
    expect(find.text('Delete your account?'), findsOneWidget);

    await tapAndSettle(tester, find.text('Delete forever'));
    expect(backend.called('DELETE', '/api/users/me'), isFalse); // disabled until DELETE is typed

    await tester.enterText(find.byKey(const Key('delete-confirm-field')), 'delete');
    await settle(tester, 2);
    await tapAndSettle(tester, find.text('Delete forever'));
    expect(backend.called('DELETE', '/api/users/me'), isTrue);
    expect(find.text('Welcome back 👋'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
  });

  testWidgets('login: Continue with Google sends the ID token and opens the app', (tester) async {
    final backend = FakeBackend();
    backend.routes['POST /api/auth/google'] = (_) => {
      'user': hassan,
      'access_token': 'g-tok',
      'token_type': 'bearer',
      'created': true,
    };
    await setUpApi(backend, signedIn: false);
    GoogleAuth.idTokenOverride = () async => 'id-token-from-google';
    addTearDown(() => GoogleAuth.idTokenOverride = null);
    await startApp(tester);

    expect(find.textContaining('Privacy Policy', findRichText: true), findsOneWidget);
    await tapAndSettle(tester, find.byKey(const Key('google-button')));
    expect(backend.lastBody('POST', '/api/auth/google'), {'id_token': 'id-token-from-google'});
    expect(find.text('Hey, Hassan 👋'), findsOneWidget);
  });

  testWidgets('login: closing the Google account picker stays on the login screen', (tester) async {
    final backend = FakeBackend();
    await setUpApi(backend, signedIn: false);
    GoogleAuth.idTokenOverride = () async => null;
    addTearDown(() => GoogleAuth.idTokenOverride = null);
    await startApp(tester);

    await tapAndSettle(tester, find.byKey(const Key('google-button')));
    expect(backend.called('POST', '/api/auth/google'), isFalse);
    expect(find.text('Welcome back 👋'), findsOneWidget);
  });

  test('loginWithGoogle sends the ID token and stores the session', () async {
    final backend = FakeBackend();
    backend.routes['POST /api/auth/google'] = (_) => {
      'user': hassan,
      'access_token': 'g-tok',
      'token_type': 'bearer',
      'created': true,
    };
    final api = await setUpApi(backend, signedIn: false);

    final created = await api.loginWithGoogle('google-id-token');
    expect(created, isTrue);
    expect(backend.lastBody('POST', '/api/auth/google'), {'id_token': 'google-id-token'});
    expect(api.currentUser.value?.name, 'Hassan');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), 'g-tok');
  });

  test('logout runs the push hook first, once, even when the session already expired', () async {
    final backend = FakeBackend();
    backend.routes['POST /api/devices/unregister'] = (_) =>
        http.Response(jsonEncode({'detail': 'Invalid or expired token'}), 401);
    final api = await setUpApi(backend);
    var calls = 0;
    api.beforeLogout = () async {
      calls++;
      await api.unregisterDevice('phone-token-123');
    };

    await api.logout();

    expect(calls, 1);
    expect(backend.lastBody('POST', '/api/devices/unregister'), {'token': 'phone-token-123', 'platform': 'android'});
    expect(api.currentUser.value, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
  });

  testWidgets('profile: switching to the dark theme recolours the app, keeps Profile open, and is saved', (
    tester,
  ) async {
    final backend = FakeBackend();
    await setUpApi(backend);
    addTearDown(() async {
      await ThemeController.instance.set(ThemeChoice.light);
      AppTheme.look = AppLook.light;
    });
    await startApp(tester);
    await tapAndSettle(tester, find.text('Profile'));
    expect(AppTheme.isDark, isFalse);

    await tester.scrollUntilVisible(find.text('Theme'), 300, scrollable: find.byType(Scrollable).first);
    await tapAndSettle(tester, find.text('Theme'));
    await tapAndSettle(tester, find.byKey(const Key('theme-dark')));

    expect(AppTheme.isDark, isTrue);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ??
          Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor,
      AppTheme.kBackground,
    );
    expect(AppTheme.kBackground, const Color(0xFF0E0E11));
    expect(find.text('hassan@sonder.app'), findsOneWidget); // still on Profile after the rebuild
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  for (final (choice, look, name) in [
    (ThemeChoice.aurora, AppLook.aurora, 'Northern Lights'),
    (ThemeChoice.blossom, AppLook.blossom, 'Aurora Blossom'),
  ]) {
    testWidgets('profile: picking $name paints its sky behind the screens and is saved', (tester) async {
      final backend = FakeBackend();
      await setUpApi(backend);
      addTearDown(() async {
        await ThemeController.instance.set(ThemeChoice.light);
        AppTheme.look = AppLook.light;
      });
      await startApp(tester);
      await tapAndSettle(tester, find.text('Profile'));
      expect(find.byType(AuroraSky), findsNothing);

      await tester.scrollUntilVisible(find.text('Theme'), 300, scrollable: find.byType(Scrollable).first);
      await tapAndSettle(tester, find.text('Theme'));
      expect(find.text(name), findsOneWidget);
      await tapAndSettle(tester, find.byKey(Key('theme-${choice.name}')));

      expect(AppTheme.look, look);
      expect(AppTheme.kCanvas, Colors.transparent); // screens are see-through...
      expect(find.byType(AuroraSky), findsWidgets); // ...over the sky
      expect(find.text('hassan@sonder.app'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), choice.name);

      // Pages opened from here carry the sky too.
      await tapAndSettle(tester, find.text('Home'));
      await tapAndSettle(tester, find.text('BIRTHDAY NIGHT'));
      expect(find.byType(AuroraSky), findsWidgets);
    });
  }

  testWidgets('intro: plays over the first screen, then opens like a shutter and goes away', (tester) async {
    final backend = FakeBackend();
    await setUpApi(backend, signedIn: false);
    usePhoneScreen(tester);
    await tester.pumpWidget(const SonderApp(showIntro: true));
    await tester.pump();

    expect(find.byType(IntroSplash), findsOneWidget);
    expect(find.text('capture now · reveal later'), findsOneWidget);
    expect(find.text('Welcome back 👋'), findsOneWidget); // the real screen is already underneath

    await tester.pump(IntroSplash.duration);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(IntroSplash), findsNothing);
    expect(find.text('Welcome back 👋'), findsOneWidget);
  });

  testWidgets('hangout: "here now", typing dots both ways, and dots clear when the message arrives', (tester) async {
    final backend = FakeBackend();
    backend.routes['GET /api/blocks'] = (_) => [];
    final api = await setUpApi(backend);
    await startApp(tester);

    await tapAndSettle(tester, find.text('BIRTHDAY NIGHT'));
    await tapAndSettle(tester, find.text('💬 Hangout'));
    expect(find.text('Just you here right now'), findsOneWidget);

    api.live.add(const HangoutPresence({'u1', 'u2', 'u4'})); // Hassan (me), Ali, Hajra
    await settle(tester, 2);
    expect(find.text('Ali and Hajra are here now'), findsOneWidget);

    api.live.add(const HangoutTyping('u2', true));
    await settle(tester, 2);
    expect(find.text('Ali is typing'), findsOneWidget);

    api.live.add(HangoutMessage(ChatMessage.fromJson(messageJson('msg7', ali, 'almost there'))));
    await settle(tester, 2);
    expect(find.text('almost there'), findsOneWidget);
    expect(find.byKey(const Key('typing-indicator')), findsNothing);

    // Our own typing: "typing" once while typing, "stopped" when sent.
    await tester.enterText(find.byKey(const Key('chat-field')), 'on my');
    await tester.enterText(find.byKey(const Key('chat-field')), 'on my way');
    expect(api.typingSent, [true]);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tapAndSettle(tester, find.text('Send'));
    expect(api.typingSent, [true, false]);

    // Someone who stops typing without sending disappears after a few seconds.
    api.live.add(const HangoutTyping('u4', true));
    await settle(tester, 2);
    expect(find.text('Hajra is typing'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.byKey(const Key('typing-indicator')), findsNothing);
  });

  testWidgets('home: a locked moment shows who added the latest memory', (tester) async {
    final backend = FakeBackend();
    final now = DateTime.now();
    backend.routes['GET /api/moments/active'] = (_) => [
      {
        ...momentJson(id: 'm1', title: 'Birthday Night', unlockAt: now.add(const Duration(hours: 2)), memoryCount: 2),
        'last_captured_at': now.subtract(const Duration(minutes: 10)).toUtc().toIso8601String(),
        'last_captured_by': ahmed,
      },
    ];
    await setUpApi(backend);
    await startApp(tester);

    expect(find.text('Ahmed added a memory 10 min ago'), findsOneWidget);
  });

  testWidgets('sign-up: enter the emailed code, a wrong one shows an error, the right one opens the app', (
    tester,
  ) async {
    final backend = FakeBackend();
    var verified = false;
    backend.routes.addAll({
      'POST /api/auth/register': (_) => {
        'user': hassan,
        'access_token': 'tok',
        'token_type': 'bearer',
        'created': true,
        'verification_required': true,
      },
      'POST /api/auth/verify-email/send': (_) =>
          http.Response(jsonEncode({'detail': 'Please wait a minute before asking for another code'}), 429),
      'POST /api/auth/verify-email': (req) {
        final code = (jsonDecode(req.body) as Map<String, dynamic>)['code'];
        if (code != '424242') return http.Response(jsonEncode({'detail': "That code isn't right. 4 tries left."}), 400);
        verified = true;
        return {'user': hassan, 'access_token': 'tok', 'token_type': 'bearer', 'verification_required': false};
      },
    });
    await setUpApi(backend, signedIn: false);
    await startApp(tester);

    await tapAndSettle(tester, find.text('New here? Create an account'));
    await tester.enterText(find.byKey(const Key('name-field')), 'Hassan');
    await tester.enterText(find.byKey(const Key('username-field')), 'Hassan');
    await settle(tester, 6); // checked as you type
    expect(find.text('That username is taken'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('username-field')), 'Hassan.K');
    await settle(tester, 6);
    expect(find.text('@hassan.k is free'), findsOneWidget); // lowercased as typed
    await tester.enterText(find.byKey(const Key('email-field')), 'hassan@sonder.app');
    await tester.enterText(find.byKey(const Key('password-field')), 'sonderpass123');
    expect(find.text('What your friends call you'), findsOneWidget);
    expect(find.textContaining('e.g.'), findsNothing);

    // The two passwords must match.
    await tester.enterText(find.byKey(const Key('confirm-password-field')), 'sonderpass12');
    await tapAndSettle(tester, find.text('SIGN UP'));
    expect(find.text("The passwords don't match."), findsOneWidget);
    expect(backend.called('POST', '/api/auth/register'), isFalse);

    // The eye shows what was typed.
    TextField confirmBox() => tester.widget<TextField>(find.byKey(const Key('confirm-password-field')));
    expect(confirmBox().obscureText, isTrue);
    await tapAndSettle(tester, find.byKey(const Key('confirm-password-field-eye')), 1);
    expect(confirmBox().obscureText, isFalse);

    await tester.enterText(find.byKey(const Key('confirm-password-field')), 'sonderpass123');
    await tapAndSettle(tester, find.text('SIGN UP'));

    expect(find.text('Check your email ✉️'), findsOneWidget);
    expect(find.textContaining('hassan@sonder.app', findRichText: true), findsOneWidget);
    expect(find.text("Please wait a minute before asking for another code"), findsNothing); // quiet on open

    await tester.enterText(find.byKey(const Key('code-field')), '111111');
    await settle(tester);
    expect(find.text("That code isn't right. 4 tries left."), findsOneWidget);

    await tester.enterText(find.byKey(const Key('code-field')), '424242'); // six digits verify by themselves
    await settle(tester);
    expect(verified, isTrue);
    expect(find.text('Hey, Hassan 👋'), findsOneWidget);
  });

  testWidgets('login: forgot password emails a code, then a new password signs you in', (tester) async {
    final backend = FakeBackend();
    backend.routes.addAll({
      'POST /api/auth/forgot-password': (_) => http.Response('', 204),
      'POST /api/auth/reset-password': (_) => {
        'user': hassan,
        'access_token': 'new-tok',
        'token_type': 'bearer',
        'verification_required': false,
      },
    });
    await setUpApi(backend, signedIn: false);
    await startApp(tester);

    await tester.enterText(find.byKey(const Key('email-field')), 'hassan@sonder.app');
    await tapAndSettle(tester, find.byKey(const Key('forgot-password')));
    expect(find.text('Forgot password? 🔑'), findsOneWidget);
    await tapAndSettle(tester, find.text('SEND CODE'));
    expect(backend.lastBody('POST', '/api/auth/forgot-password'), {'email': 'hassan@sonder.app'});

    await tester.enterText(find.byKey(const Key('reset-code')), '123456');
    await tester.enterText(find.byKey(const Key('reset-password')), 'brandnew99');
    await tester.enterText(find.byKey(const Key('reset-confirm')), 'brandnew99');
    await tapAndSettle(tester, find.text('SET NEW PASSWORD'));
    expect(backend.lastBody('POST', '/api/auth/reset-password'), {
      'email': 'hassan@sonder.app',
      'code': '123456',
      'new_password': 'brandnew99',
    });
    expect(find.text('Hey, Hassan 👋'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), 'new-tok');
  });

  testWidgets('profile: change password checks the new one twice and sends the current one', (tester) async {
    final backend = FakeBackend();
    backend.routes['GET /api/users/me'] = (_) => {
      ...hassan,
      'memory_count': 1,
      'active_moment_count': 2,
      'friend_count': 3,
      'has_password': true,
    };
    backend.routes['POST /api/auth/change-password'] = (req) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (body['current_password'] != 'sonderpass123') {
        return http.Response(jsonEncode({'detail': "Your current password isn't right"}), 400);
      }
      return http.Response('', 204);
    };
    await setUpApi(backend);
    await startApp(tester);
    await tapAndSettle(tester, find.text('Profile'));
    await tester.scrollUntilVisible(find.text('Account'), 300, scrollable: find.byType(Scrollable).first);
    await tapAndSettle(tester, find.text('Account'));
    await tapAndSettle(tester, find.byKey(const Key('account-password')));
    expect(find.text('Change password 🔑'), findsOneWidget);
    expect(find.byKey(const Key('change-forgot')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('current-password')), 'wrongpass');
    await tester.enterText(find.byKey(const Key('new-password')), 'brandnew99');
    await tester.enterText(find.byKey(const Key('confirm-new-password')), 'brandnew98');
    await tapAndSettle(tester, find.text('CHANGE PASSWORD'));
    expect(find.text("The new passwords don't match."), findsOneWidget);
    expect(backend.called('POST', '/api/auth/change-password'), isFalse);

    await tester.enterText(find.byKey(const Key('confirm-new-password')), 'brandnew99');
    await tapAndSettle(tester, find.text('CHANGE PASSWORD'));
    expect(find.text("Your current password isn't right"), findsOneWidget);

    await tester.enterText(find.byKey(const Key('current-password')), 'sonderpass123');
    await tapAndSettle(tester, find.text('CHANGE PASSWORD'));
    expect(backend.lastBody('POST', '/api/auth/change-password'), {
      'current_password': 'sonderpass123',
      'new_password': 'brandnew99',
    });
    expect(find.text('Change password 🔑'), findsNothing); // closed
    expect(find.text('Password changed 🔒'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('upload queue: photos taken offline wait on the phone, then upload by themselves', (tester) async {
    final backend = FakeBackend();
    var uploads = 0;
    backend.routes['POST /api/moments/m1/memories'] = (req) {
      uploads++;
      expect(req.body, contains('taken_at')); // keeps when it was really taken
      return {
        'id': 'up$uploads',
        'moment_id': 'm1',
        'author': hassan,
        'locked': true,
        'mine': true,
        'image_url': '/uploads/x.jpg',
        'captured_at': '2026-10-01T10:00:00Z',
      };
    };
    backend.routes['POST /api/moments/gone/memories'] = (_) =>
        http.Response(jsonEncode({'detail': 'Moment not found'}), 404);
    await setUpApi(backend);
    await startApp(tester);
    final queue = UploadQueue.instance;
    final birthday = Moment.fromJson(
      momentJson(id: 'm1', title: 'Birthday Night', unlockAt: DateTime.now().add(const Duration(hours: 2))),
    );

    // No internet: the photo is saved and waits, and Home says so.
    backend.offline = true;
    await tester.runAsync(() => queue.add(birthday, Uint8List.fromList([1, 2, 3]), 'a.jpg'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester, 3);
    expect(queue.mine.single.state, UploadState.offline);
    expect(find.text('1 photo waiting for internet'), findsOneWidget);
    final saved = (await SharedPreferences.getInstance()).getString('upload_queue');
    expect(saved, contains('Birthday Night')); // survives the app closing

    // Internet is back: it goes up by itself on the next retry.
    backend.offline = false;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await settle(tester, 3);
    expect(uploads, 1);
    expect(queue.mine, isEmpty);
    expect(find.byKey(const Key('upload-banner')), findsNothing);

    // A moment that no longer exists: shown as failed until dismissed, not retried forever.
    final gone = Moment.fromJson(momentJson(id: 'gone', title: 'Old Trip', unlockAt: DateTime.now()));
    await tester.runAsync(() => queue.add(gone, Uint8List.fromList([4]), 'b.jpg'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester, 3);
    expect(queue.mine.single.state, UploadState.failed);
    expect(find.textContaining("A photo for Old Trip couldn't upload"), findsOneWidget);
    await tapAndSettle(tester, find.byTooltip('Dismiss'));
    expect(queue.mine, isEmpty);
  });

  testWidgets('upload queue: a moment shows your photo as waiting until it uploads', (tester) async {
    final backend = FakeBackend()..offline = false;
    await setUpApi(backend);
    await startApp(tester);
    final queue = UploadQueue.instance;
    await tapAndSettle(tester, find.text('BIRTHDAY NIGHT'));

    backend.offline = true;
    final birthday = Moment.fromJson(
      momentJson(id: 'm1', title: 'Birthday Night', unlockAt: DateTime.now().add(const Duration(hours: 2))),
    );
    await tester.runAsync(() => queue.add(birthday, Uint8List.fromList([1]), 'a.jpg'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester, 3);
    expect(find.text('Your new photo'), findsOneWidget);
    expect(find.text("Saved. It'll upload when you're back online"), findsOneWidget);
    queue.stop();
  });

  testWidgets('sign-up sends the username; login takes an email or a username', (tester) async {
    final backend = FakeBackend();
    backend.routes['POST /api/auth/register'] = (_) => {
      'user': {...hassan, 'username': 'hassan.k'},
      'access_token': 'tok',
      'token_type': 'bearer',
      'created': true,
    };
    await setUpApi(backend, signedIn: false);
    await startApp(tester);
    expect(find.text('EMAIL OR USERNAME'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('email-field')), '@hassan.k');
    await tester.enterText(find.byKey(const Key('password-field')), 'sonderpass123');
    await tapAndSettle(tester, find.text('LOG IN'));
    expect(backend.lastBody('POST', '/api/auth/login'), {'email': '@hassan.k', 'password': 'sonderpass123'});
    expect(find.text('Hey, Hassan 👋'), findsOneWidget);
  });

  testWidgets('account: change name, username and email', (tester) async {
    final backend = FakeBackend();
    var me = {...hassan, 'username': 'hassan'};
    backend.routes['GET /api/users/me'] = (_) => {
      ...me,
      'memory_count': 1,
      'active_moment_count': 2,
      'friend_count': 3,
      'has_password': true,
    };
    backend.routes['PATCH /api/users/me'] = (req) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (body['username'] == 'ali') return http.Response(jsonEncode({'detail': 'That username is taken'}), 409);
      me = {...me, ...body};
      return me;
    };
    backend.routes['POST /api/auth/change-email'] = (req) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      me = {...me, 'email': body['new_email']};
      return {'status': 'changed', 'user': me};
    };
    final api = await setUpApi(backend);
    await startApp(tester);
    await tapAndSettle(tester, find.text('Profile'));
    expect(find.byKey(const Key('profile-handle')), findsOneWidget);
    expect(find.text('@hassan'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Account'), 300, scrollable: find.byType(Scrollable).first);
    await tapAndSettle(tester, find.text('Account'));
    expect(find.text('Account 🪪'), findsOneWidget);

    // Name
    await tapAndSettle(tester, find.byKey(const Key('account-name')));
    await tester.enterText(find.byKey(const Key('edit-name')), 'Hassan Khan');
    await tapAndSettle(tester, find.text('SAVE'));
    expect(backend.lastBody('PATCH', '/api/users/me'), {'name': 'Hassan Khan'});
    expect(api.currentUser.value!.name, 'Hassan Khan'); // updated everywhere

    // Username: a taken one is refused, a free one saves.
    await tapAndSettle(tester, find.byKey(const Key('account-username')));
    expect(find.text("That's your username now"), findsOneWidget);
    await tester.enterText(find.byKey(const Key('edit-username')), 'ali');
    await settle(tester, 6);
    await tapAndSettle(tester, find.text('SAVE'));
    expect(find.text('Pick a different username.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('edit-username')), 'hassan.k');
    await settle(tester, 6);
    await tapAndSettle(tester, find.text('SAVE'));
    expect(backend.lastBody('PATCH', '/api/users/me'), {'username': 'hassan.k'});
    expect(find.text('@hassan.k'), findsOneWidget); // back on Account

    // Email, confirmed with the password.
    await tapAndSettle(tester, find.byKey(const Key('account-email')));
    await tester.enterText(find.byKey(const Key('new-email')), 'new@sonder.app');
    await tapAndSettle(tester, find.text('CHANGE EMAIL'));
    expect(find.text('Enter your password to confirm.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('email-password')), 'sonderpass123');
    await tapAndSettle(tester, find.text('CHANGE EMAIL'));
    expect(backend.lastBody('POST', '/api/auth/change-email'), {
      'new_email': 'new@sonder.app',
      'password': 'sonderpass123',
    });
    expect(api.currentUser.value!.email, 'new@sonder.app');
    expect(find.text('new@sonder.app'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('account: when the server emails a code, the new email is confirmed with it', (tester) async {
    final backend = FakeBackend();
    String? pending;
    backend.routes['GET /api/users/me'] = (_) => {
      ...hassan,
      'memory_count': 1,
      'active_moment_count': 2,
      'friend_count': 3,
      'has_password': false,
      'google_linked': true,
      'pending_email': pending,
    };
    backend.routes['POST /api/auth/change-email'] = (req) {
      pending = (jsonDecode(req.body) as Map<String, dynamic>)['new_email'] as String;
      return {'status': 'code_sent', 'user': hassan};
    };
    backend.routes['POST /api/auth/change-email/confirm'] = (_) => {...hassan, 'email': pending};
    final api = await setUpApi(backend);
    await startApp(tester);
    await tapAndSettle(tester, find.text('Profile'));
    await tester.scrollUntilVisible(find.text('Account'), 300, scrollable: find.byType(Scrollable).first);
    await tapAndSettle(tester, find.text('Account'));
    expect(find.text('Set a password'), findsOneWidget); // Google account

    await tapAndSettle(tester, find.byKey(const Key('account-email')));
    expect(find.byKey(const Key('email-password')), findsNothing); // no password to ask for
    await tester.enterText(find.byKey(const Key('new-email')), 'new@sonder.app');
    await tapAndSettle(tester, find.text('CHANGE EMAIL'));
    expect(backend.lastBody('POST', '/api/auth/change-email'), {'new_email': 'new@sonder.app'});
    expect(find.text('Check your email ✉️'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('email-code')), '123456');
    await tapAndSettle(tester, find.text('CONFIRM NEW EMAIL'));
    expect(backend.lastBody('POST', '/api/auth/change-email/confirm'), {'code': '123456'});
    expect(api.currentUser.value!.email, 'new@sonder.app');
    await tester.pump(const Duration(seconds: 5));
  });
}
