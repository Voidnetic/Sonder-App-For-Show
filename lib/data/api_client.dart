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
const String defaultServerUrl = String.fromEnvironment(
  'SONDER_API_URL',
  defaultValue: 'https://sonder-api-production.up.railway.app',
);

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// The answer to "can I use this username?".
class UsernameCheck {
  final String username;
  final bool available;
  final String? reason;

  const UsernameCheck(this.username, this.available, this.reason);
}

class SonderApi {
  SonderApi({http.Client? client}) : _client = client ?? http.Client();

  /// Shared instance used by the screens; tests replace it.
  static SonderApi instance = SonderApi();

  static const _kServerUrl = 'server_url';
  static const _kToken = 'access_token';
  static const _kUser = 'user';
  static const _kVerify = 'verification_required';
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;
  String _serverUrl = defaultServerUrl;
  String? _token;

  /// Runs just before signing out while the session is still valid (push notifications use it to
  /// stop notifications to this phone).
  Future<void> Function()? beforeLogout;
  bool _loggingOut = false;

  /// True while the signed-in person still has to enter the code emailed to them. The app shows the
  /// "Check your email" screen until it's done (only when the server sends email).
  final ValueNotifier<bool> verificationRequired = ValueNotifier<bool>(false);

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
      verificationRequired.value = prefs.getBool(_kVerify) ?? false;
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

  Future<void> register(String name, String email, String password, {String? username}) async {
    final json = await _send(
      'POST',
      '/auth/register',
      body: {'name': name.trim(), 'email': email.trim(), 'password': password, 'username': ?username?.trim()},
    );
    await _saveSession(json as Map<String, dynamic>);
  }

  /// Signs in with an ID token from Google Sign-In. Returns true when this created a new account.
  Future<bool> loginWithGoogle(String idToken) async {
    final json = await _send('POST', '/auth/google', body: {'id_token': idToken}) as Map<String, dynamic>;
    await _saveSession(json);
    return (json['created'] as bool?) ?? false;
  }

  Future<void> _setVerificationRequired(bool value) async {
    verificationRequired.value = value;
    await (await SharedPreferences.getInstance()).setBool(_kVerify, value);
  }

  /// Re-checks with the server whether this account still needs its email confirmed (for example after the
  /// server starts sending email). Best effort.
  Future<void> refreshVerification() async {
    if (_token == null) return;
    try {
      final json = await _send('GET', '/users/me') as Map<String, dynamic>;
      await _setVerificationRequired((json['verification_required'] as bool?) ?? false);
    } catch (_) {
      // Offline: keep the last known state.
    }
  }

  /// Emails a fresh 6-digit code. Asking again within a minute is refused by the server.
  Future<void> sendVerificationCode() => _send('POST', '/auth/verify-email/send');

  Future<void> verifyEmail(String code) async {
    final json = await _send('POST', '/auth/verify-email', body: {'code': code.trim()}) as Map<String, dynamic>;
    await _setVerificationRequired((json['verification_required'] as bool?) ?? false);
  }

  /// Emails a password-reset code if an account has this email (the answer is the same either way).
  Future<void> forgotPassword(String email) => _send('POST', '/auth/forgot-password', body: {'email': email.trim()});

  /// Sets a new password with the emailed code and signs in.
  Future<void> resetPassword(String email, String code, String newPassword) async {
    final json = await _send(
      'POST',
      '/auth/reset-password',
      body: {'email': email.trim(), 'code': code.trim(), 'new_password': newPassword},
    );
    await _saveSession(json as Map<String, dynamic>);
  }

  /// Permanently deletes the account on the server, then signs out (unless [signOut] is false, for callers
  /// that need to tidy up their UI first and then call [logout] themselves).
  /// Changes the password (or sets one on an account made with Google, with [currentPassword] null).
  Future<void> changePassword({String? currentPassword, required String newPassword}) =>
      _send('POST', '/auth/change-password', body: {'current_password': ?currentPassword, 'new_password': newPassword});

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
    await prefs.remove(_kVerify);
    await prefs.remove(_kMomentsCache); // the next person on this phone shouldn't see these groups
    verificationRequired.value = false;
    currentUser.value = null;
  }

  /// Whether a username can be used, and why not ("That username is taken"). Works signed out (sign-up).
  Future<UsernameCheck> checkUsername(String username) async {
    final json = await _send('GET', '/auth/username-available?username=${Uri.encodeQueryComponent(username.trim())}');
    final map = json as Map<String, dynamic>;
    return UsernameCheck(map['username'] as String, map['available'] as bool, map['reason'] as String?);
  }

  /// Changes your name and/or username, and updates the signed-in user everywhere in the app.
  Future<AppUser> updateAccount({String? name, String? username}) async {
    final json = await _send('PATCH', '/users/me', body: {'name': ?name?.trim(), 'username': ?username?.trim()});
    final user = AppUser.fromJson(json as Map<String, dynamic>);
    await _setUser(user);
    return user;
  }

  /// Changes your email. Returns true when it's changed straight away, false when a code was emailed to
  /// the new address (finish with [confirmEmailChange]).
  Future<bool> changeEmail(String newEmail, {String? password}) async {
    final json = await _send(
      'POST',
      '/auth/change-email',
      body: {'new_email': newEmail.trim(), 'password': ?password},
    ) as Map<String, dynamic>;
    await _setUser(AppUser.fromJson(json['user'] as Map<String, dynamic>));
    return json['status'] == 'changed';
  }

  Future<void> confirmEmailChange(String code) async {
    final json = await _send('POST', '/auth/change-email/confirm', body: {'code': code.trim()});
    await _setUser(AppUser.fromJson(json as Map<String, dynamic>));
  }

  Future<void> cancelEmailChange() => _send('DELETE', '/auth/change-email');

  Future<void> _setUser(AppUser user) async {
    await (await SharedPreferences.getInstance()).setString(_kUser, jsonEncode(user.toJson()));
    currentUser.value = user;
  }

  Future<void> _saveSession(Map<String, dynamic> json) async {
    final user = AppUser.fromJson(json['user'] as Map<String, dynamic>);
    _token = json['access_token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, _token!);
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
    await _setVerificationRequired((json['verification_required'] as bool?) ?? false);
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

  Future<void> registerDevice(String token) => _send('POST', '/devices', body: {'token': token, 'platform': 'android'});

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

  static const _kMomentsCache = 'active_moments_cache';

  /// Home's moments. A copy is kept on the phone so the camera still knows your groups with no internet.
  Future<List<Moment>> getActiveMoments() async {
    final json = await _send('GET', '/moments/active');
    unawaited(SharedPreferences.getInstance().then((p) => p.setString(_kMomentsCache, jsonEncode(json))));
    return _list(json, Moment.fromJson);
  }

  /// The moments from the last time [getActiveMoments] worked (empty if never).
  Future<List<Moment>> cachedActiveMoments() async {
    final saved = (await SharedPreferences.getInstance()).getString(_kMomentsCache);
    if (saved == null) return const [];
    try {
      return _list(jsonDecode(saved), Moment.fromJson);
    } catch (_) {
      return const [];
    }
  }

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

  /// Opens an unlocked moment. The first time, it moves from Home to the Past Vault.
  Future<Moment> revealMoment(String id) async =>
      Moment.fromJson(await _send('POST', '/moments/$id/reveal') as Map<String, dynamic>);

  /// Moments friends invited the signed-in user to, waiting for Accept or Decline.
  Future<List<Moment>> getInvitations() async => _list(await _send('GET', '/moments/invitations'), Moment.fromJson);

  Future<Moment> acceptInvitation(String momentId) async =>
      Moment.fromJson(await _send('POST', '/moments/$momentId/accept') as Map<String, dynamic>);

  Future<void> declineInvitation(String momentId) => _send('POST', '/moments/$momentId/decline');

  /// Leaves a moment. Your photos stay for the others; if nobody is left it's deleted.
  Future<void> leaveMoment(String momentId) => _send('POST', '/moments/$momentId/leave');

  /// Deletes a moment for everyone, with its photos and chat (only whoever made it).
  Future<void> deleteMoment(String momentId) => _send('DELETE', '/moments/$momentId');

  Future<List<Memory>> getMemories(String momentId, {bool includeHidden = false}) async => _list(
    await _send('GET', '/moments/$momentId/memories${includeHidden ? '?include_hidden=true' : ''}'),
    Memory.fromJson,
  );

  /// Uploads a photo. [takenAt] keeps the real time when it was uploaded later (from the upload queue);
  /// [background] allows minutes rather than seconds, for slow connections.
  Future<Memory> uploadMemory(
    String momentId,
    Uint8List bytes,
    String filename, {
    String? caption,
    DateTime? takenAt,
    bool background = false,
  }) => _uploadPhoto(
    'POST',
    '/moments/$momentId/memories',
    bytes,
    filename,
    caption: caption,
    fields: {if (takenAt != null) 'taken_at': takenAt.toUtc().toIso8601String()},
    timeout: background ? const Duration(minutes: 5) : _timeout,
  );

  /// Swaps your photo for another one (only while the moment is still counting down).
  Future<Memory> replaceMemory(String momentId, String memoryId, Uint8List bytes, String filename) =>
      _uploadPhoto('PUT', '/moments/$momentId/memories/$memoryId', bytes, filename);

  /// Deletes your photo (only while the moment is still counting down).
  Future<void> deleteMemory(String momentId, String memoryId) =>
      _send('DELETE', '/moments/$momentId/memories/$memoryId');

  /// Hides a photo from your own view of an unlocked moment (everyone else still sees it).
  Future<void> hideMemory(String momentId, String memoryId) =>
      _send('POST', '/moments/$momentId/memories/$memoryId/hide');

  Future<void> unhideMemory(String momentId, String memoryId) =>
      _send('DELETE', '/moments/$momentId/memories/$memoryId/hide');

  Future<Memory> _uploadPhoto(
    String method,
    String path,
    Uint8List bytes,
    String filename, {
    String? caption,
    Map<String, String> fields = const {},
    Duration timeout = _timeout,
  }) async {
    final request = http.MultipartRequest(method, _uri(path))
      ..headers.addAll(_headers(json: false))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: _imageType(filename)));
    if (caption != null && caption.trim().isNotEmpty) {
      request.fields['caption'] = caption.trim();
    }
    request.fields.addAll(fields);
    final json = await _handle(() async => http.Response.fromStream(await _client.send(request)), timeout: timeout);
    return Memory.fromJson(json as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> getMessages(String momentId) async =>
      _list(await _send('GET', '/moments/$momentId/messages'), ChatMessage.fromJson);

  /// Sends a chat message; with [memoryId] it's a reaction or comment on that photo (shown with its thumbnail).
  Future<ChatMessage> sendMessage(String momentId, String text, {String? memoryId}) async {
    final json = await _send('POST', '/moments/$momentId/messages', body: {'text': text, 'memory_id': ?memoryId});
    return ChatMessage.fromJson(json as Map<String, dynamic>);
  }

  /// Open Hangout connections, so [sendTyping] can reach the right one.
  final Map<String, WebSocketChannel> _hangouts = {};

  /// Live events for a moment: chat messages, who's here, who's typing. Cancelling the subscription
  /// closes the connection.
  Stream<HangoutEvent> hangoutStream(String momentId) {
    final base = Uri.parse(_serverUrl);
    final uri = base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/api/ws/moments/$momentId',
      queryParameters: {'token': _token ?? ''},
    );
    final channel = WebSocketChannel.connect(uri);
    // Connection failures also arrive as a stream error, which the caller handles.
    channel.ready.ignore();
    late final StreamController<HangoutEvent> controller;
    StreamSubscription<dynamic>? subscription;
    controller = StreamController<HangoutEvent>(
      onListen: () {
        _hangouts[momentId] = channel;
        subscription = channel.stream.listen(
          (data) => controller.add(HangoutEvent.fromJson(jsonDecode(data as String) as Map<String, dynamic>)),
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        if (_hangouts[momentId] == channel) _hangouts.remove(momentId);
        await subscription?.cancel();
        await channel.sink.close();
      },
    );
    return controller.stream;
  }

  /// Tells the others in the moment that you started or stopped typing. Never stored.
  void sendTyping(String momentId, bool typing) {
    try {
      _hangouts[momentId]?.sink.add(jsonEncode({'typing': typing}));
    } catch (_) {
      // A dropped connection just means nobody sees the typing dots; it reconnects by itself.
    }
  }

  /// Uploaded photos are stored as `/uploads/<file>` paths on the server.
  String imageUrl(String path) => path.startsWith('http') ? path : '$_serverUrl$path';

  /// Downloads a photo (to save it to the gallery). Allows a minute, for slow connections.
  Future<Uint8List> downloadImage(String path) async {
    try {
      final response = await _client.get(Uri.parse(imageUrl(path))).timeout(const Duration(minutes: 1));
      if (response.statusCode >= 200 && response.statusCode < 300 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      throw ApiException("Couldn't download the photo (${response.statusCode}).", statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException("Couldn't download the photo. Check your internet connection and try again.");
    }
  }

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

  Future<dynamic> _handle(Future<http.Response> Function() request, {Duration timeout = _timeout}) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
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
