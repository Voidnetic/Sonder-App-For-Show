import 'package:flutter/material.dart';

import '../data/models.dart';
import 'capture_screen.dart';

/// Captures a memory for one moment. Pops with `true` when a photo was uploaded.
class CameraScreen extends StatelessWidget {
  final Moment moment;

  const CameraScreen({super.key, required this.moment});

  @override
  Widget build(BuildContext context) => CaptureScreen(moment: moment);
}
