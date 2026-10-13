import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class PickedPhoto {
  final Uint8List bytes;
  final String filename;

  const PickedPhoto(this.bytes, this.filename);
}

/// Opens the phone camera (or gallery). Returns null if the user backs out.
Future<PickedPhoto?> pickPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
  if (file == null) return null;
  return PickedPhoto(await file.readAsBytes(), file.name);
}
