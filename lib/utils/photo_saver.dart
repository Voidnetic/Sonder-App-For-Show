import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

import '../data/api_client.dart';
import '../data/models.dart';

class PhotoSaveException implements Exception {
  final String message;
  const PhotoSaveException(this.message);

  @override
  String toString() => message;
}

/// Saves revealed photos to the phone's gallery, in a "Sonder" album. Only photos from unlocked moments
/// can reach here: locked ones never have a link to download.
class PhotoSaver {
  static const album = 'Sonder';

  /// Tests replace the gallery with this.
  @visibleForTesting
  static Future<void> Function(Uint8List bytes, String name)? saveOverride;

  /// Downloads [memory]'s photo and adds it to the gallery.
  static Future<void> saveMemory(Memory memory) async {
    final url = memory.imageUrl;
    if (memory.locked || url == null) {
      throw const PhotoSaveException('This photo is still locked.');
    }
    final bytes = await SonderApi.instance.downloadImage(url);
    await save(bytes, 'sonder_${memory.id}');
  }

  static Future<void> save(Uint8List bytes, String name) async {
    final override = saveOverride;
    if (override != null) return override(bytes, name);
    try {
      if (!await Gal.hasPermission(toAlbum: true) && !await Gal.requestPermission(toAlbum: true)) {
        throw const PhotoSaveException('Allow Sonder to add photos in your phone settings, then try again.');
      }
      await Gal.putImageBytes(bytes, album: album, name: name);
    } on GalException catch (e) {
      throw PhotoSaveException(switch (e.type) {
        GalExceptionType.permissionDenied => 'Allow Sonder to add photos in your phone settings, then try again.',
        GalExceptionType.notEnoughSpace => 'Your phone is out of space.',
        _ => "Couldn't save the photo. Please try again.",
      });
    }
  }
}
