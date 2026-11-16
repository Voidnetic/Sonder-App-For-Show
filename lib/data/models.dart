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

  /// Google has confirmed this person owns the email address.
  final bool emailVerified;
  final bool googleLinked;
  final bool hasPassword;
  final bool isAdmin;

  const UserProfile({
    required this.user,
    required this.memoryCount,
    required this.activeMomentCount,
    required this.friendCount,
    this.emailVerified = false,
    this.googleLinked = false,
    this.hasPassword = true,
    this.isAdmin = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    user: AppUser.fromJson(json),
    memoryCount: json['memory_count'] as int,
    activeMomentCount: json['active_moment_count'] as int,
    friendCount: json['friend_count'] as int,
    emailVerified: (json['email_verified'] as bool?) ?? false,
    googleLinked: (json['google_linked'] as bool?) ?? false,
    hasPassword: (json['has_password'] as bool?) ?? true,
    isAdmin: (json['is_admin'] as bool?) ?? false,
  );
}

/// How a person found in search relates to the signed-in user.
enum Relationship { none, friend, outgoing, incoming }

class UserSearchResult {
  final AppUser user;
  final Relationship relationship;

  /// The pending request's id when [relationship] is outgoing or incoming.
  final String? requestId;

  const UserSearchResult({required this.user, required this.relationship, this.requestId});

  factory UserSearchResult.fromJson(Map<String, dynamic> json) => UserSearchResult(
    user: AppUser.fromJson(json),
    relationship: Relationship.values.firstWhere(
      (r) => r.name == json['relationship'],
      orElse: () => Relationship.none,
    ),
    requestId: json['request_id'] as String?,
  );
}

class FriendRequest {
  final String id;
  final AppUser requester;
  final AppUser recipient;
  final String status;

  const FriendRequest({required this.id, required this.requester, required this.recipient, required this.status});

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id'] as String,
    requester: AppUser.fromJson(json['requester'] as Map<String, dynamic>),
    recipient: AppUser.fromJson(json['recipient'] as Map<String, dynamic>),
    status: json['status'] as String,
  );
}

/// What can be reported, matching the server's target types.
enum ReportTarget { user, memory, message }

/// Report reasons: the server's code and the label shown in the app.
const Map<String, String> reportReasons = {
  'nudity': 'Nudity or sexual content',
  'harassment': 'Harassment or bullying',
  'hate': 'Hate speech',
  'violence': 'Violence or threats',
  'self_harm': 'Self-harm',
  'spam': 'Spam or scam',
  'impersonation': 'Pretending to be someone',
  'other': 'Something else',
};

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

  /// Who added the newest photo and when ("Ahmed added a memory 10 min ago"). The photo itself stays hidden.
  final DateTime? lastCapturedAt;
  final AppUser? lastCapturedBy;

  /// "joined", or "invited" while the signed-in user hasn't accepted the invitation yet.
  final String myStatus;

  /// The friend who invited the signed-in user (shown on the invitation).
  final AppUser? invitedBy;

  /// When the signed-in user first opened it after it unlocked. Until then it stays on Home as Ready to Open.
  final DateTime? openedAt;

  /// Friends who were invited but haven't accepted yet.
  final int pendingCount;

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
    this.lastCapturedAt,
    this.lastCapturedBy,
    this.myStatus = 'joined',
    this.invitedBy,
    this.openedAt,
    this.pendingCount = 0,
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
    lastCapturedAt: json['last_captured_at'] == null ? null : _parseDate(json['last_captured_at']),
    lastCapturedBy: json['last_captured_by'] == null
        ? null
        : AppUser.fromJson(json['last_captured_by'] as Map<String, dynamic>),
    myStatus: (json['my_status'] as String?) ?? 'joined',
    invitedBy: json['invited_by'] == null ? null : AppUser.fromJson(json['invited_by'] as Map<String, dynamic>),
    openedAt: json['opened_at'] == null ? null : _parseDate(json['opened_at']),
    pendingCount: (json['pending_count'] as int?) ?? 0,
  );

  /// Computed from the clock rather than the server flag, so it flips the moment the countdown ends.
  bool get isUnlocked => !DateTime.now().toUtc().isBefore(unlockAt);

  /// Unlocked but not opened by the signed-in user yet: shown on Home with a "Ready to Open" badge.
  bool get isReady => isUnlocked && openedAt == null;

  bool get isInvitation => myStatus == 'invited';

  bool createdBy(String? userId) => creator.id == userId;
}

class Memory {
  final String id;
  final String momentId;
  final AppUser author;
  final bool locked;
  final String? imageUrl;
  final String? caption;
  final DateTime capturedAt;

  /// Posted by the signed-in user. Their own photos come with [imageUrl] even while locked.
  final bool mine;

  /// Hidden from the signed-in user's own view (only listed when asked for).
  final bool hidden;

  const Memory({
    required this.id,
    required this.momentId,
    required this.author,
    required this.locked,
    required this.imageUrl,
    required this.caption,
    required this.capturedAt,
    this.mine = false,
    this.hidden = false,
  });

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
    id: json['id'] as String,
    momentId: json['moment_id'] as String,
    author: AppUser.fromJson(json['author'] as Map<String, dynamic>),
    locked: (json['locked'] as bool?) ?? json['image_url'] == null,
    mine: (json['mine'] as bool?) ?? false,
    hidden: (json['hidden'] as bool?) ?? false,
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

  /// Set when this is a reaction or comment on one photo (from the slideshow), with its thumbnail.
  final String? memoryId;
  final String? memoryImageUrl;

  const ChatMessage({
    required this.id,
    required this.momentId,
    required this.author,
    required this.isSystem,
    required this.text,
    required this.createdAt,
    this.memoryId,
    this.memoryImageUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    momentId: json['moment_id'] as String,
    author: json['author'] == null ? null : AppUser.fromJson(json['author'] as Map<String, dynamic>),
    isSystem: json['type'] == 'system',
    text: json['text'] as String,
    createdAt: _parseDate(json['created_at']),
    memoryId: json['memory_id'] as String?,
    memoryImageUrl: json['memory_image_url'] as String?,
  );
}

/// Something that happened in a moment's live Hangout connection.
sealed class HangoutEvent {
  const HangoutEvent();

  /// Chat messages have no "event" key (the original format); presence and typing do.
  factory HangoutEvent.fromJson(Map<String, dynamic> json) => switch (json['event']) {
    'presence' => HangoutPresence({for (final id in json['user_ids'] as List<dynamic>) id as String}),
    'typing' => HangoutTyping(json['user_id'] as String, json['typing'] as bool),
    _ => HangoutMessage(ChatMessage.fromJson(json)),
  };
}

class HangoutMessage extends HangoutEvent {
  final ChatMessage message;
  const HangoutMessage(this.message);
}

/// Everyone who has this moment open right now ("Here now"), including you.
class HangoutPresence extends HangoutEvent {
  final Set<String> userIds;
  const HangoutPresence(this.userIds);
}

class HangoutTyping extends HangoutEvent {
  final String userId;
  final bool typing;
  const HangoutTyping(this.userId, this.typing);
}
