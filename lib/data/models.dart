import 'package:flutter/material.dart';

Color colorFromHex(String? hex, {Color fallback = const Color(0xFFE6E6FA)}) {
  if (hex == null) return fallback;
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

DateTime _parseDate(Object? value) => DateTime.parse(value as String).toUtc();

class AppUser {
  final String id;
  final String name;
  final String email;
  final String avatarColor;

  const AppUser({required this.id, required this.name, required this.email, required this.avatarColor});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        avatarColor: (json['avatar_color'] as String?) ?? '#E6E6FA',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'avatar_color': avatarColor};

  Color get color => colorFromHex(avatarColor);
  String get initial => name.isEmpty ? '?' : name.characters.first.toUpperCase();
}

class UserProfile {
  final AppUser user;
  final int memoryCount;
  final int activeMomentCount;
  final int friendCount;

  const UserProfile({
    required this.user,
    required this.memoryCount,
    required this.activeMomentCount,
    required this.friendCount,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        user: AppUser.fromJson(json),
        memoryCount: json['memory_count'] as int,
        activeMomentCount: json['active_moment_count'] as int,
        friendCount: json['friend_count'] as int,
      );
}

class Moment {
  final String id;
  final String title;
  final AppUser creator;
  final List<AppUser> participants;
  final Color accentColor;
  final DateTime unlockAt;
  final DateTime? revealedAt;
  final int memoryCount;
  final int friendCount;

  const Moment({
    required this.id,
    required this.title,
    required this.creator,
    required this.participants,
    required this.accentColor,
    required this.unlockAt,
    required this.revealedAt,
    required this.memoryCount,
    required this.friendCount,
  });

  factory Moment.fromJson(Map<String, dynamic> json) => Moment(
        id: json['id'] as String,
        title: json['title'] as String,
        creator: AppUser.fromJson(json['creator'] as Map<String, dynamic>),
        participants: (json['participants'] as List<dynamic>)
            .map((p) => AppUser.fromJson(p as Map<String, dynamic>))
            .toList(),
        accentColor: colorFromHex(json['accent_color'] as String?),
        unlockAt: _parseDate(json['unlock_at']),
        revealedAt: json['revealed_at'] == null ? null : _parseDate(json['revealed_at']),
        memoryCount: json['memory_count'] as int,
        friendCount: json['friend_count'] as int,
      );

  /// Computed from the clock rather than the server flag, so it flips the moment the countdown ends.
  bool get isUnlocked => !DateTime.now().toUtc().isBefore(unlockAt);
}

class Memory {
  final String id;
  final String momentId;
  final AppUser author;
  final bool locked;
  final String? imageUrl;
  final String? caption;
  final DateTime capturedAt;

  const Memory({
    required this.id,
    required this.momentId,
    required this.author,
    required this.locked,
    required this.imageUrl,
    required this.caption,
    required this.capturedAt,
  });

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
        id: json['id'] as String,
        momentId: json['moment_id'] as String,
        author: AppUser.fromJson(json['author'] as Map<String, dynamic>),
        locked: json['image_url'] == null,
        imageUrl: json['image_url'] as String?,
        caption: json['caption'] as String?,
        capturedAt: _parseDate(json['captured_at']),
      );
}

class ChatMessage {
  final String id;
  final String momentId;
  final AppUser? author;
  final bool isSystem;
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.momentId,
    required this.author,
    required this.isSystem,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        momentId: json['moment_id'] as String,
        author: json['author'] == null ? null : AppUser.fromJson(json['author'] as Map<String, dynamic>),
        isSystem: json['type'] == 'system',
        text: json['text'] as String,
        createdAt: _parseDate(json['created_at']),
      );
}
