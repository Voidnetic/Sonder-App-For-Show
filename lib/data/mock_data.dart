import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Moment {
  final String title;
  final int memoryCount;
  final int friendCount;
  final String unlockText;
  final Color accentColor;
  final bool isLocked;

  Moment({
    required this.title,
    required this.memoryCount,
    required this.friendCount,
    required this.unlockText,
    required this.accentColor,
    this.isLocked = true,
  });
}

class MockData {
  static const String userName = "Hassan";
  static final List<String> friends = ["Ali", "Ahmed", "Hajra", "Manaal"];
  
  static final List<Moment> activeMoments = [
    Moment(
      title: "Birthday Night",
      memoryCount: 24,
      friendCount: 6,
      unlockText: "02 : 14 : 37",
      accentColor: AppTheme.kLavender,
    ),
    Moment(
      title: "Murree Trip",
      memoryCount: 67,
      friendCount: 8,
      unlockText: "tomorrow at 9 AM",
      accentColor: AppTheme.kSoftMint,
    ),
  ];
  static void addMoment(Moment moment) {
    activeMoments.insert(0, moment);
  }
}

