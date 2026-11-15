import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'google_auth.dart';
import 'models.dart';

/// The live Sonder server on Railway. To test against a backend on your computer, build with
/// `--dart-define=SONDER_API_URL=http://192.168.1.20:8000` (users can't change the server in the app).
const String defaultServerUrl =
    String.fromEnvironment('SONDER_API_URL', defaultValue: 'https://sonder-api-production.up.railway.app');

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class SonderApi {
  SonderApi({http.Client? client}) : _client = client ?? http.Client();

  /// Shared instance used by the screens; tests replace it.
  static SonderApi instance = SonderApi();

  static const _kServerUrl = 'server_url';
  static const _kToken = 'access_token';
  static const _kUser = 'user';
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;
  String _serverUrl = defaultServerUrl;
  String? _token;

  /// Runs just before signing out while the session is still valid (push notifications use it to
  /// stop notifications to this phone).
  Future<void> Function()? beforeLogout;
  bool _loggingOut = false;

  /// The signed-in user, or null when signed out. The app shows the login screen whenever this is null.
  final ValueNotifier<AppUser?> currentUser = ValueNotifier<AppUser?>(null);

  String get serverUrl => _serverUrl;

  // ---------------------------------------------------------------- session

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    // Older test builds let people type a server address. Release builds always use the Sonder server and
    // forget any saved address, so nobody stays stuck on a laptop IP; debug builds and tests still honour it.
    final saved = prefs.getString(_kServerUrl);
    if (kReleaseMode) {
      if (saved != null) await prefs.remove(_kServerUrl);
      _serverUrl = defaultServerUrl;
    } else {
      _serverUrl = saved ?? defaultServerUrl;
    }
    _token = prefs.getString(_kToken);
    final userJson = prefs.getString(_kUser);
    if (_token != null && userJson != null) {
      currentUser.value = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    }
  }

  /// Points the client at another backend. Only for tests: the app itself always uses [defaultServerUrl].
  @visibleForTesting
  Future<void> setServerUrl(String url) async {
    var cleaned = url.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    _serverUrl = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerUrl, cleaned);
  }

  Future<void> login(String email, String password) async {
    final json = await _send('POST', '/auth/login', body: {'email': email.trim(), 'password': password});
    await _saveSession(json as Map<String, dynamic>);
  }

  Future<void> register(String name, String email, String password) async {
    final json = await _send(
      'POST',
      '/auth/register',
      body: {'name': name.trim(), 'email': email.trim(), 'password': password},
    );
    await _saveSession(json as Map<String, dynamic>);
  }

  /// Signs in with an ID token from Google Sign-In. Returns true when this created a new account.
  Future<bool> loginWithGoogle(String idToken) async {
    final json = await _send('POST', '/auth/google', body: {'id_token': idToken}) as Map<String, dynamic>;
    await _saveSession(json);
    return (json['created'] as bool?) ?? false;
  }

  /// Permanently deletes the account on the server, then signs out (unless [signOut] is false, for callers
  /// that need to tidy up their UI first and then call [logout] themselves).
  Future<void> deleteAccount({bool signOut = true}) async {
    await _send('DELETE', '/users/me');
    if (signOut) await logout();
  }

  Future<void> logout() async {
    final hook = beforeLogout;
    if (hook != null && !_loggingOut && _token != null) {
      _loggingOut = true; // a 401 inside the hook calls logout() again; don't recurse
      try {
        await hook();
      } catch (_) {
        // Signing out must always work.
      } finally {
        _loggingOut = false;
      }
    }
    // Also forget the Google account, so the next sign-in shows the account picker again.
    unawaited(GoogleAuth.signOut());
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
    currentUser.value = null;
  }

  Future<void> _saveSession(Map<String, dynamic> json) async {
    final user = AppUser.fromJson(json['user'] as Map<String, dynamic>);
    _token = json['access_token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, _token!);
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
    currentUser.value = user;
  }

  // ---------------------------------------------------------------- endpoints

  Future<UserProfile> getProfile() async =>
      UserProfile.fromJson(await _send('GET', '/users/me') as Map<String, dynamic>);

  Future<List<AppUser>> getFriends() async => _list(await _send('GET', '/friends'), AppUser.fromJson);

  // Friends

  Future<List<UserSearchResult>> searchUsers(String query) async =>
      _list(await _send('GET', '/users/search?q=${Uri.encodeQueryComponent(query.trim())}'), UserSearchResult.fromJson);

  /// [incoming] requests were sent to you; otherwise the ones you sent.
  Future<List<FriendRequest>> getFriendRequests({bool incoming = true}) async => _list(
    await _send('GET', '/friends/requests?direction=${incoming ? 'incoming' : 'outgoing'}'),
    FriendRequest.fromJson,
  );

  Future<FriendRequest> sendFriendRequest(String userId) async => FriendRequest.fromJson(
    await _send('POST', '/friends/requests', body: {'recipient_id': userId}) as Map<String, dynamic>,
  );

  Future<void> acceptFriendRequest(String requestId) => _send('PATCH', '/friends/requests/$requestId/accept');

  Future<void> declineFriendRequest(String requestId) => _send('PATCH', '/friends/requests/$requestId/decline');

  Future<void> cancelFriendRequest(String requestId) => _send('DELETE', '/friends/requests/$requestId');

  Future<void> removeFriend(String userId) => _send('DELETE', '/friends/$userId');

  // Push notifications

  Future<void> registerDevice(String token) =>
      _send('POST', '/devices', body: {'token': token, 'platform': 'android'});

  Future<void> unregisterDevice(String token) =>
      _send('POST', '/devices/unregister', body: {'token': token, 'platform': 'android'});

  // Safety

  Future<List<AppUser>> getBlockedUsers() async => _list(await _send('GET', '/blocks'), AppUser.fromJson);

  Future<void> blockUser(String userId) => _send('POST', '/blocks', body: {'user_id': userId});

  Future<void> unblockUser(String userId) => _send('DELETE', '/blocks/$userId');

  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required String reason,
    String? details,
    bool alsoBlock = false,
  }) => _send(
    'POST',
    '/reports',
    body: {
      'target_type': target.name,
      'target_id': targetId,
      'reason': reason,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      'block': alsoBlock,
    },
  );

  /// Public web pages served by the backend (also linked from the Play Store listing).
  String get privacyPolicyUrl => '$_serverUrl/privacy';
  String get termsUrl => '$_serverUrl/terms';
  String get deleteAccountUrl => '$_serverUrl/delete-account';

  Future<List<Moment>> getActiveMoments() async => _list(await _send('GET', '/moments/active'), Moment.fromJson);

  Future<List<Moment>> getArchivedMoments() async => _list(await _send('GET', '/moments/archive'), Moment.fromJson);

  Future<Moment> getMoment(String id) async =>
      Moment.fromJson(await _send('GET', '/moments/$id') as Map<String, dynamic>);

  Future<Moment> createMoment({
    required String title,
    required List<String> participantIds,
    required DateTime unlockAt,
    required String accentColor,
  }) async {
    final json = await _send(
      'POST',
      '/moments',
      body: {
        'title': title,
        'participant_ids': participantIds,
        'unlock_at': unlockAt.toUtc().toIso8601String(),
        'accent_color': accentColor,
      },
    );
    return Moment.fromJson(json as Map<String, dynamic>);
  }

  Future<Moment> revealMoment(String id) async =>
      Moment.fromJson(await _send('POST', '/moments/$id/reveal') as Map<String, dynamic>);

  Future<List<Memory>> getMemories(String momentId) async =>
      _list(await _send('GET', '/moments/$momentId/memories'), Memory.fromJson);

  Future<Memory> uploadMemory(String momentId, Uint8List bytes, String filename, {String? caption}) async {
    final request = http.MultipartRequest('POST', _uri('/moments/$momentId/memories'))
      ..headers.addAll(_headers(json: false))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: _imageType(filename)));
    if (caption != null && caption.trim().isNotEmpty) {
      request.fields['caption'] = caption.trim();
    }
    final json = await _handle(() async => http.Response.fromStream(await _client.send(request)));
    return Memory.fromJson(json as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> getMessages(String momentId) async =>
      _list(await _send('GET', '/moments/$momentId/messages'), ChatMessage.fromJson);

  Future<ChatMessage> sendMessage(String momentId, String text) async {
    final json = await _send('POST', '/moments/$momentId/messages', body: {'text': text});
    return ChatMessage.fromJson(json as Map<String, dynamic>);
  }

  /// Live Hangout messages for a moment. Cancelling the subscription closes the connection.
  Stream<ChatMessage> hangoutStream(String momentId) {
    final base = Uri.parse(_serverUrl);
    final uri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/api/ws/moments/$momentId',
      queryParameters: {'token': _token ?? ''},
    );
    final channel = WebSocketChannel.connect(uri);
    // Connection failures also arrive as a stream error, which the caller handles.
    channel.ready.ignore();
    late final StreamController<ChatMessage> controller;
    StreamSubscription<dynamic>? subscription;
    controller = StreamController<ChatMessage>(
      onListen: () {
        subscription = channel.stream.listen(
          (data) => controller.add(ChatMessage.fromJson(jsonDecode(data as String) as Map<String, dynamic>)),
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        await subscription?.cancel();
        await channel.sink.close();
      },
    );
    return controller.stream;
  }

  /// Uploaded photos are stored as `/uploads/<file>` paths on the server.
  String imageUrl(String path) => path.startsWith('http') ? path : '$_serverUrl$path';

  // ---------------------------------------------------------------- plumbing

  Uri _uri(String path) => Uri.parse('$_serverUrl/api$path');

  Map<String, String> _headers({bool json = true}) => {
    if (json) 'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> _send(String method, String path, {Object? body}) {
    return _handle(() {
      final uri = _uri(path);
      final encoded = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'GET':
          return _client.get(uri, headers: _headers());
        case 'POST':
          return _client.post(uri, headers: _headers(), body: encoded);
        case 'PATCH':
          return _client.patch(uri, headers: _headers(), body: encoded);
        case 'DELETE':
          return _client.delete(uri, headers: _headers());
        default:
          throw ArgumentError('Unsupported method $method');
      }
    });
  }

  Future<dynamic> _handle(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Can't connect to Sonder. Check your internet connection and try again.");
    }

    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : _tryDecode(text);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (response.statusCode == 401 && _token != null) {
      await logout();
      throw const ApiException('Your session expired. Please log in again.', statusCode: 401);
    }
    throw ApiException(_errorMessage(decoded, response.statusCode), statusCode: response.statusCode);
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  /// FastAPI errors look like {"detail": "..."} or {"detail": [{"msg": "..."}]} for validation errors.
  static String _errorMessage(Object? decoded, int status) {
    if (decoded is Map && decoded['detail'] != null) {
      final detail = decoded['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty && detail.first is Map) {
        final msg = (detail.first as Map)['msg'];
        if (msg is String) return msg.replaceFirst('Value error, ', '');
      }
    }
    return 'Something went wrong (error $status).';
  }

  static List<T> _list<T>(Object? json, T Function(Map<String, dynamic>) parse) =>
      (json as List<dynamic>).map((e) => parse(e as Map<String, dynamic>)).toList();

  static MediaType _imageType(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'heic' || 'heif' => MediaType('image', 'heic'),
      _ => MediaType('image', 'jpeg'),
    };
  }
}
