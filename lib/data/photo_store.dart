import 'package:flutter/foundation.dart';

import 'photo_store_memory.dart' if (dart.library.io) 'photo_store_io.dart' as impl;

/// Where photos waiting to upload are kept until they reach the server.
///
/// On the phone that's Sonder's private app storage: the Gallery, the Files app and other apps can't see
/// it, and the app never shows these photos (they stay hidden until the reveal, like any other). Each one
/// is deleted the moment it has uploaded.
abstract class PhotoStore {
  Future<void> save(String id, Uint8List bytes);
  Future<Uint8List?> read(String id);
  Future<void> delete(String id);

  /// Deletes a temporary file the camera wrote (once the photo is safely in this store).
  Future<void> discardTemp(String path);

  /// The real store for this platform (private files on Android and iOS).
  static PhotoStore platform() => impl.createStore();
}

/// Keeps photos in memory. Used on the web preview and in tests.
class MemoryPhotoStore implements PhotoStore {
  final Map<String, Uint8List> photos = {};

  @override
  Future<void> save(String id, Uint8List bytes) async => photos[id] = bytes;

  @override
  Future<Uint8List?> read(String id) async => photos[id];

  @override
  Future<void> delete(String id) async => photos.remove(id);

  @override
  Future<void> discardTemp(String path) async {}
}
