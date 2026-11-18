import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'photo_store.dart';

PhotoStore createStore() => _FilePhotoStore();

/// Files in the app's private support folder (on Android /data/data/com.mhcorps.sonder/files), which no
/// other app or the Gallery can read, and which isn't scanned into the photo library.
class _FilePhotoStore implements PhotoStore {
  Directory? _dir;

  Future<File> _file(String id) async {
    final dir = _dir ??= Directory('${(await getApplicationSupportDirectory()).path}/pending_uploads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$id');
  }

  @override
  Future<void> save(String id, Uint8List bytes) async => (await _file(id)).writeAsBytes(bytes, flush: true);

  @override
  Future<Uint8List?> read(String id) async {
    final file = await _file(id);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> discardTemp(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Only tidying up the camera's cache.
    }
  }
}
