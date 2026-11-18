import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';
import 'photo_store.dart';

enum UploadState {
  /// Next in line, or uploading right now.
  waiting,

  /// No connection (or the server is down). Tried again automatically.
  offline,

  /// The server said no for good (e.g. the moment was deleted). Shown until dismissed.
  failed,
}

/// A photo that was taken but hasn't reached the server yet.
class PendingUpload {
  final String id;
  final String userId;
  final String momentId;
  final String momentTitle;
  final String filename;
  final DateTime takenAt;
  final UploadState state;
  final String? error;

  const PendingUpload({
    required this.id,
    required this.userId,
    required this.momentId,
    required this.momentTitle,
    required this.filename,
    required this.takenAt,
    this.state = UploadState.waiting,
    this.error,
  });

  PendingUpload copyWith({UploadState? state, String? error}) => PendingUpload(
    id: id,
    userId: userId,
    momentId: momentId,
    momentTitle: momentTitle,
    filename: filename,
    takenAt: takenAt,
    state: state ?? this.state,
    error: error,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'moment_id': momentId,
    'moment_title': momentTitle,
    'filename': filename,
    'taken_at': takenAt.toUtc().toIso8601String(),
    'failed': state == UploadState.failed,
    'error': error,
  };

  factory PendingUpload.fromJson(Map<String, dynamic> json) => PendingUpload(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    momentId: json['moment_id'] as String,
    momentTitle: json['moment_title'] as String,
    filename: json['filename'] as String,
    takenAt: DateTime.parse(json['taken_at'] as String),
    state: json['failed'] == true ? UploadState.failed : UploadState.waiting,
    error: json['error'] as String?,
  );
}

/// Photos are saved here the instant they're taken, then uploaded in the background, one at a time, oldest
/// first. With no internet they wait and go up by themselves once it's back: on a timer, when the app comes
/// back to the front, and whenever another photo is added. The list is kept on the phone, so nothing is lost
/// if the app is closed. Photos only upload for the account that took them.
class UploadQueue with WidgetsBindingObserver {
  UploadQueue({PhotoStore? store, this.retryDelays = _defaultDelays}) : _store = store ?? PhotoStore.platform();

  static UploadQueue instance = UploadQueue();

  static const _kQueue = 'upload_queue';
  static const _defaultDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  final PhotoStore _store;

  /// How long to wait before trying again after each failed attempt in a row (the last one repeats).
  final List<Duration> retryDelays;

  /// Everything still to upload (and uploads that failed for good), oldest first.
  final ValueNotifier<List<PendingUpload>> items = ValueNotifier(const []);

  /// The moment id of each photo that just finished uploading, so open screens can refresh.
  final StreamController<String> _uploaded = StreamController<String>.broadcast();
  Stream<String> get uploaded => _uploaded.stream;

  SonderApi get _api => SonderApi.instance;
  bool _running = false;
  bool _started = false;
  Timer? _retry;
  int _failuresInARow = 0;
  int _counter = 0;

  /// The signed-in person's photos still to send, for a badge or banner.
  List<PendingUpload> get mine {
    final userId = _api.currentUser.value?.id;
    return [
      for (final u in items.value)
        if (u.userId == userId) u,
    ];
  }

  List<PendingUpload> pendingFor(String momentId) => [
    for (final u in mine)
      if (u.momentId == momentId && u.state != UploadState.failed) u,
  ];

  /// Reads the saved list and starts sending. Call once at startup, after the session is restored.
  Future<void> start() async {
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      _api.currentUser.addListener(kick); // someone signed in: send their waiting photos
    }
    final saved = (await SharedPreferences.getInstance()).getString(_kQueue);
    if (saved != null) {
      try {
        items.value = [
          for (final json in jsonDecode(saved) as List<dynamic>) PendingUpload.fromJson(json as Map<String, dynamic>),
        ];
      } catch (_) {
        items.value = const [];
      }
    }
    unawaited(kick());
  }

  /// Saves the photo on the phone and queues it for [moment]. Returns straight away; the upload happens in
  /// the background.
  Future<PendingUpload> add(Moment moment, Uint8List bytes, String filename) async {
    final userId = _api.currentUser.value?.id;
    if (userId == null) throw const ApiException('Please log in again.');
    final upload = PendingUpload(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_counter++}',
      userId: userId,
      momentId: moment.id,
      momentTitle: moment.title,
      filename: filename,
      takenAt: DateTime.now(),
    );
    await _store.save(upload.id, bytes);
    await _set([...items.value, upload]);
    _failuresInARow = 0;
    unawaited(kick());
    return upload;
  }

  /// Deletes the camera's temporary copy of a photo that is now queued.
  Future<void> discardTemp(String path) => _store.discardTemp(path);

  /// Forgets a photo that couldn't upload (deleting it from the phone).
  Future<void> dismiss(String id) async {
    await _store.delete(id);
    await _set([
      for (final u in items.value)
        if (u.id != id) u,
    ]);
  }

  /// Tries again now (e.g. the person tapped "Retry" or the app came back to the front).
  Future<void> kick() async {
    if (_running) return;
    _running = true;
    _retry?.cancel();
    try {
      while (true) {
        final userId = _api.currentUser.value?.id;
        if (userId == null) return;
        final next = items.value.where((u) => u.userId == userId && u.state != UploadState.failed).firstOrNull;
        if (next == null) return;
        final bytes = await _store.read(next.id);
        if (bytes == null) {
          await _set([
            for (final u in items.value)
              if (u.id != next.id) u,
          ]); // the file is gone
          continue;
        }
        try {
          await _api.uploadMemory(next.momentId, bytes, next.filename, takenAt: next.takenAt, background: true);
        } on ApiException catch (e) {
          final status = e.statusCode;
          if (status == 401) return; // signed out; it's sent once they log in again
          if (status == null || status == 408 || status == 429 || status >= 500) {
            // No internet, or the server is busy: wait and try again.
            await _replace(next.copyWith(state: UploadState.offline, error: e.message));
            final delay = retryDelays[_failuresInARow.clamp(0, retryDelays.length - 1)];
            _failuresInARow++;
            _retry = Timer(delay, kick);
            return;
          }
          // Refused for good (moment deleted, you left it, ...): keep it visible so the person knows.
          await _replace(next.copyWith(state: UploadState.failed, error: e.message));
          continue;
        }
        _failuresInARow = 0;
        await _store.delete(next.id);
        await _set([
          for (final u in items.value)
            if (u.id != next.id) u,
        ]);
        _uploaded.add(next.momentId);
      }
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _failuresInARow = 0;
      unawaited(kick());
    }
  }

  Future<void> _replace(PendingUpload upload) => _set([for (final u in items.value) u.id == upload.id ? upload : u]);

  Future<void> _set(List<PendingUpload> next) async {
    items.value = next;
    await (await SharedPreferences.getInstance()).setString(_kQueue, jsonEncode([for (final u in next) u.toJson()]));
  }

  /// Stops retrying (tests).
  @visibleForTesting
  void stop() {
    _retry?.cancel();
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _api.currentUser.removeListener(kick);
      _started = false;
    }
  }
}
