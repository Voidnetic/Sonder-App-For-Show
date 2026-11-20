import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class PickedPhoto {
  final Uint8List bytes;
  final String filename;

  const PickedPhoto(this.bytes, this.filename);
}

/// The longest side photos are uploaded at (5 MP for a 4:3 photo): sharp on any phone screen and when saved
/// to the gallery, and still about 1 MB, so uploads stay quick on slow connections.
const int maxPhotoSide = 2560;
const int _photoQuality = 88;

/// Opens the phone camera (or gallery). Returns null if the user backs out.
Future<PickedPhoto?> pickPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: maxPhotoSide.toDouble(),
    maxHeight: maxPhotoSide.toDouble(),
    imageQuality: _photoQuality,
  );
  if (file == null) return null;
  return PickedPhoto(await file.readAsBytes(), file.name);
}

/// Shrinks a full-resolution camera photo so its short side is 1920 px (2560 × 1920 for a 4:3 photo),
/// turned the right way up, as a high-quality JPEG without the camera's location data. Falls back to the
/// original if the phone can't compress it (or on the web preview and in tests).
Future<Uint8List> shrinkPhoto(Uint8List original) async {
  if (kIsWeb) return original;
  try {
    final shrunk = await FlutterImageCompress.compressWithList(
      original,
      minWidth: maxPhotoSide * 3 ~/ 4,
      minHeight: maxPhotoSide * 3 ~/ 4,
      quality: _photoQuality,
      keepExif: false,
    );
    return shrunk.isEmpty || shrunk.length > original.length ? original : shrunk;
  } catch (_) {
    return original;
  }
}
